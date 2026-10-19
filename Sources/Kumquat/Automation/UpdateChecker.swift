import AppKit

/// Asks GitHub whether a newer release exists. This is Kumquat's only network request,
/// and it can be turned off in Settings → About.
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()
    static let releasesURL = URL(string: "https://github.com/iandifilippo/Kumquat/releases/latest")!
    private let api = URL(string: "https://api.github.com/repos/iandifilippo/Kumquat/releases/latest")!
    private var timer: Timer?

    /// The newer version, once found.
    @Published private(set) var available: String?
    var onChange: (() -> Void)?

    var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func startAutomaticChecks() {
        timer?.invalidate()
        guard SettingsStore.shared.checkForUpdates else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.check(userInitiated: false) }
        timer = Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.check(userInitiated: false) }
    }

    func check(userInitiated: Bool) {
        var request = URLRequest(url: api, timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self else { return }
            let tag = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any])?["tag_name"] as? String
            let latest = tag.map { $0.hasPrefix("v") ? String($0.dropFirst()) : $0 }
            DispatchQueue.main.async {
                if let latest, Self.isNewer(latest, than: self.current) {
                    let isNew = self.available != latest
                    self.available = latest
                    self.onChange?()
                    if isNew || userInitiated {
                        ToastCenter.shared.showInfo(L("Kumquat %@ is available", latest), detail: nil,
                                                    actionTitle: L("Update Now")) { self.installUpdate() }
                    }
                } else if userInitiated {
                    ToastCenter.shared.showInfo(L("You're up to date"), detail: L("Kumquat %@ is the latest version.", self.current))
                }
            }
        }.resume()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Updates in place: a small helper waits for Kumquat to quit, runs the install script
    /// (which replaces the app and opens the new one), and Kumquat quits right away.
    func installUpdate() {
        let pid = ProcessInfo.processInfo.processIdentifier
        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        curl -fsSL https://raw.githubusercontent.com/iandifilippo/Kumquat/main/install.sh | KUMQUAT_UPDATING=1 bash \
          || open "\(Self.releasesURL.absoluteString)"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", script]
        // Detach from Kumquat so the helper outlives it.
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            NSWorkspace.shared.open(Self.releasesURL)
            return
        }
        ToastCenter.shared.showProgress(title: L("Updating Kumquat…"), total: 1)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { NSApp.terminate(nil) }
    }
}
