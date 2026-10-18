import AppKit
import KumquatCore
import SwiftUI
import UniformTypeIdentifiers

/// Renders the images used in the README (`Kumquat --render-screenshots docs/assets`).
/// Real glass needs a live window, so these use the drawn "snapshot" glass.
@MainActor
enum ScreenshotRenderer {
    static func renderAll(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        // Show what everyone gets out of the box, not this Mac's extra engines.
        Engines.override(Engines())
        let settings = SettingsStore.shared
        let savedLanguage = settings.language
        for lang in [AppLanguage.en, .es] {
            settings.language = lang
            let suffix = lang == .en ? "" : "-es"
            save(HeroScene(), size: CGSize(width: 1600, height: 900), to: dir.appendingPathComponent("hero\(suffix).jpg"))
            save(ToolsScene(), size: CGSize(width: 1600, height: 760), to: dir.appendingPathComponent("tools\(suffix).jpg"))
        }
        settings.language = .en
        save(ThemesScene(), size: CGSize(width: 1600, height: 820), to: dir.appendingPathComponent("themes.jpg"))
        save(SocialScene(), size: CGSize(width: 1280, height: 640), to: dir.appendingPathComponent("social-preview.jpg"))
        snapshotWindow(SettingsView(selection: { let s = SettingsSelection(); s.pane = .appearance; return s }()).environmentObject(settings),
                       size: CGSize(width: 760, height: 560), to: dir.appendingPathComponent("settings.jpg"))
        settings.language = savedLanguage
        print("Rendered screenshots into \(dir.path)")
    }

    /// The Tools ring in every language, to check labels fit (`--render-rings <dir>`).
    static func renderRings(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        Engines.override(Engines())
        let settings = SettingsStore.shared
        let saved = settings.language
        for lang in AppLanguage.allCases where lang != .system {
            settings.language = lang
            let tools = model("Photo.png", page: 1, hovered: 4)
            let pdf = model("Scan.pdf", page: 1, hovered: 5)
            save(HStack(spacing: 30) { RingView(model: tools, theme: theme("kumquat", size: 300)); RingView(model: pdf, theme: theme("ocean", size: 300)) }
                .frame(width: 760, height: 380).background(Wallpaper()),
                 size: CGSize(width: 760, height: 380), to: dir.appendingPathComponent("ring-\(lang.rawValue).jpg"))
        }
        settings.language = saved
    }

    /// Every window, for checking layouts by eye (`--render-ui <dir> <image>`).
    static func renderUI(to dir: URL, sample: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let settings = SettingsStore.shared
        for pane in SettingsPane.allCases {
            let selection = SettingsSelection()
            selection.pane = pane
            snapshotWindow(SettingsView(selection: selection).environmentObject(settings),
                           size: CGSize(width: 780, height: 1100), to: dir.appendingPathComponent("settings-\(pane.rawValue).png"))
        }
        let none: () -> Void = {}
        let ignore: (ToolParameters) -> Void = { _ in }
        snapshotWindow(CropEditor(url: sample, onCancel: none, onApply: ignore).environmentObject(settings),
                       size: CGSize(width: 640, height: 640), to: dir.appendingPathComponent("editor-crop.png"))
        snapshotWindow(BackgroundEditor(url: sample, count: 1, onCancel: none, onApply: ignore).environmentObject(settings),
                       size: CGSize(width: 620, height: 660), to: dir.appendingPathComponent("editor-background.png"))
        snapshotWindow(ResizeEditor(url: sample, count: 1, onCancel: none, onApply: ignore).environmentObject(settings),
                       size: CGSize(width: 420, height: 440), to: dir.appendingPathComponent("editor-resize.png"))
        snapshotWindow(PasswordEditor(url: sample, onCancel: none, onApply: ignore).environmentObject(settings),
                       size: CGSize(width: 380, height: 300), to: dir.appendingPathComponent("editor-password.png"))
        snapshotWindow(OnboardingView(onDone: none).environmentObject(settings),
                       size: CGSize(width: 560, height: 640), to: dir.appendingPathComponent("onboarding.png"))
        let ring = RingModel()
        ring.load(files: [sample])
        ring.shown = true
        ring.chosen = 0
        ring.progress = 0.62
        var t = settings.theme
        t.glass = .snapshot
        save(ZStack { Wallpaper(); RingView(model: ring, theme: t) }, size: CGSize(width: 500, height: 500), to: dir.appendingPathComponent("ring-progress.png"))
        // On a flat color, any square edge around the ring would show.
        let plain = RingModel()
        plain.load(files: [sample])
        plain.shown = true
        for scheme in [RingScheme.light, .dark] {
            var st = settings.theme
            st.glass = .solid
            st.scheme = scheme
            save(ZStack { SwiftUI.Color(white: 0.55); RingView(model: plain, theme: st) }, size: CGSize(width: 420, height: 420),
                 to: dir.appendingPathComponent("ring-edge-\(scheme.rawValue).png"))
        }
        print("Rendered UI into \(dir.path)")
    }

