import Foundation

/// A person's piece on the Tangram canvas. Unlike Tiles, pieces fit together
/// along cell diagonals: each cell is split by both diagonals into four
/// quarters, and a piece covers whichever quarters lie inside it. Two right
/// triangles can share a cell, and a square turned 45° becomes a diamond
/// whose sides run along the diagonals of a two-by-two block, so four
/// triangles fill its corners. The colour is the person's tile colour.
struct TangramPiece: Codable, Equatable, Hashable {
    enum Shape: String, Codable, CaseIterable, Identifiable {
        case triangle
        case square
        case largeTriangle
        case largeSquare
        case circle

        var id: Self { self }

        var title: String {
            switch self {
            case .triangle:      return "Triangle"
            case .square:        return "Square"
            case .largeTriangle: return "Large Triangle"
            case .largeSquare:   return "Large Square"
            case .circle:        return "Circle"
            }
        }

        var isSquare: Bool { self == .square || self == .largeSquare }
        var isTriangle: Bool { self == .triangle || self == .largeTriangle }
    }

    var shape: Shape
    /// Clockwise quarter turns; only triangles look different when turned.
    var quarterTurns: Int
    /// Squares only: turned 45° into a diamond.
    var isTilted: Bool
    /// Top-left cell of the piece's block, row by row from the top-left.
    /// `nil` until placed; such pieces take the first spot they fit.
    var cell: Int?

    init(shape: Shape, quarterTurns: Int = 0, isTilted: Bool = false, cell: Int? = nil) {
        self.shape = shape
        self.quarterTurns = quarterTurns
        self.isTilted = isTilted
        self.cell = cell
    }

    /// The starting piece for a person: a small triangle turned by their seed,
    /// so a few people already pair up into squares.
    init(seed rawSeed: Int) {
        self.init(shape: .triangle, quarterTurns: abs(rawSeed) % 4)
    }

    /// Cells along each side of the square block the piece sits in.
    var blockSize: Int {
        switch shape {
        case .triangle, .circle: return 1
        case .square:            return isTilted ? 2 : 1
        case .largeTriangle:     return 2
        case .largeSquare:       return isTilted ? 4 : 2
        }
    }

    /// Corners of the piece in block units (y down), turned. A circle's
    /// outline is its block; it is drawn round.
    var polygon: [Point] {
        let n = Double(blockSize)
        let corners: [Point]
        switch shape {
        case .triangle, .largeTriangle:
            corners = [Point(x: 0, y: 0), Point(x: 0, y: n), Point(x: n, y: n)]
        case .square, .largeSquare:
            corners = isTilted
                ? [Point(x: n / 2, y: 0), Point(x: n, y: n / 2), Point(x: n / 2, y: n), Point(x: 0, y: n / 2)]
                : Self.block(n)
        case .circle:
            corners = Self.block(n)
        }
        guard shape.isTriangle else { return corners }
        let turns = ((quarterTurns % 4) + 4) % 4
        return corners.map { corner in
            (0..<turns).reduce(corner) { point, _ in Point(x: n - point.y, y: point.x) }
        }
    }

    var canRotate: Bool { shape != .circle }

    /// Triangles turn a quarter; squares tip between square and diamond.
    mutating func rotate() {
        if shape.isSquare {
            isTilted.toggle()
        } else {
            quarterTurns += 1
        }
    }

    struct Point: Equatable {
        var x: Double
        var y: Double
    }

    private static func block(_ n: Double) -> [Point] {
        [Point(x: 0, y: 0), Point(x: n, y: 0), Point(x: n, y: n), Point(x: 0, y: n)]
    }

    private enum CodingKeys: String, CodingKey { case shape, quarterTurns, isTilted, cell }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shape = (try? container.decodeIfPresent(Shape.self, forKey: .shape)) ?? nil ?? .triangle
        quarterTurns = (try? container.decodeIfPresent(Int.self, forKey: .quarterTurns)) ?? nil ?? 0
        isTilted = (try? container.decodeIfPresent(Bool.self, forKey: .isTilted)) ?? nil ?? false
        let cell = (try? container.decodeIfPresent(Int.self, forKey: .cell)) ?? nil
        self.cell = cell.flatMap { $0 >= 0 ? $0 : nil }
    }
}

