import AppKit
import SwiftUI

enum OnboardingWindow {
    private static var window: NSWindow?

    static func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 640),
                             styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: OnboardingView { w.close() }.environmentObject(SettingsStore.shared))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct OnboardingView: View {
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var preview = RingPreviewModel()
    let onDone: () -> Void

    var body: some View {
        let theme = settings.theme
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: [SwiftUI.Color(hex: "#FFC371"), SwiftUI.Color(hex: "#FF5F6D"), SwiftUI.Color(hex: "#A18CD1")],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RingView(model: preview.model, theme: snapshotTheme(theme), showsHint: false)
                    .scaleEffect(230 / max(settings.ringSize, 1))
            }
            .frame(height: 270)

            VStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text(L("Welcome to Kumquat")).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(L("Convert and edit files without opening a single app."))
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 14) {
                    step(1, symbol: "hand.draw.fill", text: L("Grab a file and move it a little. Keep holding."))
                    step(2, symbol: nil, key: settings.triggerKey.symbol, text: L("Tap %@. The ring appears right away.", settings.triggerKey.symbol))
                    step(3, symbol: "target", text: L("Drop it on a format or tool"))
                }

                Text(L("Tap %@ again while dragging to switch between Convert and Tools. Kumquat lives in your menu bar.", settings.triggerKey.symbol))
                    .font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                HStack(spacing: 18) {
                    Picker("", selection: $settings.language) {
                        ForEach(AppLanguage.allCases) { Text($0.name).tag($0) }
                    }
                    .labelsHidden().frame(width: 170)
                    Toggle(L("Open at login"), isOn: Binding(get: { settings.launchAtLogin }, set: { settings.launchAtLogin = $0 }))
                }

                Button {
                    settings.didOnboard = true
                    onDone()
                } label: {
                    Text(L("Get Started")).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 220, height: 36)
                        .background(Capsule().fill(theme.gradient))
                        .shadow(color: theme.accent2.opacity(0.4), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
            }
            .padding(24)
            .frame(maxHeight: .infinity)
        }
        .frame(width: 560, height: 640)
        .background(VisualBackground())
        .tint(theme.accent2)
        .onAppear { preview.start() }
        .onDisappear { preview.stop() }
    }

    private func snapshotTheme(_ t: Theme) -> Theme {
        var t = t
        if t.glass != .solid { t.glass = .snapshot }
        return t
    }

    private func step(_ n: Int, symbol: String?, key: String? = nil, text: String) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(.primary.opacity(0.06)).frame(width: 52, height: 52)
                if let symbol {
                    Image(systemName: symbol).font(.system(size: 22)).foregroundStyle(settings.theme.gradient)
                } else if let key {
                    Text(key).font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(settings.theme.gradient)
                }
            }
            Text(text).font(.system(size: 12, weight: .medium)).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: 150)
    }
}
