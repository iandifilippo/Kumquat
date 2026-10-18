import AppKit
import AVFoundation
import PDFKit
import XCTest
@testable import KumquatCore

/// Archives, data, subtitles, e-books, SVG and the new image/PDF/video tools.
final class FormatTests: XCTestCase {
    var dir: URL!
    let engine = Engine()

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("KumquatFormats-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: dir) }

    func write(_ name: String, _ text: String) throws -> URL {
        let url = dir.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    // MARK: Catalog

    func testNewKinds() {
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.tar.gz")), .archive)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.rar")), .archive)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.csv")), .data)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.xlsx")), .data)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.srt")), .subtitle)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.epub")), .ebook)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.pptx")), .office)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.webm")), .video)
        XCTAssertEqual(FileKind.of(URL(fileURLWithPath: "/x/a.svg")), .image)
        XCTAssertEqual(FileKind.of(dir), .folder)
    }

    func testEngineFormatsOnlyWithEngines() {
        let none = Engines()
        let some = Engines(ffmpeg: URL(fileURLWithPath: "/ffmpeg"), soffice: URL(fileURLWithPath: "/soffice"), cwebp: URL(fileURLWithPath: "/cwebp"))
        let png = [URL(fileURLWithPath: "/x/a.png")]
        XCTAssertFalse(ActionCatalog.convertActions(for: png, engines: none).contains(.convert(.webp)))
        XCTAssertTrue(ActionCatalog.convertActions(for: png, engines: some).contains(.convert(.webp)))
        let webm = [URL(fileURLWithPath: "/x/a.webm")]
        XCTAssertTrue(ActionCatalog.convertActions(for: webm, engines: none).isEmpty)
        XCTAssertTrue(ActionCatalog.convertActions(for: webm, engines: some).contains(.convert(.mp4)))
        let pptx = [URL(fileURLWithPath: "/x/a.pptx")]
        XCTAssertTrue(ActionCatalog.convertActions(for: pptx, engines: none).isEmpty)
        XCTAssertEqual(ActionCatalog.convertActions(for: pptx, engines: some), [.convert(.pdf)])
    }

    func testEveryKindHasSomething() {
        for kind in FileKind.allCases where kind != .other {
            let all = ActionCatalog.allActions(for: kind)
            XCTAssertFalse(all.convert.isEmpty && all.tools.isEmpty, "\(kind)")
        }
    }

    // MARK: Archives

    func testZipExtractAndRepack() async throws {
        let folder = dir.appendingPathComponent("Trip", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "hello".write(to: folder.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try "world".write(to: folder.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)

        let zip = try await engine.run(.tool(.zip), on: [folder]).outputs[0]
        XCTAssertEqual(zip.lastPathComponent, "Trip.zip")

        let tgz = try await engine.run(.convert(.tgz), on: [zip]).outputs[0]
        XCTAssertEqual(tgz.lastPathComponent, "Trip.tar.gz")

        try FileManager.default.removeItem(at: folder)
        let extracted = try await engine.run(.tool(.extract), on: [tgz]).outputs[0]
        XCTAssertEqual(extracted.lastPathComponent, "Trip")
        XCTAssertEqual(try String(contentsOf: extracted.appendingPathComponent("a.txt"), encoding: .utf8), "hello")
    }

    func testSeveralFilesZipTogether() async throws {
        let a = try write("a.txt", "1"), b = try write("b.txt", "2")
        let zip = try await engine.run(.tool(.zip), on: [a, b]).outputs[0]
        XCTAssertEqual(zip.pathExtension, "zip")
        let out = try await engine.run(.tool(.extract), on: [zip]).outputs[0]
        XCTAssertEqual(Set(try FileManager.default.contentsOfDirectory(atPath: out.path)), ["a.txt", "b.txt"])
    }

    // MARK: Data

    func testCSVParsing() {
        let t = DataFiles.parseDelimited("name,note\n\"Lee, Ann\",\"said \"\"hi\"\"\"\nBo,\"two\nlines\"\n", separator: ",")
        XCTAssertEqual(t, [["name", "note"], ["Lee, Ann", "said \"hi\""], ["Bo", "two\nlines"]])
    }

    func testTableRoundTrips() async throws {
        let csv = try write("People.csv", "name,age,city\nAna,31,Madrid\n\"Lee, Ann\",44,Bogotá\n")
        let xlsx = try await engine.run(.convert(.xlsx), on: [csv]).outputs[0]
        let fromXLSX = try await engine.run(.convert(.csv), on: [xlsx]).outputs[0]
        let back = DataFiles.parseDelimited(try String(contentsOf: fromXLSX, encoding: .utf8), separator: ",")
        XCTAssertEqual(back, [["name", "age", "city"], ["Ana", "31", "Madrid"], ["Lee, Ann", "44", "Bogotá"]])

        let json = try await engine.run(.convert(.json), on: [csv]).outputs[0]
        let objects = try JSONSerialization.jsonObject(with: Data(contentsOf: json)) as! [[String: Any]]
        XCTAssertEqual(objects.count, 2)
        XCTAssertEqual(objects[0]["age"] as? Int, 31)

        let tsv = try await engine.run(.convert(.tsv), on: [json]).outputs[0]
        // JSON keys come back sorted: age, city, name.
        XCTAssertTrue(try String(contentsOf: tsv, encoding: .utf8).contains("31\tMadrid\tAna"))

        for format in [OutputFormat.html, .pdf] {
            let out = try await engine.run(.convert(format), on: [csv]).outputs[0]
            XCTAssertGreaterThan(out.fileSize, 0, "\(format)")
        }
    }

    func testPlistAndJSON() async throws {
        let json = try write("Config.json", #"{"name":"Kumquat","size":3,"tags":["a","b"],"none":null}"#)
        let plist = try await engine.run(.convert(.plist), on: [json]).outputs[0]
        let dict = try PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as! [String: Any]
        XCTAssertEqual(dict["name"] as? String, "Kumquat")
        try FileManager.default.removeItem(at: json)
        let back = try await engine.run(.convert(.json), on: [plist]).outputs[0]
        XCTAssertTrue(try String(contentsOf: back, encoding: .utf8).contains("\"Kumquat\""))
    }

    // MARK: Subtitles

    func testSRTAndVTT() async throws {
        let srt = try write("Movie.srt", "1\n00:00:01,000 --> 00:00:02,500\nHello\n\n2\n00:00:03,000 --> 00:00:04,000\n<i>World</i>\n")
        let vtt = try await engine.run(.convert(.vtt), on: [srt]).outputs[0]
        let v = try String(contentsOf: vtt, encoding: .utf8)
        XCTAssertTrue(v.hasPrefix("WEBVTT"))
        XCTAssertTrue(v.contains("00:00:01.000 --> 00:00:02.500"))
        try FileManager.default.removeItem(at: srt)
        let srt2 = try await engine.run(.convert(.srt), on: [vtt]).outputs[0]
        XCTAssertTrue(try String(contentsOf: srt2, encoding: .utf8).contains("2\n00:00:03,000 --> 00:00:04,000"))
    }

    // MARK: E-books

    func testEPUBRoundTrip() async throws {
        let md = try write("Story.md", "# Chapter One\n\nIt was a **bright** day in the orchard.\n")
        let epub = try await engine.run(.convert(.epub), on: [md]).outputs[0]
        // The container must be a valid EPUB: "mimetype" first and stored.
        let head = try Data(contentsOf: epub).prefix(60)
        XCTAssertTrue(String(decoding: head, as: UTF8.self).contains("mimetypeapplication/epub+zip"))
        let txt = try await engine.run(.convert(.txt), on: [epub]).outputs[0]
        XCTAssertTrue(try String(contentsOf: txt, encoding: .utf8).contains("bright day in the orchard"))
        let pdf = try await engine.run(.convert(.pdf), on: [epub]).outputs[0]
        XCTAssertTrue(PDFDocument(url: pdf)?.string?.contains("orchard") ?? false)
    }

    // MARK: Images

    func testSVGConverts() async throws {
        let svg = try write("Logo.svg", ##"<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><rect width="100" height="50" fill="#ff8800"/></svg>"##)
        let png = try await engine.run(.convert(.png), on: [svg]).outputs[0]
        let image = try Images.load(png).image
        XCTAssertEqual(image.width, 1024)
        XCTAssertEqual(image.height, 512)
    }

    func testRemovePlainBackgroundKeepsInk() async throws {
        // Dark "ink" stroke on off-white paper, like a scanned signature.
        let ctx = CGContext(data: nil, width: 300, height: 120, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(srgbRed: 0.97, green: 0.96, blue: 0.93, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 300, height: 120))
        ctx.setStrokeColor(CGColor(srgbRed: 0.05, green: 0.1, blue: 0.4, alpha: 1))
        ctx.setLineWidth(6)
        ctx.move(to: CGPoint(x: 30, y: 60)); ctx.addLine(to: CGPoint(x: 270, y: 60)); ctx.strokePath()
        let src = dir.appendingPathComponent("Signature.jpg")
        try Images.write(ctx.makeImage()!, to: src, format: .jpg, quality: 0.95)

        let out = try await engine.run(.tool(.removeBackground), on: [src]).outputs[0]
        let image = try Images.load(out).image
        let (pctx, p) = Images.pixels(image)!
        let row = pctx.bytesPerRow
        XCTAssertEqual(p[10 * row + 10 * 4 + 3], 0, "paper should be transparent")
        // CGContext rows start at the top; the line is at y = 60 from the bottom, i.e. row 59/60.
        XCTAssertEqual(p[60 * row + 150 * 4 + 3], 255, "ink should stay opaque")
    }

    // MARK: PDF and video tools

    func makePDF(pages: Int) throws -> URL {
        let url = dir.appendingPathComponent("Pages.pdf")
        var box = CGRect(x: 0, y: 0, width: 300, height: 400)
        let ctx = CGContext(url as CFURL, mediaBox: &box, nil)!
        for i in 0..<pages {
            ctx.beginPDFPage(nil)
            ctx.setFillColor(CGColor(srgbRed: Double(i) / Double(pages), green: 0.5, blue: 0.5, alpha: 1))
            ctx.fill(CGRect(x: 20, y: 20, width: 260, height: 360))
            ctx.endPDFPage()
        }
        ctx.closePDF()
        return url
    }

    func testLongImage() async throws {
        let pdf = try makePDF(pages: 3)
        var e = engine
        e.options.pdfDPI = 72
        let out = try await e.run(.tool(.longImage), on: [pdf]).outputs[0]
        let image = try Images.load(out).image
        XCTAssertEqual(image.width, 300)
        XCTAssertEqual(image.height, 1200)
    }

    func testStrongPDFCompressionShrinksScans() async throws {
        // A "scan": a big noisy photo-like image on a page.
        let w = 1600, h = 2000
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let p = ctx.data!.bindMemory(to: UInt8.self, capacity: ctx.bytesPerRow * h)
        for i in 0..<(ctx.bytesPerRow * h) { p[i] = UInt8.random(in: 0...255) | 3 }
        let scan = dir.appendingPathComponent("Scan.pdf")
        try Images.writePDF([ctx.makeImage()!], to: scan)
        var e = engine
        e.options.pdfCompression = .strong
        let out = try await e.run(.tool(.compressPDF), on: [scan])
        XCTAssertLessThan(out.outputBytes, out.inputBytes / 2)
    }

    func testVideoFrames() async throws {
        let mov = try await EngineTests().makeMovie(in: dir)
        var e = engine
        e.options.framesPerSecond = 10
        let out = try await e.run(.tool(.frames), on: [mov]).outputs[0]
        let files = try FileManager.default.contentsOfDirectory(atPath: out.path).filter { $0.hasSuffix(".jpg") }
        XCTAssertEqual(files.count, 10) // 1 second at 10 fps
        XCTAssertTrue(out.lastPathComponent.hasPrefix("Clip Frames"))
    }
}