/// Where everyone's piece sits on the Tangram canvas.
enum TangramLayout {
    static let columns = 4

    /// Centres of a cell's four quarters (top, right, bottom, left) in cell units.
    private static let quarterCentres: [TangramPiece.Point] = [
        .init(x: 0.5, y: 1.0 / 6), .init(x: 5.0 / 6, y: 0.5), .init(x: 0.5, y: 5.0 / 6), .init(x: 1.0 / 6, y: 0.5),
    ]

    /// The quarters a piece covers with its block's top-left at `anchor`, as
    /// `cell * 4 + quarter`, or `nil` when it would run off the right edge.
    static func footprint(of piece: TangramPiece, at anchor: Int) -> Set<Int>? {
        let n = piece.blockSize
        guard anchor >= 0, anchor % columns + n <= columns else { return nil }
        let polygon = piece.polygon
        var quarters = Set<Int>()
        for row in 0..<n {
            for column in 0..<n {
                for (quarter, centre) in quarterCentres.enumerated() {
                    let point = TangramPiece.Point(x: Double(column) + centre.x, y: Double(row) + centre.y)
                    if contains(polygon, point) {
                        quarters.insert((anchor + row * columns + column) * 4 + quarter)
                    }
                }
            }
        }
        return quarters
    }

    /// `target`, moved left as far as needed for a block of `size` to fit.
    static func fitting(_ target: Int, size: Int) -> Int {
        target - max(0, target % columns + size - columns)
    }

    static func anchors(for people: [Person]) -> [UUID: Int] {
        GridPlacement.anchors(for: people, cell: \.tangram.cell) { person, anchor in
            footprint(of: person.tangram, at: anchor)
        }
    }

    /// Everyone's pieces packed as tightly as possible from the top-left, in
    /// one of many snug arrangements picked at random. Shapes, sizes and
    /// tilts are kept; triangles may turn so they pair up and fill the
    /// corners around diamonds. Many placement orders and turn preferences
    /// are tried; of those using the fewest rows and leaving the fewest gaps
    /// before the last piece, one that looks different from how the pieces
    /// sit now is chosen when there is one.
    static func packed(_ people: [Person], using generator: inout some RandomNumberGenerator) -> [UUID: TangramPiece] {
        guard !people.isEmpty else { return [:] }
        let biggestFirst = people.indices.sorted {
            let (a, b) = (area(people[$0].tangram), area(people[$1].tangram))
            return a != b ? a > b : $0 < $1
        }
        var orders = [biggestFirst, Array(people.indices)]
        for _ in 0..<(people.count <= 40 ? 60 : 8) {
            orders.append(people.indices.shuffled(using: &generator))
        }

        var best: (score: (Int, Int), arrangements: [[UUID: TangramPiece]])?
        for order in orders {
            let firstTurn = Int.random(in: 0..<4, using: &generator)
            let attempt = pack(people, in: order, firstTurn: firstTurn)
            if best == nil || attempt.score < best!.score {
                best = (attempt.score, [attempt.pieces])
            } else if attempt.score == best!.score {
                best!.arrangements.append(attempt.pieces)
            }
        }
        let current = arrangement(people.map { ($0.id, $0.tangram) })
        let candidates = best!.arrangements
        let fresh = candidates.filter { arrangement($0.map { ($0, $1) }) != current }
        return (fresh.isEmpty ? candidates : fresh).randomElement(using: &generator)!
    }

    /// First fit in `order`: each piece takes the earliest anchor where one
    /// of its turns fits, trying turns from `firstTurn`. Scored by rows used,
    /// then by the last quarter covered (fewer gaps before it).
    private static func pack(_ people: [Person], in order: [Int],
                             firstTurn: Int) -> (score: (Int, Int), pieces: [UUID: TangramPiece]) {
        var taken = Set<Int>()
        var pieces: [UUID: TangramPiece] = [:]
        for index in order {
            let base = people[index].tangram
            let turns = base.shape.isTriangle ? 4 : 1
            var anchor = 0
            placing: while true {
                for turn in 0..<turns {
                    var piece = base
                    piece.quarterTurns += (firstTurn + turn) % turns
                    if let quarters = footprint(of: piece, at: anchor), taken.isDisjoint(with: quarters) {
                        piece.cell = anchor
                        pieces[people[index].id] = piece
                        taken.formUnion(quarters)
                        break placing
                    }
                }
                anchor += 1
            }
        }
        let last = taken.max() ?? 0
        return ((last / 4 / columns + 1, last), pieces)
    }

