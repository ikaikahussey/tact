import Foundation

/// A person's piece on the Tangram canvas: one of the pattern-block shapes
/// built from equilateral triangles. Pieces sit anywhere on the canvas, not
/// on a grid, and when one is moved or turned into another they push each
/// other aside like wooden pieces on a table. Each shape has its own colour
/// unless the person picks another.
struct TangramPiece: Codable, Equatable, Hashable {
    enum Shape: String, Codable, CaseIterable, Identifiable {
        case triangle
        case diamond
        case trapezoid
        case hexagon

        var id: Self { self }

        var title: String {
            switch self {
            case .triangle:  return "Triangle"
            case .diamond:   return "Diamond"
            case .trapezoid: return "Half Hexagon"
            case .hexagon:   return "Hexagon"
            }
        }

        /// How many triangles the shape is made of.
        var triangleCount: Int {
            switch self {
            case .triangle: return 1
            case .diamond: return 2
            case .trapezoid: return 3
            case .hexagon: return 6
            }
        }

        /// The shape's own colour, as a `TilePalette` index: the classic
        /// pattern-block colours.
        var defaultColorIndex: Int {
            switch self {
            case .triangle:  return 3   // green
            case .diamond:   return 5   // blue
            case .trapezoid: return 8   // red
            case .hexagon:   return 2   // yellow
            }
        }

        /// Turns (in sixths) after which the shape looks the same again.
        var symmetry: Int {
            switch self {
            case .triangle: return 2
            case .diamond: return 3
            case .trapezoid: return 6
            case .hexagon: return 1
            }
        }
    }

    struct Point: Equatable, Hashable, Codable {
        var x: Double
        var y: Double

        static func + (a: Point, b: Point) -> Point { Point(x: a.x + b.x, y: a.y + b.y) }
        static func - (a: Point, b: Point) -> Point { Point(x: a.x - b.x, y: a.y - b.y) }
        static func * (a: Point, s: Double) -> Point { Point(x: a.x * s, y: a.y * s) }
        var length: Double { (x * x + y * y).squareRoot() }
        func dot(_ other: Point) -> Double { x * other.x + y * other.y }
    }

    /// Length of a triangle's side, in canvas cells.
    static let edge = 1.0
    /// Height of one triangle.
    static let triangleHeight = edge * 3.0.squareRoot() / 2

    var shape: Shape
    /// Clockwise turns of 60°.
    var sixths: Int
    /// Centre of the piece on the canvas, in cells from the top-left; `nil`
    /// until placed, when it takes the first free spot.
    var position: Point?
    /// A colour chosen for this piece instead of the shape's own.
    var colorIndex: Int?

    init(shape: Shape, sixths: Int = 0, position: Point? = nil, colorIndex: Int? = nil) {
        self.shape = shape
        self.sixths = sixths
        self.position = position
        self.colorIndex = colorIndex
    }

    /// The starting piece for a person: a triangle, pointing up or down by
    /// their seed, so neighbours already fit together.
    init(seed rawSeed: Int) {
        self.init(shape: .triangle, sixths: abs(rawSeed) % 2)
    }

    /// The colour the piece is drawn in.
    var resolvedColorIndex: Int { colorIndex ?? shape.defaultColorIndex }

    var canRotate: Bool { shape.symmetry > 1 }

    mutating func rotate() {
        turn(by: 1)
    }

    /// Turns the piece `steps` sixths clockwise (anticlockwise when negative).
    mutating func turn(by steps: Int) {
        sixths = (((sixths + steps) % 6) + 6) % 6
    }

