import XCTest
@testable import Tact

final class TangramTests: XCTestCase {
    typealias Point = TangramPiece.Point

    private func overlaps(_ a: TangramPiece, at pa: Point, _ b: TangramPiece, at pb: Point) -> Bool {
        TangramLayout.separation(a, at: pa, from: b, at: pb) != nil
    }

    /// Every pair of placed pieces is apart.
    private func assertNoOverlaps(_ people: [Person], _ positions: [UUID: Point],
                                  file: StaticString = #filePath, line: UInt = #line) {
        for (i, a) in people.enumerated() {
            for b in people[(i + 1)...] {
                XCTAssertFalse(overlaps(a.tangram, at: positions[a.id]!, b.tangram, at: positions[b.id]!),
                               "\(a.name) overlaps \(b.name)", file: file, line: line)
            }
        }
    }

    func testShapesAreBuiltFromTriangles() {
        let h = TangramPiece.triangleHeight
        XCTAssertEqual(TangramPiece.Shape.allCases.map(\.triangleCount), [1, 2, 3, 6])
        XCTAssertEqual(TangramPiece(shape: .triangle).halfExtent.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(TangramPiece(shape: .hexagon).halfExtent.x, 1, accuracy: 1e-9)
        XCTAssertEqual(TangramPiece(shape: .hexagon).halfExtent.y, h, accuracy: 1e-9)
        XCTAssertEqual(TangramPiece(shape: .trapezoid).halfExtent, Point(x: 1, y: h / 2))
        XCTAssertEqual(TangramPiece(shape: .diamond).halfExtent, Point(x: 0.75, y: h / 2))
        // A hexagon turned by 60° is the same hexagon.
        let turned = TangramPiece(shape: .hexagon, sixths: 1).corners
        for corner in turned {
            XCTAssertTrue(TangramPiece(shape: .hexagon).corners.contains {
                abs($0.x - corner.x) < 1e-9 && abs($0.y - corner.y) < 1e-9
            })
        }
    }

    func testEachShapeHasItsOwnColourUntilOneIsPicked() {
        let colours = Set(TangramPiece.Shape.allCases.map(\.defaultColorIndex))
        XCTAssertEqual(colours.count, 4, "the four shapes are told apart by colour")
        var piece = TangramPiece(shape: .hexagon)
        XCTAssertEqual(piece.resolvedColorIndex, TangramPiece.Shape.hexagon.defaultColorIndex)
        piece.colorIndex = 7
        XCTAssertEqual(piece.resolvedColorIndex, 7)
        piece.shape = .triangle
        XCTAssertEqual(piece.resolvedColorIndex, 7, "a chosen colour sticks to the person, not the shape")
    }

    func testRotatingTurnsBySixthsAndHexagonsNeedNot() {
        var triangle = TangramPiece(shape: .triangle)
        triangle.rotate()
        XCTAssertEqual(triangle.sixths, 1)
        for _ in 0..<5 { triangle.rotate() }
        XCTAssertEqual(triangle.sixths, 0, "six turns bring it round")
        XCTAssertFalse(TangramPiece(shape: .hexagon).canRotate)
        XCTAssertTrue(TangramPiece(shape: .trapezoid).canRotate)
    }

    func testTrianglesFitPointToPointAndOverlapWhenPushedIn() {
        let up = TangramPiece(shape: .triangle)
        let down = TangramPiece(shape: .triangle, sixths: 3)
        // Side by side in a row, an up and a down triangle sit a third of a
        // triangle apart in height and their slanted edges run alongside.
        let h = TangramPiece.triangleHeight
        XCTAssertFalse(overlaps(up, at: Point(x: 1, y: 1), down, at: Point(x: 1.6, y: 1 - h / 3)))
        XCTAssertTrue(overlaps(up, at: Point(x: 1, y: 1), down, at: Point(x: 1.3, y: 1 - h / 3)))
        XCTAssertTrue(overlaps(up, at: Point(x: 1, y: 1), up, at: Point(x: 1.2, y: 1)))
        // Far apart on the same row.
        XCTAssertFalse(overlaps(up, at: Point(x: 1, y: 1), up, at: Point(x: 3, y: 1)))
    }

    func testSeparationPushesTheMoverStraightOut() {
        let a = TangramPiece(shape: .hexagon)
        let b = TangramPiece(shape: .hexagon)
        let push = TangramLayout.separation(a, at: Point(x: 2, y: 2), from: b, at: Point(x: 2 + 1.5, y: 2))!
        XCTAssertLessThan(push.x, 0, "a moves left, away from b, along the nearest edge")
        XCTAssertFalse(overlaps(a, at: Point(x: 2, y: 2) + push, b, at: Point(x: 3.5, y: 2)))
    }

    func testUnplacedPiecesTakeTheFirstFreeSpotsWithoutOverlapping() {
        let people = (0..<6).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, sixths: $0 % 2)) }
            + [Person(name: "H", tangram: TangramPiece(shape: .hexagon))]
        let positions = TangramLayout.positions(for: people)
        XCTAssertEqual(positions.count, people.count)
        assertNoOverlaps(people, positions)
        for person in people {
            let centre = positions[person.id]!
            let box = person.tangram.bounds
            XCTAssertGreaterThanOrEqual(centre.x + box.min.x, -1e-9)
            XCTAssertLessThanOrEqual(centre.x + box.max.x, TangramLayout.width + 1e-9)
            XCTAssertGreaterThanOrEqual(centre.y + box.min.y, -1e-9)
        }
        XCTAssertEqual(positions[people[0].id]!.y, TangramPiece.triangleHeight * 2 / 3, accuracy: 1e-9,
                       "the first triangle sits against the top")
    }

    func testPlacedPiecesKeepTheirSpotsAndClampToTheCanvas() {
        let inside = Person(name: "In", tangram: TangramPiece(shape: .diamond, position: Point(x: 2, y: 3)))
        let outside = Person(name: "Out", tangram: TangramPiece(shape: .hexagon, position: Point(x: 9, y: -4)))
        let positions = TangramLayout.positions(for: [inside, outside])
        XCTAssertEqual(positions[inside.id], Point(x: 2, y: 3))
        let hexagon = positions[outside.id]!
        XCTAssertEqual(hexagon.x, TangramLayout.width - 1, accuracy: 1e-9, "pulled back inside the right edge")
        XCTAssertEqual(hexagon.y, TangramPiece.triangleHeight, accuracy: 1e-9, "and below the top")
    }

    func testSettlingPushesAChainOfPiecesAlong() {
        let pieces = (0..<3).map { TangramPiece(shape: .hexagon, position: Point(x: 2, y: 1 + Double($0) * 1.6)) }
        let people = pieces.enumerated().map { Person(name: "H\($0)", tangram: $1) }
        var centres = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.tangram.position!) })
        TangramLayout.settle(&centres, pieces: Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.tangram) }),
                             fixed: people[0].id)
        XCTAssertEqual(centres[people[0].id], Point(x: 2, y: 1), "the held piece does not move")
        assertNoOverlaps(people, centres)
        XCTAssertGreaterThan(centres[people[1].id]!.y, 1.6)
        XCTAssertGreaterThan(centres[people[2].id]!.y, centres[people[1].id]!.y, "the second shoves the third on")
    }

    /// Applies a packing and checks it keeps shapes, has no overlaps, and is
    /// what the layout shows. Returns the lowest edge in cells.
    private func applyPacking(_ people: inout [Person], seed: UInt64 = 1) -> Double {
        var generator = SeededGenerator(seed: seed)
        let packed = TangramLayout.packed(people, using: &generator)
        XCTAssertEqual(packed.count, people.count)
        for index in people.indices {
            let piece = packed[people[index].id]!
            XCTAssertEqual(piece.shape, people[index].tangram.shape)
            XCTAssertEqual(piece.colorIndex, people[index].tangram.colorIndex)
            XCTAssertNotNil(piece.position)
            people[index].tangram = piece
        }
        let positions = TangramLayout.positions(for: people)
        for person in people {
            XCTAssertEqual(positions[person.id], person.tangram.position, "the layout keeps every packed spot")
        }
        assertNoOverlaps(people, positions)
        return people.map { $0.tangram.position!.y + $0.tangram.bounds.max.y }.max()!
    }

    func testPackedPiecesLieOnTheLatticeEdgeToEdge() {
        var people = [TangramPiece(shape: .hexagon), TangramPiece(shape: .trapezoid), TangramPiece(shape: .diamond)]
            .enumerated().map { Person(name: "P\($0)", tangram: $1) }
            + (0..<5).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle)) }
        _ = applyPacking(&people)
        var covered = Set<Int>()
        for person in people {
            let triangles = TangramLayout.latticeTriangles(of: person.tangram, at: person.tangram.position!)
            XCTAssertNotNil(triangles, "\(person.name) sits on the lattice")
            XCTAssertEqual(triangles?.count, person.tangram.area, "\(person.name) covers exactly its triangles")
            XCTAssertTrue(covered.isDisjoint(with: triangles ?? []))
            covered.formUnion(triangles ?? [])
        }
        // 6 + 3 + 2 + 5 = 16 triangles; a row across four cells holds 7, so
        // they fit in three rows with no piece pushed down by a gap.
        let bottom = people.map { $0.tangram.position!.y + $0.tangram.bounds.max.y }.max()!
        XCTAssertLessThanOrEqual(bottom, TangramPiece.triangleHeight * 3 + 1e-6)
    }

    func testLatticeTrianglesCountAndRejectOffLatticePieces() {
        let h = TangramPiece.triangleHeight
        let up = TangramPiece(shape: .triangle)
        // Row 0 vertices sit on whole numbers, row 1 on halves.
        XCTAssertEqual(TangramLayout.latticeTriangles(of: up, at: Point(x: 1, y: 2 * h / 3))?.count, 1)
        XCTAssertNil(TangramLayout.latticeTriangles(of: up, at: Point(x: 0.5, y: 2 * h / 3)), "apex between vertices")
        XCTAssertNil(TangramLayout.latticeTriangles(of: up, at: Point(x: 1, y: 0.1)), "corner above the canvas")
        let hexagon = TangramPiece(shape: .hexagon)
        XCTAssertEqual(TangramLayout.latticeTriangles(of: hexagon, at: Point(x: 1.5, y: h))?.count, 6)
        XCTAssertEqual(TangramLayout.latticeTriangles(of: TangramPiece(shape: .trapezoid), at: Point(x: 1.5, y: h / 2))?.count, 3)
        XCTAssertEqual(TangramLayout.latticeTriangles(of: TangramPiece(shape: .diamond), at: Point(x: 1.75, y: h / 2))?.count, 2)
    }

    func testFitTogetherFitsTrianglesIntoARow() {
        var people = (0..<5).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, position: Point(x: 2, y: Double($0) * 2 + 1))) }
        let bottom = applyPacking(&people)
        XCTAssertLessThanOrEqual(bottom, TangramPiece.triangleHeight + 0.01,
                                 "five triangles, turned up and down, fit in one row across four cells")
    }

    func testFitTogetherIsSnugEveryTimeButVaries() {
        let pieces = [TangramPiece(shape: .hexagon), TangramPiece(shape: .trapezoid), TangramPiece(shape: .diamond)]
            + (0..<4).map { TangramPiece(shape: .triangle, sixths: $0) }
        let people = pieces.enumerated().map { Person(name: "P\($0)", tangram: $1) }
        var arrangements = Set<[Int]>()
        var bottoms = Set<Int>()
        for seed: UInt64 in 1...8 {
            var packed = people
            bottoms.insert(Int((applyPacking(&packed, seed: seed) * 100).rounded()))
            arrangements.insert(packed.map { Int(($0.tangram.position!.x * 100).rounded()) * 1000 + $0.tangram.sixths })
        }
        XCTAssertLessThanOrEqual(bottoms.max()! - bottoms.min()!, 50, "every press is about as snug as the best found")
        XCTAssertGreaterThan(arrangements.count, 1, "but presses don't all look the same")
    }

    func testFitTogetherHandlesEveryShape() {
        var people = TangramPiece.Shape.allCases.enumerated().map { index, shape in
            Person(name: shape.title, tangram: TangramPiece(shape: shape, sixths: index))
        }
        people += (0..<5).map { Person(name: "T\($0)", tangram: TangramPiece(shape: .triangle, sixths: $0)) }
        let bottom = applyPacking(&people)
        let area = Double(people.reduce(0) { $0 + $1.tangram.area }) * TangramPiece.triangleHeight / 2
        XCTAssertLessThanOrEqual(bottom, area / TangramLayout.width + 2.5, "close to the fewest rows the pieces could fill")
    }

    func testPersonWithoutPieceGetsOneFromItsSeedAndRoundTrips() throws {
        let json = #"{"id":"6D1A4F7E-1C0B-4E8B-9D6A-1234567890AB","name":"Ada","imageSection":7}"#.data(using: .utf8)!
        var person = try JSONDecoder().decode(Person.self, from: json)
        XCTAssertEqual(person.tangram, TangramPiece(seed: 7))
        XCTAssertEqual(person.tangram.shape, .triangle)
        XCTAssertEqual(person.tangram.sixths, 1)

        person.tangram = TangramPiece(shape: .trapezoid, sixths: 4, position: Point(x: 1.25, y: 2.5), colorIndex: 9)
        let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        XCTAssertEqual(decoded.tangram, person.tangram)
    }

    func testOldSquareLatticePiecesBecomePatternBlocksWithoutASpot() throws {
        func decode(_ json: String) throws -> TangramPiece {
            try JSONDecoder().decode(TangramPiece.self, from: json.data(using: .utf8)!)
        }
        XCTAssertEqual(try decode(#"{"shape":"square","quarterTurns":1,"isTilted":true,"cell":5}"#),
                       TangramPiece(shape: .diamond))
        XCTAssertEqual(try decode(#"{"shape":"largeTriangle","cell":2}"#).shape, .trapezoid)
        XCTAssertEqual(try decode(#"{"shape":"largeSquare"}"#).shape, .hexagon)
        XCTAssertEqual(try decode(#"{"shape":"circle"}"#).shape, .hexagon)
        XCTAssertEqual(try decode(#"{"shape":"blob","sixths":-1,"x":"no"}"#), TangramPiece(shape: .triangle, sixths: 5))
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

    func testDraggingAPieceOntoAnotherPushesItAside() throws {
        let (store, ids) = try makeTangramStore([
            TangramPiece(shape: .hexagon, position: .init(x: 1, y: 2)),
            TangramPiece(shape: .hexagon, position: .init(x: 3, y: 2)),
        ])
        store.moveTangram(personID: ids[0], to: .init(x: 2.2, y: 2))
        let first = store.person(id: ids[0])!.tangram
        let second = store.person(id: ids[1])!.tangram
        XCTAssertEqual(first.position, .init(x: 2.2, y: 2), "the dragged piece goes where the finger is")
        XCTAssertNil(TangramLayout.separation(first, at: first.position!, from: second, at: second.position!))
        XCTAssertEqual(second.position!.x, TangramLayout.width - 1, accuracy: 1e-9,
                       "the other is pushed right until it meets the edge")
        XCTAssertNotEqual(second.position!.y, 2, "and then slides out of the way")
    }

    func testChangingShapePushesAsideThePiecesItNowCovers() throws {
        let (store, ids) = try makeTangramStore([
            TangramPiece(shape: .triangle, position: .init(x: 1, y: 1)),
            TangramPiece(shape: .triangle, sixths: 3, position: .init(x: 1.6, y: 1 - TangramPiece.triangleHeight / 3)),
        ])
        store.updateTangram(forPersonID: ids[0]) { $0.shape = .hexagon }
        let big = store.person(id: ids[0])!.tangram
        let small = store.person(id: ids[1])!.tangram
        XCTAssertEqual(big.position, .init(x: 1, y: 1), "the changed piece stays put")
        XCTAssertNil(TangramLayout.separation(big, at: big.position!, from: small, at: small.position!))
    }

    func testTurningByStepsWrapsEitherWay() {
        var piece = TangramPiece(shape: .trapezoid, sixths: 5)
        piece.turn(by: 1)
        XCTAssertEqual(piece.sixths, 0)
        piece.turn(by: -1)
        XCTAssertEqual(piece.sixths, 5)
        piece.turn(by: -7)
        XCTAssertEqual(piece.sixths, 4)
        piece.rotate()
        XCTAssertEqual(piece.sixths, 5)
    }
}
