import AppKit
import KumquatCore

/// Runs a ring action: opens an editor first if the tool needs one, then reports progress in a toast.
final class ActionRunner {
    static let shared = ActionRunner()

    func start(_ action: KQAction, files: [URL], progress: ((Double) -> Void)? = nil, completion: ((Bool) -> Void)? = nil) {
        guard !files.isEmpty else { return }
        if case .tool(let tool) = action, tool.needsEditor {
            EditorWindows.open(tool, files: files) { [weak self] params in
                self?.run(action, files: files, parameters: params)
            }
            return
        }
        run(action, files: files, parameters: .none, progress: progress, completion: completion)
    }

    func run(_ action: KQAction, files: [URL], parameters: ToolParameters,
             progress onProgress: ((Double) -> Void)? = nil, completion: ((Bool) -> Void)? = nil) {
        let settings = SettingsStore.shared
        let suffixes = Dictionary(uniqueKeysWithValues: ToolID.allCases.map { ($0, $0.fileSuffix) })
        let planner = OutputPlanner(location: settings.outputLocation) { suffixes[$0] ?? OutputPlanner.englishSuffix($0) }
        let engine = Engine(options: settings.conversionOptions, planner: planner)
        let toast = ToastCenter.shared.showProgress(title: action.progressTitle, total: files.count)

        Task {
            do {
                let outcome = try await engine.run(action, on: files, parameters: parameters) { done, total in
                    DispatchQueue.main.async {
                        toast.progress(done: done, total: total)
                        if total > 1 { onProgress?(Double(done) / Double(total)) }
                    }
                }
                await MainActor.run {
                    completion?(true)
                    self.finish(outcome, action: action, files: files)
                }
            } catch KumquatError.notSmaller {
                await MainActor.run {
                    completion?(false)
                    ToastCenter.shared.showInfo(L("Already optimized"), detail: L("Kumquat couldn't make it any smaller, so nothing was saved."))
                }
            } catch {
                await MainActor.run {
                    completion?(false)
                    NSSound.beep()
                    ToastCenter.shared.showFailure(L("Couldn't finish"), detail: Self.message(for: error))
                }
            }
        }
    }

    @MainActor
    private func finish(_ outcome: ActionOutcome, action: KQAction, files: [URL]) {
        let settings = SettingsStore.shared
        if settings.playSound { NSSound(named: "Pop")?.play() }
        if settings.revealInFinder { NSWorkspace.shared.activateFileViewerSelecting(outcome.outputs) }
        var trashed: [URL] = []
        if settings.trashOriginal, case .convert = action {
            for url in files {
                var result: NSURL?
                if (try? FileManager.default.trashItem(at: url, resultingItemURL: &result)) != nil, let r = result as URL? {
                    trashed.append(r)
                }
            }
        }
        settings.addRecents(outcome.outputs)
        ToastCenter.shared.showSuccess(outcome, detail: summary(outcome, action: action, files: files),
                                       originals: files, trashedOriginals: trashed)
    }

    /// The second line of the notification, tailored to what was done.
    @MainActor
    private func summary(_ outcome: ActionOutcome, action: KQAction, files: [URL]) -> String {
        var parts: [String] = []
        switch action {
        case .tool(.extractText), .tool(.extractPDFText):
            // Recognized text is most useful on the clipboard.
            let text = outcome.outputs.compactMap { try? String(contentsOf: $0, encoding: .utf8) }.joined(separator: "\n\n")
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            let words = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
            return L("%d words · copied to the clipboard", words)
        case .tool(.compress), .tool(.compressPDF), .tool(.compressVideo):
            if let d = outcome.detail { parts.append(d) }
            parts.append(ByteText.change(from: outcome.inputBytes, to: outcome.outputBytes))
        case .tool(.split):
            parts.append(L("%d pages", outcome.outputs.count))
        case .tool(.frames):
            parts.append(L("%@ frames", outcome.detail ?? "0"))
        case .tool(.zip):
            parts.append(L("%d items", files.count))
            parts.append(ByteText.change(from: outcome.inputBytes, to: outcome.outputBytes))
        case .tool(.extract):
            let count = (try? FileManager.default.contentsOfDirectory(atPath: outcome.outputs.first?.path ?? "").count) ?? 0
            parts.append(L("%d items", count))
        case .tool(.merge):
            parts.append(L("%d files combined", files.count))
            parts.append(ByteText.string(outcome.outputBytes))
        case .tool(.protect):
            parts.append(L("Password protected"))
        case .tool(.stripMetadata):
            parts.append(L("Location and camera data removed"))
        case .tool:
            if let d = outcome.detail { parts.append(d) }
            parts.append(ByteText.string(outcome.outputBytes))
        case .convert(let format):
            let from = Set(files.map { $0.pathExtension.uppercased() }).sorted().joined(separator: ", ")
            parts.append("\(from) → \(format.label)")
            if let d = outcome.detail { parts.append(d) }
            parts.append(ByteText.string(outcome.outputBytes))
        }
        return parts.joined(separator: " · ")
    }

    /// A short, translated explanation of what went wrong.
    static func message(for error: Error) -> String {
        switch error {
        case KumquatError.unreadable(let url): return L("Couldn't read %@.", url.lastPathComponent)
        case KumquatError.unsupported(let what): return L("%@ isn't supported.", what)
        case KumquatError.writeFailed(let url): return L("Couldn't save %@.", url.lastPathComponent)
        case KumquatError.noText: return L("No text was found.")
        case KumquatError.noSubject: return L("No clear subject was found to cut out.")
        case KumquatError.needsEngine(let name): return L("This needs %@. Install it and try again (Settings → Engines).", name)
        case KumquatError.toolFailed(let tool, let message): return "\(tool): \(message)"
        case KumquatError.badData(let why): return why
        default: return error.localizedDescription
        }
    }

    /// Moves the results to the Trash and puts back originals that were trashed.
    func undo(outputs: [URL], originals: [URL], trashed: [URL]) {
        for url in outputs { try? FileManager.default.trashItem(at: url, resultingItemURL: nil) }
        for (original, inTrash) in zip(originals, trashed) {
            try? FileManager.default.moveItem(at: inTrash, to: original)
        }
    }
}

enum ByteText {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    /// "2.4 MB → 610 KB · 75% smaller"
    static func change(from a: Int64, to b: Int64) -> String {
        guard a > 0, b > 0 else { return string(b) }
        let base = "\(string(a)) → \(string(b))"
        let pct = Int((1 - Double(b) / Double(a)) * 100)
        if pct >= 1 { return base + " · " + L("%d%% smaller", pct) }
        if pct <= -1 { return base + " · " + L("%d%% larger", -pct) }
        return base
    }
}
