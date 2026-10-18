import AppKit
import AVFoundation
import ImageIO
import PDFKit

/// Runs one ring action on one or more files.
public struct Engine: Sendable {
    public var options: ConversionOptions
    public var planner: OutputPlanner

    public init(options: ConversionOptions = .init(), planner: OutputPlanner = .init()) {
        self.options = options
        self.planner = planner
    }

    /// - Parameter progress: called with (finished, total) after each file.
    public func run(_ action: KQAction, on urls: [URL], parameters: ToolParameters = .none,
                    progress: @escaping @Sendable (Int, Int) -> Void = { _, _ in }) async throws -> ActionOutcome {
        let inputBytes = urls.reduce(0) { $0 + $1.fileSize }
        var outputs: [URL] = []
        var detail: String?

        // Group actions that turn many files into one.
        if case .tool(.merge) = action {
            let out = try planner.url(for: urls[0], tool: .merge, ext: "pdf")
            try PDFs.merge(urls, into: out)
            progress(1, 1)
            return outcome([out], inputBytes)
        }
        if case .convert(.pdf) = action, urls.count > 1, options.combineImagesIntoPDF,
           Set(urls.map(FileKind.of)).isSubset(of: [.image, .pdf]) {
            let out = try planner.url(for: urls[0], tool: urls.allSatisfy { FileKind.of($0) == .pdf } ? .merge : nil, ext: "pdf")
            try PDFs.merge(urls, into: out)
            progress(1, 1)
            return outcome([out], inputBytes)
        }

        if case .tool(.zip) = action {
            let name = urls.count == 1 ? OutputPlanner.stem(urls[0]) : planner.suffix(.zip)
            let out = try planner.url(for: urls[0], baseName: name, ext: "zip")
            try await Archives.zip(urls, to: out)
            progress(1, 1)
            return outcome([out], inputBytes)
        }

        var skipped = 0
        for (i, url) in urls.enumerated() {
            try Task.checkCancellation()
            do {
                let (made, info) = try await runSingle(action, url: url, parameters: parameters)
                outputs += made
                detail = info ?? detail
            } catch KumquatError.notSmaller {
                // One file that won't shrink shouldn't stop the others.
                skipped += 1
            }
            progress(i + 1, urls.count)
        }
        if outputs.isEmpty, skipped > 0 { throw KumquatError.notSmaller }
        return outcome(outputs, inputBytes, detail: urls.count == 1 ? detail : nil)
    }

    private func outcome(_ outputs: [URL], _ inputBytes: Int64, detail: String? = nil) -> ActionOutcome {
        ActionOutcome(outputs: outputs, inputBytes: inputBytes, outputBytes: outputs.reduce(0) { $0 + $1.fileSize }, detail: detail)
    }

    private func runSingle(_ action: KQAction, url: URL, parameters: ToolParameters) async throws -> ([URL], String?) {
        switch action {
        case .convert(let format): return (try await convert(url, to: format), nil)
        case .tool(let tool): return try await apply(tool, to: url, parameters: parameters)
        }
    }

    // MARK: - Convert

    private func convert(_ url: URL, to format: OutputFormat) async throws -> [URL] {
        let kind = FileKind.of(url)
        let ext = url.pathExtension.lowercased()
        let engines = Engines.current
        let out = { try planner.url(for: url, ext: format.fileExtension) }

        switch (kind, format) {
        case (.image, .webp):
            // The encoders read few camera formats, so decode with ImageIO first.
            guard engines.canWriteWebP else { throw KumquatError.needsEngine("WebP") }
            let target = try out()
            let temp = FileManager.default.temporaryDirectory.appendingPathComponent("kumquat-\(UUID().uuidString).png")
            defer { try? FileManager.default.removeItem(at: temp) }
            try Images.write(try Images.load(url).image, to: temp, format: .png, quality: 1)
            try await FFmpeg.convert(temp, to: target, format: .webp)
            return [target]

        case (.image, _):
            let target = try out()
            let (image, props) = try Images.load(url)
            try Images.write(image, to: target, format: format, quality: options.imageQuality, properties: options.keepMetadata ? props : nil)
            return [target]

        case (.pdf, .jpg), (.pdf, .png), (.pdf, .tiff):
            let doc = try PDFs.open(url)
            var outs: [URL] = []
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i), let image = PDFs.render(page, dpi: options.pdfDPI) else { continue }
                let extra = doc.pageCount > 1 ? String(format: "%03d", i + 1) : nil
                let target = try planner.url(for: url, extra: extra, ext: format.fileExtension)
                try Images.write(image, to: target, format: format, quality: options.imageQuality)
                outs.append(target)
            }
            return outs

