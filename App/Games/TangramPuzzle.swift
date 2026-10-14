import CoreGraphics
import Foundation

/// The state of a tangram board: seven pieces that can be moved, turned and
/// flipped, and (in Shapes mode) a silhouette to fill. Everything is in
/// tangram units, where the full set of pieces covers a 4×4 square; y grows
/// downward. The silhouette sits at the top and the pieces start in a tray
/// below it.
struct TangramPuzzle {
    struct Piece: Equatable, Identifiable {
        /// Index into `TangramPiece.allCases`; also the person's slot in the set.
        let id: Int
        let shape: TangramPiece
        /// Clockwise eighth-turns. Not wrapped, so turning always animates forward.
        var rotation: Int
        var flipped: Bool
        /// Where the piece's vertex average sits on the board.
        var center: CGPoint

        /// The piece around its own centre, mirrored if flipped, before turning.
        var localPolygon: [CGPoint] { Self.localPolygon(shape, flipped: flipped) }

        /// The piece as placed on the board.
        var polygon: [CGPoint] {
            let angle = Double(rotation) * .pi / 4
            let (sine, cosine) = (CGFloat(sin(angle)), CGFloat(cos(angle)))
            return localPolygon.map {
                CGPoint(x: center.x + $0.x * cosine - $0.y * sine, y: center.y + $0.x * sine + $0.y * cosine)
            }
        }

        static func localPolygon(_ shape: TangramPiece, flipped: Bool) -> [CGPoint] {
            let points = shape.canonicalPolygon.map { CGPoint(x: flipped ? -$0.x : $0.x, y: $0.y) }
            let center = TangramPuzzle.average(points)
            return points.map { CGPoint(x: $0.x - center.x, y: $0.y - center.y) }
        }
    }

    // MARK: Board geometry

    static let width: CGFloat = 13
    static let margin: CGFloat = 0.5
    /// Tall enough for every silhouette, so the board never changes size.
    static let targetHeight: CGFloat = TangramFigure.all.map(\.bounds.height).max() ?? 8
    static let trayTop = margin + targetHeight + 0.5
    static let height = trayTop + 4.5 + margin
    /// How close (in units) a corner must come to another corner to snap to it.
    static let snapDistance: CGFloat = 0.5

    private(set) var pieces: [Piece]
    /// Draw order, back to front. The piece last touched is on top.
    private(set) var order: [Int]
    let figure: TangramFigure?
    /// The silhouette's piece polygons, already positioned on the board.
    let target: [[CGPoint]]

    init(figure: TangramFigure?) {
        self.figure = figure
        if let figure {
            let offset = Self.targetOffset(for: figure)
            target = figure.placements.map { $0.polygon.map { CGPoint(x: $0.x + offset.x, y: $0.y + offset.y) } }
        } else {
            target = []
        }
        pieces = Self.trayPieces()
        order = Array(pieces.indices)
    }

    /// Moves a figure's own coordinates so it is centred in the target area.
    static func targetOffset(for figure: TangramFigure) -> CGPoint {
        let bounds = figure.bounds
        return CGPoint(x: (width - bounds.width) / 2 - bounds.minX,
                       y: margin + (targetHeight - bounds.height) / 2 - bounds.minY)
    }

    /// The pieces laid out in rows along the tray, unturned.
    static func trayPieces() -> [Piece] {
        // The second large triangle's canonical shape is the first turned
        // three-quarters, so a half turn of it lies flat like the first.
        let startRotation: [TangramPiece: Int] = [.largeTriangleB: 2]
        var pieces: [Piece] = []
        var rows: [[Int]] = [[]]
        var rowWidth: CGFloat = 0
        let gap: CGFloat = 0.5
        let sizes = TangramPiece.allCases.map { shape -> CGSize in
            let placement = TangramPlacement(shape, rotation: startRotation[shape] ?? 0, at: .zero)
            let points = placement.polygon
            return CGSize(width: points.map(\.x).max() ?? 0, height: points.map(\.y).max() ?? 0)
        }
        for (index, size) in sizes.enumerated() {
            let needed = (rows[rows.count - 1].isEmpty ? 0 : gap) + size.width
            if rowWidth + needed > width - 2 * margin {
                rows.append([])
                rowWidth = 0
            }
            rowWidth += rows[rows.count - 1].isEmpty ? size.width : needed
            rows[rows.count - 1].append(index)
        }
        var top = trayTop
        for row in rows {
            let rowWidth = row.map { sizes[$0].width }.reduce(0, +) + gap * CGFloat(row.count - 1)
            let rowHeight = row.map { sizes[$0].height }.max() ?? 0
            var left = (width - rowWidth) / 2
            for index in row {
                let shape = TangramPiece.allCases[index]
                let rotation = startRotation[shape] ?? 0
                let placed = TangramPlacement(shape, rotation: rotation,
                                              at: CGPoint(x: left, y: top + (rowHeight - sizes[index].height) / 2))
                pieces.append(Piece(id: index, shape: shape, rotation: rotation, flipped: false,
                                    center: average(placed.polygon)))
                left += sizes[index].width + gap
            }
            top += rowHeight + gap
        }
        return pieces
    }

