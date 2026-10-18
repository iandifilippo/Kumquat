import AppKit
import KumquatCore
import SwiftUI

/// Borderless floating panel that hosts the ring right under the cursor.
final class RingPanel: NSPanel {
    var allowsKey = false
    override var canBecomeKey: Bool { allowsKey }
    override var canBecomeMain: Bool { false }
}

private struct RingContainer: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var model: RingModel

    var body: some View {
        RingView(model: model, theme: settings.theme)
    }
}

/// Shows, hides and routes input for the ring.
final class RingController {
    static let shared = RingController()

    let model = RingModel()
    private var panel: RingPanel?
    private var dropView: RingDropView?
    private var hideWork: DispatchWorkItem?
    private var outsideClickMonitor: Any?

    private let margin: CGFloat = 60
    var isVisible: Bool { panel?.isVisible == true && model.shown }

    var geometry: RingGeometry { RingGeometry(diameter: SettingsStore.shared.ringSize) }

    // MARK: Show / hide

    func show(files: [URL], at point: NSPoint, mode: RingModel.Mode) {
        hideWork?.cancel()
        model.load(files: files)
        guard !model.isEmpty else {
            ToastCenter.shared.showInfo(L("Nothing to do with this file"), detail: files.first?.lastPathComponent)
            return
        }
        model.mode = mode
        let panel = makePanelIfNeeded()
        let side = geometry.diameter + margin * 2
        var frame = NSRect(x: point.x - side / 2, y: point.y - side / 2, width: side, height: side)
        if let screen = NSScreen.screens.first(where: { NSMouseInRect(point, $0.frame, false) }) ?? NSScreen.main {
            let vf = screen.visibleFrame.insetBy(dx: -margin + 8, dy: -margin + 8)
            frame.origin.x = min(max(frame.minX, vf.minX), vf.maxX - side)
            frame.origin.y = min(max(frame.minY, vf.minY), vf.maxY - side)
        }
        panel.setFrame(frame, display: false)
        panel.allowsKey = mode == .click
        model.shown = false
        if mode == .click {
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            panel.makeFirstResponder(dropView)
            installOutsideClickMonitor()
        } else {
            panel.orderFrontRegardless()
        }
        DispatchQueue.main.async { self.model.shown = true }
    }

    func hide(after delay: TimeInterval = 0) {
        hideWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.model.shown = false
            self.removeOutsideClickMonitor()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                if !self.model.shown {
                    self.panel?.orderOut(nil)
                    self.model.progress = nil
                    self.model.finished = nil
                }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    func togglePage() {
        model.togglePage()
        haptic()
    }

    // MARK: Input from the drop view

    func hover(_ hit: RingGeometry.Hit) {
        let index: Int?
        if case .slice(let i) = hit { index = i } else { index = nil }
        guard index != model.hovered else { return }
        model.hovered = index
        if index != nil { haptic() }
    }

    func choose(_ index: Int, files: [URL]) {
        guard model.items.indices.contains(index), model.progress == nil else { return }
        let action = model.items[index].action
        let files = files.isEmpty ? model.files : files
        model.chosen = index
        let needsEditor: Bool = { if case .tool(let t) = action { return t.needsEditor } else { return false } }()
        guard SettingsStore.shared.progressInRing, !needsEditor else {
            hide(after: 0.12)
            ActionRunner.shared.start(action, files: files)
            return
        }
        // Keep the ring up and show progress in its center, like a download ring.
        model.progress = -1
        removeOutsideClickMonitor()
        ActionRunner.shared.start(action, files: files, progress: { [weak self] fraction in
            self?.model.progress = fraction
        }, completion: { [weak self] success in
            guard let self else { return }
            self.model.finished = success
            self.hide(after: success ? 0.7 : 1.0)
        })
    }

    /// True while the ring is showing an action's progress (it must not close on mouse-up).
    var isBusy: Bool { model.progress != nil && model.finished == nil }

    func hubClicked() {
        if model.mode == .click { togglePage() }
    }

    // MARK: Helpers

    private func haptic() {
        guard SettingsStore.shared.haptics else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
    }

    private func makePanelIfNeeded() -> RingPanel {
        if let panel { return panel }
        let p = RingPanel(contentRect: .init(x: 0, y: 0, width: 400, height: 400),
                          styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .popUpMenu
        p.isFloatingPanel = true
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.animationBehavior = .none

        let root = NSView()
        let host = NSHostingView(rootView: RingContainer(model: model))
        host.translatesAutoresizingMaskIntoConstraints = false
        let drop = RingDropView(controller: self)
        drop.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(host)
        root.addSubview(drop)
        for v in [host, drop] {
            NSLayoutConstraint.activate([
                v.leadingAnchor.constraint(equalTo: root.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: root.trailingAnchor),
                v.topAnchor.constraint(equalTo: root.topAnchor),
                v.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            ])
        }
        p.contentView = root
        panel = p
        dropView = drop
        return p
    }

    private func installOutsideClickMonitor() {
        removeOutsideClickMonitor()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hide()
        }
    }

    func removeOutsideClickMonitor() {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
        outsideClickMonitor = nil
    }
}

/// Transparent view on top of the ring: receives the drop, hover and clicks.
final class RingDropView: NSView {
    private unowned let controller: RingController
    private var tracking: NSTrackingArea?

    init(controller: RingController) {
        self.controller = controller
        super.init(frame: .zero)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let t = NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(t)
        tracking = t
    }

    private func hit(_ windowPoint: NSPoint) -> RingGeometry.Hit {
        let p = convert(windowPoint, from: nil)
        let rel = CGPoint(x: p.x - bounds.midX, y: p.y - bounds.midY)
        return controller.geometry.hit(rel, count: controller.model.items.count)
    }

    // Dragging
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller.hover(hit(sender.draggingLocation))
        return .copy
    }

    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        controller.hover(hit(sender.draggingLocation))
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        controller.hover(.outside)
    }

    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { true }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard case .slice(let index) = hit(sender.draggingLocation) else {
            controller.hide()
            return false
        }
        let urls = (sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL]) ?? []
        controller.choose(index, files: urls)
        return true
    }

    // Clicking (Open With, menu bar, Services)
    override func mouseMoved(with event: NSEvent) {
        controller.hover(hit(event.locationInWindow))
    }

    override func mouseExited(with event: NSEvent) {
        controller.hover(.outside)
    }

    override func mouseDown(with event: NSEvent) {
        switch hit(event.locationInWindow) {
        case .slice(let i): controller.choose(i, files: [])
        case .hub: controller.hubClicked()
        case .outside: controller.hide()
        }
    }

    override func rightMouseDown(with event: NSEvent) {
        controller.togglePage()
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 53: controller.hide() // Esc
        case 48, 49: controller.togglePage() // Tab, Space
        default: super.keyDown(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        if event.modifierFlags.contains(SettingsStore.shared.triggerKey.flag) { controller.togglePage() }
    }
}
