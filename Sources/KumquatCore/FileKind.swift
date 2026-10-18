import Foundation
import UniformTypeIdentifiers

/// The broad family a file belongs to. Kumquat picks which actions to offer from this.
public enum FileKind: String, CaseIterable, Sendable, Codable {
    case image, pdf, document, data, ebook, subtitle, office, video, audio, archive, folder, other

    public static func of(_ url: URL) -> FileKind {
        if url.hasDirectoryPath || (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
            // Packages such as .pages or .key are folders on disk but documents to people.
            if officeExtensions.contains(url.pathExtension.lowercased()) { return .office }
            return .folder
        }
        let name = url.lastPathComponent.lowercased()
        let ext = url.pathExtension.lowercased()
        if archiveSuffixes.contains(where: { name.hasSuffix($0) }) { return .archive }
        if dataExtensions.contains(ext) { return .data }
        if officeExtensions.contains(ext) { return .office }
        if ext == "epub" { return .ebook }
        if ["srt", "vtt"].contains(ext) { return .subtitle }
        if documentExtensions.contains(ext) { return .document }
        if ffmpegVideoExtensions.contains(ext) { return .video }
        if ffmpegAudioExtensions.contains(ext) { return .audio }
        guard let type = UTType(filenameExtension: ext) else { return .other }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .video }
        if type.conforms(to: .audio) { return .audio }
        if type.conforms(to: .text) || type.conforms(to: .rtf) || type.conforms(to: .html) { return .document }
        return .other
    }

    /// Text-like documents NSAttributedString can read.
    static let documentExtensions: Set<String> = [
        "txt", "text", "md", "markdown", "rtf", "rtfd", "html", "htm",
        "doc", "docx", "odt", "webarchive", "log", "xml", "yaml", "yml",
    ]

    /// Tables and structured data.
    static let dataExtensions: Set<String> = ["csv", "tsv", "json", "xlsx", "plist"]

    /// Office files that need LibreOffice.
    static let officeExtensions: Set<String> = ["xls", "ods", "numbers", "ppt", "pptx", "odp", "key", "pages"]

    static let archiveSuffixes: [String] = [
        ".zip", ".tar", ".tar.gz", ".tgz", ".tar.bz2", ".tbz", ".tbz2", ".tar.xz", ".txz",
        ".gz", ".bz2", ".7z", ".rar", ".cpio", ".xar",
    ]

    /// Formats macOS can't play on its own but FFmpeg can.
    static let ffmpegVideoExtensions: Set<String> = ["webm", "mkv", "avi", "flv", "wmv", "mpeg", "mpg", "ts", "m2ts", "ogv", "vob", "3gp"]
    static let ffmpegAudioExtensions: Set<String> = ["ogg", "oga", "opus", "wma", "ape", "wv", "ac3", "dts", "amr"]

    /// The common kind of a group of files, or `nil` when they are mixed.
    public static func common(_ urls: [URL]) -> FileKind? {
        let kinds = Set(urls.map(FileKind.of))
        return kinds.count == 1 ? kinds.first : nil
    }

    /// Whether macOS can read this file without an extra engine.
    public static func isNativeMedia(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        return !ffmpegVideoExtensions.contains(ext) && !ffmpegAudioExtensions.contains(ext)
    }
}
