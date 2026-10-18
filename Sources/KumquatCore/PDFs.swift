import AppKit
import ImageIO
import PDFKit

public enum PDFs {
    public static func open(_ url: URL) throws -> PDFDocument {
        guard let doc = PDFDocument(url: url) else { throw KumquatError.unreadable(url) }
        return doc
    }

    /// Renders one page at the given DPI, upright and on white.
    public static func render(_ page: PDFPage, dpi: Double) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let rotated = page.rotation % 180 != 0
        let scale = dpi / 72
        let size = NSSize(width: (rotated ? bounds.height : bounds.width) * scale,
                          height: (rotated ? bounds.width : bounds.height) * scale)
        let image = page.thumbnail(of: size, for: .mediaBox)
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return Images.flatten(cg)
    }

    /// The document's text layer; falls back to on-device OCR for scanned pages.
    public static func text(of doc: PDFDocument) throws -> String {
        var pages: [String] = []
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i) else { continue }
            let layer = page.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !layer.isEmpty {
                pages.append(layer)
            } else if let img = render(page, dpi: 200) {
                pages.append(try VisionTools.recognizeText(img))
            }
        }
        let text = pages.joined(separator: "\n\n")
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw KumquatError.noText }
        return text
    }

    public static func attributedText(of doc: PDFDocument) -> NSAttributedString {
        let result = NSMutableAttributedString()
        for i in 0..<doc.pageCount {
            guard let s = doc.page(at: i)?.attributedString else { continue }
            if result.length > 0 { result.append(NSAttributedString(string: "\n\u{0C}")) }
            result.append(s)
        }
        return result
    }

    public static func merge(_ urls: [URL], into output: URL) throws {
        let merged = PDFDocument()
        for url in urls {
            if FileKind.of(url) == .image {
                let (img, _) = try Images.load(url)
                if let page = PDFPage(image: NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))) {
                    merged.insert(page, at: merged.pageCount)
                }
                continue
            }
            let doc = try open(url)
            for i in 0..<doc.pageCount {
                if let page = doc.page(at: i) { merged.insert(page, at: merged.pageCount) }
            }
        }
        guard merged.write(to: output) else { throw KumquatError.writeFailed(output) }
    }

    public static func compress(_ url: URL, to output: URL) throws {
        let doc = try open(url)
        let options: [PDFDocumentWriteOption: Any] = [
            .saveImagesAsJPEGOption: true,
            .optimizeImagesForScreenOption: true,
        ]
        guard doc.write(to: output, withOptions: options) else { throw KumquatError.writeFailed(output) }
        try Engine.keepOnlyIfSmaller(output, than: url)
    }

    /// Rebuilds every page as a JPEG picture. Much smaller for scans and photos,
    /// but the text can no longer be selected.
    public static func compressStrongly(_ url: URL, to output: URL, dpi: Double = 110, quality: Double = 0.55) throws {
        let doc = try open(url)
        let result = PDFDocument()
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i), let image = render(page, dpi: dpi) else { continue }
            let data = NSMutableData()
            guard let dest = CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
            CGImageDestinationFinalize(dest)
            guard let jpeg = NSImage(data: data as Data) else { continue }
            // Keep the page's physical size so it prints the same.
            jpeg.size = page.bounds(for: .mediaBox).size
            if page.rotation % 180 != 0 { jpeg.size = NSSize(width: jpeg.size.height, height: jpeg.size.width) }
            if let newPage = PDFPage(image: jpeg) { result.insert(newPage, at: result.pageCount) }
        }
        guard result.write(to: output) else { throw KumquatError.writeFailed(output) }
        try Engine.keepOnlyIfSmaller(output, than: url)
    }

    public static func protect(_ url: URL, password: String, to output: URL) throws {
        let doc = try open(url)
        let options: [PDFDocumentWriteOption: Any] = [
            .userPasswordOption: password,
            .ownerPasswordOption: password,
        ]
        guard doc.write(to: output, withOptions: options) else { throw KumquatError.writeFailed(output) }
    }

    public static func rotate(_ url: URL, to output: URL) throws {
        let doc = try open(url)
        for i in 0..<doc.pageCount { doc.page(at: i)?.rotation += 90 }
        guard doc.write(to: output) else { throw KumquatError.writeFailed(output) }
    }
}
