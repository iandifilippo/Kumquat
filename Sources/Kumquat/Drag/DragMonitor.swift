import AppKit

/// Watches for file drags anywhere on the Mac and reports when the trigger key is pressed mid-drag.
///
/// How it works, without Accessibility permission:
/// - A global mouse monitor notices `leftMouseDragged`.
/// - The system drag pasteboard's `changeCount` tells us a new drag started, and what it carries.
/// - While a drag is active, a 60 Hz timer polls `NSEvent.modifierFlags` (allowed without permission)
///   and `NSEvent.pressedMouseButtons` to see when the drag ends.
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
            guard let self else { return }
            self.lastChangeCount = self.pasteboard.changeCount
        }) { monitors.append(m) }
        if let m = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged, handler: { [weak self] _ in
            self?.checkForNewDrag()
        }) { monitors.append(m) }
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        endDrag()
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
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private var triggerIsDown: Bool {
        NSEvent.modifierFlags.contains(SettingsStore.shared.triggerKey.flag)
    }

    private func tick() {
        guard NSEvent.pressedMouseButtons & 1 == 1 else {
            endDrag()
            return
        }
        let down = triggerIsDown
        if down != triggerWasDown {
            triggerWasDown = down
            if down { onTriggerDown?(dragURLs) } else { onTriggerUp?() }
        }
    }

    private func endDrag() {
        timer?.invalidate()
        timer = nil
        guard isDragging else { return }
        isDragging = false
        dragURLs = []
        lastChangeCount = pasteboard.changeCount
        onDragEnded?()
    }
}
