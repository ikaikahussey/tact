import XCTest
import CoreGraphics
@testable import Tact

/// Stacks: tiles grouped into one cell, and the tray an open stack's tiles
/// are laid out in.
final class TileStackTests: XCTestCase {
    private var store: TactStore!
    private var a: Person!, b: Person!, c: Person!, d: Person!

    override func setUp() {
        super.setUp()
        store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        a = store.addPerson(named: "A")   // cell 0
        b = store.addPerson(named: "B")   // cell 1
        c = store.addPerson(named: "C")   // cell 2
        d = store.addPerson(named: "D")   // cell 3
    }

    private var cells: [Int: UUID] { TileLayout.cells(for: store.people) }
    private func tile(_ person: Person) -> TileArt { store.person(id: person.id)!.tile }

    // MARK: Stacking

    func testStackingPutsTilesInTheFirstOfTheirCells() {
        let stack = store.stackTiles(personIDs: [b.id, d.id])
        XCTAssertNotNil(stack)
        XCTAssertEqual(tile(b).stack, stack)
        XCTAssertEqual(tile(d).stack, stack)
        XCTAssertNil(tile(a).stack)

        XCTAssertEqual(cells, [0: a.id, 1: b.id, 2: c.id], "the stack is one tile; D's old cell is left empty")
        XCTAssertEqual(TileLayout.stacks(for: store.people), [stack!: [b.id, d.id]])
        XCTAssertEqual(TileLayout.covered(for: store.people), [d.id: b.id])
        XCTAssertEqual(tile(d).cell, 1, "everyone in the stack is pinned to its cell")
    }

    func testStackingNeedsTwoTiles() {
        XCTAssertNil(store.stackTiles(personIDs: [a.id]))
        XCTAssertNil(store.stackTiles(personIDs: []))
        XCTAssertNil(store.stackTiles(personIDs: [a.id, UUID()]), "unknown ids do not count")
        XCTAssertNil(tile(a).stack)
        XCTAssertTrue(TileLayout.stacks(for: store.people).isEmpty)
    }

    func testStackingWithAStackMergesEveryoneInIt() {
        let first = store.stackTiles(personIDs: [b.id, d.id])!
        // C joins by being stacked with just the top tile.
        let merged = store.stackTiles(personIDs: [b.id, c.id])!
        XCTAssertEqual(merged, first, "the stack sitting first keeps its id")
        XCTAssertEqual(TileLayout.stacks(for: store.people), [first: [b.id, c.id, d.id]])
        XCTAssertEqual(cells, [0: a.id, 1: b.id])

        // A, sitting first, takes the stack to its cell under a new id.
        let all = store.stackTiles(personIDs: [a.id, d.id])!
        XCTAssertEqual(TileLayout.stacks(for: store.people), [all: [a.id, b.id, c.id, d.id]])
        XCTAssertEqual(cells, [0: a.id])
    }

    func testAStackMovesAsOneTileAndSurvivesItsTopPerson() {
        store.stackTiles(personIDs: [b.id, d.id])
        store.moveTile(personID: b.id, toCell: 6)
        XCTAssertEqual(cells[6], b.id)
        XCTAssertEqual(tile(d).cell, 6, "the tiles underneath follow")
        XCTAssertEqual(cells[0], a.id)
        XCTAssertEqual(cells[2], c.id)

        // Dropping a tile on the stack shifts the stack like any tile.
        store.moveTile(personID: a.id, toCell: 6)
        XCTAssertEqual(cells[6], a.id)
        XCTAssertEqual(cells[5], b.id)
        XCTAssertEqual(tile(d).cell, 5)

        // With the top person gone the next one holds the cell.
        store.deletePerson(id: b.id)
        XCTAssertEqual(cells[5], d.id)
        XCTAssertTrue(TileLayout.stacks(for: store.people).isEmpty, "one tile is not a stack")
    }

    func testCoveredTilesCannotBeMovedOnTheirOwn() {
        store.stackTiles(personIDs: [b.id, d.id])
        let before = store.people
        store.moveTile(personID: d.id, toCell: 9)
        XCTAssertEqual(store.people, before)
    }

    // MARK: Unstacking

    func testUnstackingLaysTheTilesOutAfterTheStack() {
        let stack = store.stackTiles(personIDs: [a.id, b.id, d.id])!   // stack at 0, C at 2
        store.unstack(id: stack)
        XCTAssertEqual(cells, [0: a.id, 1: b.id, 2: c.id, 3: d.id], "the top stays; the rest take the next empty cells")
        XCTAssertTrue(store.people.allSatisfy { $0.tile.stack == nil })
        XCTAssertTrue(TileLayout.stacks(for: store.people).isEmpty)
    }