    /// Corners around the centre, in cells (y down), turned.
    var corners: [Point] {
        let e = Self.edge
        let h = Self.triangleHeight
        let raw: [Point]
        switch shape {
        case .triangle:
            // Point up, centred on its centroid.
            raw = [Point(x: 0, y: -2 * h / 3), Point(x: e / 2, y: h / 3), Point(x: -e / 2, y: h / 3)]
        case .diamond:
            raw = [Point(x: -e * 0.75, y: -h / 2), Point(x: e * 0.25, y: -h / 2),
                   Point(x: e * 0.75, y: h / 2), Point(x: -e * 0.25, y: h / 2)]
        case .trapezoid:
            raw = [Point(x: -e / 2, y: -h / 2), Point(x: e / 2, y: -h / 2),
                   Point(x: e, y: h / 2), Point(x: -e, y: h / 2)]
        case .hexagon:
            raw = (0..<6).map { index in
                let angle = Double(index) * .pi / 3
                return Point(x: e * cos(angle), y: e * sin(angle))
            }
        }
        let angle = Double(((sixths % 6) + 6) % 6) * .pi / 3
        let (s, c) = (sin(angle), cos(angle))
        return raw.map { Point(x: $0.x * c - $0.y * s, y: $0.x * s + $0.y * c) }
    }

    /// Corners on the canvas, for a piece centred at `centre`.
    func corners(at centre: Point) -> [Point] {
        corners.map { $0 + centre }
    }

    /// The turned piece's bounding box around its centre: the least and
    /// greatest offsets of its corners.
    var bounds: (min: Point, max: Point) {
        let points = corners
        return (Point(x: points.map(\.x).min() ?? 0, y: points.map(\.y).min() ?? 0),
                Point(x: points.map(\.x).max() ?? 0, y: points.map(\.y).max() ?? 0))
    }

    /// Half the width and height of the turned piece's bounding box.
    var halfExtent: Point {
        let box = bounds
        return (box.max - box.min) * 0.5
    }

    /// Where the bounding box's centre sits relative to the piece's centre.
    var boundsOffset: Point {
        let box = bounds
        return (box.max + box.min) * 0.5
    }

    /// Area in triangles.
    var area: Int { shape.triangleCount }

    private enum CodingKeys: String, CodingKey { case shape, sixths, x, y, colorIndex }

    /// Decoding is tolerant of earlier data: the square-lattice shapes map to
    /// the nearest pattern block, and their grid cell is dropped so the piece
    /// takes the first free spot.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawShape = (try? container.decodeIfPresent(String.self, forKey: .shape)) ?? nil
        shape = rawShape.flatMap(Shape.init(rawValue:)) ?? Self.legacyShape(rawShape) ?? .triangle
        sixths = ((((try? container.decodeIfPresent(Int.self, forKey: .sixths)) ?? nil ?? 0) % 6) + 6) % 6
        if let x = (try? container.decodeIfPresent(Double.self, forKey: .x)) ?? nil,
           let y = (try? container.decodeIfPresent(Double.self, forKey: .y)) ?? nil,
           x.isFinite, y.isFinite {
            position = Point(x: x, y: y)
        } else {
            position = nil
        }
        colorIndex = (try? container.decodeIfPresent(Int.self, forKey: .colorIndex)) ?? nil
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shape, forKey: .shape)
        try container.encode(sixths, forKey: .sixths)
        try container.encodeIfPresent(position?.x, forKey: .x)
        try container.encodeIfPresent(position?.y, forKey: .y)
        try container.encodeIfPresent(colorIndex, forKey: .colorIndex)
    }

    private static func legacyShape(_ raw: String?) -> Shape? {
        switch raw {
        case "square":                   return .diamond
        case "largeTriangle":            return .trapezoid
        case "largeSquare", "circle":    return .hexagon
        default:                         return nil
        }
    }
}

/// Where everyone's piece sits on the Tangram canvas, and how pieces make
/// room for each other.
enum TangramLayout {
    typealias Point = TangramPiece.Point

    /// Width of the canvas in cells; pieces stay within it.
    static let columns = 4
    static let width = Double(columns)
    /// Gap kept between pieces when they are pushed apart: none, so blocks
    /// can sit edge to edge like a real tangram.
    static let clearance = 0.0

    // MARK: Placement

