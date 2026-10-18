import AppKit
import Foundation

/// Tables (CSV, TSV, XLSX) and structured data (JSON, PLIST), without Office.
public enum DataFiles {
    /// A table is a list of rows; the first row is the header when there is one.
    public typealias Table = [[String]]

    // MARK: Reading

    public static func readTable(_ url: URL) async throws -> Table {
        switch url.pathExtension.lowercased() {
        case "csv": return parseDelimited(try text(url), separator: detectSeparator(try text(url)))
        case "tsv": return parseDelimited(try text(url), separator: "\t")
        case "xlsx": return try await readXLSX(url)
        case "json": return try tableFromJSON(try JSONSerialization.jsonObject(with: Data(contentsOf: url), options: [.fragmentsAllowed]))
        case "plist":
            let object = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
            return try tableFromJSON(jsonSafe(object))
        default: throw KumquatError.unsupported(url.pathExtension.uppercased())
        }
    }

    static func text(_ url: URL) throws -> String {
        if let s = try? String(contentsOf: url, encoding: .utf8) { return s.hasPrefix("\u{FEFF}") ? String(s.dropFirst()) : s }
        if let s = try? String(contentsOf: url, encoding: .windowsCP1252) { return s }
        throw KumquatError.unreadable(url)
    }

    /// Commas unless the first line clearly uses semicolons (common in European Excel exports).
    static func detectSeparator(_ text: String) -> Character {
        let firstLine = text.prefix { $0 != "\n" }
        return firstLine.filter { $0 == ";" }.count > firstLine.filter { $0 == "," }.count ? ";" : ","
    }

    /// RFC 4180 parsing: quoted fields, doubled quotes, newlines inside quotes.
    public static func parseDelimited(_ text: String, separator: Character) -> Table {
        var rows: Table = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text)
        if chars.last != "\n" { chars.append("\n") }
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if inQuotes {
                if c == "\"" {
                    if i + 1 < chars.count, chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else if c == "\"" && field.isEmpty {
                inQuotes = true
            } else if c == separator {
                row.append(field); field = ""
            } else if c == "\n" || c == "\r\n" {
                row.append(field); field = ""
                if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
                row = []
            } else if c != "\r" {
                field.append(c)
            }
            i += 1
        }
        return rows
    }

    /// JSON arrays of objects become rows with a header of all keys; arrays of arrays stay as they are.
    static func tableFromJSON(_ object: Any) throws -> Table {
        var items: [Any]
        if let array = object as? [Any] {
            items = array
        } else if let dict = object as? [String: Any] {
            // A single object: either it wraps the real list, or it becomes key/value rows.
            if dict.count == 1, let inner = dict.values.first as? [Any] {
                items = inner
            } else {
                return [["key", "value"]] + dict.keys.sorted().map { [$0, cell(dict[$0] as Any)] }
            }
        } else {
            throw KumquatError.badData("This JSON isn't a list of rows.")
        }
        if items.allSatisfy({ $0 is [Any] }) {
            return items.map { ($0 as! [Any]).map(cell) }
        }
        var keys: [String] = []
        for case let obj as [String: Any] in items {
            for key in obj.keys.sorted() where !keys.contains(key) { keys.append(key) }
        }
        guard !keys.isEmpty else { return items.map { [cell($0)] } }
        return [keys] + items.map { item in
            let obj = item as? [String: Any] ?? [:]
            return keys.map { obj[$0].map(cell) ?? "" }
        }
    }

