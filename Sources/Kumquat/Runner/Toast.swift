import AppKit
import KumquatCore
import QuickLookThumbnailing
import SwiftUI

/// Only touched on the main thread.
final class ToastModel: ObservableObject, @unchecked Sendable {
    enum Kind: Equatable { case working, success, failure, info }

    @Published var kind: Kind = .working
    @Published var title = ""
    @Published var detail: String?
    @Published var done = 0
    @Published var total = 1
    @Published var thumbnail: NSImage?
    @Published var outputs: [URL] = []
    @Published var visible = false
    var originals: [URL] = []
    var trashed: [URL] = []

    func progress(done: Int, total: Int) {
        self.done = done
        self.total = max(total, 1)
    }
}

/// The little glass card that says "Converting to JPG · 1 of 1 saved" and offers Undo.
final class ToastCenter {
    static let shared = ToastCenter()

    let model = ToastModel()
    private var panel: NSPanel?
    private var dismissWork: DispatchWorkItem?
    private let size = NSSize(width: 360, height: 112)
    var hovering = false { didSet { if !hovering { scheduleDismiss() } } }

    @discardableResult
    func showProgress(title: String, total: Int) -> ToastModel {
        dismissWork?.cancel()
        model.kind = .working
        model.title = title
        model.detail = nil
        model.done = 0
        model.total = max(total, 1)
        model.outputs = []
        model.thumbnail = nil
        present()
        return model
    }

    func showSuccess(_ outcome: ActionOutcome, detail: String, originals: [URL], trashedOriginals: [URL]) {
        model.kind = .success
        model.outputs = outcome.outputs
        model.originals = originals
        model.trashed = trashedOriginals
        model.done = model.total
        if outcome.outputs.count == 1, let out = outcome.outputs.first {
            model.title = out.lastPathComponent
        } else {
            model.title = L("%d files saved", outcome.outputs.count)
        }
        model.detail = detail
        loadThumbnail(outcome.outputs.first)
        present()
        scheduleDismiss()
    }

    func showFailure(_ title: String, detail: String?) {
        model.kind = .failure
        model.title = title
        model.detail = detail
        model.outputs = []
        model.thumbnail = nil
        present()
        scheduleDismiss(extra: 2)
    }

    func showInfo(_ title: String, detail: String?) {
        model.kind = .info
        model.title = title
        model.detail = detail
        model.outputs = []
        model.thumbnail = nil
        present()
        scheduleDismiss()
    }

    func dismiss() {
        dismissWork?.cancel()
        model.visible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            if self?.model.visible == false { self?.panel?.orderOut(nil) }
        }
    }

    private func scheduleDismiss(extra: Double = 0) {
        dismissWork?.cancel()
        guard !hovering, model.kind != .working else { return }
        let work = DispatchWorkItem { [weak self] in self?.dismiss() }
        dismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + SettingsStore.shared.toastSeconds + extra, execute: work)
    }

    private func loadThumbnail(_ url: URL?) {
        guard let url else { return }
        model.thumbnail = NSWorkspace.shared.icon(forFile: url.path)
        // Previews of text files are blank pages; the file icon says more.
        guard [.image, .pdf, .video].contains(FileKind.of(url)) else { return }
        let request = QLThumbnailGenerator.Request(fileAt: url, size: CGSize(width: 96, height: 96), scale: 2, representationTypes: .thumbnail)
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { [weak self] rep, _ in
            guard let image = rep?.nsImage else { return }
            DispatchQueue.main.async {
                if self?.model.outputs.first == url { self?.model.thumbnail = image }
            }
        }
    }

    private func present() {
        let panel = makePanelIfNeeded()
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let vf = screen?.visibleFrame {
            let m: CGFloat = 12
            let origin: NSPoint
            switch SettingsStore.shared.toastPosition {
            case .topRight: origin = NSPoint(x: vf.maxX - size.width - m, y: vf.maxY - size.height - m)
            case .topCenter: origin = NSPoint(x: vf.midX - size.width / 2, y: vf.maxY - size.height - m)
            case .bottomRight: origin = NSPoint(x: vf.maxX - size.width - m, y: vf.minY + m)
            case .bottomCenter: origin = NSPoint(x: vf.midX - size.width / 2, y: vf.minY + m)
            }
            panel.setFrame(NSRect(origin: origin, size: size), display: true)
        }
        panel.orderFrontRegardless()
        DispatchQueue.main.async { self.model.visible = true }
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }
        let p = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .statusBar
        p.hidesOnDeactivate = false
        p.isReleasedWhenClosed = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = NSHostingView(rootView: ToastView(model: model, center: self))
        panel = p
        return p
    }
}

