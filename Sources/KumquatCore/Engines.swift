import Foundation

/// Optional command-line engines. Kumquat never downloads them; it uses them when the user
/// already has them (Homebrew, LibreOffice.app) and offers more formats.
public struct Engines: Sendable, Equatable {
    public var ffmpeg: URL?
    public var soffice: URL?
    public var ghostscript: URL?
    /// Google's WebP encoder (`brew install webp`).
    public var cwebp: URL?
    /// Encoders this FFmpeg build has (builds differ: Homebrew's has no Vorbis or WebP).
    public var ffmpegEncoders: Set<String>

    public init(ffmpeg: URL? = nil, soffice: URL? = nil, ghostscript: URL? = nil, cwebp: URL? = nil, ffmpegEncoders: Set<String>? = nil) {
        self.ffmpeg = ffmpeg
        self.soffice = soffice
        self.ghostscript = ghostscript
        self.cwebp = cwebp
        self.ffmpegEncoders = ffmpegEncoders ?? (ffmpeg == nil ? [] : ["libx264", "libx265", "libvpx-vp9", "libmp3lame", "libopus", "libvorbis", "libwebp", "aac", "flac", "mpeg4"])
    }

    /// WebP needs cwebp or an FFmpeg built with libwebp.
    public var canWriteWebP: Bool { cwebp != nil || ffmpegEncoders.contains("libwebp") }

    private static let lock = NSLock()
    nonisolated(unsafe) private static var cached: Engines?

    /// The engines found on this Mac (looked up once, then cached until `refresh()`).
    public static var current: Engines {
        lock.lock(); defer { lock.unlock() }
        if let cached { return cached }
        let found = detect()
        cached = found
        return found
    }

    /// Use this set instead of the detected one (tests, or "turn engines off").
    public static func override(_ engines: Engines?) {
        lock.lock(); defer { lock.unlock() }
        cached = engines
    }

    @discardableResult
    public static func refresh() -> Engines {
        override(nil)
        return current
    }

    public static func detect() -> Engines {
        let bins = ["/opt/homebrew/bin", "/usr/local/bin", "/opt/local/bin", "/usr/bin"]
        func find(_ name: String) -> URL? {
            for dir in bins {
                let path = dir + "/" + name
                if FileManager.default.isExecutableFile(atPath: path) { return URL(fileURLWithPath: path) }
            }
            return nil
        }
        let officeApps = ["/Applications/LibreOffice.app", NSHomeDirectory() + "/Applications/LibreOffice.app"]
        let soffice = officeApps.map { $0 + "/Contents/MacOS/soffice" }.first { FileManager.default.isExecutableFile(atPath: $0) }
        let ffmpeg = find("ffmpeg")
        return Engines(ffmpeg: ffmpeg, soffice: soffice.map { URL(fileURLWithPath: $0) }, ghostscript: find("gs"),
                       cwebp: find("cwebp"), ffmpegEncoders: ffmpeg.map(encoders) ?? [])
    }

    /// Asks FFmpeg which encoders it was built with.
    static func encoders(_ ffmpeg: URL) -> Set<String> {
        let process = Process()
        process.executableURL = ffmpeg
        process.arguments = ["-hide_banner", "-encoders"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        // A semaphore, not waitUntilExit(): that spins the run loop, which breaks SwiftUI
        // when detection happens during a view update.
        let done = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in done.signal() }
        guard (try? process.run()) != nil else { return [] }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        _ = done.wait(timeout: .now() + 10)
        var names: Set<String> = []
        for line in String(decoding: data, as: UTF8.self).split(separator: "\n") {
            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
            if parts.count >= 2, parts[0].count == 6 { names.insert(String(parts[1])) }
        }
        return names
    }

    // MARK: Running tools

    /// Runs a command and throws with its last error lines if it fails.
    @discardableResult
    public static func run(_ tool: URL, _ arguments: [String], currentDirectory: URL? = nil, timeout: TimeInterval = 600) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            let process = Process()
            process.executableURL = tool
            process.arguments = arguments
            if let currentDirectory { process.currentDirectoryURL = currentDirectory }
            let out = Pipe(), err = Pipe()
            process.standardOutput = out
            process.standardError = err
            let output = LockedData(), errors = LockedData()
            out.fileHandleForReading.readabilityHandler = { output.append($0.availableData) }
            err.fileHandleForReading.readabilityHandler = { errors.append($0.availableData) }
            let timer = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timer)
            process.terminationHandler = { p in
                timer.cancel()
                out.fileHandleForReading.readabilityHandler = nil
                err.fileHandleForReading.readabilityHandler = nil
                output.append(out.fileHandleForReading.readDataToEndOfFile())
                errors.append(err.fileHandleForReading.readDataToEndOfFile())
                if p.terminationStatus == 0 {
                    cont.resume(returning: String(decoding: output.data, as: UTF8.self))
                } else {
                    let message = String(decoding: errors.data, as: UTF8.self)
                        .split(separator: "\n").suffix(2).joined(separator: " ")
                    cont.resume(throwing: KumquatError.toolFailed(tool.lastPathComponent, message))
                }
            }
            do { try process.run() } catch { cont.resume(throwing: error) }
        }
    }
}

/// Collects pipe output from background threads.
final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    func append(_ d: Data) { lock.lock(); storage.append(d); lock.unlock() }
    var data: Data { lock.lock(); defer { lock.unlock() }; return storage }
}

// MARK: - FFmpeg

public enum FFmpeg {
    static func require() throws -> URL {
        guard let url = Engines.current.ffmpeg else { throw KumquatError.needsEngine("FFmpeg") }
        return url
    }