    static func cell(_ value: Any) -> String {
        switch value {
        case let s as String: return s
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() { return n.boolValue ? "true" : "false" }
            return n.stringValue
        case is NSNull: return ""
        default:
            if JSONSerialization.isValidJSONObject(value), let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]) {
                return String(decoding: data, as: UTF8.self)
            }
            return "\(value)"
        }
    }

    // MARK: Writing

    public static func write(_ table: Table, to url: URL, format: OutputFormat, title: String) async throws {
        switch format {
        case .csv: try Data(delimited(table, separator: ",").utf8).write(to: url)
        case .tsv: try Data(delimited(table, separator: "\t").utf8).write(to: url)
        case .json: try jsonData(table).write(to: url)
        case .xlsx: try await writeXLSX(table, to: url)
        case .html: try Data(html(table, title: title).utf8).write(to: url)
        case .pdf:
            let page = html(table, title: title)
            try await MainActor.run {
                guard let text = NSAttributedString(html: Data(page.utf8), documentAttributes: nil) else { throw KumquatError.writeFailed(url) }
                try Documents.writePDF(text, to: url, landscape: (table.first?.count ?? 0) > 6)
            }
        default: throw KumquatError.unsupported(format.label)
        }
    }

    public static func delimited(_ table: Table, separator: String) -> String {
        table.map { row in
            row.map { field in
                let needsQuotes = field.contains(separator) || field.contains("\"") || field.contains("\n") || field.contains("\r")
                return needsQuotes ? "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\"" : field
            }.joined(separator: separator)
        }.joined(separator: "\n") + "\n"
    }

    static func jsonData(_ table: Table) throws -> Data {
        guard let header = table.first else { return Data("[]".utf8) }
        let objects: [[String: Any]] = table.dropFirst().map { row in
            var obj: [String: Any] = [:]
            for (i, key) in header.enumerated() {
                let raw = i < row.count ? row[i] : ""
                obj[key.isEmpty ? "column\(i + 1)" : key] = typed(raw)
            }
            return obj
        }
        return try JSONSerialization.data(withJSONObject: objects, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    }

    /// Numbers and booleans become real JSON values.
    static func typed(_ s: String) -> Any {
        if s == "true" { return true }
        if s == "false" { return false }
        if let i = Int(s), String(i) == s { return i }
        if let d = Double(s), s.contains("."), !s.hasPrefix("."), d.isFinite { return d }
        return s
    }

    static func html(_ table: Table, title: String) -> String {
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }
        var out = """
        <!doctype html><html><head><meta charset="utf-8"><title>\(esc(title))</title>
        <style>body{font-family:-apple-system,Helvetica,sans-serif;font-size:11px;margin:24px}
        table{border-collapse:collapse}th,td{border:1px solid #ccc;padding:4px 8px;text-align:left;vertical-align:top}
        th{background:#f3f3f3;font-weight:600}tr:nth-child(even) td{background:#fafafa}</style></head><body><table>
        """
        for (i, row) in table.enumerated() {
            let tag = i == 0 ? "th" : "td"
            out += "<tr>" + row.map { "<\(tag)>\(esc($0))</\(tag)>" }.joined() + "</tr>\n"
        }
        return out + "</table></body></html>"
    }

    // MARK: PLIST ↔ JSON

    public static func plistToJSON(_ url: URL, to output: URL) throws {
        let object = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let data = try JSONSerialization.data(withJSONObject: jsonSafe(object), options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: output)
    }

    public static func jsonToPlist(_ url: URL, to output: URL) throws {
        let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        let data = try PropertyListSerialization.data(fromPropertyList: plistSafe(object), format: .xml, options: 0)
        try data.write(to: output)
    }

    /// Dates and data blobs aren't valid JSON, so they become strings.
    static func jsonSafe(_ value: Any) -> Any {
        switch value {
        case let d as [String: Any]: return d.mapValues(jsonSafe)
        case let a as [Any]: return a.map(jsonSafe)
        case let date as Date: return ISO8601DateFormatter().string(from: date)
        case let data as Data: return data.base64EncodedString()
        default: return value
        }
    }

    /// Property lists can't hold null.
    static func plistSafe(_ value: Any) -> Any {
        switch value {
        case let d as [String: Any]: return d.filter { !($0.value is NSNull) }.mapValues(plistSafe)
        case let a as [Any]: return a.filter { !($0 is NSNull) }.map(plistSafe)
        default: return value
        }
    }

    // MARK: XLSX

    /// Reads the first worksheet of an Excel file.
    public static func readXLSX(_ url: URL) async throws -> Table {
        let folder = try Archives.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try await Archives.extract(url, into: folder)
        let xl = folder.appendingPathComponent("xl")
        var shared: [String] = []
        if let data = try? Data(contentsOf: xl.appendingPathComponent("sharedStrings.xml")) {
            shared = SharedStringsParser.parse(data)
        }
        let sheets = (try? FileManager.default.contentsOfDirectory(atPath: xl.appendingPathComponent("worksheets").path)) ?? []
        guard let first = sheets.filter({ $0.hasSuffix(".xml") }).sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending }).first,
              let data = try? Data(contentsOf: xl.appendingPathComponent("worksheets").appendingPathComponent(first)) else {
            throw KumquatError.unreadable(url)
        }
        return SheetParser.parse(data, shared: shared)
    }

    public static func writeXLSX(_ table: Table, to url: URL) async throws {
        let folder = try Archives.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        func put(_ path: String, _ content: String) throws {
            let file = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: file)
        }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\"", with: "&quot;")
        }
        var rows = ""
        for (r, row) in table.enumerated() {
            rows += "<row r=\"\(r + 1)\">"
            for (c, value) in row.enumerated() {
                let ref = columnName(c) + "\(r + 1)"
                let style = r == 0 ? " s=\"1\"" : ""
                if r > 0, let n = Double(value), value.trimmingCharacters(in: .whitespaces) == value, !value.isEmpty, n.isFinite {
                    rows += "<c r=\"\(ref)\"\(style)><v>\(value)</v></c>"
                } else if !value.isEmpty {
                    rows += "<c r=\"\(ref)\" t=\"inlineStr\"\(style)><is><t xml:space=\"preserve\">\(esc(value))</t></is></c>"
                }
            }
            rows += "</row>"
        }
        let xml = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        try put("[Content_Types].xml", xml + """
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>
        """)
        try put("_rels/.rels", xml + """
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>
        """)
        try put("xl/workbook.xml", xml + """
        <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets></workbook>
        """)
        try put("xl/_rels/workbook.xml.rels", xml + """
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>
        """)
        try put("xl/styles.xml", xml + """
        <styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><fonts count="2"><font><sz val="11"/><name val="Calibri"/></font><font><b/><sz val="11"/><name val="Calibri"/></font></fonts><fills count="2"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill></fills><borders count="1"><border/></borders><cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs><cellXfs count="2"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/><xf numFmtId="0" fontId="1" fillId="0" borderId="0" xfId="0" applyFont="1"/></cellXfs></styleSheet>
        """)
        try put("xl/worksheets/sheet1.xml", xml + """
        <worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetViews><sheetView workbookViewId="0"><pane ySplit="1" topLeftCell="A2" activePane="bottomLeft" state="frozen"/></sheetView></sheetViews><sheetData>\(rows)</sheetData></worksheet>
        """)
        try? FileManager.default.removeItem(at: url)
        try await Engines.run(Archives.zipTool, ["-r", "-X", "-q", url.path, "[Content_Types].xml", "_rels", "xl"], currentDirectory: folder)
    }

    static func columnName(_ index: Int) -> String {
        var n = index + 1, name = ""
        while n > 0 {
            let r = (n - 1) % 26
            name = String(UnicodeScalar(65 + r)!) + name
            n = (n - 1) / 26
        }
        return name
    }

    static func columnIndex(_ ref: String) -> Int {
        var n = 0
        for c in ref.unicodeScalars where c.value >= 65 && c.value <= 90 { n = n * 26 + Int(c.value - 64) }
        return max(n - 1, 0)
    }
}

