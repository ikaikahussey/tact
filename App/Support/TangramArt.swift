import CoreGraphics
import Foundation

/// The seven tangram pieces. Canonical polygons tile a 4×4 square
/// (y grows downward), so the whole set has an area of 16.
enum TangramPiece: CaseIterable {
    case largeTriangleA, largeTriangleB, mediumTriangle, smallTriangleA, smallTriangleB, square, parallelogram

    var canonicalPolygon: [CGPoint] {
        switch self {
        case .largeTriangleA: return [CGPoint(x: 0, y: 0), CGPoint(x: 4, y: 0), CGPoint(x: 2, y: 2)]
        case .largeTriangleB: return [CGPoint(x: 0, y: 0), CGPoint(x: 2, y: 2), CGPoint(x: 0, y: 4)]
        case .mediumTriangle: return [CGPoint(x: 4, y: 2), CGPoint(x: 4, y: 4), CGPoint(x: 2, y: 4)]
        case .smallTriangleA: return [CGPoint(x: 4, y: 0), CGPoint(x: 4, y: 2), CGPoint(x: 3, y: 1)]
        case .smallTriangleB: return [CGPoint(x: 2, y: 2), CGPoint(x: 3, y: 3), CGPoint(x: 1, y: 3)]
        case .square:         return [CGPoint(x: 2, y: 2), CGPoint(x: 3, y: 1), CGPoint(x: 4, y: 2), CGPoint(x: 3, y: 3)]
        case .parallelogram:  return [CGPoint(x: 0, y: 4), CGPoint(x: 1, y: 3), CGPoint(x: 3, y: 3), CGPoint(x: 2, y: 4)]
        }
    }

    var canonicalArea: CGFloat {
        switch self {
        case .largeTriangleA, .largeTriangleB: return 4
        case .mediumTriangle, .square, .parallelogram: return 2
        case .smallTriangleA, .smallTriangleB: return 1
        }
    }
}

/// One piece placed in a figure: mirrored (optional), turned clockwise by
/// `rotation` eighth-turns, then moved so its bounding box starts at `offset`.
struct TangramPlacement {
    let piece: TangramPiece
    let rotation: Int
    let flipped: Bool
    let offset: CGPoint

    init(_ piece: TangramPiece, rotation: Int = 0, flipped: Bool = false, at offset: CGPoint) {
        self.piece = piece
        self.rotation = rotation
        self.flipped = flipped
        self.offset = offset
    }

    /// The placed polygon in figure units.
    var polygon: [CGPoint] {
        let angle = Double(rotation) * .pi / 4
        let (sine, cosine) = (CGFloat(sin(angle)), CGFloat(cos(angle)))
        let turned = piece.canonicalPolygon.map { point -> CGPoint in
            let x = flipped ? -point.x : point.x
            return CGPoint(x: x * cosine - point.y * sine, y: x * sine + point.y * cosine)
        }
        let minX = turned.map(\.x).min() ?? 0
        let minY = turned.map(\.y).min() ?? 0
        return turned.map { CGPoint(x: $0.x - minX + offset.x, y: $0.y - minY + offset.y) }
    }
}

/// A silhouette built from all seven pieces.
struct TangramFigure {
    let name: String
    let placements: [TangramPlacement]

    /// Bounding box of the figure in figure units.
    var bounds: CGRect {
        let points = placements.flatMap(\.polygon)
        let xs = points.map(\.x), ys = points.map(\.y)
        guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return .zero }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    /// Piece polygons scaled to fit inside `rect` (keeping the aspect ratio,
    /// centred), in the same order as `placements`.
    func polygons(in rect: CGRect, padding: CGFloat = 0) -> [[CGPoint]] {
        let target = rect.insetBy(dx: padding, dy: padding)
        let source = bounds
        guard source.width > 0, source.height > 0, target.width > 0, target.height > 0 else { return [] }
        let scale = min(target.width / source.width, target.height / source.height)
        let originX = target.midX - source.width * scale / 2
        let originY = target.midY - source.height * scale / 2
        return placements.map { placement in
            placement.polygon.map {
                CGPoint(x: originX + ($0.x - source.minX) * scale, y: originY + ($0.y - source.minY) * scale)
            }
        }
    }
}

