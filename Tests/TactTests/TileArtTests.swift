import XCTest
import SwiftUI
@testable import Tact

final class TileArtTests: XCTestCase {
    func testStartingLookIsDeterministicAndInRange() {
        for seed in [0, 1, 2, 7, 100, 359, -5] {
            let art = TileArt(seed: seed)
            XCTAssertEqual(art, TileArt(seed: seed))
            XCTAssertTrue((0..<TileArt.colorCount).contains(art.colorIndex), "\(seed)")
            XCTAssertTrue((0..<4).contains(art.quarterTurns), "\(seed)")
            XCTAssertNil(art.cell)
        }
        XCTAssertEqual(TilePalette.colors.count, TileArt.colorCount)
    }

    func testRotatingKeepsCountingAndPaletteIsComplete() {
        var art = TileArt(quarterTurns: 3)
        art.rotate()
        XCTAssertEqual(art.quarterTurns, 4, "turns keep counting so the animation goes forward")
        XCTAssertEqual(TilePalette.names.count, TileArt.colorCount)
        XCTAssertEqual(Set(TilePalette.menuOrder), Set(0..<TileArt.colorCount))
    }

    func testEachPersonKeepsTheirPatternAndEveryPatternIsUsed() {
        for seed in [0, 5, 77, 359, -42] {
            XCTAssertEqual(TilePattern(seed: seed), TilePattern(seed: seed))
        }
        XCTAssertEqual(Set((0..<360).map { TilePattern(seed: $0) }), Set(TilePattern.allCases))
    }

    func testDecodingIsTolerant() throws {
        // Shapes and sizes from earlier versions are ignored.
        let json = #"{"shape":"hexagon","isLarge":true,"colorIndex":-3,"cell":-1}"#.data(using: .utf8)!
        let art = try JSONDecoder().decode(TileArt.self, from: json)
        XCTAssertEqual(art, TileArt(quarterTurns: 0, colorIndex: 9, cell: nil))
    }

    func testPersonWithoutTileGetsOneFromItsSeedAndRoundTrips() throws {
        let json = #"{"id":"6D1A4F7E-1C0B-4E8B-9D6A-1234567890AB","name":"Ada","imageSection":7}"#.data(using: .utf8)!
        var person = try JSONDecoder().decode(Person.self, from: json)
        XCTAssertEqual(person.tile, TileArt(seed: 7))

        person.tile = TileArt(quarterTurns: 6, colorIndex: 2, cell: 9)
        let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        XCTAssertEqual(decoded.tile, person.tile)
    }

    func testChosenPatternAndPhotoChoiceRoundTrip() throws {
        var person = Person(name: "Ada", colorSeed: 7, photoData: Data([1, 2, 3]))
        XCTAssertTrue(person.showsPhoto, "a photo shows on the tile by default")
        XCTAssertEqual(person.tilePattern, TilePattern(seed: 7))

        person.tile.pattern = TilePattern.diamond.rawValue
        person.tile.showsPhoto = false
        XCTAssertFalse(person.showsPhoto)
        XCTAssertEqual(person.tilePattern, .diamond)

        let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        XCTAssertEqual(decoded.tile, person.tile)
        XCTAssertFalse(Person(name: "Bo").showsPhoto, "no photo, nothing to show")
    }

    func testSymbolsOnTheAccentStandOutInLightAndDark() {
        func luminance(_ color: UIColor) -> CGFloat {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ c: CGFloat) -> CGFloat { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for palette in AppPalette.allCases {
                let accent = luminance(UIColor(palette.accent).resolvedColor(with: traits))
                let symbol = luminance(UIColor(palette.onAccent).resolvedColor(with: traits))
                let contrast = (max(accent, symbol) + 0.05) / (min(accent, symbol) + 0.05)
                XCTAssertGreaterThan(contrast, 3, "\(palette) in \(style == .dark ? "dark" : "light") mode")
            }
        }
    }

    func testEveryPaletteHasEveryTileColour() {
        for palette in AppPalette.allCases {
            for index in 0..<TileArt.colorCount {
                XCTAssertNotNil(UIColor(palette.tileColor(index)).cgColor, "\(palette) \(index)")
            }
        }
        XCTAssertEqual(TilePalette.color(3, in: .classic), TilePalette.colors[3])
        // Grayscale keeps every tile colour told apart.
        let grays = TilePalette.menuOrder.map { index -> CGFloat in
            var white: CGFloat = 0, alpha: CGFloat = 0
            UIColor(AppPalette.grayscale.tileColor(index)).getWhite(&white, alpha: &alpha)
            return white
        }
        XCTAssertEqual(Set(grays.map { Int($0 * 100) }).count, grays.count)
        XCTAssertTrue(grays == grays.sorted(), "lighter along the menu")
    }