/// Reads xl/sharedStrings.xml.
private final class SharedStringsParser: NSObject, XMLParserDelegate {
    var strings: [String] = []
    private var current = ""
    private var inText = false
    private var inPhonetic = false

    static func parse(_ data: Data) -> [String] {
        let p = SharedStringsParser()
        let parser = XMLParser(data: data)
        parser.delegate = p
        parser.parse()
        return p.strings
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes: [String: String] = [:]) {
        switch name {
        case "si": current = ""
        case "rPh": inPhonetic = true
        case "t": inText = !inPhonetic
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inText { current += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "t": inText = false
        case "rPh": inPhonetic = false
        case "si": strings.append(current)
        default: break
        }
    }
}

/// Reads one worksheet into rows, filling gaps for empty cells.
private final class SheetParser: NSObject, XMLParserDelegate {
    var rows: [Int: [Int: String]] = [:]
    private let shared: [String]
    private var row = 0, col = 0, type = "", value = "", inValue = false, autoCol = 0

    init(shared: [String]) { self.shared = shared }

    static func parse(_ data: Data, shared: [String]) -> DataFiles.Table {
        let p = SheetParser(shared: shared)
        let parser = XMLParser(data: data)
        parser.delegate = p
        parser.parse()
        guard let maxRow = p.rows.keys.max() else { return [] }
        let width = (p.rows.values.compactMap { $0.keys.max() }.max() ?? 0) + 1
        return (0...maxRow).map { r in (0..<width).map { p.rows[r]?[$0] ?? "" } }
            .filter { !$0.allSatisfy(\.isEmpty) }
    }

    func parser(_ parser: XMLParser, didStartElement name: String, namespaceURI: String?, qualifiedName: String?, attributes a: [String: String] = [:]) {
        switch name {
        case "row":
            row = (Int(a["r"] ?? "") ?? (row + 1)) - 1
            autoCol = 0
        case "c":
            col = a["r"].map(DataFiles.columnIndex) ?? autoCol
            autoCol = col + 1
            type = a["t"] ?? ""
            value = ""
        case "v", "t": inValue = true
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if inValue { value += string }
    }

    func parser(_ parser: XMLParser, didEndElement name: String, namespaceURI: String?, qualifiedName: String?) {
        switch name {
        case "v", "t": inValue = false
        case "c":
            var text = value
            if type == "s", let i = Int(value), shared.indices.contains(i) { text = shared[i] }
            if type == "b" { text = value == "1" ? "TRUE" : "FALSE" }
            if !text.isEmpty { rows[row, default: [:]][col] = text }
        default: break
        }
    }
}

