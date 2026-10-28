import SwiftUI

/// The colours a tile can be, in the Classic palette. Mid-tone and saturated
/// so they read on light and dark backgrounds alike; other palettes are made
/// from these (`AppPalette`). New colours go at the end so saved indexes keep
/// their colour.
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
        Color(red: 0.84, green: 0.18, blue: 0.22),  // red
        Color(red: 0.36, green: 0.73, blue: 0.93),  // sky
        Color(red: 0.62, green: 0.43, blue: 0.29),  // brown
        Color(red: 0.52, green: 0.55, blue: 0.60),  // gray
    ]

    static let names = ["coral", "amber", "yellow", "green", "teal", "blue", "violet", "pink",
                        "red", "sky", "brown", "gray"]

    /// Menu order: the rainbow, then the neutrals.
    static let menuOrder = [8, 0, 1, 2, 3, 4, 9, 5, 6, 7, 10, 11]

    static func color(_ index: Int, in palette: AppPalette = .current) -> Color {
        palette.tileColor(((index % colors.count) + colors.count) % colors.count)
    }

    static func name(_ index: Int) -> String {
        names[((index % names.count) + names.count) % names.count]
    }

    /// A dot of a palette colour, for menus, which otherwise draw symbols in
    /// one colour.
    static func swatch(_ colorIndex: Int) -> UIImage {
        let size = CGSize(width: 24, height: 24)
        return UIGraphicsImageRenderer(size: size).image { context in
            context.cgContext.setFillColor(UIColor(color(colorIndex)).cgColor)
            context.cgContext.fillEllipse(in: CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1))
        }
        .withRenderingMode(.alwaysOriginal)
    }
}

/// A tile's geometric motif in the tile colour, turned, filling a square of
/// `side` points.
struct TileArtView: View {
    let art: TileArt
    let pattern: TilePattern
    let side: CGFloat

    var body: some View {
        TileMotifView(bits: art.bits, pattern: pattern, colorIndex: art.colorIndex)
            .frame(width: side, height: side)
            .rotationEffect(.degrees(Double(art.quarterTurns) * 90))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: art)
    }
}

/// A person's square on the Tiles canvas: their photo or pattern with their name.
struct PersonTile: View {
    let person: Person
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.tactCardBackground
            if person.showsPhoto, let image = person.thumbnail(maxPixelSize: 512) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
            } else {
                TileArtView(art: person.tile, pattern: person.tilePattern, side: size)
            }
            Text(person.name)
                .font(.tactBold(size: max(10, size * 0.12)))
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
/// pattern when there is none or they chose the pattern.
struct PersonAvatar: View {
    let person: Person
    var size: CGFloat = 40

    var body: some View {
        Group {
            if person.showsPhoto, let image = person.thumbnail(maxPixelSize: 256) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                TileMotifView(person: person)
                    .rotationEffect(.degrees(Double(person.tile.quarterTurns) * 90))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
