import XCTest
@testable import Tact

final class TangramArtTests: XCTestCase {
    func testCanonicalPiecesTileTheSquare() {
        XCTAssertEqual(TangramPiece.allCases.map(\.canonicalArea).reduce(0, +), 16)
        for piece in TangramPiece.allCases {
            XCTAssertEqual(Self.area(piece.canonicalPolygon), piece.canonicalArea, accuracy: 1e-9, "\(piece)")
        }
    }

    func testEveryFigureUsesEachPieceOnce() {
        XCTAssertEqual(TangramFigure.all.count, 8)
        for figure in TangramFigure.all {
            XCTAssertEqual(figure.placements.count, 7, figure.name)
            XCTAssertEqual(Set(figure.placements.map(\.piece)), Set(TangramPiece.allCases), figure.name)
        }
    }

    func testPlacementsAreRigid() {
        for figure in TangramFigure.all {
            for placement in figure.placements {
                XCTAssertEqual(Self.area(placement.polygon), placement.piece.canonicalArea, accuracy: 1e-9,
                               "\(figure.name) \(placement.piece)")
                let sides = Self.sideLengths(placement.polygon).sorted()
                let canonical = Self.sideLengths(placement.piece.canonicalPolygon).sorted()
                for (side, expected) in zip(sides, canonical) {
                    XCTAssertEqual(side, expected, accuracy: 1e-9, "\(figure.name) \(placement.piece)")
                }
            }
        }
    }

    func testPiecesDoNotOverlap() {
        for figure in TangramFigure.all {
            let polygons = figure.placements.map(\.polygon)
            for i in polygons.indices {
                for j in polygons.indices where j > i {
                    XCTAssertEqual(Self.overlap(polygons[i], polygons[j]), 0, accuracy: 1e-6,
                                   "\(figure.name): \(figure.placements[i].piece) / \(figure.placements[j].piece)")
                }
            }
        }
    }

    func testFittedPolygonsStayInsideTheRect() {
        let rect = CGRect(x: 10, y: 20, width: 98, height: 60)
        for figure in TangramFigure.all {
            let polygons = figure.polygons(in: rect, padding: 6)
            XCTAssertEqual(polygons.count, 7)
            for point in polygons.joined() {
                XCTAssertTrue(rect.insetBy(dx: 6 - 1e-6, dy: 6 - 1e-6).contains(point), "\(figure.name) \(point)")
            }
        }
    }

    func testDesignIsDeterministicAndInRange() {
        for seed in [0, 1, 7, 8, 100, 359, 4096, -5] {
            let design = TangramDesign(seed: seed)
            XCTAssertEqual(design, TangramDesign(seed: seed))
            XCTAssertEqual(design.pieceColors.count, 7)
            for color in [design.background] + design.pieceColors {
                XCTAssertTrue((0...1).contains(color.hue), "\(seed)")
                XCTAssertTrue((0...1).contains(color.saturation), "\(seed)")
                XCTAssertTrue((0...1).contains(color.brightness), "\(seed)")
            }
        }
        XCTAssertEqual(TangramDesign(seed: 3).figure.name, TangramFigure.all[3].name)
        XCTAssertNotEqual(TangramDesign(seed: 0).figure.name, TangramDesign(seed: 1).figure.name)
    }

    func testTextContrastFollowsBackground() {
        XCTAssertTrue(TangramDesign.luminance(.init(hue: 0.15, saturation: 0.6, brightness: 0.95)) > 0.5)
        XCTAssertTrue(TangramDesign.luminance(.init(hue: 0.65, saturation: 0.8, brightness: 0.4)) < 0.5)
        for seed in 0..<360 {
            let design = TangramDesign(seed: seed)
            XCTAssertEqual(design.textIsDark, TangramDesign.luminance(design.background) > 0.5)
        }
    }

    // MARK: Geometry helpers

    private static func area(_ polygon: [CGPoint]) -> CGFloat {
        var sum: CGFloat = 0
        for i in polygon.indices {
            let next = polygon[(i + 1) % polygon.count]
            sum += polygon[i].x * next.y - next.x * polygon[i].y
        }
        return abs(sum) / 2
    }

    private static func sideLengths(_ polygon: [CGPoint]) -> [CGFloat] {
        polygon.indices.map { i in
            let a = polygon[i], b = polygon[(i + 1) % polygon.count]
            return hypot(b.x - a.x, b.y - a.y)
        }
    }

    /// Area shared by two convex polygons (Sutherland–Hodgman clipping).
    private static func overlap(_ subject: [CGPoint], _ clip: [CGPoint]) -> CGFloat {
        func counterClockwise(_ p: [CGPoint]) -> [CGPoint] {
            var sum: CGFloat = 0
            for i in p.indices { let q = p[(i + 1) % p.count]; sum += p[i].x * q.y - q.x * p[i].y }
            return sum < 0 ? p.reversed() : p
        }
        var output = counterClockwise(subject)
        let edges = counterClockwise(clip)
        for i in edges.indices {
            let a = edges[i], b = edges[(i + 1) % edges.count]
            func inside(_ p: CGPoint) -> Bool { (b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) >= -1e-9 }
            func intersection(_ p: CGPoint, _ q: CGPoint) -> CGPoint {
                let a1 = b.y - a.y, b1 = a.x - b.x, c1 = a1 * a.x + b1 * a.y
                let a2 = q.y - p.y, b2 = p.x - q.x, c2 = a2 * p.x + b2 * p.y
                let d = a1 * b2 - a2 * b1
                return CGPoint(x: (b2 * c1 - b1 * c2) / d, y: (a1 * c2 - a2 * c1) / d)
            }
            let input = output
            output = []
            for j in input.indices {
                let current = input[j], previous = input[(j + input.count - 1) % input.count]
                if inside(current) {
                    if !inside(previous) { output.append(intersection(previous, current)) }
                    output.append(current)
                } else if inside(previous) {
                    output.append(intersection(previous, current))
                }
            }
            if output.isEmpty { return 0 }
        }
        return area(output)
    }
}
