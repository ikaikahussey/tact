import SwiftUI

/// Quilt-block geometric motifs drawn on a person's tile, in shades of their
/// colour. Each person gets one from their seed, so it never changes on its
/// own; turning the tile turns the motif.
enum TilePattern: Int, CaseIterable {
    case quarterCircles
    case nestedSquares
    case pinwheel
    case bullseye
    case diamond
    case sunrise
    case stripes
    case halfSquare

    init(seed: Int) {
        // Divided first so neighbouring seeds, which share colours, differ.
        self = Self.allCases[(abs(seed) / 3) % Self.allCases.count]
    }
}

/// Four shades of a palette colour: nearly white, light, the colour itself,
/// and dark.
struct TileShades {
    let pale: Color
    let light: Color
    let base: Color
    let dark: Color

    init(colorIndex: Int) {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        UIColor(TilePalette.color(colorIndex)).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func mix(_ target: CGFloat, _ amount: CGFloat) -> Color {
            Color(red: red + (target - red) * amount,
                  green: green + (target - green) * amount,
                  blue: blue + (target - blue) * amount)
        }
        pale = mix(1, 0.78)
        light = mix(1, 0.42)
        base = TilePalette.color(colorIndex)
        dark = mix(0, 0.32)
    }
}

/// A tile's motif filling its square, unturned.
struct TilePatternView: View {
    let pattern: TilePattern
    let colorIndex: Int

    var body: some View {
        Canvas { context, size in
            Self.draw(pattern, shades: TileShades(colorIndex: colorIndex),
                      in: CGRect(origin: .zero, size: size), context: &context)
        }
    }

    private static func draw(_ pattern: TilePattern, shades: TileShades, in rect: CGRect,
                             context: inout GraphicsContext) {
        let s = rect.width
        context.clip(to: Path(rect))
        func fill(_ path: Path, _ color: Color) { context.fill(path, with: .color(color)) }
        func square(_ inset: CGFloat) -> Path { Path(rect.insetBy(dx: s * inset, dy: s * inset)) }
        func circle(_ centre: CGPoint, _ radius: CGFloat) -> Path {
            Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2))
        }
        func polygon(_ points: [CGPoint]) -> Path {
            var path = Path()
            path.addLines(points)
            path.closeSubpath()
            return path
        }
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: rect.minX + x * s, y: rect.minY + y * s) }
        let centre = point(0.5, 0.5)

        switch pattern {
        case .quarterCircles:
            // Truchet-style arcs: a big quarter disc and a small one in opposite corners.
            fill(Path(rect), shades.light)
            fill(circle(point(0, 0), s * 0.82), shades.base)
            fill(circle(point(0, 0), s * 0.42), shades.dark)
            fill(circle(point(1, 1), s * 0.38), shades.pale)

        case .nestedSquares:
            fill(Path(rect), shades.base)
            fill(square(0.14), shades.pale)
            fill(square(0.26), shades.light)
            fill(square(0.37), shades.dark)

        case .pinwheel:
            // Four half-square triangles turning around the centre.
            fill(Path(rect), shades.pale)
            fill(polygon([point(0, 0), point(0.5, 0), point(0.5, 0.5)]), shades.base)
            fill(polygon([point(1, 0), point(1, 0.5), point(0.5, 0.5)]), shades.dark)
            fill(polygon([point(1, 1), point(0.5, 1), point(0.5, 0.5)]), shades.base)
            fill(polygon([point(0, 1), point(0, 0.5), point(0.5, 0.5)]), shades.dark)

        case .bullseye:
            fill(Path(rect), shades.pale)
            fill(circle(centre, s * 0.44), shades.base)
            fill(circle(centre, s * 0.31), shades.light)
            fill(circle(centre, s * 0.17), shades.dark)

        case .diamond:
            fill(Path(rect), shades.base)
            fill(polygon([point(0.5, 0.06), point(0.94, 0.5), point(0.5, 0.94), point(0.06, 0.5)]), shades.pale)
            fill(polygon([point(0.5, 0.24), point(0.76, 0.5), point(0.5, 0.76), point(0.24, 0.5)]), shades.dark)
            fill(circle(centre, s * 0.08), shades.light)

        case .sunrise:
            // A half disc rising from the bottom edge, with rays of light behind.
            fill(Path(rect), shades.pale)
            for ray in 0..<5 {
                let start = Double.pi + Double(ray) * Double.pi / 5
                var wedge = Path()
                wedge.move(to: point(0.5, 1))
                wedge.addArc(center: point(0.5, 1), radius: s * 1.2, startAngle: .radians(start),
                             endAngle: .radians(start + Double.pi / 10), clockwise: false)
                wedge.closeSubpath()
                context.fill(wedge, with: .color(shades.light))
            }
            fill(circle(point(0.5, 1), s * 0.42), shades.base)
            fill(circle(point(0.5, 1), s * 0.22), shades.dark)

        case .stripes:
            // Diagonal bands, clipped to the square.
            fill(Path(rect), shades.pale)
            var bands = context
            bands.clip(to: Path(rect))
            for (index, offset) in [-0.5, 0.0, 0.5, 1.0].enumerated() {
                let band = polygon([point(offset, 0), point(offset + 0.25, 0),
                                    point(offset + 1.25, 1), point(offset + 1, 1)])
                bands.fill(band, with: .color(index.isMultiple(of: 2) ? shades.base : shades.light))
            }

        case .halfSquare:
            // Split on the diagonal, with a quarter circle tucked in each half.
            fill(Path(rect), shades.light)
            fill(polygon([point(0, 0), point(1, 0), point(0, 1)]), shades.base)
            fill(circle(point(1, 1), s * 0.45), shades.dark)
            fill(circle(point(0, 0), s * 0.3), shades.pale)
        }
    }
}
