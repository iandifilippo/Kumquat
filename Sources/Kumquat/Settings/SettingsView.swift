import AppKit
import KumquatCore
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, appearance, actions, output, quality, automation, engines, about
    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: return L("General")
        case .appearance: return L("Appearance")
        case .actions: return L("Formats & Tools")
        case .output: return L("Saving")
        case .quality: return L("Quality")
        case .automation: return L("Automation")
        case .engines: return L("Engines")
        case .about: return L("About")
        }
    }

    var symbol: String {
        switch self {
        case .general: return "gearshape.fill"
        case .appearance: return "paintpalette.fill"
        case .actions: return "circle.grid.cross.fill"
        case .output: return "folder.fill"
        case .quality: return "slider.horizontal.3"
        case .automation: return "bolt.fill"
        case .engines: return "shippingbox.fill"
        case .about: return "info.circle.fill"
        }
    }

    var color: SwiftUI.Color {
        switch self {
        case .general: return .gray
        case .appearance: return .pink
        case .actions: return .orange
        case .output: return .blue
        case .quality: return .green
        case .automation: return .yellow
        case .engines: return .brown
        case .about: return .purple
        }
    }
}

final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?
    let selection = SettingsSelection()

    func show(_ pane: SettingsPane? = nil) {
        if let pane { selection.pane = pane }
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 780, height: 600),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isReleasedWhenClosed = false
            w.contentView = NSHostingView(rootView: SettingsView(selection: selection).environmentObject(SettingsStore.shared))
            w.center()
            w.setFrameAutosaveName("KumquatSettings")
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

final class SettingsSelection: ObservableObject {
    @Published var pane: SettingsPane = .general
}

struct SettingsView: View {
    @ObservedObject var selection: SettingsSelection
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(selection.pane.title)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .padding(.horizontal, 28).padding(.top, 34).padding(.bottom, 4)
                    Group {
                        switch selection.pane {
                        case .general: GeneralPane()
                        case .appearance: AppearancePane()
                        case .actions: ActionsPane()
                        case .output: OutputPane()
                        case .quality: QualityPane()
                        case .automation: AutomationPane()
                        case .engines: EnginesPane()
                        case .about: AboutPane()
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                }
            }
            .frame(maxWidth: .infinity)
            .background(SwiftUI.Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 600)
        .tint(settings.theme.accent2)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                AppIconView().frame(width: 30, height: 30)
                Text("Kumquat").font(.system(size: 15, weight: .bold, design: .rounded))
            }
            .padding(.horizontal, 10).padding(.top, 40).padding(.bottom, 14)
            ForEach(SettingsPane.allCases) { pane in
                Button { selection.pane = pane } label: {
                    HStack(spacing: 9) {
                        Image(systemName: pane.symbol)
                            .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(RoundedRectangle(cornerRadius: 6).fill(pane.color.gradient))
                        Text(pane.title).font(.system(size: 13))
                        Spacer()
                    }
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 7).fill(selection.pane == pane ? SwiftUI.Color.primary.opacity(0.1) : .clear))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Toggle(isOn: Binding(get: { !settings.paused }, set: { settings.paused = !$0 })) {
                Text(settings.paused ? L("Paused") : L("Active")).font(.system(size: 12, weight: .medium))
            }
            .toggleStyle(.switch).controlSize(.small)
            .padding(10)
        }
        .padding(.horizontal, 10)
        .frame(width: 210)
        .background(VisualBackground())
    }
}

/// The app icon drawn in SwiftUI (same art as the .icns).
struct AppIconView: View {
    var body: some View {
        if Bundle.main.bundleIdentifier != nil, let icon = NSApp.applicationIconImage {
            Image(nsImage: icon).resizable()
        } else if let icon = NSImage(contentsOfFile: "Resources/AppIcon.icns") {
            Image(nsImage: icon).resizable()
        } else {
            Circle().fill(LinearGradient(colors: [.orange, .red], startPoint: .top, endPoint: .bottom))
        }
    }
}

// MARK: - Panes