extension TangramFigure {
    /// √2: the leg of a small triangle and the side of the square.
    private static let r = CGFloat(2).squareRoot()

    private static func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: y) }

    /// Hand-made silhouettes. A person's seed picks one.
    static let all: [TangramFigure] = [cat, swan, rabbit, fish, sailboat, house, runner, bird]

    static let cat = TangramFigure(name: "Cat", placements: [
        TangramPlacement(.square, at: p(1, 1)),
        TangramPlacement(.smallTriangleA, rotation: 4, at: p(1, 0)),
        TangramPlacement(.smallTriangleB, rotation: 6, at: p(2, 0)),
        TangramPlacement(.largeTriangleA, rotation: 6, at: p(1, 2)),
        TangramPlacement(.largeTriangleB, rotation: 6, at: p(1, 4)),
        TangramPlacement(.mediumTriangle, rotation: 6, at: p(3, 4)),
        TangramPlacement(.parallelogram, rotation: 3, at: p(5, 6 - 2 * r)),
    ])

    static let swan = TangramFigure(name: "Swan", placements: [
        TangramPlacement(.largeTriangleA, rotation: 4, at: p(0, 4)),
        TangramPlacement(.largeTriangleB, rotation: 2, at: p(2, 4)),
        TangramPlacement(.mediumTriangle, at: p(4, 4)),
        TangramPlacement(.smallTriangleA, rotation: 4, at: p(1, 3)),
        TangramPlacement(.parallelogram, rotation: 1, at: p(6 - 2 * r, 4 - r)),
        TangramPlacement(.square, rotation: 1, at: p(6 - 2 * r, 4 - 2 * r)),
        TangramPlacement(.smallTriangleB, rotation: 5, at: p(6 - r, 4 - 2 * r)),
    ])

    static let rabbit = TangramFigure(name: "Rabbit", placements: [
        TangramPlacement(.largeTriangleA, rotation: 6, at: p(0, 2)),
        TangramPlacement(.largeTriangleB, rotation: 6, at: p(0, 4)),
        TangramPlacement(.mediumTriangle, rotation: 6, at: p(2, 4)),
        TangramPlacement(.square, at: p(1, 2)),
        TangramPlacement(.parallelogram, rotation: 2, flipped: true, at: p(1, 0)),
        TangramPlacement(.smallTriangleA, at: p(2, 1)),
        TangramPlacement(.smallTriangleB, rotation: 6, at: p(-1, 4)),
    ])

    static let fish = TangramFigure(name: "Fish", placements: [
        TangramPlacement(.largeTriangleA, rotation: 4, at: p(2, 0)),
        TangramPlacement(.largeTriangleB, rotation: 2, at: p(2, 2)),
        TangramPlacement(.mediumTriangle, rotation: 2, at: p(0, 0)),
        TangramPlacement(.smallTriangleA, rotation: 6, at: p(0, 2)),
        TangramPlacement(.smallTriangleB, rotation: 2, at: p(0, 2)),
        TangramPlacement(.parallelogram, rotation: 2, flipped: true, at: p(3, -2)),
        TangramPlacement(.square, at: p(2, 3)),
    ])

    static let sailboat = TangramFigure(name: "Sailboat", placements: [
        TangramPlacement(.largeTriangleB, at: p(2, 0)),
        TangramPlacement(.largeTriangleA, rotation: 4, at: p(2, 2)),
        TangramPlacement(.mediumTriangle, at: p(0, 2)),
        TangramPlacement(.smallTriangleA, rotation: 3, at: p(3 - 1.5 * r, 4)),
        TangramPlacement(.square, rotation: 1, at: p(3 - 0.5 * r, 4)),
        TangramPlacement(.smallTriangleB, rotation: 7, at: p(3 + 0.5 * r, 4)),
        TangramPlacement(.parallelogram, at: p(2, -1)),
    ])

    static let house = TangramFigure(name: "House", placements: [
        TangramPlacement(.largeTriangleA, rotation: 4, at: p(0, 0)),
        TangramPlacement(.largeTriangleB, rotation: 3, at: p(2 - r, 2)),
        TangramPlacement(.mediumTriangle, rotation: 1, at: p(2 - r, 2)),
        TangramPlacement(.smallTriangleA, rotation: 5, at: p(2, 2)),
        TangramPlacement(.smallTriangleB, rotation: 1, at: p(2, 2 + r)),
        TangramPlacement(.parallelogram, rotation: 2, at: p(2.5, -1.5)),
        TangramPlacement(.square, rotation: 1, at: p(2 - 2 * r, 2 + r)),
    ])

    static let runner = TangramFigure(name: "Runner", placements: [
        TangramPlacement(.square, at: p(2, 0)),
        TangramPlacement(.largeTriangleA, at: p(1, 2)),
        TangramPlacement(.parallelogram, at: p(-2, 2)),
        TangramPlacement(.smallTriangleA, rotation: 4, at: p(5, 1)),
        TangramPlacement(.largeTriangleB, rotation: 1, at: p(3 - 2 * r, 4)),
        TangramPlacement(.mediumTriangle, rotation: 2, at: p(3, 4)),
        TangramPlacement(.smallTriangleB, rotation: 5, at: p(5, 6 - r)),
    ])

    static let bird = TangramFigure(name: "Bird", placements: [
        TangramPlacement(.largeTriangleA, rotation: 2, at: p(2, 0)),
        TangramPlacement(.largeTriangleB, rotation: 6, at: p(0, 2)),
        TangramPlacement(.square, at: p(2, -1)),
        TangramPlacement(.smallTriangleA, rotation: 4, at: p(4, -1)),
        TangramPlacement(.mediumTriangle, rotation: 1, at: p(1 - r, 3 - r)),
        TangramPlacement(.parallelogram, rotation: 3, at: p(-r, 4)),
        TangramPlacement(.smallTriangleB, rotation: 4, at: p(2, 4)),
    ])
}

