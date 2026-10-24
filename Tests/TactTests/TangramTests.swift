import XCTest
@testable import Tact

final class TangramTests: XCTestCase {
    // Quarters of a cell: 0 top, 1 right, 2 bottom, 3 left.
    private func quarters(_ cell: Int, _ parts: Int...) -> Set<Int> {
        Set(parts.map { cell * 4 + $0 })
    }

    private func footprint(_ piece: TangramPiece, at anchor: Int = 0) -> Set<Int> {
        TangramLayout.footprint(of: piece, at: anchor)!
    }

    func testTrianglesCoverHalfACellAndOppositeOnesShareIt() {
        let turns = (0..<4).map { footprint(TangramPiece(shape: .triangle, quarterTurns: $0)) }
        XCTAssertEqual(turns[0], quarters(0, 2, 3), "right angle bottom-left")
        XCTAssertEqual(turns[1], quarters(0, 0, 3), "top-left")
        XCTAssertEqual(turns[2], quarters(0, 0, 1), "top-right")
        XCTAssertEqual(turns[3], quarters(0, 1, 2), "bottom-right")
        XCTAssertTrue(turns[0].isDisjoint(with: turns[2]))
        XCTAssertTrue(turns[1].isDisjoint(with: turns[3]))
        XCTAssertFalse(turns[0].isDisjoint(with: turns[1]))
        XCTAssertEqual(footprint(TangramPiece(shape: .triangle, quarterTurns: 6)), turns[2], "turns wrap")
    }

    func testTiltedSquareIsADiamondThatFourTrianglesFitAround() {
        let diamond = footprint(TangramPiece(shape: .square, isTilted: true))
        XCTAssertEqual(diamond, quarters(0, 1, 2).union(quarters(1, 2, 3)).union(quarters(4, 0, 1)).union(quarters(5, 0, 3)))

        let corners = [(0, 1), (1, 2), (4, 0), (5, 3)].map { cell, turns in
            footprint(TangramPiece(shape: .triangle, quarterTurns: turns), at: cell)
        }
        var all = diamond
        for corner in corners {
            XCTAssertTrue(all.isDisjoint(with: corner))
            all.formUnion(corner)
        }
        XCTAssertEqual(all, footprint(TangramPiece(shape: .largeSquare)), "together they fill a two-by-two square")
    }

    func testPieceSizes() {
        XCTAssertEqual(footprint(TangramPiece(shape: .square)).count, 4)
        XCTAssertEqual(footprint(TangramPiece(shape: .circle)).count, 4)
        XCTAssertEqual(footprint(TangramPiece(shape: .largeTriangle, quarterTurns: 3)).count, 8)
        XCTAssertEqual(footprint(TangramPiece(shape: .largeSquare)).count, 16)
        XCTAssertEqual(footprint(TangramPiece(shape: .largeSquare, isTilted: true)).count, 32)
        XCTAssertNil(TangramLayout.footprint(of: TangramPiece(shape: .square, isTilted: true), at: 3), "off the right edge")
        XCTAssertEqual(TangramLayout.fitting(3, size: 2), 2)
        XCTAssertEqual(TangramLayout.fitting(5, size: 4), 4)
    }

    func testRotatingTurnsTrianglesAndTipsSquares() {
        var triangle = TangramPiece(shape: .triangle)
        triangle.rotate()
        XCTAssertEqual(triangle.quarterTurns, 1)
        var square = TangramPiece(shape: .largeSquare)
        square.rotate()
        XCTAssertTrue(square.isTilted)
        XCTAssertEqual(square.blockSize, 4)
        square.rotate()
        XCTAssertFalse(square.isTilted)
        XCTAssertFalse(TangramPiece(shape: .circle).canRotate)
    }

    func testOppositeTrianglesPairUpInOneCell() {
        let a = Person(name: "A", tangram: TangramPiece(shape: .triangle, quarterTurns: 0))
        let b = Person(name: "B", tangram: TangramPiece(shape: .triangle, quarterTurns: 1))
        let c = Person(name: "C", tangram: TangramPiece(shape: .triangle, quarterTurns: 2))
        let anchors = TangramLayout.anchors(for: [a, b, c])
        XCTAssertEqual(anchors[a.id], 0)
        XCTAssertEqual(anchors[b.id], 1, "overlaps A, so it takes the next cell")
        XCTAssertEqual(anchors[c.id], 0, "fills the other half of A's cell")
    }

