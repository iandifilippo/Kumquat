import AppKit
import Combine
import KumquatCore
import ServiceManagement
import SwiftUI

/// Reads and writes Codable values in UserDefaults.
enum Defaults {
    static func load<Value: Codable>(_ key: String, _ fallback: Value) -> Value {
        guard let data = UserDefaults.standard.data(forKey: key),
              let value = try? JSONDecoder().decode(Value.self, from: data) else { return fallback }
        return value
    }

    static func save<Value: Codable>(_ key: String, _ value: Value) {
        if let data = try? JSONEncoder().encode(value) { UserDefaults.standard.set(data, forKey: key) }
    }
}

enum TriggerKey: String, Codable, CaseIterable, Identifiable {
    case shift, option, control, command
    var id: String { rawValue }
    var flag: NSEvent.ModifierFlags {
        switch self {
        case .shift: return .shift
        case .option: return .option
        case .control: return .control
        case .command: return .command
        }
    }
    var symbol: String {
        switch self {
        case .shift: return "⇧"
        case .option: return "⌥"
        case .control: return "⌃"
        case .command: return "⌘"
        }
    }
    var name: String {
        switch self {
        case .shift: return L("Shift")
        case .option: return L("Option")
        case .control: return L("Control")
        case .command: return L("Command")
        }
    }
}

enum TriggerMode: String, Codable, CaseIterable, Identifiable {
    case tap, hold
    var id: String { rawValue }
}

enum GlassStyle: String, Codable, CaseIterable, Identifiable {
    case liquid, frosted, solid
    /// Used only to render README screenshots, where real blur isn't available.
    case snapshot
    var id: String { rawValue }
    static var userChoices: [GlassStyle] { [.frosted, .liquid, .solid] }
    var name: String {
        switch self {
        case .liquid: return L("Liquid Glass")
        case .frosted: return L("Frosted")
        case .solid: return L("Solid")
        case .snapshot: return "Snapshot"
        }
    }
}

enum LabelStyle: String, Codable, CaseIterable, Identifiable {
    case iconAndText, text, icon
    var id: String { rawValue }
    var name: String {
        switch self {
        case .iconAndText: return L("Icon and text")
        case .text: return L("Text only")
        case .icon: return L("Icon only")
        }
    }
}

enum RingScheme: String, Codable, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var name: String {
        switch self {
        case .system: return L("Match system")
        case .light: return L("Light")
        case .dark: return L("Dark")
        }
    }
}

enum SaveLocation: String, Codable, CaseIterable, Identifiable {
    case nextToOriginal, subfolder, folder
    var id: String { rawValue }
    var name: String {
        switch self {
        case .nextToOriginal: return L("Next to the original")
        case .subfolder: return L("In a subfolder")
        case .folder: return L("In a folder I choose")
        }
    }
}

enum ToastPosition: String, Codable, CaseIterable, Identifiable {
    case topRight, topCenter, bottomRight, bottomCenter
    var id: String { rawValue }
    var name: String {
        switch self {
        case .topRight: return L("Top right")
        case .topCenter: return L("Top center")
        case .bottomRight: return L("Bottom right")
        case .bottomCenter: return L("Bottom center")
        }
    }
}

