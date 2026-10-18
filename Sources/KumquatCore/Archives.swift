import Foundation

/// ZIP and friends, using the `zip`, `tar` (libarchive) and `gzip` tools that ship with macOS.
public enum Archives {
    static let zipTool = URL(fileURLWithPath: "/usr/bin/zip")
    static let tarTool = URL(fileURLWithPath: "/usr/bin/tar")

    /// Packs files and folders into one ZIP, skipping Finder clutter.
    public static func zip(_ items: [URL], to output: URL) async throws {
        try? FileManager.default.removeItem(at: output)
        for item in items {
            // Each item is added relative to its own folder, so the ZIP has no long paths.
            try await Engines.run(zipTool, ["-r", "-y", "-q", "-X", output.path, item.lastPathComponent,
                                            "-x", "*.DS_Store", "-x", "__MACOSX/*"],
                                  currentDirectory: item.deletingLastPathComponent())
        }
        guard FileManager.default.fileExists(atPath: output.path) else { throw KumquatError.writeFailed(output) }
    }

    public static func tarGz(folder: URL, to output: URL) async throws {
        try await Engines.run(tarTool, ["-czf", output.path, "-C", folder.path, "."])
    }

    /// Unpacks an archive into `folder`. Handles ZIP, TAR (any compression), 7Z, RAR, CPIO, XAR,
    /// and single-file .gz / .bz2.
    public static func extract(_ archive: URL, into folder: URL) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let name = archive.lastPathComponent.lowercased()
        let isTar = name.contains(".tar.") || name.hasSuffix(".tgz") || name.hasSuffix(".tbz") || name.hasSuffix(".tbz2") || name.hasSuffix(".txz")
        if !isTar, name.hasSuffix(".gz") || name.hasSuffix(".bz2") {
            // A single compressed file, not a folder of files.
            let tool = name.hasSuffix(".gz") ? "/usr/bin/gunzip" : "/usr/bin/bunzip2"
            let out = folder.appendingPathComponent(archive.deletingPathExtension().lastPathComponent)
            try await Engines.run(URL(fileURLWithPath: "/bin/sh"), ["-c", "\"\(tool)\" -c \"$0\" > \"$1\"", archive.path, out.path])
            return
        }
        try await Engines.run(tarTool, ["-xf", archive.path, "-C", folder.path])
        // Drop the resource-fork folder some Mac ZIPs carry.
        try? FileManager.default.removeItem(at: folder.appendingPathComponent("__MACOSX"))
    }

    /// The archive's name without any of its extensions ("Photos.tar.gz" → "Photos").
    public static func baseName(_ url: URL) -> String {
        var name = url.lastPathComponent
        for suffix in FileKind.archiveSuffixes.sorted(by: { $0.count > $1.count }) where name.lowercased().hasSuffix(suffix) {
            name = String(name.dropLast(suffix.count))
            break
        }
        return name
    }

    /// If extracting produced a single folder, use it directly instead of nesting it.
    static func flatten(_ folder: URL) throws -> URL {
        let items = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.isDirectoryKey])
            .filter { !$0.lastPathComponent.hasPrefix(".") }
        guard items.count == 1, items[0].hasDirectoryPath else { return folder }
        return items[0]
    }

    static func temporaryFolder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("kumquat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