    static func save<V: View>(_ view: V, size: CGSize, to url: URL) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).environment(\.colorScheme, .light))
        renderer.scale = 1.5
        guard let cg = renderer.cgImage else { return }
        write(NSBitmapImageRep(cgImage: cg), to: url)
    }

    /// AppKit-backed views (forms, toggles) need a real window to draw.
    static func snapshotWindow<V: View>(_ view: V, size: CGSize, to url: URL) {
        let host = NSHostingView(rootView: view.frame(width: size.width, height: size.height))
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.contentView = host
        window.appearance = NSAppearance(named: .aqua)
        window.isReleasedWhenClosed = false
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.6))
        host.layoutSubtreeIfNeeded()
        guard let rep = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { return }
        host.cacheDisplay(in: host.bounds, to: rep)
        write(rep, to: url)
        window.close()
    }

    /// JPEG keeps the README light; PNG only where transparency matters.
    static func write(_ rep: NSBitmapImageRep, to url: URL) {
        let jpeg = url.pathExtension == "jpg"
        let data = rep.representation(using: jpeg ? .jpeg : .png, properties: jpeg ? [.compressionFactor: 0.86] : [:])
        try? data?.write(to: url)
    }
}

// MARK: - Scenes

private func theme(_ id: String, size: Double = 340, glass: GlassStyle = .snapshot, scheme: RingScheme = .light, labels: LabelStyle = .iconAndText) -> Theme {
    let p = ThemePreset.all.first { $0.id == id }!
    return Theme(accent: SwiftUI.Color(hex: p.accent), accent2: SwiftUI.Color(hex: p.accent2), sliceOpacity: 0.72,
                 glass: glass, size: size, labels: labels, scheme: scheme)
}

private func model(_ file: String, page: Int = 0, hovered: Int?) -> RingModel {
    let m = RingModel()
    m.load(files: [URL(fileURLWithPath: "/tmp/\(file)")])
    m.page = page
    m.hovered = hovered
    m.shown = true
    return m
}

struct Wallpaper: View {
    var colors = ["#FFC371", "#FF8A5B", "#F25F7C", "#9C7CF4"]
    var body: some View {
        ZStack {
            LinearGradient(colors: colors.map(SwiftUI.Color.init(hex:)), startPoint: .topLeading, endPoint: .bottomTrailing)
            RadialGradient(colors: [.white.opacity(0.35), .clear], center: .init(x: 0.25, y: 0.2), startRadius: 0, endRadius: 700)
            RadialGradient(colors: [SwiftUI.Color(hex: "#6E8BFF").opacity(0.45), .clear], center: .init(x: 0.85, y: 0.95), startRadius: 0, endRadius: 600)
        }
    }
}

