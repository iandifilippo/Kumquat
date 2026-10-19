import AppKit

/// Watches for file drags anywhere on the Mac and reports when the trigger key is pressed mid-drag.
///
/// How it works, without Accessibility permission:
/// - A global monitor notices the mouse button going down.
/// - While it's held, a 60 Hz timer polls the system drag pasteboard (`changeCount` tells us a
///   drag started and what it carries), `NSEvent.modifierFlags` (allowed without permission) and
///   `NSEvent.pressedMouseButtons`.
///
/// Polling matters: once Finder's drag session begins, macOS stops sending `leftMouseDragged`
/// to other apps, so waiting for those events made the ring show up late or not at all.
final class DragMonitor {
    var onTriggerDown: (([URL]) -> Void)?
    var onTriggerUp: (() -> Void)?
    var onDragEnded: (() -> Void)?

    private let pasteboard = NSPasteboard(name: .drag)
    private var monitors: [Any] = []
    private var lastChangeCount: Int
    private var timer: Timer?
    private var dragURLs: [URL] = []
    private var triggerWasDown = false

    private(set) var isDragging = false

    init() {
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard monitors.isEmpty else { return }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown, handler: { [weak self] _ in
            self?.mouseDown()
        }) { monitors.append(m) }
        // Dragged events still help when they do arrive (e.g. the first moves of a drag).
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            guard let self else { return }
            if self.timer == nil { self.startPolling() }
            self.checkForNewDrag()
        }) { monitors.append(m) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        stopPolling()
        endDrag()
    }

    private func mouseDown() {
        lastChangeCount = pasteboard.changeCount
        startPolling()
    }

    private func startPolling() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopPolling() {
        timer?.invalidate()
        timer = nil
    }

    private func checkForNewDrag() {
        guard !isDragging, pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        let urls = (pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        guard !urls.isEmpty else { return }
        dragURLs = urls
        isDragging = true
        // If the key was already held when the drag started, wait for a fresh press.
        triggerWasDown = triggerIsDown
    }

    private var triggerIsDown: Bool {
        NSEvent.modifierFlags.contains(SettingsStore.shared.triggerKey.flag)
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 == 1 else {
            stopPolling()
            endDrag()
            return
        }
        if !isDragging {
            checkForNewDrag()
            return
        }
        let down = triggerIsDown
        if down != triggerWasDown {
            triggerWasDown = down
            if down { onTriggerDown?(dragURLs) } else { onTriggerUp?() }
        }
    }

    private func endDrag() {
        guard isDragging else { return }
        isDragging = false
        dragURLs = []
        lastChangeCount = pasteboard.changeCount
        onDragEnded?()
    }
}
