import AppKit
import PDFKit
import XCTest
@testable import KumquatCore

/// Runs only on Macs that have FFmpeg / Ghostscript installed (skipped otherwise).
final class EngineIntegrationTests: XCTestCase {
    var dir: URL!
    let engine = Engine()

    override func setUpWithError() throws {
        Engines.refresh()
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("KumquatEngines-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func testFFmpegFormats() async throws {
        try XCTSkipIf(Engines.current.ffmpeg == nil, "FFmpeg isn't installed")
        let helper = EngineTests()
        let mov = try await helper.makeMovie(in: dir)

        let webm = try await engine.run(.convert(.webm), on: [mov]).outputs[0]
        XCTAssertGreaterThan(webm.fileSize, 0)
        // A format macOS can't play, back to MP4 and a GIF, plus frames and compress.
        let mp4 = try await engine.run(.convert(.mp4), on: [webm]).outputs[0]
        XCTAssertGreaterThan(mp4.fileSize, 0)
        let gif = try await engine.run(.convert(.gif), on: [webm]).outputs[0]
        XCTAssertGreaterThan(CGImageSourceGetCount(CGImageSourceCreateWithURL(gif as CFURL, nil)!), 3)
        var e = engine
        e.options.framesPerSecond = 5
        let frames = try await e.run(.tool(.frames), on: [webm]).outputs[0]
        XCTAssertGreaterThanOrEqual(try FileManager.default.contentsOfDirectory(atPath: frames.path).count, 4)

        let png = dir.appendingPathComponent("P.png")
        let ctx = CGContext(data: nil, width: 64, height: 64, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(.black); ctx.fill(CGRect(x: 8, y: 8, width: 48, height: 48))
        try Images.write(ctx.makeImage()!, to: png, format: .png, quality: 1)
        try XCTSkipUnless(Engines.current.canWriteWebP, "No WebP encoder")
        let webp = try await engine.run(.convert(.webp), on: [png]).outputs[0]
        XCTAssertEqual(try Images.load(webp).image.width, 64)
    }

    func testFFmpegAudio() async throws {
        try XCTSkipIf(Engines.current.ffmpeg == nil, "FFmpeg isn't installed")
        let wav = try EngineTests.makeWAV(in: dir)
        for format in [OutputFormat.mp3, .ogg, .opus] {
            let out = try await engine.run(.convert(format), on: [wav]).outputs[0]
            XCTAssertGreaterThan(out.fileSize, 0, "\(format)")
            // And back to something macOS plays.
            let back = try await engine.run(.convert(.m4a), on: [out]).outputs[0]
            XCTAssertGreaterThan(back.fileSize, 0, "\(format) → m4a")
            try FileManager.default.removeItem(at: back)
        }
    }

    func testGhostscriptCompression() async throws {
        try XCTSkipIf(Engines.current.ghostscript == nil, "Ghostscript isn't installed")
        let w = 1600, h = 2000
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let p = ctx.data!.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * h)
        // A smooth photo-like gradient, stored losslessly: Ghostscript's JPEG pass shrinks it.
        for y in 0..<h { for x in 0..<w {
            let i = y * ctx.bytesPerRow + x * 4
            p[i] = UInt8(x * 255 / w); p[i + 1] = UInt8(y * 255 / h); p[i + 2] = UInt8((x + y) % 256); p[i + 3] = 255
        } }
        let scan = dir.appendingPathComponent("Scan.pdf")
        try Images.writePDF([ctx.makeImage()!], to: scan)
        let out = try await engine.run(.tool(.compressPDF), on: [scan])
        XCTAssertLessThan(out.outputBytes, out.inputBytes)
        XCTAssertEqual(PDFDocument(url: out.outputs[0])?.pageCount, 1)
    }
}