private struct DesktopFile: View {
    let name: String
    var selected = false
    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: (name as NSString).pathExtension) ?? .data))
                .resizable().frame(width: 64, height: 64)
                .shadow(color: .black.opacity(0.2), radius: 3, y: 2)
            Text(name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                .padding(.horizontal, 5).padding(.vertical, 1)
                .background(RoundedRectangle(cornerRadius: 4).fill(selected ? SwiftUI.Color(hex: "#2F6FED") : .black.opacity(0.0)))
                .shadow(color: .black.opacity(selected ? 0 : 0.5), radius: 2)
        }
    }
}

private struct MenuBar: View {
    var body: some View {
        HStack(spacing: 18) {
            Text("Finder").font(.system(size: 13, weight: .bold))
            ForEach(["File", "Edit", "View", "Go", "Window", "Help"], id: \.self) { Text($0).font(.system(size: 13)) }
            Spacer()
            Image(nsImage: StatusIcon.make()).renderingMode(.template)
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Sat 4:20 PM").font(.system(size: 13))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 30)
        .background(.black.opacity(0.18))
    }
}

private struct DraggedFile: View {
    let name: String
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(nsImage: NSWorkspace.shared.icon(for: UTType(filenameExtension: (name as NSString).pathExtension) ?? .data))
                .resizable().frame(width: 60, height: 60).opacity(0.85)
            Image(systemName: "plus.circle.fill").font(.system(size: 20)).foregroundStyle(.white, .green)
                .offset(x: 4, y: 2)
        }
        .overlay(alignment: .topLeading) {
            Image(systemName: "cursorarrow").font(.system(size: 22, weight: .regular))
                .foregroundStyle(.black).background(Image(systemName: "cursorarrow.fill").font(.system(size: 22)).foregroundStyle(.white))
                .offset(x: -6, y: -8)
        }
    }
}

private struct StaticToast: View {
    let theme: Theme
    let title: String
    let detail: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(nsImage: NSWorkspace.shared.icon(for: .png)).resizable().frame(width: 44, height: 44)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 15)).foregroundStyle(.white, theme.accent2).offset(x: 4, y: 4)
                }
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold, design: .rounded))
                Text(detail).font(.system(size: 11)).foregroundStyle(.secondary)
                HStack(spacing: 6) {
                    Text(L("Show in Finder")).font(.system(size: 11, weight: .semibold)).lineLimit(1).fixedSize().foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(theme.gradient))
                    ForEach([L("Open"), L("Undo")], id: \.self) {
                        Text($0).font(.system(size: 11, weight: .semibold)).lineLimit(1).fixedSize()
                            .padding(.horizontal, 10).padding(.vertical, 4).background(Capsule().fill(.black.opacity(0.07)))
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(width: 344)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.82))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.9)))
            .shadow(color: .black.opacity(0.18), radius: 14, y: 6))
    }
}