    // MARK: Moves

    mutating func move(_ id: Int, by delta: CGPoint) {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else { return }
        let center = pieces[index].center
        pieces[index].center = CGPoint(x: min(Self.width - 0.3, max(0.3, center.x + delta.x)),
                                       y: min(Self.height - 0.3, max(0.3, center.y + delta.y)))
        bringToFront(id)
    }

    /// Nudges the piece so one of its corners meets a nearby corner of another
    /// piece or of the silhouette. Of the possible nudges, the one that lines
    /// up the most corners at once wins (then the shortest), so a piece dropped
    /// near its slot settles into it rather than onto a stray corner.
    /// Returns whether it moved.
    @discardableResult
    mutating func snap(_ id: Int, within distance: CGFloat = snapDistance) -> Bool {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else { return false }
        let others = pieces.filter { $0.id != id }.flatMap(\.polygon) + target.joined()
        let corners = pieces[index].polygon
        var best: (matches: Int, distance: CGFloat, delta: CGPoint)?
        for corner in corners {
            for other in others {
                let delta = CGPoint(x: other.x - corner.x, y: other.y - corner.y)
                let length = hypot(delta.x, delta.y)
                guard length < distance else { continue }
                let matches = corners.filter { moved in
                    others.contains { hypot(moved.x + delta.x - $0.x, moved.y + delta.y - $0.y) < 0.05 }
                }.count
                if best == nil || matches > best!.matches || (matches == best!.matches && length < best!.distance) {
                    best = (matches, length, delta)
                }
            }
        }
        guard let best, best.distance > 1e-9 else { return false }
        pieces[index].center.x += best.delta.x
        pieces[index].center.y += best.delta.y
        return true
    }

    /// Turns a piece an eighth clockwise (negative turns go anticlockwise),
    /// keeping its centre where it is.
    mutating func rotate(_ id: Int, by eighths: Int = 1) {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else { return }
        pieces[index].rotation += eighths
        bringToFront(id)
    }

    /// Mirrors a piece left to right. Only the parallelogram looks different
    /// flipped; the others are symmetric.
    mutating func flip(_ id: Int) {
        guard let index = pieces.firstIndex(where: { $0.id == id }) else { return }
        pieces[index].flipped.toggle()
        bringToFront(id)
    }

    mutating func reset() {
        pieces = Self.trayPieces()
        order = Array(pieces.indices)
    }

    /// Puts a piece exactly where the silhouette's matching piece goes.
    mutating func place(_ id: Int, matching placement: TangramPlacement) {
        guard let index = pieces.firstIndex(where: { $0.id == id }), let figure else { return }
        let offset = Self.targetOffset(for: figure)
        let center = Self.average(placement.polygon)
        pieces[index].rotation = placement.rotation
        pieces[index].flipped = placement.flipped
        pieces[index].center = CGPoint(x: center.x + offset.x, y: center.y + offset.y)
    }

    private mutating func bringToFront(_ id: Int) {
        order.removeAll { $0 == id }
        order.append(id)
    }

    // MARK: Solving

    /// The silhouette is filled when the pieces cover it and nothing spills
    /// outside. Any arrangement that does this counts, not only the one the
    /// figure was drawn with.
    var isSolved: Bool {
        guard !target.isEmpty else { return false }
        let placed = pieces.map(\.polygon)
        return Self.fraction(of: target, coveredBy: placed) > 0.985
            && Self.fraction(of: placed, coveredBy: target) > 0.985
    }

    /// Share of sample points inside `regions` that also fall inside `cover`.
    static func fraction(of regions: [[CGPoint]], coveredBy cover: [[CGPoint]]) -> Double {
        let points = regions.joined()
        guard let minX = points.map(\.x).min(), let maxX = points.map(\.x).max(),
              let minY = points.map(\.y).min(), let maxY = points.map(\.y).max() else { return 0 }
        // An odd offset keeps samples off the edges, which lie on simple fractions.
        let step: CGFloat = 0.1, jitter: CGFloat = 0.0371
        var inside = 0, covered = 0
        var y = minY + jitter
        while y < maxY {
            var x = minX + jitter
            while x < maxX {
                let point = CGPoint(x: x, y: y)
                if regions.contains(where: { contains($0, point) }) {
                    inside += 1
                    if cover.contains(where: { contains($0, point) }) { covered += 1 }
                }
                x += step
            }
            y += step
        }
        return inside == 0 ? 0 : Double(covered) / Double(inside)
    }

    /// Whether a point lies inside a convex polygon (either winding).
    static func contains(_ polygon: [CGPoint], _ point: CGPoint) -> Bool {
        var sign: CGFloat = 0
        for i in polygon.indices {
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            let cross = (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            if abs(cross) < 1e-9 { continue }
            if sign == 0 { sign = cross } else if (cross > 0) != (sign > 0) { return false }
        }
        return true
    }

    static func average(_ points: [CGPoint]) -> CGPoint {
        guard !points.isEmpty else { return .zero }
        return CGPoint(x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
                       y: points.map(\.y).reduce(0, +) / CGFloat(points.count))
    }
}
