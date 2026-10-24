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

    func testStylesSetShapeAndSize() {
        var art = TileArt(shape: .triangle, quarterTurns: 3)
        XCTAssertEqual(art.style, .triangle)
        XCTAssertEqual(art.span, 1)
        art.style = .largeSquare
        XCTAssertEqual(art.shape, .square)
        XCTAssertTrue(art.isLarge)
        XCTAssertEqual(art.span, 2)
        art.style = .circle
        XCTAssertEqual(art.shape, .circle)
        XCTAssertFalse(art.isLarge)
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
        let json = #"{"shape":"hexagon","colorIndex":-3,"cell":-1}"#.data(using: .utf8)!
        let art = try JSONDecoder().decode(TileArt.self, from: json)
        XCTAssertEqual(art.shape, .triangle)
        XCTAssertEqual(art.quarterTurns, 0)
        XCTAssertEqual(art.colorIndex, 9)
        XCTAssertFalse(art.isLarge)
        XCTAssertNil(art.cell)
    }

    func testPersonWithoutTileGetsOneFromItsSeedAndRoundTrips() throws {
        let json = #"{"id":"6D1A4F7E-1C0B-4E8B-9D6A-1234567890AB","name":"Ada","imageSection":7}"#.data(using: .utf8)!
        var person = try JSONDecoder().decode(Person.self, from: json)
        XCTAssertEqual(person.tile, TileArt(seed: 7))

        person.tile = TileArt(shape: .square, isLarge: true, quarterTurns: 6, colorIndex: 2, cell: 9)
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

    func testLargeTilesCoverFourCellsAndOthersFlowAroundThem() {
        var a = Person(name: "A"), b = Person(name: "B"), c = Person(name: "C"), d = Person(name: "D")
        a.tile = TileArt(shape: .square, isLarge: true, cell: 1)   // covers 1, 2, 5, 6
        b.tile = TileArt(shape: .triangle, cell: 6)                 // overlaps A, so placed like an unplaced tile
        c.tile = TileArt(shape: .triangle, isLarge: true, cell: 3)  // would run off the right edge
        d.tile = TileArt(shape: .circle)
        let layout = TileLayout.cells(for: [a, b, c, d])
        XCTAssertEqual(layout[1], a.id)
        XCTAssertEqual(layout[0], b.id)
        XCTAssertEqual(layout[8], c.id, "first spot with two free columns and rows")
        XCTAssertEqual(layout[3], d.id)
        XCTAssertEqual(TileLayout.covered(anchor: 1, span: 2), [1, 2, 5, 6])
        XCTAssertNil(TileLayout.covered(anchor: 3, span: 2))
        XCTAssertEqual(TileLayout.fitting(7, span: 2), 6)
        XCTAssertEqual(TileLayout.fitting(6, span: 2), 6)
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

    func testGrowingATilePushesAsideTheTilesItCovers() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!     // 0
        let grace = store.addPerson(named: "Grace")! // 1
        let kai = store.addPerson(named: "Kai")!     // 2
        let mei = store.addPerson(named: "Mei")!     // 3
        let noa = store.addPerson(named: "Noa")!     // 4

        store.updateTile(forPersonID: grace.id) { $0.style = .largeSquare }
        var layout = TileLayout.cells(for: store.people)
        XCTAssertEqual(layout[1], grace.id, "covers 1, 2, 5, 6")
        XCTAssertEqual(layout[0], ada.id)
        XCTAssertEqual(layout[3], mei.id)
        XCTAssertEqual(layout[4], noa.id)
        XCTAssertEqual(layout[7], kai.id, "Kai moves to the first gap")

        // In the last column, a large tile moves left to fit.
        store.updateTile(forPersonID: mei.id) { $0.style = .largeTriangle }
        layout = TileLayout.cells(for: store.people)
        XCTAssertEqual(layout[2], mei.id)
        XCTAssertEqual(layout[0], ada.id)
        XCTAssertEqual(layout[4], noa.id)
        XCTAssertEqual(Set(layout.values), Set([ada, grace, kai, mei, noa].map(\.id)))
        for (cell, id) in layout {
            let span = store.person(id: id)!.tile.span
            XCTAssertNotNil(TileLayout.covered(anchor: cell, span: span))
        }
        let covered = layout.flatMap { TileLayout.covered(anchor: $0, span: store.person(id: $1)!.tile.span)! }
        XCTAssertEqual(covered.count, Set(covered).count, "no overlaps")
    }

    func testMovingALargeTileSendsTheTileThereToItsOldSpot() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!     // 0
        let grace = store.addPerson(named: "Grace")! // 1
        store.updateTile(forPersonID: ada.id) { $0.style = .largeSquare }
        // Ada covers 0, 1, 4, 5; Grace was pushed to 2.
        XCTAssertEqual(TileLayout.cells(for: store.people)[2], grace.id)

        store.moveTile(personID: ada.id, toCell: 3)
        let layout = TileLayout.cells(for: store.people)
        XCTAssertEqual(layout[2], ada.id, "moved left to fit, covering Grace")
        XCTAssertEqual(layout[0], grace.id, "Grace takes Ada's old spot")
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
