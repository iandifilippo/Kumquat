import CoreGraphics
import Foundation

/// The math behind the crop editor, kept apart from the UI so it can be tested.
/// Crop rectangles are normalized (0...1) with a top-left origin; points are in view space.
public struct CropGeometry: Sendable {
    public enum Grab: Equatable, Sendable {
        case move
        case corner(Int)   // 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right
        case edge(Int)     // 0 top, 1 right, 2 bottom, 3 left
        case draw
    }

    public var pixelSize: CGSize
    /// Width ÷ height in pixels, or `nil` for a free crop.
    public var ratio: Double?
    public var minSide: CGFloat = 0.03

    public init(pixelSize: CGSize, ratio: Double? = nil) {
        self.pixelSize = pixelSize
        self.ratio = ratio
    }

    public static let full = CGRect(x: 0, y: 0, width: 1, height: 1)

    /// The image's on-screen rectangle when fitted into `size`.
    public func fit(in size: CGSize) -> CGRect {
        guard pixelSize.width > 0, pixelSize.height > 0, size.width > 0 else { return .zero }
        let s = min(size.width / pixelSize.width, size.height / pixelSize.height)
        let w = pixelSize.width * s, h = pixelSize.height * s
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    public func viewRect(_ crop: CGRect, in frame: CGRect) -> CGRect {
        CGRect(x: frame.minX + crop.minX * frame.width, y: frame.minY + crop.minY * frame.height,
               width: crop.width * frame.width, height: crop.height * frame.height)
    }

    public func pixelRect(_ crop: CGRect) -> CGRect {
        CGRect(x: (crop.minX * pixelSize.width).rounded(), y: (crop.minY * pixelSize.height).rounded(),
               width: (crop.width * pixelSize.width).rounded(), height: (crop.height * pixelSize.height).rounded())
    }

    public static func corner(_ i: Int, of r: CGRect) -> CGPoint {
        CGPoint(x: i % 2 == 0 ? r.minX : r.maxX, y: i < 2 ? r.minY : r.maxY)
    }

    public static func edgeMid(_ i: Int, of r: CGRect) -> CGPoint {
        switch i {
        case 0: return CGPoint(x: r.midX, y: r.minY)
        case 1: return CGPoint(x: r.maxX, y: r.midY)
        case 2: return CGPoint(x: r.midX, y: r.maxY)
        default: return CGPoint(x: r.minX, y: r.midY)
        }
    }

    /// What the pointer at `p` would grab, given the crop's on-screen rectangle `r`.
    public func grab(at p: CGPoint, viewRect r: CGRect, reach: CGFloat = 14) -> Grab {
        for i in 0..<4 {
            let c = Self.corner(i, of: r)
            if hypot(p.x - c.x, p.y - c.y) < reach { return .corner(i) }
        }
        if ratio == nil {
            if abs(p.y - r.minY) < reach, p.x > r.minX, p.x < r.maxX { return .edge(0) }
            if abs(p.x - r.maxX) < reach, p.y > r.minY, p.y < r.maxY { return .edge(1) }
            if abs(p.y - r.maxY) < reach, p.x > r.minX, p.x < r.maxX { return .edge(2) }
            if abs(p.x - r.minX) < reach, p.y > r.minY, p.y < r.maxY { return .edge(3) }
        }
        return r.contains(p) ? .move : .draw
    }

    /// The new crop after dragging from `from` to `to`, starting from `start`.
    public func update(_ grab: Grab, start: CGRect, from: CGPoint, to: CGPoint, frame: CGRect) -> CGRect {
        let p = normalize(to, frame)
        switch grab {
        case .move:
            let dx = (to.x - from.x) / max(frame.width, 1), dy = (to.y - from.y) / max(frame.height, 1)
            var r = start
            r.origin.x = min(max(0, start.minX + dx), 1 - start.width)
            r.origin.y = min(max(0, start.minY + dy), 1 - start.height)
            return r
        case .corner(let i):
            // The opposite corner stays put.
            let anchor = CGPoint(x: i % 2 == 0 ? start.maxX : start.minX, y: i < 2 ? start.maxY : start.minY)
            return rect(from: anchor, to: p)
        case .draw:
            return rect(from: normalize(from, frame), to: p)
        case .edge(let i):
            var r = start
            switch i {
            case 0:
                let y = min(p.y, r.maxY - minSide)
                r = CGRect(x: r.minX, y: y, width: r.width, height: r.maxY - y)
            case 1: r.size.width = max(p.x - r.minX, minSide)
            case 2: r.size.height = max(p.y - r.minY, minSide)
            default:
                let x = min(p.x, r.maxX - minSide)
                r = CGRect(x: x, y: r.minY, width: r.maxX - x, height: r.height)
            }
            return r
        }
    }

    /// Largest centered crop with the current ratio (or the whole image).
    public func centered() -> CGRect {
        guard let ratio, pixelSize.height > 0 else { return Self.full }
        let imageRatio = pixelSize.width / pixelSize.height
        var w = 1.0, h = 1.0
        if ratio > imageRatio { h = imageRatio / ratio } else { w = ratio / imageRatio }
        return CGRect(x: (1 - w) / 2, y: (1 - h) / 2, width: w, height: h)
    }

    func normalize(_ p: CGPoint, _ frame: CGRect) -> CGPoint {
        CGPoint(x: min(max((p.x - frame.minX) / max(frame.width, 1), 0), 1),
                y: min(max((p.y - frame.minY) / max(frame.height, 1), 0), 1))
    }

    /// Rectangle between an anchor and a point, honoring the ratio and the image bounds.
    func rect(from a: CGPoint, to p: CGPoint) -> CGRect {
        var w = max(abs(p.x - a.x), minSide), h = max(abs(p.y - a.y), minSide)
        let sx: CGFloat = p.x >= a.x ? 1 : -1, sy: CGFloat = p.y >= a.y ? 1 : -1
        if let ratio {
            let maxW = sx > 0 ? 1 - a.x : a.x, maxH = sy > 0 ? 1 - a.y : a.y
            // Work in pixels so the ratio is the real one.
            var pw = w * pixelSize.width, ph = h * pixelSize.height
            if pw / ph > ratio { ph = pw / ratio } else { pw = ph * ratio }
            if pw > maxW * pixelSize.width { pw = maxW * pixelSize.width; ph = pw / ratio }
            if ph > maxH * pixelSize.height { ph = maxH * pixelSize.height; pw = ph * ratio }
            w = pw / pixelSize.width
            h = ph / pixelSize.height
        }
        let x = max(0, sx > 0 ? a.x : a.x - w), y = max(0, sy > 0 ? a.y : a.y - h)
        return CGRect(x: x, y: y, width: min(w, 1 - x), height: min(h, 1 - y))
    }
}
