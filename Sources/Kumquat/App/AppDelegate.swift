import AppKit
import Combine
import KumquatCore
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let monitor = DragMonitor()
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private let settings = SettingsStore.shared
    private let statusDrop = StatusDropTarget()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(settings.showDockIcon ? .regular : .accessory)
        // Look for optional engines early, off the main thread.
        DispatchQueue.global(qos: .utility).async { _ = Engines.current }
        setUpStatusItem()
        setUpMonitor()
        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        settings.applyLoginDefaultIfNeeded()
        WatchService.shared.start()
        RingController.shared.prepare()
        Hotkey.shared.setEnabled(settings.hotkeyEnabled)
        UpdateChecker.shared.onChange = { [weak self] in self?.statusItem?.menu = self?.makeMenu() }
        UpdateChecker.shared.startAutomaticChecks()

        if let i = CommandLine.arguments.firstIndex(of: "--capture-ring"), CommandLine.arguments.count > i + 2 {
            // Debug: show the real ring and save a picture of its window (own windows need no permission).
            let file = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            let out = URL(fileURLWithPath: CommandLine.arguments[i + 2])
            RingController.shared.show(files: [file], at: NSPoint(x: 700, y: 500), mode: .drag)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                RingController.shared.captureWindow(to: out)
                NSApp.terminate(nil)
            }
        } else if let i = CommandLine.arguments.firstIndex(of: "--self-test"), CommandLine.arguments.count > i + 1 {
            runSelfTest(file: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
        } else if CommandLine.arguments.contains("--demo-ring") {
            let files = CommandLine.arguments.drop { $0 != "--demo-ring" }.dropFirst().map { URL(fileURLWithPath: $0) }
            let point = NSScreen.main.map { NSPoint(x: $0.frame.midX, y: $0.frame.midY) } ?? .zero
            RingController.shared.show(files: files.isEmpty ? [URL(fileURLWithPath: "/tmp/Photo.heic")] : files, at: point, mode: .click)
        } else if !settings.didOnboard {
            OnboardingWindow.show()
        }

        // Rebuild the menu when the language changes.
        settings.objectWillChange
            .debounce(for: .milliseconds(50), scheduler: RunLoop.main)
            .sink { [weak self] in self?.statusItem?.menu = self?.makeMenu() }
            .store(in: &cancellables)
    }

    /// Smoke test of the whole UI path: ring → slice → runner → toast → file on disk.
    private func runSelfTest(file: URL) {
        let ring = RingController.shared
        ring.show(files: [file], at: NSPoint(x: 600, y: 500), mode: .click)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let item = ring.model.items.first
            print("SELFTEST ring visible=\(ring.isVisible) slices=\(ring.model.items.map(\.title)) choosing=\(item?.title ?? "-")")
            ring.choose(0, files: [file])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            let toast = ToastCenter.shared.model
            print("SELFTEST toast kind=\(toast.kind) title=\(toast.title) detail=\(toast.detail ?? "-") outputs=\(toast.outputs.map(\.path))")
            print("SELFTEST exists=\(toast.outputs.allSatisfy { FileManager.default.fileExists(atPath: $0.path) }) ringHidden=\(!ring.isVisible)")
            NSApp.terminate(nil)
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        SettingsWindowController.shared.show()
        return true
    }

    /// "Open With → Kumquat" and drops on the Dock icon show the ring in click mode.
    func application(_ application: NSApplication, open urls: [URL]) {
        RingController.shared.show(files: urls, at: NSEvent.mouseLocation, mode: .click)
    }

    // MARK: Drag gesture

    private func setUpMonitor() {
        monitor.onTriggerDown = { urls in
            guard !SettingsStore.shared.paused else { return }
            let ring = RingController.shared
            if ring.isVisible {
                ring.togglePage()
            } else {
                ring.show(files: urls, at: NSEvent.mouseLocation, mode: .drag)
            }
        }
        monitor.onTriggerUp = {
            if SettingsStore.shared.triggerMode == .hold, !RingController.shared.isBusy { RingController.shared.hide() }
        }
        monitor.onDragEnded = {
            // Give the drop a moment to land before the ring goes away.
            let ring = RingController.shared
            if ring.model.mode == .drag, !ring.isBusy {
                // Hide unless the drop just started an action shown in the ring.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { if !ring.isBusy { ring.hide() } }
            }
        }
        monitor.start()
    }

    // MARK: Menu bar

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = StatusIcon.make()
        item.button?.toolTip = "Kumquat"
        item.menu = makeMenu()
        statusItem = item
        // Files dropped on the menu bar icon open the ring.
        if let window = item.button?.window {
            window.registerForDraggedTypes([.fileURL])
            window.delegate = statusDrop
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        let header = NSMenuItem(title: settings.paused ? L("Kumquat is paused") : L("Drag a file a little, then tap %@", settings.triggerKey.symbol), action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        menu.addItem(.separator())
        if let version = UpdateChecker.shared.available {
            let update = item(L("Update to Kumquat %@…", version), #selector(installUpdate), "")
            update.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: nil)
            menu.addItem(update)
            menu.addItem(.separator())
        }
        menu.addItem(item(L("Convert a File…"), #selector(chooseFile), "o"))
        menu.addItem(item(L("Convert Finder Selection") + (settings.hotkeyEnabled ? "  " + Hotkey.display : ""), #selector(convertSelection), ""))
        let recent = NSMenuItem(title: L("Recent"), action: nil, keyEquivalent: "")
        let sub = NSMenu()
        let paths = settings.recents.filter { FileManager.default.fileExists(atPath: $0) }
        for path in paths.prefix(10) {
            let entry = NSMenuItem(title: (path as NSString).lastPathComponent, action: #selector(revealRecent(_:)), keyEquivalent: "")
            entry.target = self
            entry.representedObject = path
            entry.image = NSWorkspace.shared.icon(forFile: path)
            entry.image?.size = NSSize(width: 16, height: 16)
            entry.toolTip = path
            sub.addItem(entry)
        }
        if paths.isEmpty {
            let none = NSMenuItem(title: L("Nothing yet"), action: nil, keyEquivalent: "")
            none.isEnabled = false
            sub.addItem(none)
        } else {
            sub.addItem(.separator())
            sub.addItem(item(L("Clear"), #selector(clearRecents), ""))
        }
        recent.submenu = sub
        menu.addItem(recent)
        menu.addItem(item(settings.paused ? L("Resume") : L("Pause"), #selector(togglePause), "p"))
        menu.addItem(.separator())
        menu.addItem(item(L("Settings…"), #selector(openSettings), ","))
        menu.addItem(item(L("Welcome Screen"), #selector(openWelcome), ""))
        menu.addItem(item(L("Check for Updates…"), #selector(checkUpdates), ""))
        menu.addItem(.separator())
        menu.addItem(item(L("Quit Kumquat"), #selector(quit), "q"))
        return menu
    }

    private func item(_ title: String, _ action: Selector, _ key: String) -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.prompt = L("Choose")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, !panel.urls.isEmpty else { return }
        RingController.shared.show(files: panel.urls, at: NSEvent.mouseLocation, mode: .click)
    }

    @objc private func togglePause() { settings.paused.toggle() }
    @objc private func openSettings() { SettingsWindowController.shared.show() }
    @objc private func openWelcome() { OnboardingWindow.show() }
    @objc private func checkUpdates() { UpdateChecker.shared.check(userInitiated: true) }
    @objc private func installUpdate() { UpdateChecker.shared.installUpdate() }
    @objc private func convertSelection() { Hotkey.openForFinderSelection() }
    @objc private func clearRecents() { settings.recents = [] }
    @objc private func revealRecent(_ sender: NSMenuItem) {
        guard let path = sender.representedObject as? String else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
    }
    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Services ("Convert with Kumquat" in Finder's right-click menu)

    @objc func convertFiles(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        let urls = (pboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { return }
        DispatchQueue.main.async {
            RingController.shared.show(files: urls, at: NSEvent.mouseLocation, mode: .click)
        }
    }
}

/// Receives files dropped on the menu bar icon.
final class StatusDropTarget: NSObject, NSWindowDelegate, NSDraggingDestination {
    func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { .copy }

    func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { return false }
        DispatchQueue.main.async {
            // Open just below the icon so the ring doesn't cover the menu bar.
            var point = NSEvent.mouseLocation
            point.y -= SettingsStore.shared.ringSize / 2 + 20
            RingController.shared.show(files: urls, at: point, mode: .click)
        }
        return true
    }
}

/// The menu bar glyph: a little segmented ring.
enum StatusIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let c = NSPoint(x: rect.midX, y: rect.midY)
            let segments = 6
            for i in 0..<segments {
                let start = CGFloat(i) * 360 / CGFloat(segments) + 90 + 9
                let end = start + 360 / CGFloat(segments) - 18
                let path = NSBezierPath()
                path.appendArc(withCenter: c, radius: 7.5, startAngle: start, endAngle: end)
                path.lineWidth = 2.6
                path.lineCapStyle = .round
                NSColor.black.setStroke()
                path.stroke()
            }
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 2.2, y: c.y - 2.2, width: 4.4, height: 4.4)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