    func testRemovingOneTileLeavesTheRestStacked() {
        let stack = store.stackTiles(personIDs: [a.id, b.id, c.id])!   // stack at 0, D at 3
        store.removeFromStack(personID: a.id)
        XCTAssertNil(tile(a).stack)
        XCTAssertEqual(cells, [0: b.id, 1: a.id, 3: d.id], "the top tile left; the next one is on top in the same cell")
        XCTAssertEqual(TileLayout.stacks(for: store.people), [stack: [b.id, c.id]])

        // The last pair comes apart altogether.
        store.removeFromStack(personID: c.id)
        XCTAssertEqual(cells, [0: b.id, 1: a.id, 2: c.id, 3: d.id])
        XCTAssertNil(tile(b).stack)
        XCTAssertNil(tile(c).stack)

        // Someone not in a stack: nothing happens.
        let before = store.people
        store.removeFromStack(personID: d.id)
        XCTAssertEqual(store.people, before)
    }

    func testDraggingATileOutOfAStackPutsItOnTheCell() {
        store.stackTiles(personIDs: [a.id, b.id, c.id])   // stack at 0, D at 3
        store.moveOutOfStack(personID: c.id, toCell: 9)
        XCTAssertEqual(cells, [0: a.id, 3: d.id, 9: c.id])
        XCTAssertNil(tile(c).stack)
        XCTAssertEqual(TileLayout.covered(for: store.people), [b.id: a.id])

        // Onto an occupied cell: the tiles there make room.
        store.moveOutOfStack(personID: b.id, toCell: 3)
        XCTAssertEqual(cells[3], b.id)
        XCTAssertEqual(cells[0], a.id)
        XCTAssertEqual(Set(cells.values), [a.id, b.id, c.id, d.id])
        XCTAssertTrue(store.people.allSatisfy { $0.tile.stack == nil })
    }

    // MARK: Layout

    func testBringTogetherCountsAStackAsOneTile() {
        store.stackTiles(personIDs: [b.id, d.id])
        XCTAssertTrue(TileLayout.isCompact(store.people), "three tiles in the first three cells")
        store.moveTile(personID: a.id, toCell: 9)
        XCTAssertFalse(TileLayout.isCompact(store.people))
        store.bringTilesTogether()
        XCTAssertEqual(cells, [0: b.id, 1: c.id, 2: a.id])
        XCTAssertEqual(tile(d).cell, 0)
        XCTAssertTrue(TileLayout.isCompact(store.people))
    }

    func testFreeCellsSkipTakenOnes() {
        XCTAssertEqual(TileLayout.freeCells(after: 1, count: 3, taken: [0, 1, 2, 4]), [3, 5, 6])
        XCTAssertEqual(TileLayout.freeCells(after: 0, count: 0, taken: []), [])
    }

    func testGridShowsAStackAsOneTile() {
        store.stackTiles(personIDs: [b.id, d.id])
        let items = PeopleGridItems(people: store.people, notes: store.notes, query: "")
        XCTAssertEqual(items.tiles.map(\.person.id), [a.id, b.id, c.id])
        XCTAssertEqual(items.tiles.map(\.isStack), [false, true, false])
        XCTAssertEqual(items.tiles[1].stack.map(\.id), [b.id, d.id])
        XCTAssertEqual(items.tiles[1].ids, [b.id, d.id])
        XCTAssertEqual(items.tiles[0].ids, [a.id])
        XCTAssertEqual(items.selectableIDs, [a.id, b.id, d.id, c.id])

        // A search that finds someone under the top tile shows the stack.
        let found = PeopleGridItems(people: store.people, notes: store.notes, query: "D")
        XCTAssertEqual(found.tiles.map(\.person.id), [b.id])
        XCTAssertEqual(found.tiles.map(\.cell), [1])
    }

    func testStackedTileShowsUpToTwoTilesUnderneath() {
        XCTAssertEqual(StackedTile.layers(count: 1), 0)
        XCTAssertEqual(StackedTile.layers(count: 2), 1)
        XCTAssertEqual(StackedTile.layers(count: 3), 2)
        XCTAssertEqual(StackedTile.layers(count: 9), 2)
        XCTAssertGreaterThanOrEqual(StackedTile.step(size: 20), 3)
    }

    // MARK: Coding