struct ToastView: View {
    @ObservedObject var model: ToastModel
    @ObservedObject var settings = SettingsStore.shared
    let center: ToastCenter

    var body: some View {
        let theme = settings.theme
        HStack(alignment: .top, spacing: 12) {
            icon(theme)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(model.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 4)
                    Button { center.dismiss() } label: {
                        Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(.primary.opacity(0.08)))
                    }
                    .buttonStyle(.plain)
                }
                switch model.kind {
                case .working:
                    Text(L("%d of %d saved", model.done, model.total))
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                    ProgressBar(value: Double(model.done) / Double(max(model.total, 1)), theme: theme)
                default:
                    if let detail = model.detail {
                        Text(detail).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    if model.kind == .success { actions(theme) }
                }
            }
        }
        .padding(14)
        .frame(width: 344, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial)
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(theme.accent.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.35)))
                .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        )
        .frame(width: 360, height: 112, alignment: .top)
        .offset(y: model.visible ? 0 : -14)
        .opacity(model.visible ? 1 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: model.visible)
        .animation(.easeOut(duration: 0.2), value: model.done)
        .onHover { center.hovering = $0 }
    }

    @ViewBuilder
    private func icon(_ theme: Theme) -> some View {
        switch model.kind {
        case .working:
            ZStack {
                Circle().stroke(theme.accent.opacity(0.2), lineWidth: 4)
                Circle().trim(from: 0, to: max(0.08, Double(model.done) / Double(max(model.total, 1))))
                    .stroke(theme.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(6)
        case .success:
            if let thumb = model.thumbnail {
                Image(nsImage: thumb).resizable().aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15)).foregroundStyle(.white, theme.accent2)
                            .offset(x: 4, y: 4)
                    }
            } else {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 30)).foregroundStyle(theme.gradient)
            }
        case .failure:
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 26)).foregroundStyle(.orange)
        case .info:
            Image(systemName: "info.circle.fill").font(.system(size: 28)).foregroundStyle(theme.gradient)
        }
    }

    private func actions(_ theme: Theme) -> some View {
        // Long translations drop the "Open" button rather than overflow the card.
        ViewThatFits(in: .horizontal) {
            buttons(theme, includeOpen: true)
            buttons(theme, includeOpen: false)
        }
        .padding(.top, 2)
    }

    private func buttons(_ theme: Theme, includeOpen: Bool) -> some View {
        HStack(spacing: 6) {
            pill(L("Show in Finder"), theme, filled: true) {
                NSWorkspace.shared.activateFileViewerSelecting(model.outputs)
                center.dismiss()
            }
            if includeOpen, model.outputs.count == 1, let url = model.outputs.first {
                pill(L("Open"), theme) {
                    NSWorkspace.shared.open(url)
                    center.dismiss()
                }
            }
            pill(L("Undo"), theme) {
                ActionRunner.shared.undo(outputs: model.outputs, originals: model.originals, trashed: model.trashed)
                center.dismiss()
            }
        }
    }

    private func pill(_ title: String, _ theme: Theme, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1).fixedSize()
                .foregroundStyle(filled ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule().fill(filled ? AnyShapeStyle(theme.gradient) : AnyShapeStyle(.primary.opacity(0.08))))
        }
        .buttonStyle(.plain)
    }
}

struct ProgressBar: View {
    var value: Double
    var theme: Theme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule().fill(theme.gradient).frame(width: max(6, geo.size.width * value))
            }
        }
        .frame(height: 5)
    }
}
