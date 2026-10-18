// Draws the Kumquat app icon and writes Resources/AppIcon.icns plus docs/assets/icon.png.
// Usage: swift scripts/make-icon.swift
import AppKit

func color(_ hex: UInt32, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func drawIcon(size: CGFloat) -> NSImage {
    NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
        let s = size / 1024
        let ctx = NSGraphicsContext.current!.cgContext
        ctx.scaleBy(x: s, y: s)

        // Squircle background (Apple's 824pt grid inside 1024).
        let bg = NSBezierPath(roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: NSColor.black.withAlphaComponent(0.3).cgColor)
        color(0xFF8A1F).setFill()
        bg.fill()
        ctx.restoreGState()
        NSGradient(colors: [color(0xFFC15A), color(0xFF7A1A), color(0xF2482B)])!.draw(in: bg, angle: -90)

        let c = NSPoint(x: 512, y: 500)
        let outer: CGFloat = 318, inner: CGFloat = 196
        let count = 6
        let gap: CGFloat = 16

        // Glass ring shadow.
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor(red: 0.55, green: 0.12, blue: 0, alpha: 0.45).cgColor)
        NSColor.white.withAlphaComponent(0.01).setFill()
        NSBezierPath(ovalIn: NSRect(x: c.x - outer, y: c.y - outer, width: outer * 2, height: outer * 2)).fill()
        ctx.restoreGState()

        for i in 0..<count {
            let step = 360 / CGFloat(count)
            let mid = 90 - CGFloat(i) * step
            let a0 = mid - step / 2, a1 = mid + step / 2
            let go = gap / 2 / outer * 180 / .pi, gi = gap / 2 / inner * 180 / .pi
            let path = NSBezierPath()
            path.appendArc(withCenter: c, radius: outer, startAngle: a0 + go, endAngle: a1 - go)
            path.appendArc(withCenter: c, radius: inner, startAngle: a1 - gi, endAngle: a0 + gi, clockwise: true)
            path.close()
            path.lineJoinStyle = .round
            if i == 1 {
                ctx.saveGState()
                ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 18, color: NSColor(red: 0.6, green: 0.1, blue: 0, alpha: 0.5).cgColor)
                color(0xFF5A1F).setFill()
                path.fill()
                ctx.restoreGState()
                NSGradient(colors: [color(0xFF9F1C), color(0xE8361B)])!.draw(in: path, angle: -60)
            } else {
                NSGradient(colors: [NSColor.white.withAlphaComponent(0.95), NSColor.white.withAlphaComponent(0.72)])!.draw(in: path, angle: -90)
            }
        }

        // Hub.
        let hubR: CGFloat = 168
        let hub = NSBezierPath(ovalIn: NSRect(x: c.x - hubR, y: c.y - hubR, width: hubR * 2, height: hubR * 2))
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: NSColor.black.withAlphaComponent(0.18).cgColor)
        NSColor.white.setFill()
        hub.fill()
        ctx.restoreGState()

        // The kumquat.
        let fruit = NSBezierPath(ovalIn: NSRect(x: c.x - 92, y: c.y - 118, width: 184, height: 214))
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 10, color: NSColor(red: 0.7, green: 0.2, blue: 0, alpha: 0.35).cgColor)
        color(0xFF8A00).setFill()
        fruit.fill()
        ctx.restoreGState()
        NSGradient(colors: [color(0xFFC93C), color(0xFF8A00), color(0xF25C05)])!
            .draw(in: fruit, relativeCenterPosition: NSPoint(x: -0.35, y: 0.4))
        // Highlight.
        NSColor.white.withAlphaComponent(0.55).setFill()
        let shine = NSBezierPath(ovalIn: NSRect(x: c.x - 58, y: c.y + 20, width: 44, height: 62))
        var t = AffineTransform(translationByX: c.x - 36, byY: c.y + 51)
        t.rotate(byDegrees: 25)
        t.translate(x: -(c.x - 36), y: -(c.y + 51))
        shine.transform(using: t)
        shine.fill()
        // Pores.
        color(0xE86A00, 0.35).setFill()
        for (dx, dy) in [(40, 30), (55, -20), (10, -60), (-30, -40), (-55, 0), (20, 70), (60, 60)] as [(CGFloat, CGFloat)] {
            NSBezierPath(ovalIn: NSRect(x: c.x + dx - 4, y: c.y + dy - 4, width: 8, height: 8)).fill()
        }
        // Stem and leaf.
        color(0x6B4A2B).setStroke()
        let stem = NSBezierPath()
        stem.move(to: NSPoint(x: c.x + 2, y: c.y + 92))
        stem.curve(to: NSPoint(x: c.x + 10, y: c.y + 128), controlPoint1: NSPoint(x: c.x + 2, y: c.y + 108), controlPoint2: NSPoint(x: c.x + 6, y: c.y + 120))
        stem.lineWidth = 9
        stem.lineCapStyle = .round
        stem.stroke()
        let leaf = NSBezierPath()
        leaf.move(to: NSPoint(x: c.x + 8, y: c.y + 118))
        leaf.curve(to: NSPoint(x: c.x + 120, y: c.y + 150), controlPoint1: NSPoint(x: c.x + 40, y: c.y + 175), controlPoint2: NSPoint(x: c.x + 95, y: c.y + 180))
        leaf.curve(to: NSPoint(x: c.x + 8, y: c.y + 118), controlPoint1: NSPoint(x: c.x + 90, y: c.y + 112), controlPoint2: NSPoint(x: c.x + 40, y: c.y + 100))
        NSGradient(colors: [color(0x5BD15B), color(0x1E9E4A)])!.draw(in: leaf, angle: -30)
        color(0x17803A, 0.6).setStroke()
        let vein = NSBezierPath()
        vein.move(to: NSPoint(x: c.x + 14, y: c.y + 120))
        vein.curve(to: NSPoint(x: c.x + 112, y: c.y + 148), controlPoint1: NSPoint(x: c.x + 50, y: c.y + 138), controlPoint2: NSPoint(x: c.x + 85, y: c.y + 146))
        vein.lineWidth = 4
        vein.stroke()
        return true
    }
}

func png(_ image: NSImage, _ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
let art = drawIcon(size: 1024)
for base in [16, 32, 128, 256, 512] {
    try! png(art, base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! png(art, base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! FileManager.default.createDirectory(at: root.appendingPathComponent("Resources"), withIntermediateDirectories: true)
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! p.run()
p.waitUntilExit()
try! png(art, 512).write(to: root.appendingPathComponent("docs/assets/icon.png"))
print("Wrote Resources/AppIcon.icns and docs/assets/icon.png")
