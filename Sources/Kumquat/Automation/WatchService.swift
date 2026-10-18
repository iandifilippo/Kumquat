import AppKit
import Combine
import KumquatCore

/// Runs the watch-folder rules from Settings.
final class WatchService {
    static let shared = WatchService()
    private var watchers: [UUID: FolderWatcher] = [:]
    private var cancellable: AnyCancellable?

    func start() {
        apply(SettingsStore.shared.watchRules)
        cancellable = SettingsStore.shared.$watchRules
            .removeDuplicates()
            .sink { [weak self] in self?.apply($0) }
    }

    private func apply(_ rules: [WatchRule]) {
        watchers.values.forEach { $0.stop() }
        watchers = [:]
        for rule in rules where rule.enabled {
            let w = Self.watcher(for: rule) { message in NSLog("Kumquat watch: %@", message) }
            w.start()
            watchers[rule.id] = w
        }
    }

    /// A watcher that converts each new file with the rule's action.
    static func watcher(for rule: WatchRule, log: @escaping @Sendable (String) -> Void) -> FolderWatcher {
        let folder = URL(fileURLWithPath: rule.folder, isDirectory: true)
        weak var watcherRef: FolderWatcher?
        let watcher = FolderWatcher(folder: folder) { url in
            guard let action = rule.applies(to: url) else { return }
            Task { @MainActor in
                let suffixes = Dictionary(uniqueKeysWithValues: ToolID.allCases.map { ($0, $0.fileSuffix) })
                let engine = KumquatCore.Engine(options: SettingsStore.shared.conversionOptions,
                                                planner: OutputPlanner(location: .nextToOriginal) { suffixes[$0] ?? OutputPlanner.englishSuffix($0) })
                do {
                    let outcome = try await engine.run(action, on: [url])
                    watcherRef?.ignore(outcome.outputs)
                    if rule.moveOriginals {
                        let originals = folder.appendingPathComponent(L("Originals"), isDirectory: true)
                        try? FileManager.default.createDirectory(at: originals, withIntermediateDirectories: true)
                        watcherRef?.ignore([originals])
                        try? FileManager.default.moveItem(at: url, to: OutputPlanner.unique(originals.appendingPathComponent(url.lastPathComponent)))
                    }
                    log("✓ \(url.lastPathComponent) → \(outcome.outputs.map(\.lastPathComponent).joined(separator: ", "))")
                    SettingsStore.shared.addRecents(outcome.outputs)
                } catch {
                    log("✗ \(url.lastPathComponent): \(ActionRunner.message(for: error))")
                }
            }
        }
        watcherRef = watcher
        return watcher
    }
}