    /// Applies a packing and checks it keeps shapes, has no overlaps, and is
    /// what the layout shows. Returns the rows used.
    private func applyPacking(_ people: inout [Person], seed: UInt64 = 1) -> Int {
        var generator = SeededGenerator(seed: seed)
        let packed = TangramLayout.packed(people, using: &generator)
        XCTAssertEqual(packed.count, people.count)
        for index in people.indices {
            let piece = packed[people[index].id]!
            XCTAssertEqual(piece.shape, people[index].tangram.shape)
            XCTAssertEqual(piece.isTilted, people[index].tangram.isTilted)
            people[index].tangram = piece
        }
        let anchors = TangramLayout.anchors(for: people)
        var covered = Set<Int>()
        for person in people {
            XCTAssertEqual(anchors[person.id], person.tangram.cell, "the layout keeps every packed spot")
            let quarters = TangramLayout.footprint(of: person.tangram, at: person.tangram.cell!)!
            XCTAssertTrue(covered.isDisjoint(with: quarters))
            covered.formUnion(quarters)
        }
        return covered.max()! / 4 / TangramLayout.columns + 1
    }

    func testFitTogetherPairsTrianglesIntoCells() {
        var people = (0..<4).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, cell: $0 * 5)) }
        XCTAssertEqual(applyPacking(&people), 1)
        let cells = people.map { $0.tangram.cell! }
        XCTAssertEqual(Set(cells), [0, 1], "four triangles make two full cells")
    }

    func testFitTogetherFillsTheCornersAroundADiamond() {
        var people = (0..<4).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, cell: 20 + $0)) }
        people.append(Person(name: "D", tangram: TangramPiece(shape: .square, isTilted: true, cell: 30)))
        people.append(Person(name: "S", tangram: TangramPiece(shape: .largeSquare)))
        XCTAssertEqual(applyPacking(&people), 2, "a large square, and a diamond with four triangles round it")
        XCTAssertEqual(Set(people.prefix(4).map { $0.tangram.cell! }).count, 4, "one triangle in each corner")
    }

    func testFitTogetherPutsDiamondsSideBySideBeforeASquareThatCannotShareTheirRows() {
        var people = [
            Person(name: "Herb", tangram: TangramPiece(shape: .square, cell: 2)),
            Person(name: "Pili", tangram: TangramPiece(shape: .triangle, quarterTurns: 2, cell: 4)),
            Person(name: "One", tangram: TangramPiece(shape: .square, isTilted: true, cell: 0)),
            Person(name: "Wehena", tangram: TangramPiece(shape: .triangle, quarterTurns: 1, cell: 9)),
            Person(name: "Three", tangram: TangramPiece(shape: .triangle, quarterTurns: 3, cell: 10)),
            Person(name: "Kirby", tangram: TangramPiece(shape: .square, isTilted: true, cell: 5)),
        ]
        XCTAssertEqual(applyPacking(&people), 3)
        XCTAssertEqual(Set([people[2].tangram.cell!, people[5].tangram.cell!]), [0, 2], "diamonds share the top two rows")
        XCTAssertEqual(people[0].tangram.cell, 8, "the square sits alone in the last row")
    }

    func testFitTogetherIsSnugEveryTimeButVaries() {
        let pieces = [TangramPiece(shape: .square, isTilted: true), TangramPiece(shape: .square),
                      TangramPiece(shape: .largeTriangle)] + (0..<5).map { TangramPiece(shape: .triangle, quarterTurns: $0) }
        let people = pieces.enumerated().map { Person(name: "P\($0)", tangram: $1) }
        var arrangements = Set<[Int]>()
        var rows = Set<Int>()
        for seed: UInt64 in 1...12 {
            var packed = people
            rows.insert(applyPacking(&packed, seed: seed))
            arrangements.insert(packed.map { $0.tangram.cell! * 4 + (($0.tangram.quarterTurns % 4) + 4) % 4 })
        }
        XCTAssertEqual(rows.count, 1, "every press is as snug as the best found")
        XCTAssertGreaterThan(arrangements.count, 1, "but presses don't all look the same")
    }

    func testFitTogetherPicksSomethingNewWhenItCan() {
        var people = (0..<3).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, quarterTurns: $0)) }
        _ = applyPacking(&people)
        for seed: UInt64 in 2...6 {
            var again = people
            _ = applyPacking(&again, seed: seed)
            XCTAssertNotEqual(again.map(\.tangram), people.map(\.tangram), "seed \(seed)")
        }
    }

    func testFitTogetherHandlesEveryShape() {
        var people = TangramPiece.Shape.allCases.flatMap { shape in
            [false, true].map { tilted in
                Person(name: shape.title, tangram: TangramPiece(shape: shape, quarterTurns: 3, isTilted: tilted))
            }
        }
        people += (0..<7).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, quarterTurns: $0)) }
        let rows = applyPacking(&people)
        let area = people.reduce(0) { $0 + TangramLayout.footprint(of: $1.tangram, at: 0)!.count }
        XCTAssertLessThanOrEqual(rows, area / 16 + 3, "close to the fewest rows the pieces could fill")
    }

    func testPersonWithoutPieceGetsOneFromItsSeedAndRoundTrips() throws {
        let json = #"{"id":"6D1A4F7E-1C0B-4E8B-9D6A-1234567890AB","name":"Ada","imageSection":7}"#.data(using: .utf8)!
        var person = try JSONDecoder().decode(Person.self, from: json)
        XCTAssertEqual(person.tangram, TangramPiece(seed: 7))

        person.tangram = TangramPiece(shape: .largeSquare, quarterTurns: 3, isTilted: true, cell: 4)
        let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        XCTAssertEqual(decoded.tangram, person.tangram)

        let odd = #"{"shape":"hexagon","cell":-2}"#.data(using: .utf8)!
        XCTAssertEqual(try JSONDecoder().decode(TangramPiece.self, from: odd), TangramPiece(shape: .triangle))
    }
}

