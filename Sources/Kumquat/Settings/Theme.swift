import KumquatCore
import SwiftUI

struct ThemePreset: Identifiable, Hashable {
    let id: String
    let name: String
    let accent: String
    let accent2: String

    static let all: [ThemePreset] = [
        ThemePreset(id: "kumquat", name: "Kumquat", accent: "#FFA62B", accent2: "#FF5E1A"),
        ThemePreset(id: "sunset", name: "Sunset", accent: "#FF7E5F", accent2: "#E8467C"),
        ThemePreset(id: "lemon", name: "Lemon", accent: "#FFD23F", accent2: "#F59E0B"),
        ThemePreset(id: "mint", name: "Mint", accent: "#4ADE80", accent2: "#0EA5A4"),
        ThemePreset(id: "ocean", name: "Ocean", accent: "#38BDF8", accent2: "#4F46E5"),
        ThemePreset(id: "grape", name: "Grape", accent: "#C084FC", accent2: "#7C3AED"),
        ThemePreset(id: "rose", name: "Rosé", accent: "#FB7185", accent2: "#DB2777"),
        ThemePreset(id: "graphite", name: "Graphite", accent: "#9CA3AF", accent2: "#374151"),
        ThemePreset(id: "custom", name: "Custom", accent: "#FF8A1F", accent2: "#FF4D4D"),
    ]

    var localizedName: String { L(name) }
}

/// Everything the ring needs to draw itself.
struct Theme {
    var accent: SwiftUI.Color
    var accent2: SwiftUI.Color
    var sliceOpacity: Double
    var glass: GlassStyle
    var size: Double
    var labels: LabelStyle
    var scheme: RingScheme
    /// False in the live ring, where the window draws the frosted blur itself (with a true round mask).
    var drawsBackdrop = true

    var gradient: LinearGradient {
        LinearGradient(colors: [accent, accent2], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var colorScheme: ColorScheme? {
        switch scheme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension SwiftUI.Color {
    init(hex: String) {
        let c = HexColor.components(hex)
        self.init(.sRGB, red: c.r, green: c.g, blue: c.b, opacity: c.a)
    }

    var hex: String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .orange
        return HexColor.hex(r: ns.redComponent, g: ns.greenComponent, b: ns.blueComponent)
    }
}
