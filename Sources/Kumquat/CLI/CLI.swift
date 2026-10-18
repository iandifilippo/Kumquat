import AppKit
import KumquatCore

/// The `kumquat` command. The app binary runs it when started with a subcommand.
enum CLI {
    /// Returned by commands that keep running (watch) instead of exiting.
    static let keepRunning: Int32 = -1
    /// Keeps the folder watcher alive while `kumquat watch` runs.
    private static var activeWatcher: FolderWatcher?

    static let commands: Set<String> = ["convert", "tool", "formats", "watch", "engines", "help", "--help", "-h", "version", "--version"]

    static let usage = """
    Kumquat — convert and edit files from Terminal.

    USAGE
      kumquat convert <files…> --to <format> [-o <folder>] [--quality <1-100>]
      kumquat tool <name> <files…> [-o <folder>] [--scale <0.1-2>] [--password <pw>]
      kumquat formats <file>              What a file can become
      kumquat watch <folder> (--to <format> | --tool <name>) [--move-originals]
      kumquat engines                     Optional engines found on this Mac

    TOOLS
      compress, resize (--scale), remove-bg, metadata, text, rotate, flip, bw, background,
      merge, split, one-image, protect (--password), compress-pdf, frames, mute, zip, extract

    EXAMPLES
      kumquat convert photo.heic --to jpg
      kumquat convert *.png --to webp -o converted
      kumquat tool compress IMG_*.jpg
      kumquat watch ~/Downloads/Inbox --to pdf --move-originals
    """

    static let toolNames: [String: ToolID] = [
        "compress": .compress, "resize": .resize, "remove-bg": .removeBackground, "removebg": .removeBackground,
        "metadata": .stripMetadata, "text": .extractText, "ocr": .extractText, "rotate": .rotate, "flip": .flip,
        "bw": .grayscale, "grayscale": .grayscale, "background": .addBackground, "merge": .merge, "split": .split,
        "one-image": .longImage, "protect": .protect, "compress-pdf": .compressPDF, "frames": .frames,
        "mute": .mute, "compress-video": .compressVideo, "zip": .zip, "extract": .extract, "crop": .crop,
    ]