final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    // General
    @Published var triggerKey: TriggerKey = Defaults.load("triggerKey", TriggerKey.shift) { didSet { Defaults.save("triggerKey", triggerKey) } }
    @Published var triggerMode: TriggerMode = Defaults.load("triggerMode", TriggerMode.tap) { didSet { Defaults.save("triggerMode", triggerMode) } }
    @Published var paused: Bool = Defaults.load("paused", false) { didSet { Defaults.save("paused", paused) } }
    @Published var showDockIcon: Bool = Defaults.load("showDockIcon", false) { didSet { Defaults.save("showDockIcon", showDockIcon) } }
    @Published var language: AppLanguage = Defaults.load("language", AppLanguage.system) { didSet { Defaults.save("language", language) } }
    /// Set once Kumquat has turned on "Open at login" for a new install, so it never overrides the user's choice again.
    @Published var didApplyLoginDefault: Bool = Defaults.load("didApplyLoginDefault", false) { didSet { Defaults.save("didApplyLoginDefault", didApplyLoginDefault) } }
    @Published var didOnboard: Bool = Defaults.load("didOnboard", false) { didSet { Defaults.save("didOnboard", didOnboard) } }

    // Appearance
    @Published var themeID: String = Defaults.load("themeID", "kumquat") { didSet { Defaults.save("themeID", themeID) } }
    @Published var customAccent: String = Defaults.load("customAccent", "#FF8A1F") { didSet { Defaults.save("customAccent", customAccent) } }
    @Published var customAccent2: String = Defaults.load("customAccent2", "#FF4D4D") { didSet { Defaults.save("customAccent2", customAccent2) } }
    @Published var glassStyle: GlassStyle = Defaults.load("glassStyle", GlassStyle.frosted) { didSet { Defaults.save("glassStyle", glassStyle) } }
    @Published var sliceOpacity: Double = Defaults.load("sliceOpacity", 0.72) { didSet { Defaults.save("sliceOpacity", sliceOpacity) } }
    @Published var ringSize: Double = Defaults.load("ringSize", 300.0) { didSet { Defaults.save("ringSize", ringSize) } }
    @Published var labelStyle: LabelStyle = Defaults.load("labelStyle", LabelStyle.iconAndText) { didSet { Defaults.save("labelStyle", labelStyle) } }
    @Published var ringScheme: RingScheme = Defaults.load("ringScheme", RingScheme.system) { didSet { Defaults.save("ringScheme", ringScheme) } }
    @Published var animations: Bool = Defaults.load("animations", true) { didSet { Defaults.save("animations", animations) } }
    @Published var haptics: Bool = Defaults.load("haptics", true) { didSet { Defaults.save("haptics", haptics) } }

    // Actions
    @Published var disabledActions: [String] = Defaults.load("disabledActions", SettingsStore.defaultDisabled) { didSet { Defaults.save("disabledActions", disabledActions) } }

    // Output
    @Published var saveLocation: SaveLocation = Defaults.load("saveLocation", SaveLocation.nextToOriginal) { didSet { Defaults.save("saveLocation", saveLocation) } }
    @Published var subfolderName: String = Defaults.load("subfolderName", "Kumquat") { didSet { Defaults.save("subfolderName", subfolderName) } }
    @Published var customFolder: String = Defaults.load("customFolder", "") { didSet { Defaults.save("customFolder", customFolder) } }
    @Published var revealInFinder: Bool = Defaults.load("revealInFinder", false) { didSet { Defaults.save("revealInFinder", revealInFinder) } }
    @Published var playSound: Bool = Defaults.load("playSound", true) { didSet { Defaults.save("playSound", playSound) } }
    @Published var trashOriginal: Bool = Defaults.load("trashOriginal", false) { didSet { Defaults.save("trashOriginal", trashOriginal) } }
    @Published var toastPosition: ToastPosition = Defaults.load("toastPosition", ToastPosition.topRight) { didSet { Defaults.save("toastPosition", toastPosition) } }
    @Published var toastSeconds: Double = Defaults.load("toastSeconds", 5.0) { didSet { Defaults.save("toastSeconds", toastSeconds) } }

    // Quality
    @Published var imageQuality: Double = Defaults.load("imageQuality", 0.9) { didSet { Defaults.save("imageQuality", imageQuality) } }
    @Published var compressQuality: Double = Defaults.load("compressQuality", 0.6) { didSet { Defaults.save("compressQuality", compressQuality) } }
    @Published var compressMaxDimension: Int = Defaults.load("compressMaxDimension", 0) { didSet { Defaults.save("compressMaxDimension", compressMaxDimension) } }
    @Published var keepMetadata: Bool = Defaults.load("keepMetadata", true) { didSet { Defaults.save("keepMetadata", keepMetadata) } }
    @Published var pdfDPI: Double = Defaults.load("pdfDPI", 200.0) { didSet { Defaults.save("pdfDPI", pdfDPI) } }
    @Published var combineImagesIntoPDF: Bool = Defaults.load("combineImagesIntoPDF", true) { didSet { Defaults.save("combineImagesIntoPDF", combineImagesIntoPDF) } }
    @Published var gifFPS: Int = Defaults.load("gifFPS", 12) { didSet { Defaults.save("gifFPS", gifFPS) } }
    @Published var gifMaxWidth: Int = Defaults.load("gifMaxWidth", 640) { didSet { Defaults.save("gifMaxWidth", gifMaxWidth) } }

    // Formats: frames per second (0 = every frame), PDF compression, LibreOffice for Word
    @Published var framesPerSecond: Double = Defaults.load("framesPerSecond", 0.0) { didSet { Defaults.save("framesPerSecond", framesPerSecond) } }
    @Published var pdfCompression: ConversionOptions.PDFCompression = Defaults.load("pdfCompression", ConversionOptions.PDFCompression.balanced) { didSet { Defaults.save("pdfCompression", pdfCompression) } }
    @Published var preferLibreOffice: Bool = Defaults.load("preferLibreOffice", true) { didSet { Defaults.save("preferLibreOffice", preferLibreOffice) } }
    @Published var gifMaxSeconds: Double = Defaults.load("gifMaxSeconds", 15.0) { didSet { Defaults.save("gifMaxSeconds", gifMaxSeconds) } }

    // Automation
    @Published var watchRules: [WatchRule] = Defaults.load("watchRules", [WatchRule]()) { didSet { Defaults.save("watchRules", watchRules) } }
    @Published var hotkeyEnabled: Bool = Defaults.load("hotkeyEnabled", true) { didSet { Defaults.save("hotkeyEnabled", hotkeyEnabled); Hotkey.shared.setEnabled(hotkeyEnabled) } }
    @Published var checkForUpdates: Bool = Defaults.load("checkForUpdates", true) { didSet { Defaults.save("checkForUpdates", checkForUpdates); UpdateChecker.shared.startAutomaticChecks() } }
    @Published var progressInRing: Bool = Defaults.load("progressInRing", true) { didSet { Defaults.save("progressInRing", progressInRing) } }
    @Published var recents: [String] = Defaults.load("recents", [String]()) { didSet { Defaults.save("recents", recents) } }
    /// Slice order chosen by the user (action ids); anything missing keeps the default order.
    @Published var actionOrder: [String] = Defaults.load("actionOrder", [String]()) { didSet { Defaults.save("actionOrder", actionOrder) } }

    // Editors
    @Published var lastBackground: KumquatCore.BackgroundStyle = Defaults.load("lastBackground", KumquatCore.BackgroundStyle()) { didSet { Defaults.save("lastBackground", lastBackground) } }

    /// Rarely used formats start hidden so the ring stays readable.
    static let defaultDisabled: [String] = [
        "convert.icns", "convert.psd", "convert.bmp", "convert.m4v", "convert.caf", "convert.odt",
        "convert.html", "convert.plist", "convert.avi", "convert.rtf",
        "tool.grayscale", "tool.flip", "tool.zip",
    ]

    var theme: Theme {
        let preset = ThemePreset.all.first { $0.id == themeID } ?? ThemePreset.all[0]
        let colors = preset.id == "custom" ? (customAccent, customAccent2) : (preset.accent, preset.accent2)
        return Theme(accent: SwiftUI.Color(hex: colors.0), accent2: SwiftUI.Color(hex: colors.1),
                     sliceOpacity: sliceOpacity, glass: glassStyle, size: ringSize, labels: labelStyle, scheme: ringScheme)
    }

    var conversionOptions: ConversionOptions {
        var o = ConversionOptions()
        o.imageQuality = imageQuality
        o.compressQuality = compressQuality
        o.compressMaxDimension = compressMaxDimension > 0 ? compressMaxDimension : nil
        o.keepMetadata = keepMetadata
        o.pdfDPI = pdfDPI
        o.combineImagesIntoPDF = combineImagesIntoPDF
        o.gifFPS = gifFPS
        o.gifMaxWidth = gifMaxWidth
        o.gifMaxSeconds = gifMaxSeconds
        o.framesPerSecond = framesPerSecond > 0 ? framesPerSecond : nil
        o.pdfCompression = pdfCompression
        o.preferLibreOffice = preferLibreOffice
        return o
    }

    var outputLocation: OutputLocation {
        switch saveLocation {
        case .nextToOriginal: return .nextToOriginal
        case .subfolder: return .subfolder(subfolderName.isEmpty ? "Kumquat" : subfolderName)
        case .folder:
            return customFolder.isEmpty ? .nextToOriginal : .folder(URL(fileURLWithPath: customFolder))
        }
    }

    func isEnabled(_ action: KQAction) -> Bool { !disabledActions.contains(action.id) }

    /// Puts actions in the user's order; unknown ones keep their place after the ordered ones.
    func ordered(_ actions: [KQAction]) -> [KQAction] {
        let rank = Dictionary(uniqueKeysWithValues: actionOrder.enumerated().map { ($1, $0) })
        return actions.enumerated().sorted { a, b in
            let ra = rank[a.element.id] ?? (10_000 + a.offset), rb = rank[b.element.id] ?? (10_000 + b.offset)
            return ra < rb
        }.map(\.element)
    }

    /// Moves one slice earlier (-1) or later (+1) among `group`.
    func move(_ action: KQAction, by delta: Int, in group: [KQAction]) {
        var list = ordered(group).map(\.id)
        guard let i = list.firstIndex(of: action.id) else { return }
        let j = min(max(i + delta, 0), list.count - 1)
        guard i != j else { return }
        list.swapAt(i, j)
        // Keep the other groups' order, replacing only this group's entries.
        actionOrder = actionOrder.filter { !list.contains($0) } + list
    }

    func addRecents(_ urls: [URL]) {
        recents = Array((urls.map(\.path) + recents.filter { p in !urls.contains { $0.path == p } }).prefix(12))
    }

    func setEnabled(_ action: KQAction, _ on: Bool) {
        var list = disabledActions.filter { $0 != action.id }
        if !on { list.append(action.id) }
        disabledActions = list
    }

    // MARK: Launch at login

    /// Turns "Open at login" on the first time Kumquat runs from an Applications folder.
    func applyLoginDefaultIfNeeded() {
        guard !didApplyLoginDefault else { return }
        let path = Bundle.main.bundlePath
        guard path.hasPrefix("/Applications/") || path.hasPrefix(NSHomeDirectory() + "/Applications/") else { return }
        didApplyLoginDefault = true
        if !launchAtLogin { launchAtLogin = true }
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("Kumquat: launch at login failed: \(error)")
            }
        }
    }

    /// Clears every preference and relaunches so all windows start fresh.
    func resetAll() {
        guard let id = Bundle.main.bundleIdentifier else { return }
        UserDefaults.standard.removePersistentDomain(forName: id)
        Defaults.save("didOnboard", true)
        UserDefaults.standard.synchronize()
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: config) { _, _ in
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }
}