private struct HeroScene: View {
    var body: some View {
        let t = theme("kumquat", size: 360)
        let m = model("Vacation.heic", hovered: 0)
        ZStack(alignment: .topLeading) {
            Wallpaper()
            MenuBar()
            VStack(alignment: .trailing, spacing: 22) {
                DesktopFile(name: "Vacation.heic", selected: true)
                DesktopFile(name: "Invoice.pdf")
                DesktopFile(name: "Notes.md")
                DesktopFile(name: "Clip.mov")
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.trailing, 40).padding(.top, 200)

            RingView(model: m, theme: t)
                .position(x: 640, y: 470)

            DraggedFile(name: "Vacation.heic")
                .position(x: 700, y: 330)

            StaticToast(theme: t, title: "Vacation.jpg", detail: "HEIC → JPG · 4032×3024 · 2.8 MB")
                .position(x: 1380, y: 110)

            VStack(alignment: .leading, spacing: 10) {
                Text(L("Drag. Tap ⇧. Drop."))
                    .font(.system(size: 54, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(L("Convert and edit any file without opening an app."))
                    .font(.system(size: 22, weight: .medium, design: .rounded)).foregroundStyle(.white.opacity(0.92))
            }
            .shadow(color: .black.opacity(0.18), radius: 8, y: 2)
            .padding(.leading, 70).padding(.top, 720)
        }
    }
}

private struct ToolsScene: View {
    var body: some View {
        let t = theme("kumquat", size: 330)
        ZStack {
            Wallpaper(colors: ["#FFD194", "#FF9A76", "#E86A92", "#7F7FD5"])
            HStack(spacing: 80) {
                VStack(spacing: 34) {
                    RingView(model: model("Screenshot.png", page: 1, hovered: 4), theme: t)
                    caption(L("Tools"), L("Compress, crop, add a background, remove the background, OCR…"))
                }
                VStack(spacing: 30) {
                    StaticToast(theme: t, title: "Screenshot \(ToolID.compress.fileSuffix).jpg", detail: "2.4 MB → 610 KB · " + L("%d%% smaller", 75))
                    StaticToast(theme: theme("ocean"), title: "Invoice.docx", detail: "PDF → Word · 182 KB")
                    StaticToast(theme: theme("mint"), title: "Clip.gif", detail: "MOV → GIF · 12 fps · 3.4 MB")
                }
            }
        }
    }

    private func caption(_ title: String, _ text: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.system(size: 26, weight: .heavy, design: .rounded))
            Text(text).font(.system(size: 15, weight: .medium)).opacity(0.9)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.2), radius: 6)
    }
}

private struct ThemesScene: View {
    private let items: [(String, String, RingScheme, LabelStyle)] = [
        ("kumquat", "Photo.heic", .light, .iconAndText), ("ocean", "Report.pdf", .light, .iconAndText),
        ("grape", "Notes.md", .dark, .iconAndText), ("mint", "Clip.mov", .light, .text),
        ("rose", "Song.mp3", .dark, .iconAndText), ("lemon", "Logo.png", .light, .icon),
        ("sunset", "Scan.pdf", .light, .iconAndText), ("graphite", "Draft.docx", .dark, .iconAndText),
    ]

    var body: some View {
        ZStack {
            LinearGradient(colors: [SwiftUI.Color(hex: "#1E1B2E"), SwiftUI.Color(hex: "#3B2A4A"), SwiftUI.Color(hex: "#5A3A3A")], startPoint: .topLeading, endPoint: .bottomTrailing)
            VStack(spacing: 24) {
                Text(L("Make it yours")).font(.system(size: 40, weight: .heavy, design: .rounded)).foregroundStyle(.white)
                Text(L("Themes, custom colors, light or dark, glass or solid, size, labels and which slices appear."))
                    .font(.system(size: 17, weight: .medium)).foregroundStyle(.white.opacity(0.75))
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(330)), count: 4), spacing: 20) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        VStack(spacing: 6) {
                            RingView(model: model(item.1, hovered: i % 3 + 1), theme: theme(item.0, size: 250, glass: .snapshot, scheme: item.2, labels: item.3), showsHint: false)
                                .frame(width: 290, height: 270)
                            Text(ThemePreset.all.first { $0.id == item.0 }!.localizedName)
                                .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }
        }
    }
}

private struct SocialScene: View {
    var body: some View {
        ZStack {
            Wallpaper()
            HStack(spacing: 60) {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 16) {
                        if let icon = NSImage(contentsOfFile: "docs/assets/icon.png") {
                            Image(nsImage: icon).resizable().frame(width: 96, height: 96)
                        }
                        Text("Kumquat").font(.system(size: 64, weight: .heavy, design: .rounded))
                    }
                    Text("Drag. Tap ⇧. Drop.").font(.system(size: 36, weight: .bold, design: .rounded))
                    Text("Free, open-source file converter for macOS.\nImages · PDFs · Docs · Video · Audio")
                        .font(.system(size: 22, weight: .medium)).opacity(0.92)
                }
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 6)
                RingView(model: model("Photo.heic", hovered: 2), theme: theme("kumquat", size: 380), showsHint: false)
            }
        }
    }
}
