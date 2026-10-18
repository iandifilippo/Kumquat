import CoreGraphics
import Foundation

/// The "Add BG" look: a screenshot placed on a gradient with padding, round corners and a shadow.
public struct BackgroundStyle: Sendable, Equatable, Codable {
    public enum Fill: Sendable, Equatable, Codable {
        case gradient([String], angle: Double)
        case solid(String)
        case transparent
    }

    public enum Aspect: String, Sendable, Codable, CaseIterable {
        case auto, square, wide, classic, story

        public var ratio: Double? {
            switch self {
            case .auto: return nil
            case .square: return 1
            case .wide: return 16.0 / 9
            case .classic: return 4.0 / 3
            case .story: return 9.0 / 16
            }
        }

        public var label: String {
            switch self {
            case .auto: return "Auto"
            case .square: return "1:1"
            case .wide: return "16:9"
            case .classic: return "4:3"
            case .story: return "9:16"
            }
        }
    }

    public var fill: Fill
    /// Padding as a fraction of the image's shorter side.
    public var padding: Double
    /// Corner radius as a fraction of the image's shorter side.
    public var cornerRadius: Double
    /// Shadow blur as a fraction of the image's shorter side.
    public var shadow: Double
    public var aspect: Aspect

    public init(fill: Fill = .gradient(["#FFB347", "#FF5E62"], angle: 135), padding: Double = 0.12, cornerRadius: Double = 0.03, shadow: Double = 0.04, aspect: Aspect = .auto) {
        self.fill = fill
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.aspect = aspect
    }

    public static let gradientPresets: [[String]] = [
        ["#FFB347", "#FF5E62"], ["#F6D365", "#FDA085"], ["#A18CD1", "#FBC2EB"], ["#84FAB0", "#8FD3F4"],
        ["#4FACFE", "#00F2FE"], ["#43E97B", "#38F9D7"], ["#FA709A", "#FEE140"], ["#30CFD0", "#330867"],
        ["#0F2027", "#2C5364"], ["#FF9A9E", "#FAD0C4"],
    ]
    public static let solidPresets: [String] = [
        "#FFFFFF", "#F2F2F7", "#FFE8CC", "#FFD6E0", "#D6F5E3", "#D6E8FF", "#1C1C1E", "#000000",
    ]
}

public enum BackgroundRenderer {
    public static func render(_ image: CGImage, style: BackgroundStyle) -> CGImage {
        let w = Double(image.width), h = Double(image.height)
        let unit = min(w, h)
        let pad = unit * style.padding
        var canvasW = w + pad * 2, canvasH = h + pad * 2
        if let ratio = style.aspect.ratio {
            if canvasW / canvasH < ratio { canvasW = canvasH * ratio } else { canvasH = canvasW / ratio }
        }
        let cw = Int(canvasW.rounded()), ch = Int(canvasH.rounded())
        guard let ctx = Images.context(width: cw, height: ch) else { return image }
        let canvas = CGRect(x: 0, y: 0, width: cw, height: ch)

        switch style.fill {
        case .transparent: break
        case .solid(let hex):
            ctx.setFillColor(HexColor.cg(hex))
            ctx.fill(canvas)
        case .gradient(let hexes, let angle):
            let colors = hexes.map { HexColor.cg($0) } as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors, locations: nil) {
                let rad = angle * .pi / 180
                let cx = canvas.midX, cy = canvas.midY
                let len = max(canvas.width, canvas.height) / 2
                let dx = cos(rad) * len, dy = -sin(rad) * len
                ctx.drawLinearGradient(gradient, start: CGPoint(x: cx - dx, y: cy - dy), end: CGPoint(x: cx + dx, y: cy + dy), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
            }
        }

        let rect = CGRect(x: (canvasW - w) / 2, y: (canvasH - h) / 2, width: w, height: h)
        let radius = unit * style.cornerRadius
        let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

        if style.shadow > 0 {
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -unit * style.shadow * 0.35), blur: unit * style.shadow * 2, color: CGColor(gray: 0, alpha: 0.35))
            ctx.addPath(path)
            ctx.setFillColor(.white)
            ctx.fillPath()
            ctx.restoreGState()
        }
        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        ctx.draw(image, in: rect)
        ctx.restoreGState()
        return ctx.makeImage() ?? image
    }
}

/// Tiny hex color helper shared by the core and the app.
public enum HexColor {
    public static func components(_ hex: String) -> (r: Double, g: Double, b: Double, a: Double) {
        var s = hex.trimmingCharacters(in: .whitespaces).uppercased()
        if s.hasPrefix("#") { s.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        switch s.count {
        case 8: return (Double((v >> 24) & 0xFF) / 255, Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255)
        default: return (Double((v >> 16) & 0xFF) / 255, Double((v >> 8) & 0xFF) / 255, Double(v & 0xFF) / 255, 1)
        }
    }

    public static func cg(_ hex: String) -> CGColor {
        let c = components(hex)
        return CGColor(srgbRed: c.r, green: c.g, blue: c.b, alpha: c.a)
    }

    public static func hex(r: Double, g: Double, b: Double) -> String {
        String(format: "#%02X%02X%02X", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }
}
