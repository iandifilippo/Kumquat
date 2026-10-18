import AppKit
import KumquatCore
import SwiftUI

/// Opens the small window a tool needs before it can run (Crop, Add BG, Resize, Protect).
enum EditorWindows {
    private static var open: [NSWindow] = []

    static func open(_ tool: ToolID, files: [URL], completion: @escaping (ToolParameters) -> Void) {
        guard let first = files.first else { return }
        var window: NSWindow!
        let close: () -> Void = { window?.close() }
        let finish: (ToolParameters) -> Void = { params in
            close()
            completion(params)
        }

        let content: AnyView
        let size: NSSize
        switch tool {
        case .crop:
            content = AnyView(CropEditor(url: first, onCancel: close, onApply: finish))
            size = NSSize(width: 640, height: 640)
        case .addBackground:
            content = AnyView(BackgroundEditor(url: first, count: files.count, onCancel: close, onApply: finish))
            size = NSSize(width: 620, height: 660)
        case .resize:
            content = AnyView(ResizeEditor(url: first, count: files.count, onCancel: close, onApply: finish))
            size = NSSize(width: 420, height: 440)
        case .protect:
            content = AnyView(PasswordEditor(url: first, onCancel: close, onApply: finish))
            size = NSSize(width: 380, height: 300)
        default:
            completion(.none)
            return
        }

        window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                          styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // Off, or dragging inside an editor would move the window instead.
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.contentView = NSHostingView(rootView: content.environmentObject(SettingsStore.shared))
        window.center()
        open.append(window)
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: window, queue: .main) { note in
            open.removeAll { $0 === note.object as? NSWindow }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

/// Shared header and footer for editor windows.
struct EditorChrome<Content: View>: View {
    @EnvironmentObject var settings: SettingsStore
    let title: String
    let subtitle: String
    let applyTitle: String
    var canApply = true
    let onReset: (() -> Void)?
    let onCancel: () -> Void
    let onApply: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        let theme = settings.theme
        VStack(spacing: 14) {
            VStack(spacing: 2) {
                Text(title).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            .padding(.top, 6)
            content
            HStack {
                if let onReset {
                    Button(L("Reset"), action: onReset).buttonStyle(.bordered)
                }
                Spacer()
                Button(L("Cancel"), action: onCancel).keyboardShortcut(.cancelAction).buttonStyle(.bordered)
                Button(action: onApply) {
                    Text(applyTitle).font(.system(size: 13, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 5)
                        .background(Capsule().fill(theme.gradient))
                        .opacity(canApply ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.defaultAction)
                .disabled(!canApply)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualBackground())
        .tint(theme.accent2)
    }
}

/// Window background with a soft blur.
struct VisualBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .underWindowBackground
        v.blendingMode = .behindWindow
        v.state = .followsWindowActiveState
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Checkerboard to show transparency.
struct Checkerboard: View {
    var body: some View {
        Canvas { ctx, size in
            let s: CGFloat = 10
            for row in 0..<Int(size.height / s) + 1 {
                for col in 0..<Int(size.width / s) + 1 where (row + col) % 2 == 0 {
                    ctx.fill(Path(CGRect(x: CGFloat(col) * s, y: CGFloat(row) * s, width: s, height: s)), with: .color(.gray.opacity(0.18)))
                }
            }
        }
    }
}

// MARK: - Crop

struct CropEditor: View {
    let url: URL
    let onCancel: () -> Void
    let onApply: (ToolParameters) -> Void

    @State private var image: CGImage?
    @State private var math = CropGeometry(pixelSize: CGSize(width: 1, height: 1))
    /// Normalized crop rect (0...1), top-left origin.
    @State private var crop = CropGeometry.full
    @State private var start = CGRect.zero
    @State private var grab: CropGeometry.Grab?

    private let ratios: [(String, Double?)] = [("Free", nil), ("1:1", 1), ("4:3", 4.0 / 3), ("3:2", 1.5), ("16:9", 16.0 / 9), ("9:16", 9.0 / 16)]

    var body: some View {
        EditorChrome(title: L("Crop Image"), subtitle: url.lastPathComponent, applyTitle: L("Apply"),
                     canApply: crop != CropGeometry.full,
                     onReset: { crop = CropGeometry.full; math.ratio = nil },
                     onCancel: onCancel,
                     onApply: { onApply(.crop(math.pixelRect(crop))) }) {
            GeometryReader { outer in
                // A margin so the corner handles never touch the window edge.
                let inset: CGFloat = 12
                let geoSize = CGSize(width: outer.size.width - inset * 2, height: outer.size.height - inset * 2)
                let frame = math.fit(in: geoSize).offsetBy(dx: inset, dy: inset)
                let r = math.viewRect(crop, in: frame)
                ZStack(alignment: .topLeading) {
                    // Catches every drag; the drawing on top ignores the mouse.
                    SwiftUI.Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { v in
                                    if grab == nil {
                                        grab = math.grab(at: v.startLocation, viewRect: r)
                                        start = crop
                                    }
                                    if let grab {
                                        crop = math.update(grab, start: start, from: v.startLocation, to: v.location, frame: frame)
                                    }
                                }
                                .onEnded { _ in grab = nil }
                        )
                        .onContinuousHover { phase in
                            switch phase {
                            case .active(let p): cursor(for: math.grab(at: p, viewRect: r)).set()
                            case .ended: NSCursor.arrow.set()
                            }
                        }

                    ZStack(alignment: .topLeading) {
                        if let image {
                            Image(decorative: image, scale: 1).resizable()
                                .frame(width: frame.width, height: frame.height)
                                .offset(x: frame.minX, y: frame.minY)
                        }
                        Path { p in
                            p.addRect(frame)
                            p.addRect(r)
                        }
                        .fill(.black.opacity(0.55), style: FillStyle(eoFill: true))

                        Rectangle().strokeBorder(.white, lineWidth: 1.5)
                            .overlay(grid.opacity(grab == nil ? 0 : 1))
                            .frame(width: r.width, height: r.height)
                            .offset(x: r.minX, y: r.minY)

                        ForEach(0..<4, id: \.self) { i in
                            let p = CropGeometry.corner(i, of: r)
                            Circle().fill(.white).frame(width: 16, height: 16)
                                .shadow(color: .black.opacity(0.4), radius: 2)
                                .offset(x: p.x - 8, y: p.y - 8)
                        }
                        if math.ratio == nil {
                            ForEach(0..<4, id: \.self) { i in
                                let p = CropGeometry.edgeMid(i, of: r)
                                let horizontal = i % 2 == 0
                                Capsule().fill(.white).frame(width: horizontal ? 22 : 5, height: horizontal ? 5 : 22)
                                    .shadow(color: .black.opacity(0.4), radius: 2)
                                    .offset(x: p.x - (horizontal ? 11 : 2.5), y: p.y - (horizontal ? 2.5 : 11))
                            }
                        }
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 400)

            HStack(spacing: 6) {
                Text(L("Aspect ratio")).font(.system(size: 11)).foregroundStyle(.secondary)
                ForEach(ratios, id: \.0) { item in
                    chip(item.0 == "Free" ? L("Free") : item.0, selected: math.ratio == item.1) {
                        math.ratio = item.1
                        if item.1 != nil { crop = math.centered() }
                    }
                }
                Spacer()
                let px = math.pixelRect(crop)
                Text(verbatim: "\(Int(px.width)) × \(Int(px.height)) px")
                    .font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
            }
            Text(L("Drag the corners or edges, drag inside to move, or drag on the photo to draw a new area."))
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .onAppear(perform: load)
    }

    private var grid: some View {
        GeometryReader { g in
            Path { p in
                for i in 1...2 {
                    let x = g.size.width * CGFloat(i) / 3, y = g.size.height * CGFloat(i) / 3
                    p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: g.size.height))
                    p.move(to: CGPoint(x: 0, y: y)); p.addLine(to: CGPoint(x: g.size.width, y: y))
                }
            }
            .stroke(.white.opacity(0.6), lineWidth: 0.5)
        }
    }

    private func load() {
        image = Images.thumbnail(url, maxPixel: 1400)
        if let (full, _) = try? Images.load(url) { math.pixelSize = CGSize(width: full.width, height: full.height) }
    }

    private func cursor(for grab: CropGeometry.Grab) -> NSCursor {
        switch grab {
        case .move: return .openHand
        case .edge(let i): return i % 2 == 0 ? .resizeUpDown : .resizeLeftRight
        case .corner, .draw: return .crosshair
        }
    }
}

func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Text(title)
            .font(.system(size: 11, weight: selected ? .bold : .medium))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(selected ? AnyShapeStyle(SettingsStore.shared.theme.gradient) : AnyShapeStyle(.primary.opacity(0.08))))
    }
    .buttonStyle(.plain)
}

// MARK: - Add background

struct BackgroundEditor: View {
    let url: URL
    let count: Int
    let onCancel: () -> Void
    let onApply: (ToolParameters) -> Void

    @EnvironmentObject var settings: SettingsStore
    @State private var style = KumquatCore.BackgroundStyle()
    @State private var source: CGImage?
    @State private var preview: CGImage?
    @State private var custom = SwiftUI.Color.orange

    var body: some View {
        EditorChrome(title: L("Add Background"), subtitle: count > 1 ? L("%d images", count) : url.lastPathComponent,
                     applyTitle: L("Save with Background"),
                     onReset: { style = KumquatCore.BackgroundStyle() },
                     onCancel: onCancel,
                     onApply: {
                         settings.lastBackground = style
                         onApply(.background(style))
                     }) {
            ZStack {
                Checkerboard()
                if let preview {
                    Image(decorative: preview, scale: 1).resizable().aspectRatio(contentMode: .fit).padding(10)
                }
            }
            .frame(height: 330)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 10) {
                row(L("Background")) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            ForEach(KumquatCore.BackgroundStyle.gradientPresets, id: \.self) { colors in
                                swatch(LinearGradient(colors: colors.map(SwiftUI.Color.init(hex:)), startPoint: .topLeading, endPoint: .bottomTrailing),
                                       selected: style.fill == .gradient(colors, angle: 135)) {
                                    style.fill = .gradient(colors, angle: 135)
                                }
                            }
                        }
                        HStack(spacing: 6) {
                            ForEach(KumquatCore.BackgroundStyle.solidPresets, id: \.self) { hex in
                                swatch(SwiftUI.Color(hex: hex), selected: style.fill == .solid(hex)) { style.fill = .solid(hex) }
                            }
                            swatch(Checkerboard(), selected: style.fill == .transparent) { style.fill = .transparent }
                            ColorPicker("", selection: $custom, supportsOpacity: false)
                                .labelsHidden()
                                .onChange(of: custom) { _, c in style.fill = .solid(c.hex) }
                        }
                    }
                }
                row(L("Padding")) { slider($style.padding, 0...0.4) }
                row(L("Corners")) { slider($style.cornerRadius, 0...0.15) }
                row(L("Shadow")) { slider($style.shadow, 0...0.1) }
                row(L("Ratio")) {
                    HStack(spacing: 6) {
                        ForEach(KumquatCore.BackgroundStyle.Aspect.allCases, id: \.self) { a in
                            chip(a == .auto ? L("Auto") : a.label, selected: style.aspect == a) { style.aspect = a }
                        }
                    }
                }
            }
        }
        .onAppear {
            style = settings.lastBackground
            source = Images.thumbnail(url, maxPixel: 900)
            render()
        }
        .onChange(of: style) { _, _ in render() }
    }

    private func render() {
        guard let source else { return }
        preview = BackgroundRenderer.render(source, style: style)
    }

    private func row<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).frame(width: 78, alignment: .leading)
            content()
        }
    }

    private func slider(_ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        HStack {
            Slider(value: value, in: range)
            Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 40, alignment: .trailing)
        }
    }

    private func swatch<S: View>(_ fill: S, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            fill.frame(width: 22, height: 22).clipShape(Circle())
                .overlay(Circle().strokeBorder(selected ? SwiftUI.Color.accentColor : .primary.opacity(0.15), lineWidth: selected ? 2.5 : 1))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Resize

struct ResizeEditor: View {
    let url: URL
    let count: Int
    let onCancel: () -> Void
    let onApply: (ToolParameters) -> Void

    @State private var original = CGSize(width: 1, height: 1)
    @State private var factor = 0.5
    @State private var thumb: CGImage?

    private var target: CGSize { CGSize(width: (original.width * factor).rounded(), height: (original.height * factor).rounded()) }

    var body: some View {
        EditorChrome(title: L("Resize"), subtitle: count > 1 ? L("%d images", count) : url.lastPathComponent,
                     applyTitle: L("Resize"), onReset: { factor = 0.5 }, onCancel: onCancel,
                     onApply: { onApply(count > 1 ? .scale(factor) : .resize(width: Int(target.width), height: Int(target.height))) }) {
            if let thumb {
                Image(decorative: thumb, scale: 1).resizable().aspectRatio(contentMode: .fit)
                    .frame(height: 150).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            VStack(spacing: 10) {
                HStack {
                    Text("\(Int(original.width)) × \(Int(original.height))").foregroundStyle(.secondary)
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                    Text("\(Int(target.width)) × \(Int(target.height)) px").fontWeight(.semibold)
                }
                .font(.system(size: 13, design: .monospaced))
                HStack {
                    Slider(value: $factor, in: 0.05...2, step: 0.01)
                    Text("\(Int((factor * 100).rounded()))%").font(.system(size: 12, design: .monospaced)).frame(width: 46, alignment: .trailing)
                }
                HStack(spacing: 6) {
                    chip("25%", selected: abs(factor - 0.25) < 0.001) { factor = 0.25 }
                    chip("50%", selected: abs(factor - 0.5) < 0.001) { factor = 0.5 }
                    chip("75%", selected: abs(factor - 0.75) < 0.001) { factor = 0.75 }
                    ForEach([1080, 1920, 3840], id: \.self) { side in
                        chip("\(side) px", selected: false) {
                            factor = Double(side) / Double(max(original.width, original.height, 1))
                        }
                    }
                }
            }
        }
        .onAppear {
            thumb = Images.thumbnail(url, maxPixel: 600)
            if let (img, _) = try? Images.load(url) { original = CGSize(width: img.width, height: img.height) }
        }
    }
}

// MARK: - Protect PDF

struct PasswordEditor: View {
    let url: URL
    let onCancel: () -> Void
    let onApply: (ToolParameters) -> Void

    @State private var password = ""
    @State private var confirm = ""

    var body: some View {
        EditorChrome(title: L("Protect PDF"), subtitle: url.lastPathComponent, applyTitle: L("Protect"),
                     canApply: !password.isEmpty && password == confirm,
                     onReset: nil, onCancel: onCancel, onApply: { onApply(.password(password)) }) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "lock.doc.fill").font(.system(size: 34)).foregroundStyle(SettingsStore.shared.theme.gradient)
                    .frame(maxWidth: .infinity)
                SecureField(L("Password"), text: $password).textFieldStyle(.roundedBorder)
                SecureField(L("Confirm password"), text: $confirm).textFieldStyle(.roundedBorder)
                Text(L("A protected copy is saved. The original stays as it is."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
    }
}
