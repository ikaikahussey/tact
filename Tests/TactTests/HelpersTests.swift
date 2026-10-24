import XCTest
@testable import Tact

final class HelpersTests: XCTestCase {
    func testOutlineListsPeopleNotesAndUnlinkedNotes() {
        let ada = Person(name: "Ada")
        let notes = [
            Note(personIds: [ada.id], text: "Loves\nmath", date: Date(timeIntervalSince1970: 0)),
            Note(personIds: [], text: String(repeating: "x", count: 150)),
        ]
        let outline = OutlineExporter.outline(people: [ada], notes: notes)
        XCTAssertTrue(outline.contains("PEOPLE (1)"))
        XCTAssertTrue(outline.contains("• Ada"))
        XCTAssertTrue(outline.contains("Loves math"), "newlines are flattened")
        XCTAssertTrue(outline.contains("UNLINKED NOTES (1)"))
        XCTAssertTrue(outline.contains(String(repeating: "x", count: 100) + "..."))
        XCTAssertFalse(outline.contains(String(repeating: "x", count: 101)))
    }

    func testOutlineWithNoPeople() {
        XCTAssertTrue(OutlineExporter.outline(people: [], notes: []).contains("No people added yet."))
    }

    func testRandomColorIsDeterministicAndInRange() {
        for palette in ColorPalette.allCases {
            for seed in [0, 1, 17, 359, 4096, -5] {
                let a = RandomColor.hsb(seed: seed, palette: palette)
                let b = RandomColor.hsb(seed: seed, palette: palette)
                XCTAssertEqual(a, b)
                XCTAssertTrue((0...1).contains(a.hue), "\(palette) \(seed)")
                XCTAssertTrue((0...1).contains(a.saturation), "\(palette) \(seed)")
                XCTAssertTrue((0...1).contains(a.brightness), "\(palette) \(seed)")
            }
        }
    }

    func testArtGridGeometry() {
        XCTAssertEqual(ArtImageCache.rows(forTileCount: 1), 1)
        XCTAssertEqual(ArtImageCache.rows(forTileCount: 4), 1)
        XCTAssertEqual(ArtImageCache.rows(forTileCount: 5), 2)
        XCTAssertEqual(ArtImageCache.rows(forTileCount: 16), 4)

        let wide = ArtImageCache.cropRect(for: CGSize(width: 400, height: 100), tileCount: 16)
        XCTAssertEqual(wide, CGRect(x: 150, y: 0, width: 100, height: 100))
        let tall = ArtImageCache.cropRect(for: CGSize(width: 100, height: 400), tileCount: 8)
        XCTAssertEqual(tall, CGRect(x: 0, y: 175, width: 100, height: 50))
    }

    func testArtTilesAreProducedForEveryIndexAndNotBeyond() {
        let data = TestSupport.jpeg(width: 200, height: 120)
        let cache = ArtImageCache()
        for index in 0..<6 {
            XCTAssertNotNil(cache.tile(for: data, index: index, tileCount: 6), "tile \(index)")
        }
        XCTAssertNil(cache.tile(for: data, index: 8, tileCount: 6))
        XCTAssertNil(cache.tile(for: data, index: -1, tileCount: 6))
        XCTAssertNil(cache.tile(for: data, index: 0, tileCount: 0))
    }

    func testStorableJPEGDownscalesLargeImages() throws {
        let big = TestSupport.jpeg(width: 3000, height: 1500)
        let stored = try XCTUnwrap(ImageProcessing.storableJPEG(from: big))
        let image = try XCTUnwrap(UIImage(data: stored))
        XCTAssertEqual(image.size.width, 1024)
        XCTAssertEqual(image.size.height, 512)

        let small = TestSupport.jpeg(width: 300, height: 200)
        let keptSmall = try XCTUnwrap(UIImage(data: ImageProcessing.storableJPEG(from: small)!))
        XCTAssertEqual(keptSmall.size, CGSize(width: 300, height: 200))
        XCTAssertNil(ImageProcessing.storableJPEG(from: Data([0, 1, 2])))
    }

    func testImageCacheThumbnails() throws {
        let data = TestSupport.jpeg(width: 1000, height: 500)
        let cache = ImageCache()
        let thumb = try XCTUnwrap(cache.image(for: data, maxPixelSize: 100))
        XCTAssertEqual(max(thumb.size.width, thumb.size.height), 100, accuracy: 1)
        XCTAssertTrue(cache.image(for: data, maxPixelSize: 100) === thumb)
        XCTAssertEqual(cache.image(for: data)?.size.width, 1000)
    }

    func testDefaultPuzzleImageIsBundled() throws {
        let data = PuzzleDefaultImage.data
        XCTAssertFalse(data.isEmpty)
        let image = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), ImageProcessing.maxStoredDimension)
        XCTAssertNotNil(ArtImageCache().tile(for: data, index: ArtPuzzle.pieceCount - 1, tileCount: ArtPuzzle.pieceCount))
    }

    func testHiddenLayoutsResolveToTiles() {
        XCTAssertEqual(PeopleLayout.colors.resolved, .grid)
        XCTAssertEqual(PeopleLayout.flashcards.resolved, .grid)
        XCTAssertEqual(PeopleLayout.art.resolved, .art)
        XCTAssertFalse(PeopleLayout.available.contains(.colors))
        XCTAssertEqual(PeopleLayout.available, [.grid, .list, .tangram, .art])
        XCTAssertEqual(PeopleLayout.standard, .grid)
        XCTAssertEqual(PeopleLayout.art.title, "Puzzles")
    }

    func testBirthdayFormatting() {
        let locale = Locale(identifier: "en_US")
        XCTAssertEqual(ContactSnapshot.format(birthday: DateComponents(month: 12, day: 10), locale: locale), "December 10")
        XCTAssertEqual(ContactSnapshot.format(birthday: DateComponents(year: 1815, month: 12, day: 10), locale: locale), "December 10, 1815")
        XCTAssertEqual(ContactSnapshot.format(birthday: DateComponents(month: 2, day: 29), locale: locale), "February 29")
        XCTAssertNil(ContactSnapshot.format(birthday: DateComponents(year: 1990), locale: locale))
    }

    func testContactActionURLs() {
        XCTAssertEqual(LinkedContactInfoView.phoneURL(scheme: "tel", "+1 (555) 010-0000")?.absoluteString, "tel:+15550100000")
        XCTAssertNil(LinkedContactInfoView.phoneURL(scheme: "tel", "n/a"))
        XCTAssertEqual(LinkedContactInfoView.mailURL("ada@example.com")?.absoluteString, "mailto:ada@example.com")
        XCTAssertEqual(LinkedContactInfoView.webURL("example.com")?.absoluteString, "https://example.com")
        XCTAssertEqual(LinkedContactInfoView.webURL("http://example.com")?.absoluteString, "http://example.com")
        let map = LinkedContactInfoView.mapURL("1 Infinite Loop\nCupertino")
        XCTAssertEqual(map?.host, "maps.apple.com")
        XCTAssertTrue(map?.query?.contains("Cupertino") ?? false)
    }
}
