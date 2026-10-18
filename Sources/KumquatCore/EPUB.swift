import AppKit
import Foundation

/// Reading and writing EPUB e-books with the system's ZIP tools and HTML import.
public enum EPUB {
    /// The book's chapters in reading order, as one attributed string.
    @MainActor
    public static func read(_ url: URL) async throws -> NSAttributedString {
        let folder = try Archives.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        try await Archives.extract(url, into: folder)

        let container = try Data(contentsOf: folder.appendingPathComponent("META-INF/container.xml"))
        guard let opfPath = firstAttribute("full-path", in: container) else { throw KumquatError.unreadable(url) }
        let opfURL = folder.appendingPathComponent(opfPath)
        let opf = try XMLDocument(contentsOf: opfURL, options: [])
        var manifest: [String: String] = [:]
        for item in try opf.nodes(forXPath: "//*[local-name()='manifest']/*[local-name()='item']") {
            guard let el = item as? XMLElement, let id = el.attribute(forName: "id")?.stringValue,
                  let href = el.attribute(forName: "href")?.stringValue else { continue }
            manifest[id] = href.removingPercentEncoding ?? href
        }
        let spine = try opf.nodes(forXPath: "//*[local-name()='spine']/*[local-name()='itemref']")
            .compactMap { ($0 as? XMLElement)?.attribute(forName: "idref")?.stringValue }

        let book = NSMutableAttributedString()
        let base = opfURL.deletingLastPathComponent()
        for id in spine {
            guard let href = manifest[id] else { continue }
            let chapter = base.appendingPathComponent(href)
            guard let data = try? Data(contentsOf: chapter),
                  let text = NSAttributedString(html: data, baseURL: chapter.deletingLastPathComponent(), documentAttributes: nil) else { continue }
            if book.length > 0 { book.append(NSAttributedString(string: "\n\u{0C}")) }
            book.append(text)
        }
        if book.length == 0 { throw KumquatError.noText }
        return book
    }

    static func firstAttribute(_ name: String, in xml: Data) -> String? {
        guard let doc = try? XMLDocument(data: xml) else { return nil }
        return (try? doc.nodes(forXPath: "//@\(name)"))?.first?.stringValue
    }

    /// Builds an EPUB 3 from any text. The title is the file name.
    @MainActor
    public static func write(_ text: NSAttributedString, title: String, to url: URL) async throws {
        let folder = try Archives.temporaryFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        func put(_ path: String, _ content: String) throws {
            let file = folder.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: file)
        }
        func esc(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
        }

        // AppKit's HTML export, cleaned into strict XHTML (EPUB requires it).
        let html = try text.data(from: NSRange(location: 0, length: text.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
        var body: String
        var style = ""
        if let doc = try? XMLDocument(data: html, options: [.documentTidyHTML]),
           let bodyNode = try? doc.nodes(forXPath: "//*[local-name()='body']").first as? XMLElement {
            body = (bodyNode.children ?? []).map { $0.xmlString }.joined(separator: "\n")
            // Keep AppKit's paragraph styles (bold, sizes, spacing).
            style = ((try? doc.nodes(forXPath: "//*[local-name()='style']")) ?? []).map { $0.stringValue ?? "" }.joined(separator: "\n")
        } else {
            body = text.string.components(separatedBy: "\n").map { "<p>\(esc($0))</p>" }.joined(separator: "\n")
        }
        let id = UUID().uuidString
        let lang = Locale.current.language.languageCode?.identifier ?? "en"

        try put("mimetype", "application/epub+zip")
        try put("META-INF/container.xml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>
        """)
        try put("OEBPS/content.opf", """
        <?xml version="1.0" encoding="UTF-8"?>
        <package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="uid">
          <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
            <dc:identifier id="uid">urn:uuid:\(id)</dc:identifier>
            <dc:title>\(esc(title))</dc:title>
            <dc:language>\(lang)</dc:language>
            <meta property="dcterms:modified">\(ISO8601DateFormatter().string(from: Date()).prefix(19))Z</meta>
          </metadata>
          <manifest>
            <item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/>
            <item id="text" href="text.xhtml" media-type="application/xhtml+xml"/>
          </manifest>
          <spine><itemref idref="text"/></spine>
        </package>
        """)
        try put("OEBPS/nav.xhtml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><head><title>\(esc(title))</title></head>
        <body><nav epub:type="toc"><ol><li><a href="text.xhtml">\(esc(title))</a></li></ol></nav></body></html>
        """)
        try put("OEBPS/text.xhtml", """
        <?xml version="1.0" encoding="UTF-8"?>
        <html xmlns="http://www.w3.org/1999/xhtml"><head><title>\(esc(title))</title>
        <style>body{font-family:serif;line-height:1.5}
        \(esc(style))</style></head>
        <body>
        \(body)
        </body></html>
        """)
        try? FileManager.default.removeItem(at: url)
        // "mimetype" must come first and uncompressed.
        try await Engines.run(Archives.zipTool, ["-X", "-0", "-q", url.path, "mimetype"], currentDirectory: folder)
        try await Engines.run(Archives.zipTool, ["-X", "-9", "-r", "-q", url.path, "META-INF", "OEBPS"], currentDirectory: folder)
    }
}
