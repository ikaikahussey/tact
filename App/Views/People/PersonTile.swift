import SwiftUI

enum TileStyle: Equatable {
    /// The person's photo, or their name on a plain card.
    case photo
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
            case .photo:
                if let image = person.thumbnail() {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color.tactCardBackground
                    Text(person.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.6)
                        .padding(6)
                }
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(person.name)
    }
}

/// Circular avatar used in lists.
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
                Circle()
                    .fill(Color.tactTileGray)
                    .overlay(Image(systemName: "person.fill").foregroundStyle(.secondary))
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}
