import Foundation

/// Tools live on the second page of the ring (tap the trigger key again to switch).
public enum ToolID: String, CaseIterable, Sendable, Codable, Hashable {
    // Images
    case compress, resize, crop, addBackground, removeBackground, rotate, flip, grayscale, stripMetadata, extractText
    // PDFs
    case merge, split, rotatePDF, protect, compressPDF, extractPDFText, longImage
    // Video
    case compressVideo, mute, frames
    // Any file
    case zip, extract

    /// Tools that need a small window to collect settings first.
    public var needsEditor: Bool {
        switch self {
        case .crop, .addBackground, .resize, .protect: return true
        default: return false
        }
    }

    /// SF Symbol shown on the ring.
    public var symbol: String {
        switch self {
        case .compress, .compressPDF, .compressVideo: return "arrow.down.right.and.arrow.up.left"
        case .resize: return "arrow.up.left.and.down.right.magnifyingglass"
        case .crop: return "crop"
        case .addBackground: return "photo.on.rectangle.angled"
        case .removeBackground: return "person.crop.rectangle.badge.plus"
        case .rotate, .rotatePDF: return "rotate.right"
        case .flip: return "arrow.left.and.right.righttriangle.left.righttriangle.right"
        case .grayscale: return "circle.lefthalf.filled"
        case .stripMetadata: return "location.slash"
        case .extractText, .extractPDFText: return "text.viewfinder"
        case .merge: return "doc.on.doc"
        case .split: return "scissors"
        case .protect: return "lock.doc"
        case .mute: return "speaker.slash"
        case .longImage: return "rectangle.portrait.on.rectangle.portrait"
        case .frames: return "film.stack"
        case .zip: return "doc.zipper"
        case .extract: return "archivebox"
        }
    }
}

/// One slice of the ring.
public enum KQAction: Hashable, Sendable, Codable {
    case convert(OutputFormat)
    case tool(ToolID)

    /// Stable identifier, used to store which slices the user turned off.
    public var id: String {
        switch self {
        case .convert(let f): return "convert.\(f.rawValue)"
        case .tool(let t): return "tool.\(t.rawValue)"
        }
    }

    public var symbol: String {
        switch self {
        case .tool(let t): return t.symbol
        case .convert(let f):
            switch f {
            case .pdf: return "doc.richtext"
            case .docx, .rtf, .odt: return "doc.text"
            case .txt: return "text.alignleft"
            case .html: return "chevron.left.forwardslash.chevron.right"
            case .epub: return "book"
            case .pptx: return "rectangle.on.rectangle"
            case .csv, .tsv, .xlsx: return "tablecells"
            case .json, .plist: return "curlybraces"
            case .srt, .vtt: return "captions.bubble"
            case .mp4, .mov, .m4v, .webm, .mkv, .avi: return "film"
            case .gif: return "sparkles.rectangle.stack"
            case .m4a, .mp3, .wav, .aiff, .flac, .ogg, .opus, .caf: return "waveform"
            case .ico, .icns: return "app.dashed"
            case .zip, .tgz: return "doc.zipper"
            default: return "photo"
            }
        }
    }
}