/// SplitMix64, so packing tests are repeatable.
struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

extension TactStoreTests {
    /// A store holding people with the given pieces, in order.
    private func makeTangramStore(_ pieces: [TangramPiece]) throws -> (TactStore, [UUID]) {
        let directory = TestSupport.temporaryDirectory()
        let people = pieces.enumerated().map { Person(name: "P\($0)", tangram: $1) }
        try PersistenceController(directory: directory).save(PersistedData(people: people))
        return (TestSupport.makeStore(directory: directory, defaults: TestSupport.defaults()), people.map(\.id))
    }

    func testDroppingATriangleOntoAHalfFullCellTurnsItToFit() throws {
        let (store, ids) = try makeTangramStore([TangramPiece(shape: .triangle), TangramPiece(shape: .triangle)])
        XCTAssertEqual(TangramLayout.anchors(for: store.people)[ids[1]], 1)

        store.moveTangram(personID: ids[1], toCell: 0)
        let anchors = TangramLayout.anchors(for: store.people)
        XCTAssertEqual(anchors[ids[0]], 0, "the first stays")
        XCTAssertEqual(anchors[ids[1]], 0, "the second fills the other half")
        XCTAssertEqual(store.person(id: ids[1])!.tangram.quarterTurns % 4, 2)
    }

    func testTiltingASquarePushesAsideThePiecesItNowCovers() throws {
        let (store, ids) = try makeTangramStore(Array(repeating: TangramPiece(shape: .square), count: 3))
        store.updateTangram(forPersonID: ids[0]) { $0.rotate() }
        let anchors = TangramLayout.anchors(for: store.people)
        XCTAssertEqual(anchors[ids[0]], 0, "the diamond spans cells 0, 1, 4 and 5")
        XCTAssertEqual(anchors[ids[2]], 2, "the third was not in the way")
        XCTAssertEqual(anchors[ids[1]], 3, "the second moves to the first gap")
        let covered = store.people.flatMap { TangramLayout.footprint(of: $0.tangram, at: anchors[$0.id]!)! }
        XCTAssertEqual(covered.count, Set(covered).count, "no overlaps")
    }
}