    /// Codec settings for each output, using what this FFmpeg build has.
    static func arguments(for format: OutputFormat) -> [String] {
        let has = Engines.current.ffmpegEncoders
        switch format {
        case .ogg where !has.contains("libvorbis"):
            // Opus in an Ogg container plays everywhere Ogg Vorbis does.
            return ["-vn", "-c:a", "libopus", "-b:a", "160k"]
        case .mp4, .m4v: return ["-c:v", "libx264", "-preset", "medium", "-crf", "22", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart"]
        case .mov: return ["-c:v", "libx264", "-preset", "medium", "-crf", "20", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "192k"]
        case .webm: return ["-c:v", "libvpx-vp9", "-b:v", "0", "-crf", "32", "-row-mt", "1", "-c:a", "libopus", "-b:a", "128k"]
        case .mkv: return ["-c:v", "libx264", "-crf", "20", "-c:a", "aac", "-b:a", "192k"]
        case .avi: return ["-c:v", "mpeg4", "-q:v", "3", "-c:a", "libmp3lame", "-q:a", "3"]
        case .mp3: return ["-vn", "-c:a", "libmp3lame", "-q:a", "2"]
        case .m4a: return ["-vn", "-c:a", "aac", "-b:a", "256k"]
        case .ogg: return ["-vn", "-c:a", "libvorbis", "-q:a", "6"]
        case .opus: return ["-vn", "-c:a", "libopus", "-b:a", "160k"]
        case .wav: return ["-vn", "-c:a", "pcm_s16le"]
        case .aiff: return ["-vn", "-c:a", "pcm_s16be"]
        case .flac: return ["-vn", "-c:a", "flac"]
        case .caf: return ["-vn", "-c:a", "pcm_s16le"]
        case .webp: return ["-c:v", "libwebp", "-quality", "90", "-lossless", "0"]
        default: return []
        }
    }

    public static func convert(_ input: URL, to output: URL, format: OutputFormat) async throws {
        if format == .webp, let cwebp = Engines.current.cwebp {
            try await Engines.run(cwebp, ["-quiet", "-q", "90", "-metadata", "icc", input.path, "-o", output.path])
            return
        }
        try await Engines.run(try require(), ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path] + arguments(for: format) + [output.path])
    }

    public static func gif(_ input: URL, to output: URL, fps: Int, maxWidth: Int, maxSeconds: Double) async throws {
        let filter = "fps=\(fps),scale='min(\(maxWidth),iw)':-1:flags=lanczos,split[a][b];[a]palettegen[p];[b][p]paletteuse"
        try await Engines.run(try require(), ["-hide_banner", "-loglevel", "error", "-y", "-t", "\(maxSeconds)", "-i", input.path, "-vf", filter, output.path])
    }

    public static func frames(_ input: URL, into folder: URL, fps: Double?) async throws {
        var args = ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path]
        if let fps { args += ["-vf", "fps=\(fps)"] }
        args += ["-q:v", "2", "-frames:v", "5000", folder.appendingPathComponent("frame_%05d.jpg").path]
        try await Engines.run(try require(), args)
    }

    public static func compress(_ input: URL, to output: URL) async throws {
        try await Engines.run(try require(), ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path,
                                              "-vf", "scale='min(1920,iw)':-2", "-c:v", "libx265", "-crf", "28", "-tag:v", "hvc1",
                                              "-c:a", "aac", "-b:a", "128k", "-movflags", "+faststart", output.path])
    }

    public static func mute(_ input: URL, to output: URL) async throws {
        try await Engines.run(try require(), ["-hide_banner", "-loglevel", "error", "-y", "-i", input.path, "-c", "copy", "-an", output.path])
    }
}

// MARK: - LibreOffice

public enum LibreOffice {
    /// Converts with `soffice --headless`. `filter` is LibreOffice's target, e.g. "pdf" or "docx".
    public static func convert(_ input: URL, to output: URL, filter: String) async throws {
        guard let soffice = Engines.current.soffice else { throw KumquatError.needsEngine("LibreOffice") }
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("kumquat-lo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: work) }
        // A private profile so a LibreOffice window that is already open doesn't block the conversion.
        let profile = FileManager.default.temporaryDirectory.appendingPathComponent("kumquat-lo-profile").absoluteString
        try await Engines.run(soffice, ["-env:UserInstallation=\(profile)", "--headless", "--norestore",
                                        "--convert-to", filter, "--outdir", work.path, input.path], timeout: 300)
        guard let made = try FileManager.default.contentsOfDirectory(at: work, includingPropertiesForKeys: nil).first else {
            throw KumquatError.writeFailed(output)
        }
        try FileManager.default.moveItem(at: made, to: output)
    }

    static func filter(for format: OutputFormat) -> String {
        switch format {
        case .csv: return "csv:Text - txt - csv (StarCalc):44,34,76,1"
        default: return format.fileExtension
        }
    }
}

// MARK: - Ghostscript

public enum Ghostscript {
    /// `setting` is one of Ghostscript's presets: "screen" (smallest), "ebook", "printer".
    public static func compress(_ input: URL, to output: URL, setting: String) async throws {
        guard let gs = Engines.current.ghostscript else { throw KumquatError.needsEngine("Ghostscript") }
        try await Engines.run(gs, ["-sDEVICE=pdfwrite", "-dCompatibilityLevel=1.5", "-dPDFSETTINGS=/\(setting)",
                                   "-dNOPAUSE", "-dQUIET", "-dBATCH", "-sOutputFile=\(output.path)", input.path])
    }
}
