import SwiftUI

/// The colours a tile cycles through when tapped. Mid-tone and saturated so
/// they read on light and dark backgrounds alike.
enum TilePalette {
    static let colors: [Color] = [
        Color(red: 0.91, green: 0.33, blue: 0.24),  // coral
        Color(red: 0.95, green: 0.64, blue: 0.23),  // amber
        Color(red: 0.95, green: 0.81, blue: 0.23),  // sun
        Color(red: 0.26, green: 0.66, blue: 0.42),  // green
        Color(red: 0.11, green: 0.62, blue: 0.60),  // teal
        Color(red: 0.23, green: 0.47, blue: 0.83),  // blue
        Color(red: 0.48, green: 0.36, blue: 0.84),  // violet
        Color(red: 0.87, green: 0.35, blue: 0.61),  // pink
    ]

    static let names = ["coral", "amber", "yellow", "green", "teal", "blue", "violet", "pink"]

    static func color(_ index: Int) -> Color {
        colors[((index % colors.count) + colors.count) % colors.count]
    }

    static func name(_ index: Int) -> String {
        names[((index % names.count) + names.count) % names.count]
    }
}

/// A filled square, or a right-angle triangle with its right angle at the
/// bottom-left before turning.
struct TileShape: Shape {
    let shape: TileArt.Shape

    func path(in rect: CGRect) -> Path {
        var path = Path()
        switch shape {
        case .square:
            path.addRect(rect)
        case .triangle:
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.closeSubpath()
        }
        return path
    }
}

/// A tile's shape, coloured and turned, filling a square of `side` points.
struct TileArtView: View {
    let art: TileArt
    let side: CGFloat

    var body: some View {
        TileShape(shape: art.shape)
            .fill(TilePalette.color(art.colorIndex))
            .frame(width: side, height: side)
            .rotationEffect(.degrees(Double(art.quarterTurns) * 90))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: art)
    }
}

/// A person's square on the Tiles canvas: their shape with their name.
struct PersonTile: View {
    let person: Person
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.tactCardBackground
            TileArtView(art: person.tile, side: size)
            Text(person.name)
                .font(.system(size: max(10, size * 0.12), weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .padding(5)
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

/// Circular avatar used in lists and chips: the photo, or the person's tile
/// shape when there is none.
struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 40

    var body: some View {
        Group {
            if let image = person.thumbnail(maxPixelSize: 256) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    TilePalette.color(person.tile.colorIndex).opacity(0.25)
                    TileArtView(art: person.tile, side: size)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
