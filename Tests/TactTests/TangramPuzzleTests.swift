import XCTest
@testable import Tact

final class TangramPuzzleTests: XCTestCase {
    func testTrayHoldsEveryPieceWithoutOverlapAndOutsideTheSilhouette() {
        let puzzle = TangramPuzzle(figure: TangramFigure.cat)
        XCTAssertEqual(puzzle.pieces.map(\.shape), TangramPiece.allCases)
        for piece in puzzle.pieces {
            for point in piece.polygon {
                XCTAssertGreaterThanOrEqual(point.y, TangramPuzzle.trayTop - 1e-9, "\(piece.shape)")
                XCTAssertLessThanOrEqual(point.y, TangramPuzzle.height, "\(piece.shape)")
                XCTAssertTrue((0...TangramPuzzle.width).contains(point.x), "\(piece.shape)")
            }
        }
        let polygons = puzzle.pieces.map(\.polygon)
        for i in polygons.indices {
            for j in polygons.indices where j > i {
                XCTAssertLessThan(TangramPuzzle.fraction(of: [polygons[i]], coveredBy: [polygons[j]]), 0.01)
            }
        }
        XCTAssertFalse(puzzle.isSolved)
    }

    func testEveryFigureIsSolvedByItsOwnPlacements() {
        for figure in TangramFigure.all {
            var puzzle = TangramPuzzle(figure: figure)
            for placement in figure.placements {
                let id = TangramPiece.allCases.firstIndex(of: placement.piece)!
                puzzle.place(id, matching: placement)
            }
            XCTAssertTrue(puzzle.isSolved, figure.name)

            puzzle.move(0, by: CGPoint(x: 1, y: 0))
            XCTAssertFalse(puzzle.isSolved, "\(figure.name) with a piece out of place")
        }
    }

    func testIdenticalPiecesAreInterchangeable() {
        // The two large triangles swap places (each turned to fit), and the
        // silhouette still counts as filled.
        let figure = TangramFigure.fish
        var puzzle = TangramPuzzle(figure: figure)
        for placement in figure.placements {
            let id = TangramPiece.allCases.firstIndex(of: placement.piece)!
            puzzle.place(id, matching: placement)
        }
        let a = puzzle.pieces[0], b = puzzle.pieces[1]
        puzzle.move(0, by: CGPoint(x: b.center.x - a.center.x, y: b.center.y - a.center.y))
        puzzle.move(1, by: CGPoint(x: a.center.x - b.center.x, y: a.center.y - b.center.y))
        // Large triangle B's canonical shape is A turned six eighths.
        puzzle.rotate(0, by: b.rotation + 6 - a.rotation)
        puzzle.rotate(1, by: a.rotation - 6 - b.rotation)
        XCTAssertTrue(puzzle.isSolved)
    }

    func testTurningKeepsTheCentreAndEightTurnsComeBack() {
        var puzzle = TangramPuzzle(figure: nil)
        let before = puzzle.pieces[6]
        puzzle.rotate(6)
        XCTAssertEqual(puzzle.pieces[6].center, before.center)
        XCTAssertNotEqual(puzzle.pieces[6].polygon, before.polygon)
        puzzle.rotate(6, by: 7)
        for (p, q) in zip(puzzle.pieces[6].polygon, before.polygon) {
            XCTAssertEqual(p.x, q.x, accuracy: 1e-9)
            XCTAssertEqual(p.y, q.y, accuracy: 1e-9)
        }
        XCTAssertEqual(puzzle.order.last, 6, "the touched piece comes to the front")
    }

    func testFlipMirrorsOnlyTheParallelogramShape() {
        var puzzle = TangramPuzzle(figure: nil)
        let before = puzzle.pieces[6].polygon
        puzzle.flip(6)
        XCTAssertNotEqual(Set(puzzle.pieces[6].polygon.map { "\(Int(($0.x * 100).rounded())),\(Int(($0.y * 100).rounded()))" }),
                          Set(before.map { "\(Int(($0.x * 100).rounded())),\(Int(($0.y * 100).rounded()))" }))
    }

    func testDroppingNearACornerSnapsOntoIt() {
        let figure = TangramFigure.house
        var puzzle = TangramPuzzle(figure: figure)
        let placement = figure.placements[0]
        let id = TangramPiece.allCases.firstIndex(of: placement.piece)!
        puzzle.place(id, matching: placement)
        let exact = puzzle.pieces[id].polygon
        puzzle.move(id, by: CGPoint(x: 0.3, y: -0.2))
        XCTAssertTrue(puzzle.snap(id))
        for (p, q) in zip(puzzle.pieces[id].polygon, exact) {
            XCTAssertEqual(p.x, q.x, accuracy: 1e-9)
            XCTAssertEqual(p.y, q.y, accuracy: 1e-9)
        }
        puzzle.move(id, by: CGPoint(x: 3, y: 0))
        let far = puzzle.pieces[id].center
        puzzle.snap(id, within: 0.01)
        XCTAssertEqual(puzzle.pieces[id].center, far, "nothing close enough to snap to")
    }

    func testMovesStayOnTheBoard() {
        var puzzle = TangramPuzzle(figure: nil)
        puzzle.move(2, by: CGPoint(x: -100, y: 100))
        XCTAssertEqual(puzzle.pieces[2].center, CGPoint(x: 0.3, y: TangramPuzzle.height - 0.3))
        XCTAssertFalse(puzzle.isSolved, "free play has nothing to solve")
    }

    func testLabels() {
        XCTAssertEqual(TangramGameView.label(for: Person(name: "Ada Lovelace"), shape: .largeTriangleA), "Ada")
        XCTAssertEqual(TangramGameView.label(for: Person(name: "Ada Lovelace"), shape: .smallTriangleB), "AL")
        XCTAssertEqual(TangramGameView.label(for: Person(name: "kalani"), shape: .smallTriangleA), "K")
    }
}
