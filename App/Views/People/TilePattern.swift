import SwiftUI

/// Quilt-block geometric motifs drawn on a person's tile, in shades of their
/// colour. Each person gets one from their seed, so it never changes on its
/// own; turning the tile turns the motif.
///
/// Every motif keeps the same edge contract: a band of the base shade,
/// `TilePatternView.bandWidth` of the tile wide, meets the middle of all four
/// edges, and the rest of each edge is the pale background. So any two tiles
/// side by side join up, whatever their motifs, colours or turns.
enum TilePattern: Int, CaseIterable {
    case arcs
    case cross
    case pinwheel
    case bullseye
    case diamond
    case checker
    case frame
    case petals

    init(seed: Int) {
        // Divided first so neighbouring seeds, which share colours, differ.
        self = Self.allCases[(abs(seed) / 3) % Self.allCases.count]
    }

    var title: String {
        switch self {
        case .arcs:     "Arcs"
        case .cross:    "Cross"
        case .pinwheel: "Pinwheel"
        case .bullseye: "Bullseye"
        case .diamond:  "Diamond"
        case .checker:  "Checker"
        case .frame:    "Frame"
        case .petals:   "Petals"
        }
    }
}

extension Person {
    /// The motif on the person's tile: the one they chose, or one from their seed.
    var tilePattern: TilePattern {
        tile.pattern.flatMap(TilePattern.init(rawValue:)) ?? TilePattern(seed: colorSeed)
    }
}

/// Four shades of a palette colour: nearly white, light, the colour itself,
/// and dark.
struct TileShades {
    let pale: Color
    let light: Color
    let base: Color
    let dark: Color

    init(colorIndex: Int, palette: AppPalette = .current) {
        let color = TilePalette.color(colorIndex, in: palette)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(color).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func mix(_ target: CGFloat, _ amount: CGFloat) -> Color {
            Color(red: red + (target - red) * amount,
                  green: green + (target - green) * amount,
                  blue: blue + (target - blue) * amount)
        }
        pale = mix(1, 0.78)
        light = mix(1, 0.42)
        base = color
        dark = mix(0, 0.32)
    }
}

/// A tile's motif filling its square, unturned.
struct TilePatternView: View {
    let pattern: TilePattern
    let colorIndex: Int
    @Environment(\.appPalette) private var palette

    /// Width of the connecting band, as a fraction of the tile. The band
    /// runs from `(1 - bandWidth) / 2` to `(1 + bandWidth) / 2` along an edge.
    static let bandWidth: CGFloat = 0.2

    var body: some View {
        Canvas { context, size in
            Self.draw(pattern, shades: TileShades(colorIndex: colorIndex, palette: palette),
                      in: CGRect(origin: .zero, size: size), context: &context)
        }
    }

    static func draw(_ pattern: TilePattern, shades: TileShades, in rect: CGRect,
                     context: inout GraphicsContext) {
        let s = rect.width
        let half = bandWidth / 2
        context.clip(to: Path(rect))
        func fill(_ path: Path, _ color: Color) { context.fill(path, with: .color(color)) }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        func box(_ x0: CGFloat, _ y0: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> Path {
            Path(CGRect(x: rect.minX + x0 * s, y: rect.minY + y0 * s, width: (x1 - x0) * s, height: (y1 - y0) * s))
        }
        func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: centre.x - radius * s, y: centre.y - radius * s,
                                   width: radius * 2 * s, height: radius * 2 * s))
        }
        func polygon(_ points: [CGPoint]) -> Path {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }
        /// A quarter ring around a corner, from the middle of one edge to the
        /// middle of the next: the band bent round the corner.
        func cornerArc(_ corner: CGPoint) -> Path {
            var path = circle(corner, 0.5 + half)
            path.addPath(circle(corner, 0.5 - half))
            return path
        }
        let centre = point(0.5, 0.5)
        /// The band straight across and straight down.
        func cross() {
            fill(box(0, 0.5 - half, 1, 0.5 + half), shades.base)
            fill(box(0.5 - half, 0, 0.5 + half, 1), shades.base)
        }

        fill(Path(rect), shades.pale)

        switch pattern {
        case .arcs:
            // Truchet: the band bends round two opposite corners.
            fill(circle(point(0, 0), 0.5 - half), shades.light)
            fill(circle(point(1, 1), 0.5 - half), shades.light)
            context.fill(cornerArc(point(0, 0)), with: .color(shades.base), style: FillStyle(eoFill: true))
            context.fill(cornerArc(point(1, 1)), with: .color(shades.base), style: FillStyle(eoFill: true))
            fill(circle(point(1, 0), 0.14), shades.dark)
            fill(circle(point(0, 1), 0.14), shades.dark)

        case .cross:
            cross()
            fill(box(0.3, 0.3, 0.7, 0.7), shades.dark)
            fill(box(0.4, 0.4, 0.6, 0.6), shades.light)

        case .pinwheel:
            // Four half-square triangles turning around the band's crossing.
            fill(polygon([point(0, 0), point(0.5 - half, 0), point(0.5 - half, 0.5 - half)]), shades.light)
            fill(polygon([point(1, 0), point(1, 0.5 - half), point(0.5 + half, 0.5 - half)]), shades.light)
            fill(polygon([point(1, 1), point(0.5 + half, 1), point(0.5 + half, 0.5 + half)]), shades.light)
            fill(polygon([point(0, 1), point(0, 0.5 + half), point(0.5 - half, 0.5 + half)]), shades.light)
            cross()
            fill(circle(centre, 0.12), shades.dark)

        case .bullseye:
            cross()
            fill(circle(centre, 0.34), shades.dark)
            fill(circle(centre, 0.24), shades.light)
            fill(circle(centre, 0.12), shades.base)

        case .diamond:
            cross()
            fill(polygon([point(0.5, 0.1), point(0.9, 0.5), point(0.5, 0.9), point(0.1, 0.5)]), shades.dark)
            fill(polygon([point(0.5, 0.26), point(0.74, 0.5), point(0.5, 0.74), point(0.26, 0.5)]), shades.light)
            fill(circle(centre, 0.07), shades.base)

        case .checker:
            // Two light quarters on the diagonal, the band laid over them.
            fill(box(0, 0, 0.5, 0.5), shades.light)
            fill(box(0.5, 0.5, 1, 1), shades.light)
            cross()
            fill(box(0.36, 0.36, 0.64, 0.64), shades.dark)

        case .frame:
            // A dark square frame the band passes through.
            fill(box(0.14, 0.14, 0.86, 0.86), shades.dark)
            fill(box(0.26, 0.26, 0.74, 0.74), shades.pale)
            cross()
            fill(circle(centre, 0.1), shades.light)

        case .petals:
            // The band bends round every corner, leaving a four-petal flower.
            for corner in [point(0, 0), point(1, 0), point(1, 1), point(0, 1)] {
                fill(circle(corner, 0.5 - half), shades.light)
            }
            for corner in [point(0, 0), point(1, 0), point(1, 1), point(0, 1)] {
                context.fill(cornerArc(corner), with: .color(shades.base), style: FillStyle(eoFill: true))
            }
            fill(circle(centre, 0.12), shades.dark)
        }
    }
}