private struct GeneralPane: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker(L("Trigger key"), selection: $settings.triggerKey) {
                    ForEach(TriggerKey.allCases) { key in Text("\(key.symbol)  \(key.name)").tag(key) }
                }
                Picker(L("Ring behavior"), selection: $settings.triggerMode) {
                    Text(L("Tap to open, tap again to switch")).tag(TriggerMode.tap)
                    Text(L("Show only while the key is held")).tag(TriggerMode.hold)
                }
            } header: {
                Text(L("Gesture"))
            } footer: {
                Text(L("Click a file and drag it a little without letting go, then tap %@. Drop it on a slice.", settings.triggerKey.symbol))
                    .foregroundStyle(.secondary)
            }

            Section(L("Language")) {
                Picker(L("Language"), selection: $settings.language) {
                    ForEach(AppLanguage.allCases) { Text($0.name).tag($0) }
                }
            }

            Section(L("System")) {
                Toggle(L("Open at login"), isOn: Binding(get: { settings.launchAtLogin }, set: { settings.launchAtLogin = $0 }))
                Toggle(L("Show icon in the Dock"), isOn: $settings.showDockIcon)
                    .onChange(of: settings.showDockIcon) { _, show in
                        NSApp.setActivationPolicy(show ? .regular : .accessory)
                        SettingsWindowController.shared.show()
                    }
                Toggle(L("Haptic feedback on trackpad"), isOn: $settings.haptics)
                Toggle(L("Play a sound when done"), isOn: $settings.playSound)
            }

            Section {
                HStack {
                    Button(L("Show Welcome Screen")) { OnboardingWindow.show() }
                    Spacer()
                    Button(L("Reset All Settings"), role: .destructive) { settings.resetAll() }
                }
            }
        }
    }
}

private struct AppearancePane: View {
    @EnvironmentObject var settings: SettingsStore
    @StateObject private var preview = RingPreviewModel()