/// Which actions make sense for a group of files.
public enum ActionCatalog {
    public static func convertActions(for urls: [URL], engines: Engines = .current) -> [KQAction] {
        guard let first = urls.first else { return [] }
        let ffmpeg = engines.ffmpeg != nil, office = engines.soffice != nil
        guard let kind = FileKind.common(urls) else {
            // Mixed images and PDFs can still become one PDF.
            let kinds = Set(urls.map(FileKind.of))
            return kinds.isSubset(of: [.image, .pdf]) ? [.convert(.pdf)] : []
        }
        let ext = first.pathExtension.lowercased()
        var formats: [OutputFormat]
        switch kind {
        case .image:
            let preferred: [OutputFormat] = [.jpg, .png, .heic, .pdf, .webp, .avif, .tiff, .gif, .bmp, .ico, .icns, .psd]
            formats = preferred.filter { $0 == .pdf || ($0 == .webp && engines.canWriteWebP) || OutputFormat.writableImageFormats.contains($0) }
        case .pdf:
            formats = [.jpg, .png, .docx, .txt, .epub, .rtf, .tiff, .html]
        case .document:
            formats = [.pdf, .docx, .epub, .txt, .rtf, .html, .odt]
        case .ebook:
            formats = [.pdf, .docx, .txt, .html, .rtf]
        case .data:
            switch ext {
            case "json": formats = [.csv, .xlsx, .tsv, .plist, .html, .pdf]
            case "plist": formats = [.json, .csv, .xlsx]
            default: formats = [.xlsx, .csv, .json, .tsv, .html, .pdf]
            }
        case .office:
            guard office else { return [] }
            switch ext {
            case "xls", "ods", "numbers": formats = [.pdf, .xlsx, .csv, .html]
            case "ppt", "odp", "key": formats = [.pdf, .pptx]
            case "pptx": formats = [.pdf]
            default: formats = [.pdf, .docx, .txt]
            }
        case .subtitle:
            formats = [.srt, .vtt, .txt]
        case .video:
            let native = FileKind.isNativeMedia(first)
            guard native || ffmpeg else { return [] }
            formats = [.mp4, .mov, .gif, .m4a]
            if ffmpeg { formats += [.mp3, .webm, .mkv, .avi] }
            formats.append(.m4v)
        case .audio:
            guard FileKind.isNativeMedia(first) || ffmpeg else { return [] }
            formats = ffmpeg ? [.mp3, .m4a, .wav, .flac, .aiff, .ogg, .opus, .caf] : [.m4a, .wav, .aiff, .flac, .caf]
        case .archive:
            formats = [.zip, .tgz]
        case .folder, .other:
            formats = []
        }
        // Don't offer the format the file already has (unless several files have different ones).
        return formats.filter { !(urls.count == 1 && $0.matches(first)) }.map { .convert($0) }
    }

    public static func toolActions(for urls: [URL], engines: Engines = .current) -> [KQAction] {
        let kinds = Set(urls.map(FileKind.of))
        if kinds.count > 1 {
            var tools: [ToolID] = []
            if kinds.isSubset(of: [.image, .pdf]) { tools.append(.merge) }
            tools.append(.zip)
            return tools.map { .tool($0) }
        }
        var tools: [ToolID]
        switch kinds.first {
        case .image:
            tools = [.compress, .resize, .crop, .addBackground, .removeBackground, .stripMetadata, .extractText, .rotate, .flip, .grayscale, .zip]
        case .pdf:
            tools = [.compressPDF, .split, .rotatePDF, .protect, .extractPDFText, .longImage, .zip]
            if urls.count > 1 { tools.insert(.merge, at: 0) }
        case .video:
            let usable = urls.allSatisfy(FileKind.isNativeMedia) || engines.ffmpeg != nil
            tools = usable ? [.compressVideo, .mute, .frames, .zip] : [.zip]
        case .archive:
            tools = [.extract]
        default:
            tools = [.zip]
        }
        return tools.map { .tool($0) }
    }

    /// Every action that can ever appear for a kind (for Settings and watch folders).
    public static func allActions(for kind: FileKind) -> (convert: [KQAction], tools: [KQAction]) {
        let everything = Engines(ffmpeg: URL(fileURLWithPath: "/ffmpeg"), soffice: URL(fileURLWithPath: "/soffice"), cwebp: URL(fileURLWithPath: "/cwebp"))
        let samples: [URL]
        switch kind {
        case .image: samples = [URL(fileURLWithPath: "/tmp/a.webp")]
        case .pdf: samples = [URL(fileURLWithPath: "/tmp/a.pdf"), URL(fileURLWithPath: "/tmp/b.pdf")]
        case .document: samples = [URL(fileURLWithPath: "/tmp/a.md")]
        case .ebook: samples = [URL(fileURLWithPath: "/tmp/a.epub")]
        case .data: samples = [URL(fileURLWithPath: "/tmp/a.yaml.csv"), URL(fileURLWithPath: "/tmp/b.tsv")]
        case .office: samples = [URL(fileURLWithPath: "/tmp/a.xls")]
        case .subtitle: samples = [URL(fileURLWithPath: "/tmp/a.ass.srt"), URL(fileURLWithPath: "/tmp/b.vtt")]
        case .video: samples = [URL(fileURLWithPath: "/tmp/a.flv")]
        case .audio: samples = [URL(fileURLWithPath: "/tmp/a.wma")]
        case .archive: samples = [URL(fileURLWithPath: "/tmp/a.rar")]
        case .folder, .other: samples = [URL(fileURLWithPath: "/tmp/folder/", isDirectory: true)]
        }
        return (convertActions(for: samples, engines: everything), toolActions(for: samples, engines: everything))
    }
}
