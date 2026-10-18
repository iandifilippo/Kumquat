import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Every file format Kumquat can write.
public enum OutputFormat: String, CaseIterable, Sendable, Codable, Hashable {
    // Images
    case jpg, png, heic, avif, webp, tiff, gif, bmp, ico, icns, psd
    // Documents
    case pdf, docx, rtf, txt, html, odt, epub, pptx
    // Data
    case csv, tsv, json, xlsx, plist
    // Subtitles
    case srt, vtt
    // Video
    case mp4, mov, m4v, webm, mkv, avi
    // Audio
    case m4a, mp3, wav, aiff, flac, ogg, opus, caf
    // Archives
    case zip, tgz

    public var fileExtension: String {
        switch self {
        case .tgz: return "tar.gz"
        default: return rawValue
        }
    }

    /// Short label shown on the ring.
    public var label: String {
        switch self {
        case .jpg: return "JPG"
        case .aiff: return "AIFF"
        case .tgz: return "TAR.GZ"
        default: return rawValue.uppercased()
        }
    }

    public var utType: UTType {
        switch self {
        case .jpg: return .jpeg
        case .png: return .png
        case .heic: return .heic
        case .avif: return UTType("public.avif") ?? .image
        case .webp: return .webP
        case .tiff: return .tiff
        case .gif: return .gif
        case .bmp: return .bmp
        case .ico: return .ico
        case .icns: return .icns
        case .psd: return UTType("com.adobe.photoshop-image") ?? .image
        case .pdf: return .pdf
        case .docx: return UTType("org.openxmlformats.wordprocessingml.document") ?? .data
        case .rtf: return .rtf
        case .txt: return .plainText
        case .html: return .html
        case .odt: return UTType("org.oasis-open.opendocument.text") ?? .data
        case .epub: return .epub
        case .pptx: return UTType("org.openxmlformats.presentationml.presentation") ?? .data
        case .csv: return .commaSeparatedText
        case .tsv: return .tabSeparatedText
        case .json: return .json
        case .xlsx: return UTType("org.openxmlformats.spreadsheetml.sheet") ?? .data
        case .plist: return .propertyList
        case .srt, .vtt: return UTType(filenameExtension: rawValue) ?? .plainText
        case .mp4: return .mpeg4Movie
        case .mov: return .quickTimeMovie
        case .m4v: return UTType("com.apple.m4v-video") ?? .movie
        case .webm, .mkv: return UTType(filenameExtension: rawValue) ?? .movie
        case .avi: return .avi
        case .mp3: return .mp3
        case .ogg, .opus: return UTType(filenameExtension: rawValue) ?? .audio
        case .m4a: return .mpeg4Audio
        case .wav: return .wav
        case .aiff: return .aiff
        case .flac: return UTType("org.xiph.flac") ?? .audio
        case .caf: return UTType("com.apple.coreaudio-format") ?? .audio
        case .zip: return .zip
        case .tgz: return UTType(filenameExtension: "tgz") ?? .gzip
        }
    }

    public var isImage: Bool {
        switch self {
        case .jpg, .png, .heic, .avif, .webp, .tiff, .gif, .bmp, .ico, .icns, .psd: return true
        default: return false
        }
    }

    /// Formats that cannot store transparency, so Kumquat flattens onto white.
    var needsOpaqueImage: Bool { self == .jpg || self == .bmp }

    /// Whether this output format matches the source file's own format.
    public func matches(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        switch self {
        case .jpg: return ["jpg", "jpeg", "jpe"].contains(ext)
        case .tiff: return ["tif", "tiff"].contains(ext)
        case .html: return ["html", "htm"].contains(ext)
        case .aiff: return ["aif", "aiff"].contains(ext)
        case .tgz: return ["tgz"].contains(ext) || url.lastPathComponent.lowercased().hasSuffix(".tar.gz")
        case .opus: return ext == "opus"
        case .ogg: return ["ogg", "oga"].contains(ext)
        case .mp4: return ext == "mp4"
        default: return ext == rawValue
        }
    }

    /// Image formats ImageIO can write on this Mac.
    public static let writableImageFormats: [OutputFormat] = {
        let ids = Set((CGImageDestinationCopyTypeIdentifiers() as? [String]) ?? [])
        return OutputFormat.allCases.filter { $0.isImage && ids.contains($0.utType.identifier) }
    }()
}
