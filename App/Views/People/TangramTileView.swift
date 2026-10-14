import SwiftUI

/// A person's generated artwork: a tangram figure on a bold background, with
/// their name set in the corner.
struct TangramTileView: View {
    let person: Person
    /// Width of the tile; the name is sized from it.
    let size: CGFloat
    var showsName: Bool = true
    /// Height when the artwork fills a banner rather than a square.
    var height: CGFloat? = nil

    private var design: TangramDesign { TangramDesign(seed: person.colorSeed) }

    var body: some View {
        let design = design
        ZStack(alignment: .bottomLeading) {
            Color(design.background)
            Canvas { context, canvasSize in
                let art = showsName
                    ? CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height * 0.62)
                    : CGRect(origin: .zero, size: canvasSize)
                let side = min(canvasSize.width, canvasSize.height)
                let padding = side * (showsName ? 0.1 : 0.16)
                let polygons = design.figure.polygons(in: art, padding: padding)
                let gap = side * 0.015
                for (polygon, color) in zip(polygons, design.pieceColors) {
                    context.fill(Self.path(polygon, insetBy: gap), with: .color(Color(color)))
                }
            }
            if showsName {
                Text(person.name)
                    .font(.system(size: size * 0.11, weight: .bold, design: .rounded))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(design.textIsDark ? Color.black.opacity(0.85) : Color.white)
                    .padding(.horizontal, size * 0.08)
                    .padding(.bottom, size * 0.07)
            }
        }
        .frame(width: size, height: height ?? size)
        .drawingGroup()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.name)
    }

    /// The polygon shrunk toward its centroid so neighbouring pieces show a
    /// hairline gap.
    private static func path(_ polygon: [CGPoint], insetBy gap: CGFloat) -> Path {
        guard !polygon.isEmpty else { return Path() }
        let center = CGPoint(x: polygon.map(\.x).reduce(0, +) / CGFloat(polygon.count),
                             y: polygon.map(\.y).reduce(0, +) / CGFloat(polygon.count))
        let shrunk = polygon.map { point -> CGPoint in
            let dx = point.x - center.x, dy = point.y - center.y
            let distance = max((dx * dx + dy * dy).squareRoot(), 0.001)
            let factor = max(0, distance - gap) / distance
            return CGPoint(x: center.x + dx * factor, y: center.y + dy * factor)
        }
        var path = Path()
        path.addLines(shrunk)
        path.closeSubpath()
        return path
    }
}

extension Color {
    init(_ hsb: RandomColor.HSB) {
        self.init(hue: hsb.hue, saturation: hsb.saturation, brightness: hsb.brightness)
    }
}

#Preview {
    LazyVGrid(columns: Array(repeating: GridItem(.fixed(96), spacing: 1), count: 4), spacing: 1) {
        ForEach(0..<16) { seed in
            TangramTileView(person: Person(name: "Person \(seed)", colorSeed: seed * 7), size: 96)
        }
    }
}
