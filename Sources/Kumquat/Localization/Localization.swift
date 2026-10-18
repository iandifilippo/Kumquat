import Foundation
import KumquatCore

enum AppLanguage: String, Codable, CaseIterable, Identifiable {
    case system, en, es, pt, fr, de, it, ja, ko, zhHans = "zh-Hans"
    var id: String { rawValue }

    /// Each language's name in its own language.
    var name: String {
        switch self {
        case .system: return L("System language")
        case .en: return "English"
        case .es: return "Español"
        case .pt: return "Português (Brasil)"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .zhHans: return "简体中文"
        }
    }

    /// The language actually used for text.
    var resolved: AppLanguage {
        guard self == .system else { return self }
        for preferred in Locale.preferredLanguages {
            if preferred.hasPrefix("zh-Hans") || preferred == "zh-CN" || preferred.hasPrefix("zh-SG") { return .zhHans }
            let code = String(preferred.prefix(2))
            if let match = AppLanguage(rawValue: code), match != .system { return match }
        }
        return .en
    }

    var table: [String: String]? {
        switch self {
        case .system, .en: return nil
        case .es: return Translations.es
        case .pt: return Translations.pt
        case .fr: return Translations.fr
        case .de: return Translations.de
        case .it: return Translations.it
        case .ja: return Translations.ja
        case .ko: return Translations.ko
        case .zhHans: return Translations.zhHans
        }
    }
}

/// Looks up the current translation of an English string.
/// English text is the key, so missing translations fall back gracefully.
func L(_ english: String) -> String {
    SettingsStore.shared.language.resolved.table?[english] ?? english
}

/// `L` with `String(format:)` arguments, e.g. `L("%d of %d saved", 1, 3)`.
func L(_ english: String, _ args: CVarArg...) -> String {
    String(format: L(english), arguments: args)
}

extension ToolID {
    var title: String {
        switch self {
        case .compress, .compressPDF, .compressVideo: return L("Compress")
        case .resize: return L("Resize")
        case .crop: return L("Crop")
        case .addBackground: return L("Add BG")
        case .removeBackground: return L("Remove BG")
        case .rotate, .rotatePDF: return L("Rotate")
        case .flip: return L("Flip")
        case .grayscale: return L("B&W")
        case .stripMetadata: return L("Metadata")
        case .extractText, .extractPDFText: return L("Get Text")
        case .merge: return L("Merge")
        case .split: return L("Split")
        case .protect: return L("Protect")
        case .mute: return L("Mute")
        case .longImage: return L("One Image")
        case .frames: return L("Frames")
        case .zip: return "ZIP"
        case .extract: return L("Extract")
        }
    }

    /// A longer description used in Settings.
    var explanation: String {
        switch self {
        case .compress: return L("Smaller file, same look")
        case .compressPDF: return L("Shrinks images inside the PDF")
        case .compressVideo: return L("HEVC, up to 1080p")
        case .resize: return L("Pick a new size")
        case .crop: return L("Free or fixed ratio")
        case .addBackground: return L("Pretty backdrop for screenshots")
        case .removeBackground: return L("Cut out the subject, on-device")
        case .rotate, .rotatePDF: return L("90° clockwise")
        case .flip: return L("Mirror horizontally")
        case .grayscale: return L("Black and white")
        case .stripMetadata: return L("Remove location and camera data")
        case .extractText: return L("Recognize text in the image")
        case .extractPDFText: return L("Text layer, or OCR for scans")
        case .merge: return L("Combine files into one PDF")
        case .split: return L("One PDF per page")
        case .protect: return L("Add a password")
        case .mute: return L("Remove the audio track")
        case .longImage: return L("All pages as one tall picture")
        case .frames: return L("Every frame as a JPG, in a folder")
        case .zip: return L("Compress files and folders into a ZIP")
        case .extract: return L("Unpack ZIP, RAR, 7Z, TAR and more")
        }
    }

    /// Word appended to output file names.
    var fileSuffix: String {
        let english = OutputPlanner.englishSuffix(self)
        let word = SettingsStore.shared.language.resolved.table?[english] ?? english
        // Some labels ("B/N") contain characters that can't go in a file name.
        return word.replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")
    }
}

extension KQAction {
    var title: String {
        switch self {
        case .convert(let f): return f.label
        case .tool(let t): return t.title
        }
    }

    /// Text for "Converting to JPG" / "Compressing".
    var progressTitle: String {
        switch self {
        case .convert(let f): return L("Converting to %@", f.label)
        case .tool(let t): return L("%@ in progress", t.title)
        }
    }
}

extension FileKind {
    var title: String {
        switch self {
        case .image: return L("Images")
        case .pdf: return L("PDFs")
        case .document: return L("Documents")
        case .data: return L("Spreadsheets & data")
        case .ebook: return L("E-books")
        case .subtitle: return L("Subtitles")
        case .office: return L("Office (LibreOffice)")
        case .video: return L("Video")
        case .audio: return L("Audio")
        case .archive: return L("Archives")
        case .folder: return L("Folders")
        case .other: return L("Other")
        }
    }

    var symbol: String {
        switch self {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .document: return "doc.text"
        case .data: return "tablecells"
        case .ebook: return "book"
        case .subtitle: return "captions.bubble"
        case .office: return "rectangle.on.rectangle"
        case .video: return "film"
        case .audio: return "waveform"
        case .archive: return "doc.zipper"
        case .folder: return "folder"
        case .other: return "doc"
        }
    }

}
