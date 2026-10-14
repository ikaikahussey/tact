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
        XCTAssertEqual(Set((0..<12).map { TileArt(seed: $0).shape }), [.square, .triangle])
        XCTAssertEqual(TilePalette.colors.count, TileArt.colorCount)
    }

    func testTapTurnsAndChangesColourAndWraps() {
        var art = TileArt(shape: .triangle, quarterTurns: 3, colorIndex: TileArt.colorCount - 1)
        art.advance()
        XCTAssertEqual(art.quarterTurns, 4, "turns keep counting so the animation goes forward")
        XCTAssertEqual(art.colorIndex, 0)
        art.toggleShape()
        XCTAssertEqual(art.shape, .square)
        art.toggleShape()
        XCTAssertEqual(art.shape, .triangle)
    }

    func testDecodingIsTolerant() throws {
        let json = #"{"shape":"hexagon","colorIndex":-3,"cell":-1}"#.data(using: .utf8)!
        let art = try JSONDecoder().decode(TileArt.self, from: json)
        XCTAssertEqual(art.shape, .triangle)
        XCTAssertEqual(art.quarterTurns, 0)
        XCTAssertEqual(art.colorIndex, 5)
        XCTAssertNil(art.cell)
    }

    func testPersonWithoutTileGetsOneFromItsSeedAndRoundTrips() throws {
        let json = #"{"id":"6D1A4F7E-1C0B-4E8B-9D6A-1234567890AB","name":"Ada","imageSection":7}"#.data(using: .utf8)!
        var person = try JSONDecoder().decode(Person.self, from: json)
        XCTAssertEqual(person.tile, TileArt(seed: 7))

        person.tile = TileArt(shape: .square, quarterTurns: 6, colorIndex: 2, cell: 9)
        let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        XCTAssertEqual(decoded.tile, person.tile)
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

    func testTappingATileUpdatesOnlyThatPerson() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        store.updateTile(forPersonID: ada.id) { $0.advance() }
        XCTAssertEqual(store.person(id: ada.id)?.tile.quarterTurns, ada.tile.quarterTurns + 1)
        XCTAssertEqual(store.person(id: grace.id)?.tile, grace.tile)
    }
}