        case (.pdf, .txt):
            let target = try out()
            try Data(PDFs.text(of: PDFs.open(url)).utf8).write(to: target)
            return [target]

        case (.pdf, .epub):
            let target = try out()
            try await MainActor.run { PDFs.attributedText(of: try PDFs.open(url)) }
                .write(epubTitled: OutputPlanner.stem(url), to: target)
            return [target]

        case (.pdf, _):
            let target = try out()
            try await MainActor.run {
                try Documents.write(PDFs.attributedText(of: try PDFs.open(url)), to: target, format: format)
            }
            return [target]

        case (.document, .pdf) where options.preferLibreOffice && engines.soffice != nil && ["doc", "docx", "odt", "rtf"].contains(ext):
            // LibreOffice keeps headers, tables and page layout that AppKit flattens.
            let target = try out()
            try await LibreOffice.convert(url, to: target, filter: "pdf")
            return [target]

        case (.document, .epub):
            let target = try out()
            try await MainActor.run { try Documents.read(url) }.write(epubTitled: OutputPlanner.stem(url), to: target)
            return [target]

        case (.document, _):
            let target = try out()
            try await MainActor.run {
                try Documents.write(try Documents.read(url), to: target, format: format)
            }
            return [target]

        case (.ebook, _):
            let target = try out()
            let book = try await EPUB.read(url)
            try await MainActor.run { try Documents.write(book, to: target, format: format) }
            return [target]

        case (.data, .plist) where ext == "json":
            let target = try out()
            try DataFiles.jsonToPlist(url, to: target)
            return [target]

        case (.data, .json) where ext == "plist":
            let target = try out()
            try DataFiles.plistToJSON(url, to: target)
            return [target]

        case (.data, _):
            let target = try out()
            let table = try await DataFiles.readTable(url)
            if table.isEmpty { throw KumquatError.badData("The table is empty.") }
            try await DataFiles.write(table, to: target, format: format, title: OutputPlanner.stem(url))
            return [target]

        case (.office, _):
            let target = try out()
            try await LibreOffice.convert(url, to: target, filter: LibreOffice.filter(for: format))
            return [target]

        case (.subtitle, _):
            let target = try out()
            try Subtitles.write(try Subtitles.read(url), to: target, format: format)
            return [target]

        case (.archive, .zip), (.archive, .tgz):
            let target = try out()
            let temp = try Archives.temporaryFolder()
            defer { try? FileManager.default.removeItem(at: temp) }
            try await Archives.extract(url, into: temp)
            if format == .zip {
                let items = try FileManager.default.contentsOfDirectory(at: temp, includingPropertiesForKeys: nil)
                try await Archives.zip(items, to: target)
            } else {
                try await Archives.tarGz(folder: temp, to: target)
            }
            return [target]

        case (.video, .gif):
            let target = try out()
            if FileKind.isNativeMedia(url) {
                try await Media.gif(url, to: target, fps: options.gifFPS, maxWidth: options.gifMaxWidth, maxSeconds: options.gifMaxSeconds)
            } else {
                try await FFmpeg.gif(url, to: target, fps: options.gifFPS, maxWidth: options.gifMaxWidth, maxSeconds: options.gifMaxSeconds)
            }
            return [target]

        case (.video, _):
            let target = try out()
            if FileKind.isNativeMedia(url), [.mp4, .mov, .m4v, .m4a].contains(format) {
                try await Media.exportVideo(url, to: target, format: format)
            } else {
                try await FFmpeg.convert(url, to: target, format: format)
            }
            return [target]

        case (.audio, _):
            let target = try out()
            if FileKind.isNativeMedia(url), [.m4a, .wav, .aiff, .flac, .caf].contains(format) {
                try await Media.convertAudio(url, to: target, format: format)
            } else {
                try await FFmpeg.convert(url, to: target, format: format)
            }
            return [target]

