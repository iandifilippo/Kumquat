import AppKit
import ImageIO
import PDFKit
import XCTest
@testable import KumquatCore

final class CropGeometryTests: XCTestCase {
    let math = CropGeometry(pixelSize: CGSize(width: 400, height: 200))
    let frame = CGRect(x: 0, y: 0, width: 400, height: 200)

    func testGrabDetection() {
        let r = CGRect(x: 100, y: 50, width: 200, height: 100)
        XCTAssertEqual(math.grab(at: CGPoint(x: 101, y: 51), viewRect: r), .corner(0))
        XCTAssertEqual(math.grab(at: CGPoint(x: 299, y: 149), viewRect: r), .corner(3))
        XCTAssertEqual(math.grab(at: CGPoint(x: 200, y: 52), viewRect: r), .edge(0))
        XCTAssertEqual(math.grab(at: CGPoint(x: 298, y: 100), viewRect: r), .edge(1))
        XCTAssertEqual(math.grab(at: CGPoint(x: 200, y: 100), viewRect: r), .move)
        XCTAssertEqual(math.grab(at: CGPoint(x: 20, y: 20), viewRect: r), .draw)
    }

    func testFreeCornerDrag() {
        // Drag the bottom-right corner from (400,200) to (200,100): half the image remains.
        let r = math.update(.corner(3), start: CropGeometry.full, from: CGPoint(x: 400, y: 200), to: CGPoint(x: 200, y: 100), frame: frame)
        XCTAssertEqual(math.pixelRect(r), CGRect(x: 0, y: 0, width: 200, height: 100))
    }

    func testEdgeDrag() {
        let r = math.update(.edge(3), start: CropGeometry.full, from: CGPoint(x: 0, y: 100), to: CGPoint(x: 100, y: 100), frame: frame)
        XCTAssertEqual(math.pixelRect(r), CGRect(x: 100, y: 0, width: 300, height: 200))
    }

    func testMoveStaysInside() {
        let start = CGRect(x: 0, y: 0, width: 0.5, height: 0.5)
        let r = math.update(.move, start: start, from: .zero, to: CGPoint(x: 1000, y: 1000), frame: frame)
        XCTAssertEqual(r.maxX, 1, accuracy: 0.0001)
        XCTAssertEqual(r.maxY, 1, accuracy: 0.0001)
    }

    func testDrawNewArea() {
        let r = math.update(.draw, start: CropGeometry.full, from: CGPoint(x: 40, y: 20), to: CGPoint(x: 140, y: 120), frame: frame)
        XCTAssertEqual(math.pixelRect(r), CGRect(x: 40, y: 20, width: 100, height: 100))
    }

    func testRatioIsKept() {
        var square = math
        square.ratio = 1
        let centered = square.centered()
        let px = square.pixelRect(centered)
        XCTAssertEqual(px.width, px.height)
        XCTAssertEqual(px, CGRect(x: 100, y: 0, width: 200, height: 200))

        let dragged = square.update(.corner(3), start: centered, from: CGPoint(x: 300, y: 200), to: CGPoint(x: 220, y: 150), frame: frame)
        let d = square.pixelRect(dragged)
        XCTAssertEqual(d.width, d.height, accuracy: 1)
        XCTAssertEqual(d.minX, 100, accuracy: 1)
    }
}