    func testStackIsSavedWithTheTile() throws {
        let stack = UUID()
        let art = TileArt(quarterTurns: 1, colorIndex: 3, cell: 7, stack: stack)
        let decoded = try JSONDecoder().decode(TileArt.self, from: JSONEncoder().encode(art))
        XCTAssertEqual(decoded, art)
        XCTAssertEqual(decoded.stack, stack)

        // Tiles saved before stacks have none.
        let old = try JSONDecoder().decode(TileArt.self, from: Data(#"{"quarterTurns":0,"colorIndex":2,"showsPhoto":true}"#.utf8))
        XCTAssertNil(old.stack)
    }

    func testStacksSurviveSavingAndLoading() {
        let directory = TestSupport.temporaryDirectory()
        let defaults = TestSupport.defaults()
        let first = TestSupport.makeStore(directory: directory, defaults: defaults)
        let x = first.addPerson(named: "X")!, y = first.addPerson(named: "Y")!
        let stack = first.stackTiles(personIDs: [x.id, y.id])!
        first.flush(waitUntilDone: true)

        let second = TestSupport.makeStore(directory: directory, defaults: defaults)
        XCTAssertEqual(TileLayout.stacks(for: second.people), [stack: [x.id, y.id]])
        XCTAssertEqual(TileLayout.cells(for: second.people), [0: x.id])
    }

    // MARK: Tray

    func testOpenStackPushesTheRowsBelowDown() {
        let layout = BoardLayout.single(width: 393)
        let pitch = layout.pitch
        let tray = StackTray(cell: 5, count: 6)   // second row, six tiles: two tray rows
        XCTAssertEqual(layout.trayRows(tray), 2)
        let height = layout.trayHeight(tray)
        XCTAssertEqual(height, 2 * pitch + 2 * StackTray.inset)

        // Rows down to the stack's stay; every row below moves by the tray.
        for cell in 0..<8 {
            XCTAssertEqual(layout.origin(of: cell, tray: tray), layout.origin(of: cell), "cell \(cell)")
        }
        for cell in 8..<20 {
            let plain = layout.origin(of: cell)
            XCTAssertEqual(layout.origin(of: cell, tray: tray), CGPoint(x: plain.x, y: plain.y + height), "cell \(cell)")
        }
        // No tray: nothing moves.
        XCTAssertEqual(layout.origin(of: 12, tray: nil), layout.origin(of: 12))
        XCTAssertEqual(layout.height(rows: 5, tray: nil), layout.height(rows: 5))
        XCTAssertEqual(layout.height(rows: 5, tray: tray), layout.height(rows: 5) + height)

        // The tray fills the gap, a spacing short of the row pushed down.
        let frame = layout.trayFrame(tray)
        XCTAssertEqual(frame.minY, 2 * pitch)
        XCTAssertEqual(frame.minX, layout.pageX[0])
        XCTAssertEqual(frame.width, layout.boardWidth)
        XCTAssertEqual(frame.maxY + layout.spacing, layout.origin(of: 8, tray: tray).y)

        // Its tiles run four across from the leading edge.
        XCTAssertEqual(layout.trayOrigin(of: 0, in: tray), CGPoint(x: frame.minX, y: frame.minY + StackTray.inset))
        XCTAssertEqual(layout.trayOrigin(of: 5, in: tray),
                       CGPoint(x: frame.minX + pitch, y: frame.minY + StackTray.inset + pitch))
        let last = layout.trayOrigin(of: 5, in: tray)
        XCTAssertLessThanOrEqual(last.y + layout.cellSide + StackTray.inset, frame.maxY + layout.spacing)
    }

    func testTrayRowsRoundUpToWholeRows() {
        let layout = BoardLayout.single(width: 393)
        XCTAssertEqual(layout.trayRows(StackTray(cell: 0, count: 2)), 1)
        XCTAssertEqual(layout.trayRows(StackTray(cell: 0, count: 4)), 1)
        XCTAssertEqual(layout.trayRows(StackTray(cell: 0, count: 5)), 2)
        XCTAssertEqual(layout.trayRows(StackTray(cell: 0, count: 0)), 1)
    }

    func testTrayOnASpreadOpensOnTheStacksPageAndPushesBothPages() throws {
        let layout = try XCTUnwrap(BoardLayout.spread(width: 800, height: 600, fold: 395...405))
        let perPage = try XCTUnwrap(layout.rowsPerPage)
        // A stack in the first row of the right page.
        let cell = perPage * BoardLayout.columns + 1
        let tray = StackTray(cell: cell, count: 3)
        XCTAssertEqual(layout.slot(of: cell).page, 1)
        XCTAssertEqual(layout.trayFrame(tray).minX, layout.pageX[1])
        XCTAssertEqual(layout.trayFrame(tray).minY, layout.pitch)
        // The first drawn row stays on both pages; the second moves on both.
        XCTAssertEqual(layout.origin(of: 0, tray: tray), layout.origin(of: 0))
        XCTAssertEqual(layout.origin(of: cell, tray: tray), layout.origin(of: cell))
        XCTAssertEqual(layout.origin(of: 4, tray: tray).y, layout.origin(of: 4).y + layout.trayHeight(tray))
        XCTAssertEqual(layout.origin(of: cell + 4, tray: tray).y, layout.origin(of: cell + 4).y + layout.trayHeight(tray))
    }
}
