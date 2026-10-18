import AppKit

/// Text documents (TXT, Markdown, RTF, Word, HTML, ODT) via NSAttributedString.
public enum Documents {
    static let bodyFont = NSFont.systemFont(ofSize: 12)

    public static func read(_ url: URL) throws -> NSAttributedString {
        let ext = url.pathExtension.lowercased()
        if ["md", "markdown"].contains(ext) {
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { throw KumquatError.unreadable(url) }
            return markdown(text)
        }
        if ["txt", "text", "csv", "json", "log", "xml", "yaml", "yml"].contains(ext) {
            guard let text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .isoLatin1)) else {
                throw KumquatError.unreadable(url)
            }
            let font = ext == "txt" || ext == "text" ? bodyFont : NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            return NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor.black])
        }
        guard let doc = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) else {
            throw KumquatError.unreadable(url)
        }
        return doc
    }

    @MainActor
    public static func write(_ text: NSAttributedString, to url: URL, format: OutputFormat) throws {
        let range = NSRange(location: 0, length: text.length)
        let data: Data
        switch format {
        case .txt:
            data = Data(text.string.utf8)
        case .rtf:
            guard let d = text.rtf(from: range, documentAttributes: [:]) else { throw KumquatError.writeFailed(url) }
            data = d
        case .docx:
            data = try text.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML])
        case .odt:
            data = try text.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.openDocument])
        case .html:
            data = try text.data(from: range, documentAttributes: [.documentType: NSAttributedString.DocumentType.html])
        case .pdf:
            try writePDF(text, to: url)
            return
        default:
            throw KumquatError.unsupported(format.label)
        }
        try data.write(to: url)
    }

    /// Lays text out on US Letter / A4-ish pages with 1-inch margins.
    @MainActor
    public static func writePDF(_ text: NSAttributedString, to url: URL, landscape: Bool = false) throws {
        let info = NSPrintInfo()
        var paper = Locale.current.measurementSystem == .us ? NSSize(width: 612, height: 792) : NSSize(width: 595, height: 842)
        if landscape { paper = NSSize(width: paper.height, height: paper.width) }
        info.paperSize = paper
        info.topMargin = 72; info.bottomMargin = 72; info.leftMargin = 72; info.rightMargin = 72
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        info.isHorizontallyCentered = false

        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let view = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        view.textContainerInset = .zero
        view.textContainer?.lineFragmentPadding = 0
        view.backgroundColor = .white
        view.textStorage?.setAttributedString(text)
        view.layoutManager?.ensureLayout(for: view.textContainer!)
        let used = view.layoutManager?.usedRect(for: view.textContainer!).height ?? 100
        view.setFrameSize(NSSize(width: width, height: max(used, 10)))

        let op = NSPrintOperation.pdfOperation(with: view, inside: view.bounds, toPath: url.path, printInfo: info)
        op.showsPrintPanel = false
        op.showsProgressPanel = false
        guard op.run() else { throw KumquatError.writeFailed(url) }
    }

    /// A small Markdown renderer: headings, bullets, quotes, code blocks and inline styles.
    public static func markdown(_ source: String) -> NSAttributedString {
        let out = NSMutableAttributedString()
        var inCode = false
        let body: [NSAttributedString.Key: Any] = [.font: bodyFont, .foregroundColor: NSColor.black]
        for rawLine in source.components(separatedBy: .newlines) {
            var line = rawLine
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("```") { inCode.toggle(); continue }
            if inCode {
                out.append(NSAttributedString(string: line + "\n", attributes: [.font: NSFont.monospacedSystemFont(ofSize: 11, weight: .regular), .foregroundColor: NSColor.darkGray]))
                continue
            }
            var attrs = body
            var level = 0
            while line.hasPrefix("#") { level += 1; line.removeFirst() }
            if level > 0 {
                line = line.trimmingCharacters(in: .whitespaces)
                let size: CGFloat = [26, 21, 17, 15, 13, 12][min(level, 6) - 1]
                attrs[.font] = NSFont.systemFont(ofSize: size, weight: .bold)
                let para = NSMutableParagraphStyle()
                para.paragraphSpacingBefore = 8
                para.paragraphSpacing = 4
                attrs[.paragraphStyle] = para
            } else if let match = line.range(of: #"^\s*[-*+]\s+"#, options: .regularExpression) {
                line = "•  " + line[match.upperBound...]
            } else if line.hasPrefix(">") {
                line = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                attrs[.foregroundColor] = NSColor.gray
            }
            let inline = (try? AttributedString(markdown: line, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)))
                .map { NSMutableAttributedString(attributedString: NSAttributedString($0)) } ?? NSMutableAttributedString(string: line)
            let full = NSRange(location: 0, length: inline.length)
            inline.addAttributes(attrs, range: full)
            // Bring back bold/italic/code from the inline Markdown pass.
            inline.enumerateAttribute(.inlinePresentationIntent, in: full) { value, range, _ in
                guard let raw = value as? UInt else { return }
                let intent = InlinePresentationIntent(rawValue: raw)
                let base = (attrs[.font] as? NSFont) ?? bodyFont
                var traits: NSFontDescriptor.SymbolicTraits = []
                if intent.contains(.stronglyEmphasized) { traits.insert(.bold) }
                if intent.contains(.emphasized) { traits.insert(.italic) }
                if intent.contains(.code) {
                    inline.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: base.pointSize - 1, weight: .regular), range: range)
                } else if !traits.isEmpty {
                    let desc = base.fontDescriptor.withSymbolicTraits(traits)
                    inline.addAttribute(.font, value: NSFont(descriptor: desc, size: base.pointSize) ?? base, range: range)
                }
            }
            out.append(inline)
            out.append(NSAttributedString(string: "\n", attributes: attrs))
        }
        return out
    }
}