    var body: some View {
        Form {
            Section {
                ZStack {
                    LinearGradient(colors: [SwiftUI.Color(hex: "#FFB86B"), SwiftUI.Color(hex: "#F76B6B"), SwiftUI.Color(hex: "#8E7CF0")],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                    RingView(model: preview.model, theme: previewTheme)
                        .scaleEffect(min(1, 250 / settings.ringSize))
                }
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .listRowInsets(EdgeInsets())
            }

            Section(L("Theme")) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 12) {
                    ForEach(ThemePreset.all) { preset in
                        Button { settings.themeID = preset.id } label: {
                            VStack(spacing: 5) {
                                Circle()
                                    .fill(LinearGradient(colors: [SwiftUI.Color(hex: preset.id == "custom" ? settings.customAccent : preset.accent),
                                                                  SwiftUI.Color(hex: preset.id == "custom" ? settings.customAccent2 : preset.accent2)],
                                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 34, height: 34)
                                    .overlay(Circle().strokeBorder(.white, lineWidth: settings.themeID == preset.id ? 3 : 0))
                                    .overlay(Circle().strokeBorder(.primary.opacity(settings.themeID == preset.id ? 0.5 : 0.1), lineWidth: 1).padding(-2))
                                    .overlay(preset.id == "custom" ? Image(systemName: "eyedropper").font(.system(size: 12, weight: .bold)).foregroundStyle(.white) : nil)
                                Text(preset.localizedName).font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
                if settings.themeID == "custom" {
                    ColorPicker(L("First color"), selection: Binding(get: { SwiftUI.Color(hex: settings.customAccent) }, set: { settings.customAccent = $0.hex }), supportsOpacity: false)
                    ColorPicker(L("Second color"), selection: Binding(get: { SwiftUI.Color(hex: settings.customAccent2) }, set: { settings.customAccent2 = $0.hex }), supportsOpacity: false)
                }
            }

            Section(L("Ring")) {
                Picker(L("Material"), selection: $settings.glassStyle) {
                    ForEach(GlassStyle.userChoices) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker(L("Light or dark"), selection: $settings.ringScheme) {
                    ForEach(RingScheme.allCases) { Text($0.name).tag($0) }
                }
                Picker(L("Labels"), selection: $settings.labelStyle) {
                    ForEach(LabelStyle.allCases) { Text($0.name).tag($0) }
                }
                LabeledContent(L("Size")) {
                    HStack {
                        Slider(value: $settings.ringSize, in: 220...420, step: 10)
                        Text("\(Int(settings.ringSize)) pt").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 50)
                    }
                }
                LabeledContent(L("Slice opacity")) {
                    HStack {
                        Slider(value: $settings.sliceOpacity, in: 0.2...1)
                        Text("\(Int(settings.sliceOpacity * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 50)
                    }
                }
                Toggle(L("Animations"), isOn: $settings.animations)
            }

            Section(L("Notifications")) {
                Picker(L("Position"), selection: $settings.toastPosition) {
                    ForEach(ToastPosition.allCases) { Text($0.name).tag($0) }
                }
                LabeledContent(L("Stays for")) {
                    HStack {
                        Slider(value: $settings.toastSeconds, in: 2...15, step: 1)
                        Text("\(Int(settings.toastSeconds)) s").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 50)
                    }
                }
            }
        }
        .onAppear { preview.start() }
        .onDisappear { preview.stop() }
    }

    private var previewTheme: Theme {
        var t = settings.theme
        if t.glass == .frosted || t.glass == .liquid { t.glass = .snapshot }
        return t
    }
}

/// Animates a sample ring in Settings so changes are visible immediately.
final class RingPreviewModel: ObservableObject {
    let model = RingModel()
    private var timer: Timer?

    init() {
        model.load(files: [URL(fileURLWithPath: "/tmp/Photo.heic")], settings: SettingsStore.shared)
        model.shown = true
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.1, repeats: true) { [weak self] _ in
            guard let self else { return }
            let count = self.model.items.count
            guard count > 0 else { return }
            self.model.hovered = ((self.model.hovered ?? -1) + 1) % count
        }
    }

    func stop() { timer?.invalidate() }
}

private struct ActionsPane: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Text(L("Choose what appears on the ring for each kind of file. Fewer slices make bigger targets."))
                    .foregroundStyle(.secondary)
                Text(L("Right-click a format to move it; use the arrows to reorder tools. Formats marked with a dot need an engine."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            ForEach([FileKind.image, .pdf, .document, .data, .ebook, .video, .audio, .archive, .subtitle, .office, .folder], id: \.self) { kind in
                Section {
                    let all = ActionCatalog.allActions(for: kind)
                    let convert = all.convert
                    let tools = all.tools
                    if !convert.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L("Convert to"))
                            FlowChips(actions: convert)
                        }
                        .padding(.vertical, 2)
                    }
                    let orderedTools = settings.ordered(tools)
                    ForEach(Array(orderedTools.enumerated()), id: \.element.id) { index, action in
                        if case .tool(let tool) = action {
                            HStack(spacing: 8) {
                                VStack(spacing: 0) {
                                    Button { settings.move(action, by: -1, in: tools) } label: { Image(systemName: "chevron.up") }
                                        .disabled(index == 0)
                                    Button { settings.move(action, by: 1, in: tools) } label: { Image(systemName: "chevron.down") }
                                        .disabled(index == orderedTools.count - 1)
                                }
                                .buttonStyle(.borderless)
                                .font(.system(size: 9, weight: .bold))
                                .help(L("Move this slice"))
                                Toggle(isOn: Binding(get: { settings.isEnabled(action) }, set: { settings.setEnabled(action, $0) })) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(tool.title)
                                            Text(tool.explanation).font(.system(size: 11)).foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: tool.symbol).foregroundStyle(settings.theme.accent2)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Label(kind.title, systemImage: kind.symbol)
                }
            }
        }
    }
}

/// Toggleable format chips that wrap onto new lines.
private struct FlowChips: View {
    @EnvironmentObject var settings: SettingsStore
    let actions: [KQAction]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(settings.ordered(actions), id: \.id) { action in
                chip(action.title + (needsEngine(action) ? " •" : ""), selected: settings.isEnabled(action)) {
                    settings.setEnabled(action, !settings.isEnabled(action))
                }
                .contextMenu {
                    Button(L("Move Left")) { settings.move(action, by: -1, in: actions) }
                    Button(L("Move Right")) { settings.move(action, by: 1, in: actions) }
                }
                .help(needsEngine(action) ? L("Needs an engine (see Engines)") : "")
            }
        }
    }

    /// True for formats only offered when FFmpeg, LibreOffice or a WebP encoder is installed.
    private func needsEngine(_ action: KQAction) -> Bool {
        guard case .convert(let f) = action else { return false }
        return [.webp, .webm, .mkv, .avi, .mp3, .ogg, .opus, .pptx].contains(f)
    }
}

