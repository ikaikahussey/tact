import XCTest
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

    func testEveryPaletteHasEveryTileColour() {
        for palette in AppPalette.allCases {
            for index in 0..<TileArt.colorCount {
                XCTAssertNotNil(UIColor(palette.tileColor(index)).cgColor, "\(palette) \(index)")
            }
        }
        XCTAssertEqual(TilePalette.color(3, in: .classic), TilePalette.colors[3])
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
