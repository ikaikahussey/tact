import SwiftUI

/// Where each person's tile sits on the grid, reported up to the root.
struct TileAnchors: PreferenceKey {
    static var defaultValue: [UUID: Anchor<CGRect>] = [:]
    static func reduce(value: inout [UUID: Anchor<CGRect>], nextValue: () -> [UUID: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

/// Where each person's avatar sits in the list, in global coordinates.
/// Rows write here as they lay out: preferences do not escape a List's
/// cells, so the rows report through this object instead.
@Observable
final class AvatarFrames {
    var frames: [UUID: CGRect] = [:]
}

/// A tile in flight between the grid and the list.
struct TileFlight: Equatable {
    /// Toward the list (tiles shrink into their rows) or back to the grid.
    let toList: Bool
    /// 0 at the start, 1 at the end; animated.
    var progress: Double = 0

    static let duration = 0.5
}

/// Copies of every tile that slide between their grid cells and their list
/// rows while the real views are hidden. A tile whose row is off screen
/// heads for the bottom edge and fades.
struct TileFlightOverlay: View {
    let flight: TileFlight
    let people: [Person]
    let tiles: [UUID: Anchor<CGRect>]
    let avatars: [UUID: CGRect]

    var body: some View {
        GeometryReader { geometry in
            let origin = geometry.frame(in: .global).origin
            ForEach(people) { person in
                if let tileAnchor = tiles[person.id] {
                    let tile = geometry[tileAnchor]
                    let row = avatars[person.id].map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
                    let fallback = CGRect(x: 30, y: geometry.size.height + 20, width: 28, height: 28)
                    let listFrame = row ?? fallback
                    let atList = flight.toList ? flight.progress >= 1 : flight.progress < 1
                    let frame = atList ? listFrame : tile
                    let radius = atList ? listFrame.width / 2 : 0
                    TileFace(person: person)
                        .frame(width: frame.width, height: frame.height)
                        .clipShape(RoundedRectangle(cornerRadius: radius))
                        .position(x: frame.midX, y: frame.midY)
                        .opacity(atList && row == nil ? 0 : 1)
                }
            }
        }
        .animation(.spring(response: TileFlight.duration, dampingFraction: 0.86), value: flight.progress)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// A person's tile without its name: the photo or the pattern, square.
struct TileFace: View {
    let person: Person

    var body: some View {
        ZStack {
            Color.tactCardBackground
            if person.showsPhoto, let image = person.thumbnail(maxPixelSize: 512) {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                TileMotifView(person: person)
                    .rotationEffect(.degrees(Double(person.tile.quarterTurns) * 90))
            }
        }
        .clipped()
    }
}