    func testLayoutKeepsPlacedTilesAndFillsGapsInOrder() {
        var a = Person(name: "A"), b = Person(name: "B"), c = Person(name: "C"), d = Person(name: "D")
        a.tile.cell = 5
        c.tile.cell = 0
        d.tile.cell = 5   // already taken by A, so D is placed like an unplaced tile
        let layout = TileLayout.cells(for: [a, b, c, d])
        XCTAssertEqual(layout[5], a.id)
        XCTAssertEqual(layout[0], c.id)
        XCTAssertEqual(layout[1], b.id)
        XCTAssertEqual(layout[2], d.id)
        XCTAssertNil(layout[3], "gaps stay empty")
        XCTAssertEqual(layout.count, 4)
    }

    func testCanvasAlwaysHasAnEmptyRowBelowTheLowestTile() {
        XCTAssertEqual(PeopleGridContent.cellCount(occupied: [Int](), visibleRows: 6, columns: 4), 24)
        XCTAssertEqual(PeopleGridContent.cellCount(occupied: [0, 3], visibleRows: 0, columns: 4), 8)
        XCTAssertEqual(PeopleGridContent.cellCount(occupied: [0, 29], visibleRows: 6, columns: 4), 36)
    }
}

extension TactStoreTests {
    func testMovingATileIntoAGapPinsEveryoneElse() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        let kai = store.addPerson(named: "Kai")!

        store.moveTile(personID: ada.id, toCell: 10)
        var layout = TileLayout.cells(for: store.people)
        XCTAssertEqual(layout[10], ada.id)
        XCTAssertEqual(layout[1], grace.id, "others stay put instead of sliding into Ada's old cell")
        XCTAssertEqual(layout[2], kai.id)
        XCTAssertNil(layout[0])

        // A newcomer takes the first gap.
        let mei = store.addPerson(named: "Mei")!
        XCTAssertEqual(TileLayout.cells(for: store.people)[0], mei.id)

        // Dropping onto someone swaps the two.
        store.moveTile(personID: kai.id, toCell: 10)
        layout = TileLayout.cells(for: store.people)
        XCTAssertEqual(layout[10], kai.id)
        XCTAssertEqual(layout[2], ada.id)
    }

    func testBringingTilesTogetherClosesGapsAndKeepsOrder() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        let kai = store.addPerson(named: "Kai")!
        XCTAssertTrue(TileLayout.isCompact(store.people))
        store.moveTile(personID: ada.id, toCell: 13)
        store.moveTile(personID: kai.id, toCell: 6)
        XCTAssertFalse(TileLayout.isCompact(store.people))

        store.bringTilesTogether()
        let layout = TileLayout.cells(for: store.people)
        XCTAssertEqual(layout[0], grace.id)
        XCTAssertEqual(layout[1], kai.id)
        XCTAssertEqual(layout[2], ada.id)
        XCTAssertTrue(TileLayout.isCompact(store.people))
    }

    func testTappingATileUpdatesOnlyThatPerson() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        store.updateTile(forPersonID: ada.id) { $0.rotate() }
        XCTAssertEqual(store.person(id: ada.id)?.tile.quarterTurns, ada.tile.quarterTurns + 1)
        XCTAssertEqual(store.person(id: grace.id)?.tile, grace.tile)
    }
}

/// Every motif meets the middle of each edge with the base shade and leaves
/// the rest of the edge pale, so neighbouring tiles join whatever they show.
@MainActor
final class TilePatternEdgeTests: XCTestCase {
    private typealias RGB = (CGFloat, CGFloat, CGFloat)

    private func render(_ pattern: TilePattern, side: Int = 100) -> (Int, Int) -> RGB {
        let renderer = ImageRenderer(content: TilePatternView(pattern: pattern, colorIndex: 5)
            .environment(\.appPalette, .classic)
            .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        let image = renderer.cgImage!
        var data = [UInt8](repeating: 0, count: side * side * 4)
        let context = CGContext(data: &data, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side * 4,
                                space: CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        return { x, y in
            let i = (y * side + x) * 4
            return (CGFloat(data[i]) / 255, CGFloat(data[i + 1]) / 255, CGFloat(data[i + 2]) / 255)
        }
    }

    private func components(_ color: Color) -> RGB {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (r, g, b)
    }

    private func close(_ a: RGB, _ b: RGB) -> Bool {
        abs(a.0 - b.0) < 0.06 && abs(a.1 - b.1) < 0.06 && abs(a.2 - b.2) < 0.06
    }

    func testEveryPatternConnectsAtTheEdgeMidpointsAndNotBeside() {
        let shades = TileShades(colorIndex: 5, palette: .classic)
        let base = components(shades.base)
        for pattern in TilePattern.allCases {
            let pixel = render(pattern)
            // Just inside each edge, at its middle: the band.
            for (x, y) in [(50, 1), (50, 98), (1, 50), (98, 50)] {
                XCTAssertTrue(close(pixel(x, y), base), "\(pattern) band at (\(x), \(y))")
            }
            // Just inside each edge, outside the band: not the band.
            for (x, y) in [(20, 1), (80, 98), (1, 20), (98, 80)] {
                XCTAssertFalse(close(pixel(x, y), base), "\(pattern) beside the band at (\(x), \(y))")
            }
        }
    }
}