/// Colours and figure for one person's tile, derived from their seed so the
/// same person always gets the same artwork.
struct TangramDesign: Equatable {
    let figureIndex: Int
    let background: RandomColor.HSB
    /// One colour per placement, in figure order.
    let pieceColors: [RandomColor.HSB]
    /// Whether text on the background should be dark for contrast.
    let textIsDark: Bool

    var figure: TangramFigure { TangramFigure.all[figureIndex] }

    init(seed rawSeed: Int) {
        let seed = abs(rawSeed)
        figureIndex = seed % TangramFigure.all.count

        let hue = Double(seed * 37 % 360)
        background = RandomColor.HSB(hue: hue / 360,
                                     saturation: 0.55 + Double(seed * 17 % 35) / 100,
                                     brightness: 0.45 + Double(seed * 23 % 45) / 100)
        textIsDark = Self.luminance(background) > 0.5

        // Base, analogous (+30°) and complementary "pop" (+180°) hues. Pieces
        // contrast with the background: light on dark, deep on light.
        let analogous = (hue + 30).truncatingRemainder(dividingBy: 360) / 360
        let pop = (hue + 180).truncatingRemainder(dividingBy: 360) / 360
        let base = hue / 360
        let lightPieces = !textIsDark
        let hues = [analogous, base, pop, analogous, pop, base, analogous]
        pieceColors = hues.enumerated().map { index, pieceHue in
            let step = Double(index % 3) * 0.09
            let isPop = pieceHue == pop
            return RandomColor.HSB(hue: pieceHue,
                                   saturation: isPop ? 0.8 : (lightPieces ? 0.3 + step * 1.5 : 0.85 - step),
                                   brightness: lightPieces ? 1 - step : 0.3 + step)
        }
    }

    /// Relative luminance (sRGB, approximate) of an HSB colour.
    static func luminance(_ color: RandomColor.HSB) -> Double {
        let (r, g, b) = rgb(color)
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
    }

    static func rgb(_ color: RandomColor.HSB) -> (Double, Double, Double) {
        let h = (color.hue.truncatingRemainder(dividingBy: 1) + 1).truncatingRemainder(dividingBy: 1) * 6
        let s = color.saturation, v = color.brightness
        let c = v * s
        let x = c * (1 - abs(h.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let (r, g, b): (Double, Double, Double)
        switch Int(h) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return (r + m, g + m, b + m)
    }
}
