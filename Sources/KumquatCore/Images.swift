import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import ImageIO
import PDFKit
import UniformTypeIdentifiers

/// Image reading, writing and editing built on ImageIO and Core Image.
public enum Images {
    /// Decodes the first frame upright (EXIF orientation applied) with its metadata.
    public static func load(_ url: URL) throws -> (image: CGImage, properties: [CFString: Any]) {
        if url.pathExtension.lowercased() == "svg" { return (try loadSVG(url), [:]) }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetCount(source) > 0 else { throw KumquatError.unreadable(url) }
        var props = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        let w = props[kCGImagePropertyPixelWidth] as? Int ?? 0
        let h = props[kCGImagePropertyPixelHeight] as? Int ?? 0
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(w, h, 1),
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw KumquatError.unreadable(url)
        }
        // The pixels are now upright, so the orientation tag must be reset.
        props[kCGImagePropertyOrientation] = 1
        if var tiff = props[kCGImagePropertyTIFFDictionary] as? [CFString: Any] {
            tiff[kCGImagePropertyTIFFOrientation] = 1
            props[kCGImagePropertyTIFFDictionary] = tiff
        }
        return (image, props)
    }

    /// Vector SVGs are drawn at 2× their size (at least 1024 px on the long side).
    static func loadSVG(_ url: URL) throws -> CGImage {
        guard let svg = NSImage(contentsOf: url), svg.size.width > 0, svg.size.height > 0 else { throw KumquatError.unreadable(url) }
        let scale = max(2, 1024 / max(svg.size.width, svg.size.height))
        let w = Int(svg.size.width * scale), h = Int(svg.size.height * scale)
        guard let ctx = context(width: w, height: h) else { throw KumquatError.unreadable(url) }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        svg.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
        NSGraphicsContext.restoreGraphicsState()
        guard let image = ctx.makeImage() else { throw KumquatError.unreadable(url) }
        return image
    }

    /// A small preview for editor windows.
    public static func thumbnail(_ url: URL, maxPixel: Int) -> CGImage? {
        if url.pathExtension.lowercased() == "svg" { return (try? loadSVG(url)).map { fit($0, maxSide: maxPixel) } }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    public static func write(_ image: CGImage, to url: URL, format: OutputFormat, quality: Double, properties: [CFString: Any]? = nil) throws {
        if format == .pdf {
            try writePDF([image], to: url)
            return
        }
        var image = image
        if format.needsOpaqueImage { image = flatten(image) }
        if format == .ico { image = squareCanvas(fit(image, maxSide: 256), side: min(256, max(image.width, image.height))) }
        if format == .icns {
            try writeICNS(image, to: url)
            return
        }
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, format.utType.identifier as CFString, 1, nil) else {
            throw KumquatError.unsupported(format.label)
        }
        var props = properties ?? [:]
        props[kCGImageDestinationLossyCompressionQuality] = quality
        CGImageDestinationAddImage(dest, image, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw KumquatError.writeFailed(url) }
    }

    /// A full macOS icon: every size from 16 to 1024 pixels in one file.
    static func writeICNS(_ image: CGImage, to url: URL) throws {
        let master = squareCanvas(fit(image, maxSide: 1024), side: 1024)
        let sizes = [16, 32, 64, 128, 256, 512, 1024]
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, OutputFormat.icns.utType.identifier as CFString, sizes.count, nil) else {
            throw KumquatError.unsupported("ICNS")
        }
        for side in sizes { CGImageDestinationAddImage(dest, resized(master, width: side, height: side), nil) }
        guard CGImageDestinationFinalize(dest) else { throw KumquatError.writeFailed(url) }
    }

    public static func writePDF(_ images: [CGImage], to url: URL) throws {
        let doc = PDFDocument()
        for (i, img) in images.enumerated() {
            let ns = NSImage(cgImage: img, size: NSSize(width: img.width, height: img.height))
            if let page = PDFPage(image: ns) { doc.insert(page, at: i) }
        }
        guard doc.write(to: url) else { throw KumquatError.writeFailed(url) }
    }

    // MARK: - Pixel helpers

    static func context(width: Int, height: Int, opaque: Bool = false) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }

    public static func flatten(_ image: CGImage, color: CGColor = .white) -> CGImage {
        guard let ctx = context(width: image.width, height: image.height, opaque: true) else { return image }
        ctx.setFillColor(color)
        ctx.fill(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    public static func resized(_ image: CGImage, width: Int, height: Int) -> CGImage {
        guard width > 0, height > 0, let ctx = context(width: width, height: height) else { return image }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage() ?? image
    }

    public static func fit(_ image: CGImage, maxSide: Int) -> CGImage {
        let longest = max(image.width, image.height)
        guard longest > maxSide else { return image }
        let scale = Double(maxSide) / Double(longest)
        return resized(image, width: max(1, Int(Double(image.width) * scale)), height: max(1, Int(Double(image.height) * scale)))
    }

    static func squareCanvas(_ image: CGImage, side: Int) -> CGImage {
        guard let ctx = context(width: side, height: side) else { return image }
        let x = (side - image.width) / 2, y = (side - image.height) / 2
        ctx.draw(image, in: CGRect(x: x, y: y, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    public static func cropped(_ image: CGImage, to rect: CGRect) -> CGImage {
        // `rect` uses a top-left origin like the editor; CGImage.cropping also uses top-left.
        let bounds = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        let r = rect.integral.intersection(bounds)
        return image.cropping(to: r) ?? image
    }

    public static func rotatedClockwise(_ image: CGImage) -> CGImage {
        guard let ctx = context(width: image.height, height: image.width) else { return image }
        ctx.translateBy(x: 0, y: CGFloat(image.width))
        ctx.rotate(by: -.pi / 2)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    public static func flippedHorizontally(_ image: CGImage) -> CGImage {
        guard let ctx = context(width: image.width, height: image.height) else { return image }
        ctx.translateBy(x: CGFloat(image.width), y: 0)
        ctx.scaleBy(x: -1, y: 1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage() ?? image
    }

    static let ciContext = CIContext(options: [.workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!])

    public static func grayscale(_ image: CGImage) -> CGImage {
        let filter = CIFilter.photoEffectMono()
        filter.inputImage = CIImage(cgImage: image)
        guard let out = filter.outputImage,
              let result = ciContext.createCGImage(out, from: out.extent) else { return image }
        return result
    }

    // MARK: - Plain backgrounds

    /// RGBA bytes of an image in sRGB, premultiplied.
    static func pixels(_ image: CGImage) -> (ctx: CGContext, bytes: UnsafeMutablePointer<UInt8>)? {
        guard let ctx = context(width: image.width, height: image.height), let data = ctx.data else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return (ctx, data.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * image.height))
    }

    /// The border's color when it is nearly uniform (paper behind a signature, a logo's backdrop).
    public static func plainBackground(_ image: CGImage) -> (r: Double, g: Double, b: Double)? {
        let small = fit(image, maxSide: 256)
        guard let (ctx, p) = pixels(small) else { return nil }
        let w = small.width, h = small.height, row = ctx.bytesPerRow
        var samples: [(Double, Double, Double)] = []
        for x in stride(from: 0, to: w, by: 2) { for y in [0, 1, h - 2, h - 1] where y >= 0 { samples.append(rgb(p, x, y, row)) } }
        for y in stride(from: 0, to: h, by: 2) { for x in [0, 1, w - 2, w - 1] where x >= 0 { samples.append(rgb(p, x, y, row)) } }
        guard !samples.isEmpty else { return nil }
        let n = Double(samples.count)
        let mean = (samples.map(\.0).reduce(0, +) / n, samples.map(\.1).reduce(0, +) / n, samples.map(\.2).reduce(0, +) / n)
        // Most border pixels must sit close to the mean color.
        let close = samples.filter { abs($0.0 - mean.0) + abs($0.1 - mean.1) + abs($0.2 - mean.2) < 0.12 }.count
        return Double(close) / n > 0.9 ? mean : nil
    }

    private static func rgb(_ p: UnsafeMutablePointer<UInt8>, _ x: Int, _ y: Int, _ row: Int) -> (Double, Double, Double) {
        let i = y * row + x * 4
        return (Double(p[i]) / 255, Double(p[i + 1]) / 255, Double(p[i + 2]) / 255)
    }

    /// "Color to alpha": pixels close to the backdrop fade out, and edge pixels are un-mixed
    /// from it so strokes keep smooth edges without a light fringe.
    public static func removePlainBackground(_ image: CGImage, color bg: (r: Double, g: Double, b: Double), tolerance: Double = 0.10) -> CGImage {
        guard let (ctx, p) = pixels(image) else { return image }
        let w = image.width, h = image.height, row = ctx.bytesPerRow
        let soft = tolerance * 3 // distance at which a pixel is fully opaque
        for y in 0..<h {
            for x in 0..<w {
                let i = y * row + x * 4
                let a0 = Double(p[i + 3]) / 255
                guard a0 > 0 else { continue }
                let r = Double(p[i]) / 255 / a0, g = Double(p[i + 1]) / 255 / a0, b = Double(p[i + 2]) / 255 / a0
                let d = max(abs(r - bg.r), abs(g - bg.g), abs(b - bg.b))
                var alpha = d <= tolerance ? 0 : min(1, (d - tolerance) / (soft - tolerance))
                alpha *= a0
                guard alpha < 1 else { continue }
                if alpha <= 0 {
                    p[i] = 0; p[i + 1] = 0; p[i + 2] = 0; p[i + 3] = 0
                    continue
                }
                // Un-mix: color = (observed - (1 - a) * background) / a, then premultiply again.
                func unmix(_ c: Double, _ k: Double) -> UInt8 { UInt8(max(0, min(1, (c - (1 - alpha) * k) / alpha)) * alpha * 255) }
                p[i] = unmix(r, bg.r); p[i + 1] = unmix(g, bg.g); p[i + 2] = unmix(b, bg.b)
                p[i + 3] = UInt8(alpha * 255)
            }
        }
        return ctx.makeImage() ?? image
    }

    /// Stacks images vertically into one tall picture (used for "PDF → one image").
    public static func stacked(_ images: [CGImage], maxHeight: Int = 32000) -> CGImage? {
        guard let width = images.map(\.width).max() else { return nil }
        var height = images.reduce(0) { $0 + $1.height }
        var parts = images
        if height > maxHeight {
            let scale = Double(maxHeight) / Double(height)
            parts = images.map { resized($0, width: max(1, Int(Double($0.width) * scale)), height: max(1, Int(Double($0.height) * scale))) }
            height = parts.reduce(0) { $0 + $1.height }
        }
        let canvasWidth = parts.map(\.width).max() ?? width
        guard let ctx = context(width: canvasWidth, height: height, opaque: true) else { return nil }
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: height))
        var y = height
        for img in parts {
            y -= img.height
            ctx.draw(img, in: CGRect(x: (canvasWidth - img.width) / 2, y: y, width: img.width, height: img.height))
        }
        return ctx.makeImage()
    }

    /// True only when some pixel is actually see-through (checked on a small copy).
    public static func hasAlpha(_ image: CGImage) -> Bool {
        switch image.alphaInfo {
        case .none, .noneSkipFirst, .noneSkipLast: return false
        default: break
        }
        let side = 64
        guard let ctx = context(width: side, height: side), let data = ctx.data else { return true }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let bytes = data.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * side)
        for y in 0..<side {
            for x in 0..<side where bytes[y * ctx.bytesPerRow + x * 4 + 3] < 250 { return true }
        }
        return false
    }
}
