import SwiftUI

enum TileStyle: Equatable {
    /// The person's generated tangram artwork with their name.
    case tangram
    /// A colour derived from the person's seed.
    case color(ColorPalette)
}

/// A square representing one person in the grid layouts and pickers.
struct PersonTile: View {
    let person: Person
    let style: TileStyle
    let size: CGFloat

    var body: some View {
        ZStack {
            switch style {
            case .color(let palette):
                RandomColor.color(seed: person.colorSeed, palette: palette)
            case .tangram:
                TangramTileView(person: person, size: size)
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.name)
    }
}

/// Circular avatar used in lists and chips: the photo, or the tangram artwork
/// when there is none.
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
                TangramTileView(person: person, size: size, showsName: false)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