    /// What each person's piece covers, for telling arrangements apart by
    /// how they look.
    private static func arrangement(_ pieces: [(UUID, TangramPiece)]) -> [UUID: Set<Int>] {
        Dictionary(pieces.map { id, piece in (id, piece.cell.flatMap { footprint(of: piece, at: $0) } ?? []) },
                   uniquingKeysWith: { first, _ in first })
    }

    /// Quarters a piece covers, wherever it sits.
    private static func area(_ piece: TangramPiece) -> Int {
        var origin = piece
        origin.cell = nil
        return footprint(of: origin, at: 0)?.count ?? 0
    }

    /// Whether `point` is inside the convex `polygon` (either winding).
    private static func contains(_ polygon: [TangramPiece.Point], _ point: TangramPiece.Point) -> Bool {
        var sign = 0.0
        for (index, a) in polygon.enumerated() {
            let b = polygon[(index + 1) % polygon.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if cross * sign < 0 { return false }
            if cross != 0 { sign = cross }
        }
        return true
    }
}

/// Placement shared by the Tiles and Tangram canvases: each person sits at
/// an anchor cell and covers a set of grid units there.
enum GridPlacement {
    /// People keep the anchor they were placed at (the first to claim the
    /// space wins); everyone else takes the lowest anchor where they fit, in
    /// list order.
    static func anchors(for people: [Person], cell: KeyPath<Person, Int?>,
                        footprint: (Person, Int) -> Set<Int>?) -> [UUID: Int] {
        var anchors: [UUID: Int] = [:]
        var taken = Set<Int>()
        var unplaced: [Person] = []
        for person in people {
            if let anchor = person[keyPath: cell], let units = footprint(person, anchor), taken.isDisjoint(with: units) {
                anchors[person.id] = anchor
                taken.formUnion(units)
            } else {
                unplaced.append(person)
            }
        }
        for person in unplaced {
            var next = 0
            while true {
                if let units = footprint(person, next), taken.isDisjoint(with: units) {
                    anchors[person.id] = next
                    taken.formUnion(units)
                    break
                }
                next += 1
            }
        }
        return anchors
    }

    /// Pins everyone to their current anchor (so filling gaps doesn't shuffle
    /// unplaced people around) and puts `id` at `anchor`. People it now
    /// overlaps move to `vacated` when they fit there, and otherwise to the
    /// first spot they fit.
    static func pinning(_ people: [Person], moving id: UUID, to anchor: Int, anchors: [UUID: Int], vacated: Int?,
                        cell: WritableKeyPath<Person, Int?>,
                        footprint: (Person, Int) -> Set<Int>?) -> [Person] {
        guard let moverIndex = people.firstIndex(where: { $0.id == id }) else { return people }
        var updated = people
        let moverUnits = footprint(updated[moverIndex], anchor) ?? []
        updated[moverIndex][keyPath: cell] = anchor
        var taken = moverUnits
        var displaced: [Int] = []
        for index in updated.indices where index != moverIndex {
            let current = anchors[updated[index].id]
            updated[index][keyPath: cell] = current
            let units = current.flatMap { footprint(updated[index], $0) } ?? []
            if moverUnits.isDisjoint(with: units) {
                taken.formUnion(units)
            } else {
                displaced.append(index)
            }
        }
        for index in displaced {
            if let vacated, let units = footprint(updated[index], vacated), taken.isDisjoint(with: units) {
                updated[index][keyPath: cell] = vacated
                taken.formUnion(units)
            } else {
                updated[index][keyPath: cell] = nil
            }
        }
        return updated
    }
}