    /// Everyone's centre: placed pieces keep theirs, moved only as far as
    /// needed to clear earlier ones; unplaced pieces take the first free spot
    /// scanning from the top-left.
    static func positions(for people: [Person]) -> [UUID: Point] {
        var placed: [(id: UUID, piece: TangramPiece, centre: Point)] = []
        var unplaced: [Person] = []
        for person in people {
            if let centre = person.tangram.position {
                placed.append((person.id, person.tangram, clamped(centre, for: person.tangram)))
            } else {
                unplaced.append(person)
            }
        }
        var centres = Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0.centre) })
        settle(&centres, pieces: Dictionary(uniqueKeysWithValues: placed.map { ($0.id, $0.piece) }), fixed: nil)
        for person in unplaced {
            let others = centres.compactMap { id, centre in
                people.first { $0.id == id }.map { ($0.tangram, centre) }
            }
            centres[person.id] = firstFreeSpot(for: person.tangram, avoiding: others)
        }
        return centres
    }

    /// Pushes overlapping pieces apart until none overlap, moving `fixed`
    /// not at all. Each pass moves the pieces of each overlapping pair apart
    /// along the shortest way out, so a pushed piece shoves the next one on.
    static func settle(_ centres: inout [UUID: Point], pieces: [UUID: TangramPiece], fixed: UUID?,
                       passes: Int = 60) {
        let ids = pieces.keys.sorted { $0.uuidString < $1.uuidString }
        guard ids.count > 1 else { return }
        for _ in 0..<passes {
            var moved = false
            for (i, a) in ids.enumerated() {
                for b in ids[(i + 1)...] {
                    guard let ca = centres[a], let cb = centres[b],
                          let push = separation(pieces[a]!, at: ca, from: pieces[b]!, at: cb) else { continue }
                    moved = true
                    if a == fixed {
                        centres[b] = nudged(cb, by: push * -1, for: pieces[b]!)
                    } else if b == fixed {
                        centres[a] = nudged(ca, by: push, for: pieces[a]!)
                    } else {
                        centres[a] = nudged(ca, by: push * 0.5, for: pieces[a]!)
                        centres[b] = nudged(cb, by: push * -0.5, for: pieces[b]!)
                    }
                }
            }
            if !moved { return }
        }
    }

    /// Moves a piece by `push`, kept inside the canvas. A piece stopped by a
    /// wall slides down instead, as far as it was meant to go, so a pile
    /// against an edge always finds room below.
    private static func nudged(_ centre: Point, by push: Point, for piece: TangramPiece) -> Point {
        let target = centre + push
        var result = clamped(target, for: piece)
        if abs(result.x - target.x) > 1e-9 || abs(result.y - target.y) > 1e-9 {
            result.y = max(result.y, centre.y + push.length)
        }
        return result
    }

    /// Keeps a piece inside the canvas width and below its top edge.
    static func clamped(_ centre: Point, for piece: TangramPiece) -> Point {
        let box = piece.bounds
        var result = centre
        if centre.x + box.min.x < -1e-9 { result.x = -box.min.x }
        if centre.x + box.max.x > width + 1e-9 { result.x = width - box.max.x }
        if centre.y + box.min.y < -1e-9 { result.y = -box.min.y }
        return result
    }

    /// The first spot, scanning left to right then down, where `piece` does
    /// not touch any of `others`.
    static func firstFreeSpot(for piece: TangramPiece, avoiding others: [(TangramPiece, Point)]) -> Point {
        let step = TangramPiece.edge / 4
        let box = piece.bounds
        var y = -box.min.y
        while true {
            var x = -box.min.x
            while x <= width - box.max.x + 1e-9 {
                let centre = Point(x: x, y: y)
                if !others.contains(where: { separation(piece, at: centre, from: $0.0, at: $0.1) != nil }) {
                    return centre
                }
                x += step
            }
            y += step
        }
    }

    // MARK: Overlap

    /// How far `a` must move to stop overlapping `b`, by the separating-axis
    /// test on the two convex outlines, or `nil` when they are already apart.
    static func separation(_ a: TangramPiece, at ca: Point, from b: TangramPiece, at cb: Point) -> Point? {
        let (boxA, boxB) = (a.bounds, b.bounds)
        if ca.x + boxA.min.x > cb.x + boxB.max.x + clearance || cb.x + boxB.min.x > ca.x + boxA.max.x + clearance
            || ca.y + boxA.min.y > cb.y + boxB.max.y + clearance || cb.y + boxB.min.y > ca.y + boxA.max.y + clearance {
            return nil
        }
        let pa = a.corners(at: ca)
        let pb = b.corners(at: cb)
        var best: (depth: Double, axis: Point)?
        for polygon in [pa, pb] {
            for (index, p) in polygon.enumerated() {
                let q = polygon[(index + 1) % polygon.count]
                let edge = q - p
                let length = edge.length
                guard length > 0 else { continue }
                let axis = Point(x: -edge.y / length, y: edge.x / length)
                let (minA, maxA) = project(pa, onto: axis)
                let (minB, maxB) = project(pb, onto: axis)
                let depth = min(maxA, maxB) - max(minA, minB) + clearance
                if depth <= 1e-6 { return nil }
                if best == nil || depth < best!.depth { best = (depth, axis) }
            }
        }
        guard let (depth, axis) = best else { return nil }
        // Push a away from b along the axis.
        let direction = (ca - cb).dot(axis) >= 0 ? 1.0 : -1.0
        return axis * (depth * direction)
    }

    private static func project(_ points: [Point], onto axis: Point) -> (Double, Double) {
        var low = Double.infinity, high = -Double.infinity
        for point in points {
            let d = point.dot(axis)
            low = min(low, d)
            high = max(high, d)
        }
        return (low, high)
    }

    /// Whether `point` is inside the piece centred at `centre`.
    static func piece(_ piece: TangramPiece, at centre: Point, contains point: Point) -> Bool {
        let polygon = piece.corners(at: centre)
        var sign = 0.0
        for (index, a) in polygon.enumerated() {
            let b = polygon[(index + 1) % polygon.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if cross * sign < 0 { return false }
            if cross != 0 { sign = cross }
        }
        return true
    }

    // MARK: Fit Together

    /// Vertices of the triangular lattice sit on rows `triangleHeight`
    /// apart, every other row shifted by half an edge.
    static func latticeVertex(row: Int, index: Int) -> Point {
        Point(x: Double(index) + (row % 2 == 0 ? 0 : 0.5), y: Double(row) * TangramPiece.triangleHeight)
    }

    /// Keys of the unit lattice triangles a piece covers when centred at
    /// `centre`, or `nil` when it does not lie on the lattice inside the
    /// canvas. A triangle counts as covered when its centroid is inside.
    static func latticeTriangles(of piece: TangramPiece, at centre: Point) -> Set<Int>? {
        let h = TangramPiece.triangleHeight
        let corners = piece.corners(at: centre)
        for corner in corners {
            guard corner.x >= -1e-6, corner.x <= width + 1e-6, corner.y >= -1e-6 else { return nil }
            let row = corner.y / h
            guard abs(row - row.rounded()) < 1e-6 else { return nil }
            let shifted = corner.x - (Int(row.rounded()) % 2 == 0 ? 0 : 0.5)
            guard abs(shifted - shifted.rounded()) < 1e-6 else { return nil }
        }
        let box = piece.bounds
        let firstBand = max(0, Int(((centre.y + box.min.y) / h).rounded(.down)))
        let lastBand = Int(((centre.y + box.max.y) / h).rounded(.up))
        var covered = Set<Int>()
        for band in firstBand..<max(firstBand, lastBand) {
            let top = Double(band) * h
            for half in Int((centre.x + box.min.x) * 2).advanced(by: -2)...Int((centre.x + box.max.x) * 2).advanced(by: 2) {
                let x = Double(half) / 2
                // Pointing up: apex on a vertex of row `band`, so its centroid
                // shares that row's offset; pointing down: apex on the row below.
                for pointsUp in [true, false] {
                    let apexRow = pointsUp ? band : band + 1
                    guard (half % 2 == 0) == (apexRow % 2 == 0) else { continue }
                    let centroid = Point(x: x, y: top + (pointsUp ? 2 * h / 3 : h / 3))
                    guard centroid.x > 0, centroid.x < width,
                          self.piece(piece, at: centre, contains: centroid) else { continue }
                    covered.insert((band * 64 + half + 8) * 2 + (pointsUp ? 1 : 0))
                }
            }
        }
        return covered
    }

    /// Everyone's pieces packed edge to edge on the triangular lattice from
    /// the top-left, in one of several tight arrangements picked at random.
    /// Shapes and colours are kept; pieces may turn to fit. Of the orders
    /// tried, the one whose lowest piece is highest wins (then the one with
    /// its pieces highest overall), preferring an arrangement that looks
    /// different from how the pieces sit now.
    static func packed(_ people: [Person], using generator: inout some RandomNumberGenerator) -> [UUID: TangramPiece] {
        guard !people.isEmpty else { return [:] }
        let biggestFirst = people.indices.sorted {
            let (a, b) = (people[$0].tangram.area, people[$1].tangram.area)
            return a != b ? a > b : $0 < $1
        }
        var orders = [biggestFirst, Array(people.indices)]
        for _ in 0..<(people.count <= 24 ? 14 : 4) {
            orders.append(people.indices.shuffled(using: &generator))
        }
        var best: (score: (Int, Int), arrangements: [[UUID: TangramPiece]])?
        for order in orders {
            let firstTurn = Int.random(in: 0..<6, using: &generator)
            let attempt = pack(people, in: order, firstTurn: firstTurn)
            if best == nil || attempt.score < best!.score {
                best = (attempt.score, [attempt.pieces])
            } else if attempt.score == best!.score {
                best!.arrangements.append(attempt.pieces)
            }
        }
        let current = Dictionary(uniqueKeysWithValues: people.map { ($0.id, $0.tangram) })
        let candidates = best!.arrangements
        let fresh = candidates.filter { $0 != current }
        return (fresh.isEmpty ? candidates : fresh).randomElement(using: &generator)!
    }

    /// First fit in `order`: each piece's first corner is tried on every
    /// lattice vertex, row by row from the top-left, in each of its turns
    /// from `firstTurn`, and it takes the first spot whose lattice triangles
    /// are all free. Scored by the lowest row touched, then by the sum of
    /// the rows the pieces' tops sit on (both in lattice rows, so ties are exact).
    private static func pack(_ people: [Person], in order: [Int],
                             firstTurn: Int) -> (score: (Int, Int), pieces: [UUID: TangramPiece]) {
        let h = TangramPiece.triangleHeight
        var taken = Set<Int>()
        var pieces: [UUID: TangramPiece] = [:]
        var bottomRow = 0
        var rowSum = 0
        for index in order {
            let base = people[index].tangram
            var row = 0
            placing: while true {
                let count = row % 2 == 0 ? columns + 1 : columns
                for vertex in 0..<count {
                    let anchor = latticeVertex(row: row, index: vertex)
                    for turn in 0..<base.shape.symmetry {
                        var piece = base
                        piece.sixths = (firstTurn + turn) % 6
                        let centre = anchor - piece.corners[0]
                        guard let triangles = latticeTriangles(of: piece, at: centre),
                              !triangles.isEmpty, taken.isDisjoint(with: triangles) else { continue }
                        piece.position = centre
                        pieces[people[index].id] = piece
                        taken.formUnion(triangles)
                        bottomRow = max(bottomRow, Int(((centre.y + piece.bounds.max.y) / h).rounded()))
                        rowSum += Int(((centre.y + piece.bounds.min.y) / h).rounded())
                        break placing
                    }
                }
                row += 1
            }
        }
        return ((bottomRow, rowSum), pieces)
    }
}