/// Lays children out left to right, starting a new row when one is full.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.items {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row { var items: [Int] = []; var y: CGFloat = 0; var width: CGFloat = 0; var height: CGFloat = 0 }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].items.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            var row = rows[rows.count - 1]
            row.width += (row.items.isEmpty ? 0 : spacing) + size.width
            row.height = max(row.height, size.height)
            row.items.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}

private struct OutputPane: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section {
                Picker(L("Save results"), selection: $settings.saveLocation) {
                    ForEach(SaveLocation.allCases) { Text($0.name).tag($0) }
                }
                if settings.saveLocation == .subfolder {
                    TextField(L("Subfolder name"), text: $settings.subfolderName)
                }
                if settings.saveLocation == .folder {
                    LabeledContent(L("Folder")) {
                        HStack {
                            Text(settings.customFolder.isEmpty ? L("None") : (settings.customFolder as NSString).abbreviatingWithTildeInPath)
                                .lineLimit(1).truncationMode(.middle).foregroundStyle(.secondary)
                            Button(L("Choose…")) { chooseFolder() }
                        }
                    }
                }
            } footer: {
                Text(L("Originals are never changed. If a name is taken, Kumquat adds a number."))
                    .foregroundStyle(.secondary)
            }

            Section(L("After converting")) {
                Toggle(L("Reveal the result in Finder"), isOn: $settings.revealInFinder)
                Toggle(L("Move the original to the Trash"), isOn: $settings.trashOriginal)
                Text(L("Undo in the notification puts the original back."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L("Choose")
        if panel.runModal() == .OK, let url = panel.url { settings.customFolder = url.path }
    }
}

private struct QualityPane: View {
    @EnvironmentObject var settings: SettingsStore

    var body: some View {
        Form {
            Section(L("Images")) {
                percentSlider(L("Conversion quality"), $settings.imageQuality, 0.3...1)
                Toggle(L("Keep metadata (camera, date, location)"), isOn: $settings.keepMetadata)
            }
            Section(L("Compress")) {
                percentSlider(L("Quality"), $settings.compressQuality, 0.1...0.95)
                Picker(L("Shrink to at most"), selection: $settings.compressMaxDimension) {
                    Text(L("Original size")).tag(0)
                    ForEach([3840, 2560, 1920, 1280, 1024], id: \.self) { Text("\($0) px").tag($0) }
                }
            }
            Section("PDF") {
                Picker(L("Page images resolution"), selection: $settings.pdfDPI) {
                    ForEach([72.0, 150, 200, 300, 600], id: \.self) { Text("\(Int($0)) DPI").tag($0) }
                }
                Toggle(L("Combine several images into one PDF"), isOn: $settings.combineImagesIntoPDF)
                Picker(L("Compress PDF"), selection: $settings.pdfCompression) {
                    Text(L("Balanced: text stays selectable")).tag(ConversionOptions.PDFCompression.balanced)
                    Text(L("Strongest: pages become images")).tag(ConversionOptions.PDFCompression.strong)
                }
                Toggle(L("Use LibreOffice for Word → PDF when installed"), isOn: $settings.preferLibreOffice)
            }
            Section(L("Video")) {
                Picker(L("Frames"), selection: $settings.framesPerSecond) {
                    Text(L("Every frame")).tag(0.0)
                    ForEach([30.0, 10, 5, 1], id: \.self) { Text(L("%d per second", Int($0))).tag($0) }
                }
            }
            Section("GIF") {
                Picker(L("Frame rate"), selection: $settings.gifFPS) {
                    ForEach([8, 10, 12, 15, 20, 24], id: \.self) { Text("\($0) fps").tag($0) }
                }
                Picker(L("Width"), selection: $settings.gifMaxWidth) {
                    ForEach([320, 480, 640, 800, 1080], id: \.self) { Text("\($0) px").tag($0) }
                }
                Picker(L("Longest clip"), selection: $settings.gifMaxSeconds) {
                    ForEach([5.0, 10, 15, 30, 60], id: \.self) { Text("\(Int($0)) s").tag($0) }
                }
            }
        }
    }

    private func percentSlider(_ title: String, _ value: Binding<Double>, _ range: ClosedRange<Double>) -> some View {
        LabeledContent(title) {
            HStack {
                Slider(value: value, in: range)
                Text("\(Int(value.wrappedValue * 100))%").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary).frame(width: 44)
            }
        }
    }
}