    /// Runs the command and returns the process exit code.
    @MainActor
    static func run(_ args: [String]) async -> Int32 {
        // Line-buffered so progress shows up immediately, even when piped.
        setvbuf(stdout, nil, _IOLBF, 0)
        var rest = Array(args.dropFirst())
        guard let command = rest.first else { print(usage); return 0 }
        rest.removeFirst()
        do {
            switch command {
            case "help", "--help", "-h": print(usage)
            case "version", "--version": print("Kumquat \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
            case "engines": printEngines()
            case "formats": try formats(rest)
            case "convert": return try await convert(rest)
            case "tool": return try await tool(rest)
            case "watch":
                try watch(rest)
                return keepRunning
            default: print(usage); return 2
            }
            return 0
        } catch {
            fputs("kumquat: \(ActionRunner.message(for: error))\n", stderr)
            return 1
        }
    }

    // MARK: Commands

    @MainActor
    static func convert(_ args: [String]) async throws -> Int32 {
        var a = Args(args)
        guard let to = a.value("--to", "-t"), let format = OutputFormat(rawValue: to.lowercased().replacingOccurrences(of: "jpeg", with: "jpg")) else {
            throw KumquatError.badData("Choose a format with --to, e.g. --to jpg")
        }
        let engine = makeEngine(&a)
        return await runAction(.convert(format), files: a.files, engine: engine, parameters: .none)
    }

    @MainActor
    static func tool(_ args: [String]) async throws -> Int32 {
        var a = Args(args)
        guard let name = a.files.first, let tool = toolNames[name.lowercased()] else {
            throw KumquatError.badData("Unknown tool. Run `kumquat help` for the list.")
        }
        a.files.removeFirst()
        var params = ToolParameters.none
        if tool == .resize { params = .scale(Double(a.value("--scale") ?? "0.5") ?? 0.5) }
        if tool == .protect {
            guard let pw = a.value("--password") else { throw KumquatError.badData("Add --password <password>") }
            params = .password(pw)
        }
        if tool == .crop { throw KumquatError.badData("Crop needs the app's editor; try it from the ring.") }
        if tool == .addBackground { params = .background(SettingsStore.shared.lastBackground) }
        let engine = makeEngine(&a)
        return await runAction(.tool(tool), files: a.files, engine: engine, parameters: params)
    }

    static func formats(_ args: [String]) throws {
        let urls = Args(args).files.map { URL(fileURLWithPath: $0) }
        guard !urls.isEmpty else { throw KumquatError.badData("Name a file, e.g. kumquat formats photo.heic") }
        let convert = ActionCatalog.convertActions(for: urls).compactMap { if case .convert(let f) = $0 { return f.rawValue } else { return nil } }
        let tools = ActionCatalog.toolActions(for: urls).compactMap { action -> String? in
            guard case .tool(let t) = action else { return nil }
            return toolNames.first { $0.value == t }?.key
        }
        print("Convert to: " + (convert.isEmpty ? "—" : convert.joined(separator: ", ")))
        print("Tools:      " + (tools.isEmpty ? "—" : tools.joined(separator: ", ")))
    }

    static func printEngines() {
        let e = Engines.current
        func line(_ name: String, _ url: URL?, _ hint: String) {
            print(url.map { "✓ \(name)  \($0.path)" } ?? "· \(name)  not installed — \(hint)")
        }
        line("FFmpeg     ", e.ffmpeg, "brew install ffmpeg")
        line("LibreOffice", e.soffice, "https://www.libreoffice.org")
        line("Ghostscript", e.ghostscript, "brew install ghostscript")
        line("cwebp      ", e.cwebp, "brew install webp")
    }

    @MainActor
    static func watch(_ args: [String]) throws {
        var a = Args(args)
        let actionID: String
        if let to = a.value("--to", "-t") {
            actionID = "convert.\(to.lowercased())"
        } else if let name = a.value("--tool"), let t = toolNames[name.lowercased()] {
            actionID = "tool.\(t.rawValue)"
        } else {
            throw KumquatError.badData("Add --to <format> or --tool <name>")
        }
        let move = a.flag("--move-originals")
        guard let path = a.files.first else { throw KumquatError.badData("Name a folder to watch") }
        let folder = URL(fileURLWithPath: (path as NSString).expandingTildeInPath, isDirectory: true)
        let rule = WatchRule(folder: folder.path, action: actionID, moveOriginals: move)
        let watcher = WatchService.watcher(for: rule) { message in print(message) }
        watcher.start()
        activeWatcher = watcher
        print("Watching \(folder.path) — press Ctrl-C to stop.")
    }

    // MARK: Helpers

    static func makeEngine(_ a: inout Args) -> KumquatCore.Engine {
        var options = SettingsStore.shared.conversionOptions
        if let q = a.value("--quality", "-q").flatMap(Double.init) {
            options.imageQuality = min(max(q / 100, 0.01), 1)
            options.compressQuality = options.imageQuality
        }
        var location = SettingsStore.shared.outputLocation
        if let out = a.value("-o", "--output") {
            location = .folder(URL(fileURLWithPath: (out as NSString).expandingTildeInPath, isDirectory: true))
        }
        let suffixes = Dictionary(uniqueKeysWithValues: ToolID.allCases.map { ($0, $0.fileSuffix) })
        return KumquatCore.Engine(options: options, planner: OutputPlanner(location: location) { suffixes[$0] ?? OutputPlanner.englishSuffix($0) })
    }

    @MainActor
    static func runAction(_ action: KQAction, files: [String], engine: KumquatCore.Engine, parameters: ToolParameters) async -> Int32 {
        let urls = files.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
        guard !urls.isEmpty else { fputs("kumquat: no files given\n", stderr); return 2 }
        var failures: Int32 = 0
        // Group actions (merge, zip, several images → PDF) take all files at once.
        let grouped: Bool = {
            if case .tool(let t) = action { return t == .merge || t == .zip }
            if case .convert(.pdf) = action { return urls.count > 1 && engine.options.combineImagesIntoPDF }
            return false
        }()
        let batches = grouped ? [urls] : urls.map { [$0] }
        for batch in batches {
            do {
                let outcome = try await engine.run(action, on: batch, parameters: parameters)
                for out in outcome.outputs {
                    print("✓ \(batch.map(\.lastPathComponent).joined(separator: ", ")) → \(out.path)")
                }
            } catch {
                failures += 1
                fputs("✗ \(batch.map(\.lastPathComponent).joined(separator: ", ")): \(ActionRunner.message(for: error))\n", stderr)
            }
        }
        return failures == 0 ? 0 : 1
    }
}

/// Minimal argument parsing: options with values, flags, and the remaining file names.
struct Args {
    var files: [String] = []
    private var options: [String: String] = [:]
    private var flags: Set<String> = []
    private static let valued: Set<String> = ["--to", "-t", "-o", "--output", "--quality", "-q", "--scale", "--password", "--tool"]

    init(_ args: [String]) {
        var i = 0
        while i < args.count {
            let a = args[i]
            if Self.valued.contains(a), i + 1 < args.count {
                options[a] = args[i + 1]
                i += 2
                continue
            }
            if a.hasPrefix("--") { flags.insert(a) } else { files.append(a) }
            i += 1
        }
    }

    func value(_ names: String...) -> String? { names.lazy.compactMap { options[$0] }.first }
    func flag(_ name: String) -> Bool { flags.contains(name) }
}
