import Foundation

/// SRT ↔ WebVTT, and plain text transcripts.
public enum Subtitles {
    public struct Cue: Equatable, Sendable {
        public var start: String   // "00:01:02.345"
        public var end: String
        public var text: String
    }

    public static func read(_ url: URL) throws -> [Cue] {
        guard var text = (try? String(contentsOf: url, encoding: .utf8)) ?? (try? String(contentsOf: url, encoding: .windowsCP1252)) else {
            throw KumquatError.unreadable(url)
        }
        if text.hasPrefix("\u{FEFF}") { text.removeFirst() }
        text = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        var cues: [Cue] = []
        for block in text.components(separatedBy: "\n\n") {
            let lines = block.split(separator: "\n", omittingEmptySubsequences: false).map(String.init).filter { !$0.isEmpty }
            guard let timing = lines.firstIndex(where: { $0.contains("-->") }) else { continue }
            let parts = lines[timing].components(separatedBy: "-->")
            guard parts.count == 2 else { continue }
            let start = normalize(parts[0])
            // VTT cue settings ("align:start") follow the end time.
            let end = normalize(parts[1].trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? "")
            let body = lines[(timing + 1)...].joined(separator: "\n")
            cues.append(Cue(start: start, end: end, text: body))
        }
        if cues.isEmpty { throw KumquatError.badData("No subtitles were found.") }
        return cues
    }

    /// "1:02,345" or "00:01:02.345" → "00:01:02.345".
    static func normalize(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        var parts = t.components(separatedBy: ":")
        while parts.count < 3 { parts.insert("00", at: 0) }
        let h = parts[0].count < 2 ? "0" + parts[0] : parts[0]
        let m = parts[1].count < 2 ? "0" + parts[1] : parts[1]
        var s = parts[2]
        if !s.contains(".") { s += ".000" }
        if s.firstIndex(of: ".") == s.index(after: s.startIndex) { s = "0" + s }
        return "\(h):\(m):\(s)"
    }

    public static func write(_ cues: [Cue], to url: URL, format: OutputFormat) throws {
        let out: String
        switch format {
        case .srt:
            out = cues.enumerated().map { i, c in
                "\(i + 1)\n\(c.start.replacingOccurrences(of: ".", with: ",")) --> \(c.end.replacingOccurrences(of: ".", with: ","))\n\(stripTags(c.text))"
            }.joined(separator: "\n\n") + "\n"
        case .vtt:
            out = "WEBVTT\n\n" + cues.map { "\($0.start) --> \($0.end)\n\($0.text)" }.joined(separator: "\n\n") + "\n"
        case .txt:
            out = cues.map { stripTags($0.text) }.joined(separator: "\n") + "\n"
        default:
            throw KumquatError.unsupported(format.label)
        }
        try Data(out.utf8).write(to: url)
    }

    /// SRT players don't understand VTT voice and class tags.
    static func stripTags(_ s: String) -> String {
        s.replacingOccurrences(of: #"</?(v|c|lang|ruby|rt)[^>]*>"#, with: "", options: .regularExpression)
    }
}