private struct AboutPane: View {
    @EnvironmentObject var settings: SettingsStore
    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }

    var body: some View {
        Form {
            Section {
                VStack(spacing: 8) {
                    AppIconView().frame(width: 88, height: 88)
                    Text("Kumquat").font(.system(size: 24, weight: .bold, design: .rounded))
                    Text(L("Version %@", version)).foregroundStyle(.secondary)
                    Text(L("Drag a file, tap ⇧, drop. Convert anything without opening an app."))
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                    HStack {
                        Link(destination: URL(string: "https://github.com/iandifilippo/Kumquat")!) { Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right") }
                        Text("·").foregroundStyle(.secondary)
                        Link(destination: URL(string: "https://github.com/iandifilippo/Kumquat/issues/new/choose")!) { Label(L("Report a problem"), systemImage: "ladybug") }
                        Text("·").foregroundStyle(.secondary)
                        Link(destination: URL(string: "https://github.com/iandifilippo/Kumquat/releases")!) { Label(L("Updates"), systemImage: "arrow.down.circle") }
                    }
                    .padding(.top, 6)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            Section {
                Toggle(L("Check for updates automatically"), isOn: $settings.checkForUpdates)
                HStack {
                    Button(L("Check Now")) { UpdateChecker.shared.check(userInitiated: true) }
                    Spacer()
                }
            } footer: {
                Text(L("Free and open source under the MIT license. Files never leave your Mac: no accounts, no uploads, no tracking. The only network request is this update check, which asks GitHub for the latest version."))
                    .foregroundStyle(.secondary)
            }
        }
    }
}


private struct AutomationPane: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var cliMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.hotkeyEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L("Shortcut for Finder selection: %@", Hotkey.display))
                        Text(L("Select files in Finder, press the shortcut, and the ring opens. macOS asks once to let Kumquat read Finder's selection."))
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                    }
                }
                Toggle(L("Show progress inside the ring"), isOn: $settings.progressInRing)
            } header: {
                Text(L("Shortcuts"))
            }

            Section {
                if settings.watchRules.isEmpty {
                    Text(L("No folders yet. Add one and every file that lands in it is converted automatically."))
                        .foregroundStyle(.secondary)
                }
                ForEach($settings.watchRules) { $rule in
                    HStack(spacing: 10) {
                        Toggle("", isOn: $rule.enabled).labelsHidden().toggleStyle(.switch).controlSize(.small)
                        VStack(alignment: .leading, spacing: 4) {
                            Text((rule.folder as NSString).abbreviatingWithTildeInPath)
                                .lineLimit(1).truncationMode(.middle)
                            HStack {
                                Picker("", selection: $rule.action) {
                                    ForEach(WatchChoices.all, id: \.id) { choice in Text(choice.title).tag(choice.id) }
                                }
                                .labelsHidden().frame(maxWidth: 260)
                                Toggle(L("Move originals to “Originals”"), isOn: $rule.moveOriginals).controlSize(.small)
                            }
                        }
                        Spacer()
                        Button(role: .destructive) { settings.watchRules.removeAll { $0.id == rule.id } } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Button(L("Add Folder…")) { addFolder() }
            } header: {
                Text(L("Watch folders"))
            } footer: {
                Text(L("Only files that fit the action are converted; results are saved next to them."))
                    .foregroundStyle(.secondary)
            }

            Section {
                Text("kumquat convert photo.heic --to jpg")
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                HStack {
                    Button(L("Install the kumquat Command")) { cliMessage = CLIInstaller.install() }
                    Spacer()
                }
                if let cliMessage {
                    Text(cliMessage).font(.system(size: 11)).foregroundStyle(.secondary).textSelection(.enabled)
                }
            } header: {
                Text(L("Command line"))
            } footer: {
                Text(L("Run `kumquat help` in Terminal to see every command, including watching a folder."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = L("Watch")
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.watchRules.append(WatchRule(folder: url.path, action: "convert.jpg"))
    }
}

/// Every action a watch folder can run, with a readable name.
enum WatchChoices {
    struct Choice { let id: String; let title: String }

    static var all: [Choice] {
        var seen: Set<String> = []
        var out: [Choice] = []
        for kind in [FileKind.image, .pdf, .document, .data, .ebook, .video, .audio, .archive, .subtitle, .folder] {
            let a = ActionCatalog.allActions(for: kind)
            for action in a.convert + a.tools where !seen.contains(action.id) && action != .tool(.merge) {
                seen.insert(action.id)
                let title: String
                switch action {
                case .convert(let f): title = L("Convert to %@", f.label)
                case .tool(let t): title = "\(t.title) (\(kind.title))"
                }
                out.append(Choice(id: action.id, title: title))
            }
        }
        return out.filter { !(KQAction(id: $0.id).map { a in if case .tool(let t) = a { return t.needsEditor } else { return false } } ?? true) }
    }
}

/// Links the `kumquat` command into a folder on the user's PATH.
enum CLIInstaller {
    static func install() -> String {
        let binary = Bundle.main.executablePath ?? ""
        let candidates = ["/opt/homebrew/bin", "/usr/local/bin", NSHomeDirectory() + "/.local/bin"]
        for dir in candidates {
            let fm = FileManager.default
            if dir.hasSuffix(".local/bin") { try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true) }
            guard fm.isWritableFile(atPath: dir) else { continue }
            let link = dir + "/kumquat"
            try? fm.removeItem(atPath: link)
            do {
                try fm.createSymbolicLink(atPath: link, withDestinationPath: binary)
                let onPath = (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").contains { String($0) == dir }
                return onPath || !dir.hasSuffix(".local/bin")
                    ? L("Installed at %@. Open a new Terminal window and run `kumquat help`.", link)
                    : L("Installed at %@. Add this folder to your PATH: export PATH=\"$HOME/.local/bin:$PATH\"", link)
            } catch { continue }
        }
        return L("Couldn't install it automatically. In Terminal run: sudo ln -sf \"%@\" /usr/local/bin/kumquat", binary)
    }
}

private struct EnginesPane: View {
    @State private var engines = Engines.current

    var body: some View {
        Form {
            Section {
                Text(L("Kumquat converts most files with what macOS already has. These free tools add more formats. Kumquat never downloads them; install them and they're picked up automatically."))
                    .foregroundStyle(.secondary)
            }
            Section {
                row("FFmpeg", installed: engines.ffmpeg, adds: L("WebM, MKV, AVI, FLV and other video; MP3, OGG, OPUS; frames and GIFs from any video"),
                    command: "brew install ffmpeg", link: "https://ffmpeg.org")
                row("LibreOffice", installed: engines.soffice, adds: L("Excel, PowerPoint, Keynote, Numbers and Pages to PDF; Word to PDF with exact layout"),
                    command: nil, link: "https://www.libreoffice.org/download/download-libreoffice/")
                row("Ghostscript", installed: engines.ghostscript, adds: L("Much better PDF compression that keeps text selectable"),
                    command: "brew install ghostscript", link: "https://ghostscript.com")
                row("WebP", installed: engines.cwebp, adds: L("Save images as WebP"),
                    command: "brew install webp", link: "https://developers.google.com/speed/webp")
            }
            Section {
                HStack {
                    Button(L("Look Again")) { engines = Engines.refresh() }
                    Spacer()
                    Link(L("What is Homebrew?"), destination: URL(string: "https://brew.sh")!)
                }
            }
        }
    }

    @ViewBuilder
    private func row(_ name: String, installed: URL?, adds: String, command: String?, link: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: installed != nil ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(installed != nil ? SwiftUI.Color.green : .secondary)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name).fontWeight(.semibold)
                    Text(installed != nil ? L("Installed") : L("Not installed"))
                        .font(.system(size: 10, weight: .semibold))
                        .padding(.horizontal, 6).padding(.vertical, 1)
                        .background(Capsule().fill((installed != nil ? SwiftUI.Color.green : .gray).opacity(0.18)))
                }
                Text(adds).font(.system(size: 11)).foregroundStyle(.secondary)
                if installed == nil {
                    HStack(spacing: 8) {
                        if let command {
                            Text(command).font(.system(size: 11, design: .monospaced)).textSelection(.enabled)
                            Button(L("Copy")) {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(command, forType: .string)
                            }
                            .controlSize(.small)
                        }
                        Link(L("Website"), destination: URL(string: link)!).font(.system(size: 11))
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}
