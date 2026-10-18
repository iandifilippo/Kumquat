import AppKit
import AVFoundation
import PDFKit
import XCTest
@testable import KumquatCore

final class EngineTests: XCTestCase {
    var dir: URL!
    let engine = Engine()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("KumquatTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: Fixtures

    /// A 400×300 PNG with a gradient, a circle and some text.
    func makeImage(_ name: String = "Photo.png", text: String = "Hello Kumquat", alpha: Bool = false) throws -> URL {
        let w = 400, h = 300
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        if !alpha {
            ctx.setFillColor(.white)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.55, blue: 0.1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 20, y: 20, width: 120, height: 120))
        let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = ns
        (text as NSString).draw(at: NSPoint(x: 160, y: 140), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 30), .foregroundColor: NSColor.black])
        NSGraphicsContext.restoreGraphicsState()
        let url = dir.appendingPathComponent(name)
        try Images.write(ctx.makeImage()!, to: url, format: .png, quality: 1)
        return url
    }

    func makePDF(pages: Int = 3) throws -> URL {
        let url = dir.appendingPathComponent("Doc.pdf")
        var box = CGRect(x: 0, y: 0, width: 612, height: 792)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        for i in 1...pages {
            ctx.beginPDFPage(nil)
            let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ns
            ("Page \(i) of the Kumquat test document" as NSString).draw(at: NSPoint(x: 72, y: 700), withAttributes: [.font: NSFont.systemFont(ofSize: 18)])
            NSGraphicsContext.restoreGraphicsState()
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }

    func makeMarkdown() throws -> URL {
        let url = dir.appendingPathComponent("Notes.md")
        try "# Title\n\nSome **bold** and *italic* text.\n\n- one\n- two\n\n```\ncode()\n```\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func makeWAV(seconds: Double = 1) throws -> URL {
        try Self.makeWAV(in: dir, seconds: seconds)
    }

    static func makeWAV(in dir: URL, seconds: Double = 1) throws -> URL {
        let url = dir.appendingPathComponent("Tone.wav")
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(44100 * seconds)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        for i in 0..<Int(frames) { buffer.floatChannelData![0][i] = sin(Float(i) * 2 * .pi * 440 / 44100) * 0.3 }
        try file.write(from: buffer)
        return url
    }

    func makeMovie(in folder: URL? = nil) async throws -> URL {
        let url = (folder ?? dir).appendingPathComponent("Clip.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240,
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 240,
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<30 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 2_000_000) }
            var pb: CVPixelBuffer?
            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
            CVPixelBufferLockBaseAddress(pb!, [])
            memset(CVPixelBufferGetBaseAddress(pb!), Int32(frame * 8), CVPixelBufferGetDataSize(pb!))
            CVPixelBufferUnlockBaseAddress(pb!, [])
            adaptor.append(pb!, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        return url
    }

    func size(_ url: URL) -> CGSize {
        let src = CGImageSourceCreateWithURL(url as CFURL, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as! [CFString: Any]
        return CGSize(width: props[kCGImagePropertyPixelWidth] as! Int, height: props[kCGImagePropertyPixelHeight] as! Int)
    }

    // MARK: Catalog

    func testCatalogHidesTheSourceFormat() {
        let actions = ActionCatalog.convertActions(for: [URL(fileURLWithPath: "/x/a.png")])
        XCTAssertFalse(actions.contains(.convert(.png)))
        XCTAssertTrue(actions.contains(.convert(.jpg)))
        XCTAssertTrue(actions.contains(.convert(.pdf)))
    }

    func testMixedImagesAndPDFsOfferMerge() {
        let urls = [URL(fileURLWithPath: "/x/a.png"), URL(fileURLWithPath: "/x/b.pdf")]
        XCTAssertEqual(ActionCatalog.convertActions(for: urls), [.convert(.pdf)])
        XCTAssertEqual(ActionCatalog.toolActions(for: urls), [.tool(.merge), .tool(.zip)])
    }

    func testFileKinds() {
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "a.HEIC")), .image)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "a.pdf")), .pdf)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "a.docx")), .document)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "a.md")), .document)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "a.mov")), .video)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "a.mp3")), .audio)
    }

    // MARK: Images

    func testImageToEveryWritableFormat() async throws {
        let src = try makeImage()
        for format in OutputFormat.writableImageFormats where !format.matches(src) {
            let out = try await engine.run(.convert(format), on: [src])
            XCTAssertEqual(out.outputs.count, 1, "\(format)")
            let url = out.outputs[0]
            XCTAssertEqual(url.pathExtension, format.fileExtension)
            XCTAssertNotNil(CGImageSourceCreateWithURL(url as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }, "\(format) unreadable")
        }
    }

    func testNeverOverwrites() async throws {
        let src = try makeImage()
        let a = try await engine.run(.convert(.jpg), on: [src]).outputs[0]
        let b = try await engine.run(.convert(.jpg), on: [src]).outputs[0]
        XCTAssertEqual(a.lastPathComponent, "Photo.jpg")
        XCTAssertEqual(b.lastPathComponent, "Photo 2.jpg")
    }

    func testSubfolderOutput() async throws {
        let src = try makeImage()
        let e = Engine(planner: OutputPlanner(location: .subfolder("Converted")))
        let out = try await e.run(.convert(.jpg), on: [src]).outputs[0]
        XCTAssertEqual(out.deletingLastPathComponent().lastPathComponent, "Converted")
    }

    func testImagesCombineIntoOnePDF() async throws {
        let a = try makeImage("A.png"), b = try makeImage("B.png")
        let out = try await engine.run(.convert(.pdf), on: [a, b])
        XCTAssertEqual(out.outputs.count, 1)
        XCTAssertEqual(PDFDocument(url: out.outputs[0])?.pageCount, 2)
    }

    func testImageTools() async throws {
        let src = try makeImage()
        let resized = try await engine.run(.tool(.resize), on: [src], parameters: .resize(width: 200, height: 150)).outputs[0]
        XCTAssertEqual(size(resized), CGSize(width: 200, height: 150))

        let scaled = try await engine.run(.tool(.resize), on: [src], parameters: .scale(0.25)).outputs[0]
        XCTAssertEqual(size(scaled), CGSize(width: 100, height: 75))

        let cropped = try await engine.run(.tool(.crop), on: [src], parameters: .crop(CGRect(x: 10, y: 10, width: 100, height: 80))).outputs[0]
        XCTAssertEqual(size(cropped), CGSize(width: 100, height: 80))

        let rotated = try await engine.run(.tool(.rotate), on: [src]).outputs[0]
        XCTAssertEqual(size(rotated), CGSize(width: 300, height: 400))

        for tool in [ToolID.flip, .grayscale, .stripMetadata] {
            let out = try await engine.run(.tool(tool), on: [src]).outputs
            XCTAssertEqual(out.count, 1, "\(tool)")
        }

        let style = BackgroundStyle(padding: 0.1, aspect: .square)
        let bg = try await engine.run(.tool(.addBackground), on: [src], parameters: .background(style)).outputs[0]
        let s = size(bg)
        XCTAssertEqual(s.width, s.height)
        XCTAssertGreaterThan(s.width, 400)
    }

    func testCompressMakesJPEGSmallerThanPNG() async throws {
        let src = try makeImage()
        let out = try await engine.run(.tool(.compress), on: [src])
        XCTAssertEqual(out.outputs[0].pathExtension, "jpg")
        XCTAssertLessThan(out.outputBytes, out.inputBytes)
        XCTAssertTrue(out.outputs[0].lastPathComponent.contains("Compressed"))
    }

    func testOCRFindsText() async throws {
        let src = try makeImage(text: "KUMQUAT 2026")
        let out = try await engine.run(.tool(.extractText), on: [src]).outputs[0]
        let text = try String(contentsOf: out, encoding: .utf8)
        XCTAssertTrue(text.uppercased().contains("KUMQUAT"), text)
    }

    func testRemoveBackgroundCutsOutTheIcon() async throws {
        let icon = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../docs/assets/icon.png").standardized
        let src = dir.appendingPathComponent("Icon.jpg")
        try Images.write(Images.load(icon).image, to: src, format: .jpg, quality: 0.9)
        let out = try await engine.run(.tool(.removeBackground), on: [src]).outputs[0]
        XCTAssertEqual(out.pathExtension, "png")
        let (image, _) = try Images.load(out)
        XCTAssertTrue(Images.hasAlpha(image), "background should be transparent")
    }

    // MARK: PDFs

    func testPDFToImagesOnePerPage() async throws {
        let pdf = try makePDF(pages: 3)
        let out = try await engine.run(.convert(.png), on: [pdf])
        XCTAssertEqual(out.outputs.count, 3)
        XCTAssertEqual(out.outputs[0].lastPathComponent, "Doc 001.png")
    }

    func testPDFToTextAndWord() async throws {
        let pdf = try makePDF()
        let txt = try await engine.run(.convert(.txt), on: [pdf]).outputs[0]
        XCTAssertTrue(try String(contentsOf: txt, encoding: .utf8).contains("Page 2"))
        let docx = try await engine.run(.convert(.docx), on: [pdf]).outputs[0]
        XCTAssertGreaterThan(docx.fileSize, 0)
    }

    func testPDFTools() async throws {
        let pdf = try makePDF(pages: 3)
        let split = try await engine.run(.tool(.split), on: [pdf]).outputs
        XCTAssertEqual(split.count, 3)

        let merged = try await engine.run(.tool(.merge), on: split).outputs[0]
        XCTAssertEqual(PDFDocument(url: merged)?.pageCount, 3)

        let rotated = try await engine.run(.tool(.rotatePDF), on: [pdf]).outputs[0]
        XCTAssertEqual(PDFDocument(url: rotated)?.page(at: 0)?.rotation, 90)

        let protected = try await engine.run(.tool(.protect), on: [pdf], parameters: .password("s3cret")).outputs[0]
        let doc = PDFDocument(url: protected)!
        XCTAssertTrue(doc.isLocked)
        XCTAssertTrue(doc.unlock(withPassword: "s3cret"))

        // Without Ghostscript, a text-only PDF can't shrink, so nothing should be saved.
        Engines.override(Engines())
        defer { Engines.refresh() }
        do {
            _ = try await engine.run(.tool(.compressPDF), on: [pdf])
            XCTFail("expected notSmaller")
        } catch KumquatError.notSmaller {}
    }

    // MARK: Documents

    func testMarkdownToEveryDocumentFormat() async throws {
        let md = try makeMarkdown()
        for format in [OutputFormat.pdf, .docx, .rtf, .txt, .html, .odt] {
            let out = try await engine.run(.convert(format), on: [md]).outputs[0]
            XCTAssertGreaterThan(out.fileSize, 0, "\(format)")
        }
        let pdf = PDFDocument(url: dir.appendingPathComponent("Notes.pdf"))
        XCTAssertTrue(pdf?.string?.contains("Title") ?? false)
    }

    func testWordRoundTrip() async throws {
        let md = try makeMarkdown()
        let docx = try await engine.run(.convert(.docx), on: [md]).outputs[0]
        let txt = try await engine.run(.convert(.txt), on: [docx]).outputs[0]
        XCTAssertTrue(try String(contentsOf: txt, encoding: .utf8).contains("bold"))
    }

    // MARK: Media

    func testAudioConversions() async throws {
        let wav = try makeWAV()
        for format in [OutputFormat.m4a, .aiff, .flac, .caf] {
            let out = try await engine.run(.convert(format), on: [wav]).outputs[0]
            XCTAssertGreaterThan(out.fileSize, 0, "\(format)")
        }
    }

    func testVideoConversions() async throws {
        let mov = try await makeMovie()
        let mp4 = try await engine.run(.convert(.mp4), on: [mov]).outputs[0]
        XCTAssertGreaterThan(mp4.fileSize, 0)
        let gif = try await engine.run(.convert(.gif), on: [mov]).outputs[0]
        let frames = CGImageSourceGetCount(CGImageSourceCreateWithURL(gif as CFURL, nil)!)
        XCTAssertGreaterThan(frames, 5)
        let muted = try await engine.run(.tool(.mute), on: [mov]).outputs[0]
        XCTAssertGreaterThan(muted.fileSize, 0)
    }
}