final class MoreEngineTests: XCTestCase {
    var dir: URL!
    let engine = Engine()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("KumquatMore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    /// 200×100: left half red, right half blue.
    func twoColorImage(_ name: String = "Two.png") throws -> URL {
        let ctx = CGContext(data: nil, width: 200, height: 100, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        ctx.setFillColor(CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 100, y: 0, width: 100, height: 100))
        let url = dir.appendingPathComponent(name)
        try Images.write(ctx.makeImage()!, to: url, format: .png, quality: 1)
        return url
    }

    func centerColor(_ url: URL) throws -> (r: UInt8, b: UInt8) {
        let (img, _) = try Images.load(url)
        let ctx = CGContext(data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        let p = ctx.data!.bindMemory(to: UInt8.self, capacity: 4)
        return (p[0], p[2])
    }

    func testCropKeepsTheRightPixels() async throws {
        let src = try twoColorImage()
        let right = try await engine.run(.tool(.crop), on: [src], parameters: .crop(CGRect(x: 120, y: 10, width: 60, height: 60))).outputs[0]
        let c = try centerColor(right)
        XCTAssertGreaterThan(c.b, 200, "cropping the right side should keep blue")
        XCTAssertLessThan(c.r, 50)
        let left = try await engine.run(.tool(.crop), on: [src], parameters: .crop(CGRect(x: 10, y: 10, width: 60, height: 60))).outputs[0]
        XCTAssertGreaterThan(try centerColor(left).r, 200, "cropping the left side should keep red")
    }

    func testStripMetadataRemovesGPS() async throws {
        let png = try twoColorImage()
        let (img, _) = try Images.load(png)
        let jpg = dir.appendingPathComponent("Geo.jpg")
        let gps: [CFString: Any] = [kCGImagePropertyGPSDictionary: [kCGImagePropertyGPSLatitude: 40.4, kCGImagePropertyGPSLatitudeRef: "N",
                                                                    kCGImagePropertyGPSLongitude: 3.7, kCGImagePropertyGPSLongitudeRef: "W"]]
        try Images.write(img, to: jpg, format: .jpg, quality: 0.9, properties: gps)
        func hasGPS(_ url: URL) -> Bool {
            let props = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithURL(url as CFURL, nil)!, 0, nil) as? [CFString: Any]
            return props?[kCGImagePropertyGPSDictionary] != nil
        }
        XCTAssertTrue(hasGPS(jpg), "fixture should carry GPS")
        let clean = try await engine.run(.tool(.stripMetadata), on: [jpg]).outputs[0]
        XCTAssertFalse(hasGPS(clean))
    }

    func testCompressThatDoesNotShrinkSavesNothing() async throws {
        let png = try twoColorImage()
        let (img, _) = try Images.load(png)
        let tiny = dir.appendingPathComponent("Tiny.jpg")
        try Images.write(img, to: tiny, format: .jpg, quality: 0.05)
        do {
            _ = try await engine.run(.tool(.compress), on: [tiny])
            XCTFail("expected notSmaller")
        } catch KumquatError.notSmaller {}
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.contains("Compressed") }
        XCTAssertTrue(leftovers.isEmpty)
    }

    func testBlankImageHasNoText() async throws {
        let ctx = CGContext(data: nil, width: 300, height: 200, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(.white)
        ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 200))
        let blank = dir.appendingPathComponent("Blank.png")
        try Images.write(ctx.makeImage()!, to: blank, format: .png, quality: 1)
        do {
            _ = try await engine.run(.tool(.extractText), on: [blank])
            XCTFail("expected noText")
        } catch KumquatError.noText {}
    }

    func testTransparentBackgroundKeepsAlpha() async throws {
        let src = try twoColorImage()
        let style = BackgroundStyle(fill: .transparent, padding: 0.2)
        let out = try await engine.run(.tool(.addBackground), on: [src], parameters: .background(style)).outputs[0]
        XCTAssertTrue(Images.hasAlpha(try Images.load(out).image))
    }

    func testDocumentInputs() async throws {
        let text = NSAttributedString(string: "Kumquat document test", attributes: [.font: NSFont.systemFont(ofSize: 12)])
        for format in [OutputFormat.rtf, .html, .docx, .txt] {
            let src = dir.appendingPathComponent("Source.\(format.fileExtension)")
            try await MainActor.run { try Documents.write(text, to: src, format: format) }
            let pdf = try await engine.run(.convert(.pdf), on: [src]).outputs[0]
            XCTAssertTrue(PDFDocument(url: pdf)?.string?.contains("Kumquat") ?? false, "\(format) → PDF")
        }
    }

    func testMixedImageAndPDFBecomeOnePDF() async throws {
        let img = try twoColorImage()
        let pdfURL = dir.appendingPathComponent("One.pdf")
        try Images.writePDF([try Images.load(img).image], to: pdfURL)
        let out = try await engine.run(.convert(.pdf), on: [img, pdfURL]).outputs
        XCTAssertEqual(out.count, 1)
        XCTAssertEqual(PDFDocument(url: out[0])?.pageCount, 2)
    }

    func testSeveralFilesResizeTogether() async throws {
        let a = try twoColorImage("A.png"), b = try twoColorImage("B.png")
        let out = try await engine.run(.tool(.resize), on: [a, b], parameters: .scale(0.5)).outputs
        XCTAssertEqual(out.count, 2)
        for url in out { XCTAssertEqual(try Images.load(url).image.width, 100) }
    }
}
