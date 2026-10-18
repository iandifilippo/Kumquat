import Foundation

/// Watches a folder and reports files that land in it, once they've finished copying.
public final class FolderWatcher: @unchecked Sendable {
    public let folder: URL
    private let onFile: (URL) -> Void
    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String>
    private var ignored: Set<String> = []
    private let queue = DispatchQueue(label: "kumquat.watch")

    /// Files already in the folder are left alone; only new arrivals are reported.
    public init(folder: URL, onFile: @escaping (URL) -> Void) {
        self.folder = folder
        self.onFile = onFile
        known = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
    }

    deinit { stop() }

    public func start() {
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename, .link], queue: queue)
        src.setEventHandler { [weak self] in self?.scan() }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    public func stop() {
        source?.cancel()
        source = nil
    }

    /// Results Kumquat writes into the folder must not be converted again.
    public func ignore(_ urls: [URL]) {
        queue.async { self.ignored.formUnion(urls.map(\.lastPathComponent)) }
    }

    private func scan() {
        let names = Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? [])
        let fresh = names.subtracting(known).filter { !$0.hasPrefix(".") && !ignored.contains($0) }
        known = names
        for name in fresh {
            let url = folder.appendingPathComponent(name)
            waitUntilStable(url, lastSize: -1, attempts: 0)
        }
    }

    /// Waits until the size stops changing (downloads and copies write in chunks).
    private func waitUntilStable(_ url: URL, lastSize: Int64, attempts: Int) {
        queue.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, FileManager.default.fileExists(atPath: url.path) else { return }
            if url.pathExtension == "download" || url.pathExtension == "crdownload" || url.pathExtension == "part" { return }
            let size = url.fileSize
            if size == lastSize, size > 0 || url.hasDirectoryPath {
                self.onFile(url)
            } else if attempts < 600 {
                self.waitUntilStable(url, lastSize: size, attempts: attempts + 1)
            }
        }
    }
}

/// A folder plus what to do with files that arrive in it.
public struct WatchRule: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var folder: String
    /// A `KQAction.id`, e.g. "convert.jpg" or "tool.compress".
    public var action: String
    /// Move each original into an "Originals" subfolder after converting.
    public var moveOriginals: Bool = false
    public var enabled: Bool = true

    public init(folder: String, action: String, moveOriginals: Bool = false) {
        self.folder = folder
        self.action = action
        self.moveOriginals = moveOriginals
    }

    /// Whether this rule's action makes sense for the file (a JPG rule ignores PDFs, etc.).
    public func applies(to url: URL, engines: Engines = .current) -> KQAction? {
        let urls = [url]
        let all = ActionCatalog.convertActions(for: urls, engines: engines) + ActionCatalog.toolActions(for: urls, engines: engines)
        return all.first { $0.id == action }
    }
}

extension KQAction {
    /// The action for a stored id such as "convert.jpg".
    public init?(id: String) {
        let parts = id.split(separator: ".", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        switch parts[0] {
        case "convert": guard let f = OutputFormat(rawValue: parts[1]) else { return nil }; self = .convert(f)
        case "tool": guard let t = ToolID(rawValue: parts[1]) else { return nil }; self = .tool(t)
        default: return nil
        }
    }
}