        default:
            throw KumquatError.unsupported("\(url.pathExtension.uppercased()) → \(format.label)")
        }
    }

    // MARK: - Tools

    private func sameFormat(_ url: URL) -> OutputFormat {
        OutputFormat.writableImageFormats.first { $0.matches(url) } ?? .png
    }

    private func dimensions(_ a: CGImage, _ b: CGImage) -> String {
        "\(a.width)×\(a.height) → \(b.width)×\(b.height)"
    }

    private func apply(_ tool: ToolID, to url: URL, parameters: ToolParameters) async throws -> ([URL], String?) {
        switch tool {
        case .compress:
            let (image, props) = try Images.load(url)
            var scaled = image
            if let maxSide = options.compressMaxDimension { scaled = Images.fit(image, maxSide: maxSide) }
            // Lossy formats stay as they are; lossless ones become JPG (or HEIC if they have transparency).
            var format = sameFormat(url)
            if ![.jpg, .heic, .avif].contains(format) { format = Images.hasAlpha(scaled) ? .heic : .jpg }
            let out = try planner.url(for: url, tool: .compress, ext: format.fileExtension)
            try Images.write(scaled, to: out, format: format, quality: options.compressQuality, properties: options.keepMetadata ? props : nil)
            try Self.keepOnlyIfSmaller(out, than: url)
            return ([out], scaled.width != image.width ? dimensions(image, scaled) : nil)

        case .resize, .crop, .rotate, .flip, .grayscale, .addBackground, .removeBackground:
            let (image, props) = try Images.load(url)
            var format = sameFormat(url)
            let result: CGImage
            switch (tool, parameters) {
            case (.resize, .resize(let w, let h)): result = Images.resized(image, width: w, height: h)
            case (.resize, .scale(let f)):
                result = Images.resized(image, width: max(1, Int(Double(image.width) * f)), height: max(1, Int(Double(image.height) * f)))
            case (.resize, _): result = Images.resized(image, width: image.width / 2, height: image.height / 2)
            case (.crop, .crop(let rect)): result = Images.cropped(image, to: rect)
            case (.rotate, _): result = Images.rotatedClockwise(image)
            case (.flip, _): result = Images.flippedHorizontally(image)
            case (.grayscale, _): result = Images.grayscale(image)
            case (.addBackground, .background(let style)):
                result = BackgroundRenderer.render(image, style: style)
                format = .png
            case (.addBackground, _):
                result = BackgroundRenderer.render(image, style: BackgroundStyle())
                format = .png
            case (.removeBackground, _):
                result = try VisionTools.removeBackground(image)
                format = .png
            default:
                throw KumquatError.unsupported(tool.rawValue)
            }
            let out = try planner.url(for: url, tool: tool, ext: format.fileExtension)
            try Images.write(result, to: out, format: format, quality: 0.95, properties: options.keepMetadata ? props : nil)
            let changesSize = [.resize, .crop, .addBackground].contains(tool)
            return ([out], changesSize ? dimensions(image, result) : nil)

        case .stripMetadata:
            let out = try planner.url(for: url, tool: .stripMetadata, ext: url.pathExtension.isEmpty ? "png" : url.pathExtension)
            try stripMetadata(url, to: out)
            return ([out], nil)

        case .extractText:
            let (image, _) = try Images.load(url)
            let text = try VisionTools.recognizeText(image)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { throw KumquatError.noText }
            let out = try planner.url(for: url, tool: .extractText, ext: "txt")
            try Data(text.utf8).write(to: out)
            return ([out], nil)

        case .extractPDFText:
            let out = try planner.url(for: url, tool: .extractPDFText, ext: "txt")
            try Data(PDFs.text(of: PDFs.open(url)).utf8).write(to: out)
            return ([out], nil)

        case .compressPDF:
            let out = try planner.url(for: url, tool: .compressPDF, ext: "pdf")
            if options.pdfCompression == .strong {
                try PDFs.compressStrongly(url, to: out)
            } else if Engines.current.ghostscript != nil {
                try await Ghostscript.compress(url, to: out, setting: "ebook")
                try Self.keepOnlyIfSmaller(out, than: url)
            } else {
                try PDFs.compress(url, to: out)
            }
            return ([out], nil)

        case .longImage:
            let doc = try PDFs.open(url)
            let pages = (0..<doc.pageCount).compactMap { doc.page(at: $0).flatMap { PDFs.render($0, dpi: options.pdfDPI) } }
            guard let tall = Images.stacked(pages) else { throw KumquatError.unreadable(url) }
            let out = try planner.url(for: url, tool: .longImage, ext: "png")
            try Images.write(tall, to: out, format: .png, quality: 1)
            return ([out], "\(pages.count) → 1")

        case .frames:
            let folder = try planner.folder(for: url, name: OutputPlanner.stem(url) + " " + planner.suffix(.frames))
            if FileKind.isNativeMedia(url) {
                _ = try await Media.frames(url, into: folder, fps: options.framesPerSecond)
            } else {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                try await FFmpeg.frames(url, into: folder, fps: options.framesPerSecond)
            }
            let count = (try? FileManager.default.contentsOfDirectory(atPath: folder.path).count) ?? 0
            return ([folder], "\(count)")

        case .extract:
            let folder = try planner.folder(for: url, name: Archives.baseName(url))
            let temp = try Archives.temporaryFolder()
            defer { try? FileManager.default.removeItem(at: temp) }
            try await Archives.extract(url, into: temp)
            // One folder inside? Use it instead of nesting folder/folder.
            try FileManager.default.moveItem(at: try Archives.flatten(temp), to: folder)
            return ([folder], nil)

        case .rotatePDF:
            let out = try planner.url(for: url, tool: .rotatePDF, ext: "pdf")
            try PDFs.rotate(url, to: out)
            return ([out], nil)

        case .protect:
            guard case .password(let pw) = parameters, !pw.isEmpty else { throw KumquatError.cancelled }
            let out = try planner.url(for: url, tool: .protect, ext: "pdf")
            try PDFs.protect(url, password: pw, to: out)
            return ([out], nil)

        case .split:
            let doc = try PDFs.open(url)
            var outs: [URL] = []
            for i in 0..<doc.pageCount {
                guard let page = doc.page(at: i) else { continue }
                let single = PDFDocument()
                single.insert(page, at: 0)
                let out = try planner.url(for: url, tool: .split, extra: "\(i + 1)", ext: "pdf")
                guard single.write(to: out) else { throw KumquatError.writeFailed(out) }
                outs.append(out)
            }
            return (outs, nil)

        case .compressVideo:
            let out = try planner.url(for: url, tool: .compressVideo, ext: "mp4")
            if FileKind.isNativeMedia(url) {
                try await Media.exportVideo(url, to: out, format: .mp4, preset: AVAssetExportPresetHEVC1920x1080)
            } else {
                try await FFmpeg.compress(url, to: out)
            }
            try Self.keepOnlyIfSmaller(out, than: url)
            return ([out], nil)

        case .mute:
            if !FileKind.isNativeMedia(url) {
                let out = try planner.url(for: url, tool: .mute, ext: url.pathExtension)
                try await FFmpeg.mute(url, to: out)
                return ([out], nil)
            }
            let format: OutputFormat = url.pathExtension.lowercased() == "mov" ? .mov : .mp4
            let out = try planner.url(for: url, tool: .mute, ext: format.fileExtension)
            try await Media.exportVideo(url, to: out, format: format, preset: AVAssetExportPresetPassthrough, removeAudio: true)
            return ([out], nil)

        case .merge, .zip:
            throw KumquatError.unsupported("This tool needs several files")
        }
    }

    /// Deletes a "compressed" file that came out no smaller than its source.
    static func keepOnlyIfSmaller(_ output: URL, than source: URL) throws {
        guard output.fileSize >= source.fileSize else { return }
        try? FileManager.default.removeItem(at: output)
        throw KumquatError.notSmaller
    }

    /// Removes location and camera data without re-encoding when ImageIO allows it.
    private func stripMetadata(_ url: URL, to out: URL) throws {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let type = CGImageSourceGetType(source),
              let dest = CGImageDestinationCreateWithURL(out as CFURL, type, 1, nil) else { throw KumquatError.unreadable(url) }
        let props = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        let metadata = CGImageMetadataCreateMutable()
        if let orientation = props[kCGImagePropertyOrientation] as? Int {
            CGImageMetadataSetValueMatchingImageProperty(metadata, kCGImagePropertyTIFFDictionary, kCGImagePropertyTIFFOrientation, orientation as CFNumber)
        }
        let options: [CFString: Any] = [
            kCGImageDestinationMetadata: metadata,
            kCGImageDestinationMergeMetadata: false,
            kCGImageMetadataShouldExcludeGPS: true,
            kCGImageMetadataShouldExcludeXMP: true,
        ]
        var error: Unmanaged<CFError>?
        if CGImageDestinationCopyImageSource(dest, source, options as CFDictionary, &error) { return }
        // Fall back to re-encoding the pixels with no metadata at all.
        try? FileManager.default.removeItem(at: out)
        let (image, _) = try Images.load(url)
        try Images.write(image, to: out, format: sameFormat(url), quality: 0.95, properties: nil)
    }
}

extension NSAttributedString {
    /// Small helper so conversions read naturally: `text.write(epubTitled:to:)`.
    func write(epubTitled title: String, to url: URL) async throws {
        try await EPUB.write(self, title: title, to: url)
    }
}
