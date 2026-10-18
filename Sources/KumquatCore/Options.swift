import Foundation

/// Knobs that change how conversions behave. The app fills these from Settings.
public struct ConversionOptions: Sendable, Equatable {
    /// Quality for lossy formats (JPG, HEIC, AVIF) when converting, 0...1.
    public var imageQuality: Double = 0.9
    /// Quality used by the Compress tool, 0...1.
    public var compressQuality: Double = 0.6
    /// Longest side after Compress, or `nil` to keep the original size.
    public var compressMaxDimension: Int? = nil
    /// Resolution used when turning PDF pages into images.
    public var pdfDPI: Double = 200
    /// Keep EXIF/GPS and other metadata when converting images.
    public var keepMetadata: Bool = true
    /// Several images dropped on PDF become one document instead of one PDF each.
    public var combineImagesIntoPDF: Bool = true
    /// Frames per second and width for video → GIF.
    public var gifFPS: Int = 12
    public var gifMaxWidth: Int = 640
    /// GIFs only use the start of long clips, so they stay a sensible size.
    public var gifMaxSeconds: Double = 15
    /// Frames to export per second of video, or `nil` for every frame.
    public var framesPerSecond: Double? = nil
    /// How hard Compress works on PDFs.
    public var pdfCompression: PDFCompression = .balanced
    /// Use LibreOffice (when installed) for Word → PDF, which keeps complex layouts.
    public var preferLibreOffice: Bool = true

    public enum PDFCompression: String, Sendable, Codable, CaseIterable {
        /// Recompresses images; text stays selectable.
        case balanced
        /// Turns every page into a JPEG; smallest, text not selectable.
        case strong
    }

    public init() {}
}

/// Where results are saved.
public enum OutputLocation: Sendable, Equatable {
    case nextToOriginal
    case subfolder(String)
    case folder(URL)
}

/// Picks the output URL for each result and never overwrites an existing file.
public struct OutputPlanner: Sendable {
    public var location: OutputLocation
    /// Words appended to file names for tools, e.g. "Compressed" → "Photo Compressed.jpg".
    public var suffix: @Sendable (ToolID) -> String

    public init(location: OutputLocation = .nextToOriginal, suffix: @escaping @Sendable (ToolID) -> String = OutputPlanner.englishSuffix) {
        self.location = location
        self.suffix = suffix
    }

    public func directory(for source: URL) throws -> URL {
        let dir: URL
        switch location {
        case .nextToOriginal: dir = source.deletingLastPathComponent()
        case .subfolder(let name): dir = source.deletingLastPathComponent().appendingPathComponent(name, isDirectory: true)
        case .folder(let url): dir = url
        }
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// A free URL like "Photo.jpg", "Photo 2.jpg", ...
    public func url(for source: URL, baseName: String? = nil, tool: ToolID? = nil, extra: String? = nil, ext: String) throws -> URL {
        var name = baseName ?? Self.stem(source)
        if let tool { name += " " + suffix(tool) }
        if let extra { name += " " + extra }
        return Self.unique(try directory(for: source).appendingPathComponent(name, isDirectory: false).appendingPathExtension(ext))
    }

    /// A free folder URL like "Photos", "Photos 2", ...
    public func folder(for source: URL, name: String) throws -> URL {
        Self.unique(try directory(for: source).appendingPathComponent(name, isDirectory: true))
    }

    /// The file's name without extension; archives lose all of theirs ("a.tar.gz" → "a"), folders keep their name.
    static func stem(_ url: URL) -> String {
        if FileKind.of(url) == .archive { return Archives.baseName(url) }
        if url.hasDirectoryPath { return url.lastPathComponent }
        return url.deletingPathExtension().lastPathComponent
    }

    public static func unique(_ url: URL) -> URL {
        let fm = FileManager.default
        guard fm.fileExists(atPath: url.path) else { return url }
        // "tar.gz" counts as one extension.
        var ext = url.pathExtension
        var base = url.deletingPathExtension().lastPathComponent
        if base.lowercased().hasSuffix(".tar") { base = String(base.dropLast(4)); ext = "tar." + ext }
        let dir = url.deletingLastPathComponent()
        var n = 2
        while true {
            var candidate = dir.appendingPathComponent("\(base) \(n)", isDirectory: url.hasDirectoryPath)
            if !ext.isEmpty { candidate = candidate.appendingPathExtension(ext) }
            if !fm.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }

    public static let englishSuffix: @Sendable (ToolID) -> String = { tool in
        switch tool {
        case .compress, .compressPDF, .compressVideo: return "Compressed"
        case .resize: return "Resized"
        case .crop: return "Cropped"
        case .addBackground: return "With Background"
        case .removeBackground: return "No Background"
        case .rotate, .rotatePDF: return "Rotated"
        case .flip: return "Flipped"
        case .grayscale: return "B&W"
        case .stripMetadata: return "Clean"
        case .extractText, .extractPDFText: return "Text"
        case .merge: return "Merged"
        case .split: return "Page"
        case .protect: return "Protected"
        case .mute: return "Muted"
        case .longImage: return "Long"
        case .frames: return "Frames"
        case .zip: return "Archive"
        case .extract: return "Extracted"
        }
    }
}

/// Settings collected by an editor window before a tool runs.
public enum ToolParameters: Sendable {
    case none
    /// Crop rectangle in pixels of the upright image.
    case crop(CGRect)
    case resize(width: Int, height: Int)
    /// Resize every file by the same factor (used when several files are dropped).
    case scale(Double)
    case background(BackgroundStyle)
    case password(String)
}

/// What happened, so the app can show "2.4 MB → 610 KB · 75% smaller".
public struct ActionOutcome: Sendable {
    public var outputs: [URL]
    public var inputBytes: Int64
    public var outputBytes: Int64
    /// Extra facts such as "4032×3024 → 2016×1512".
    public var detail: String?

    public init(outputs: [URL], inputBytes: Int64, outputBytes: Int64, detail: String? = nil) {
        self.outputs = outputs
        self.inputBytes = inputBytes
        self.outputBytes = outputBytes
        self.detail = detail
    }
}

public enum KumquatError: LocalizedError {
    case unreadable(URL)
    case unsupported(String)
    case writeFailed(URL)
    case noText
    case noSubject
    /// Compressing didn't make the file any smaller, so nothing was saved.
    case notSmaller
    /// The conversion needs FFmpeg, LibreOffice or Ghostscript, which isn't installed.
    case needsEngine(String)
    case toolFailed(String, String)
    case badData(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .unreadable(let url): return "Couldn't read \(url.lastPathComponent)."
        case .unsupported(let what): return "\(what) isn't supported."
        case .writeFailed(let url): return "Couldn't save \(url.lastPathComponent)."
        case .noText: return "No text was found."
        case .noSubject: return "No clear subject was found to cut out."
        case .notSmaller: return "It's already as small as it gets."
        case .needsEngine(let name): return "This needs \(name), which isn't installed."
        case .toolFailed(let tool, let message): return "\(tool) failed: \(message)"
        case .badData(let why): return why
        case .cancelled: return "Cancelled."
        }
    }
}

extension URL {
    /// Size in bytes; folders add up everything inside them.
    var fileSize: Int64 {
        if hasDirectoryPath || (try? resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            let items = FileManager.default.enumerator(at: self, includingPropertiesForKeys: [.fileSizeKey])
            var total: Int64 = 0
            while let item = items?.nextObject() as? URL {
                total += Int64((try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
            }
            return total
        }
        return (try? resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }.map(Int64.init) ?? 0
    }
}
