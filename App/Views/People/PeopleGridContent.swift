import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a square with
/// their geometric pattern. Tap a tile to open the person; touch and hold to
/// change its color or turn it, or drag it to any cell (gaps allowed).
/// Bring Together closes the gaps. The Games tile sits in the first cell
/// after everyone and stays put while a search hides tiles.
struct PeopleGridContent: View {
    let query: String

    @EnvironmentObject private var store: TactStore
    @State private var dropTarget: Int?

    private let columns = TileLayout.columns
    private let spacing: CGFloat = 1

    /// Cells to draw: enough rows to fill the screen, and always one empty
    /// row below the lowest tile so there is room to build downward.
    static func cellCount(occupied: some Collection<Int>, visibleRows: Int, columns: Int) -> Int {
        let lastRow = occupied.max().map { $0 / columns } ?? -1
        return max(visibleRows, lastRow + 2) * columns
    }

    var body: some View {
        tiles
            .background(Color.tactBackground)
            .overlay(alignment: .bottomTrailing) {
                if store.people.count > 1 && query.isEmpty {
                    CanvasActionButton(title: "Bring Together", systemImage: "square.grid.3x3.topleft.filled",
                                       hint: "Closes the gaps between tiles, keeping their order.",
                                       isEnabled: !TileLayout.isCompact(store.people)) {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                            store.bringTilesTogether()
                        }
                    }
                    .padding(16)
                }
            }
            .overlay {
                if store.people.isEmpty {
                    ContentUnavailableView {
                        Label("No People Yet", systemImage: "square.grid.2x2")
                    } description: {
                        Text("Tap + to add someone. Each person becomes a patterned tile: tap it to open them, or touch and hold to change its color.")
                    }
                    .allowsHitTesting(false)
                }
            }
    }

    private var tiles: some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            let pitch = squareSize + spacing
            let visibleRows = Int((geometry.size.height / pitch).rounded(.up))
            let items = PeopleGridItems(people: store.people, notes: store.notes, query: query)
            let cellCount = Self.cellCount(occupied: items.occupiedCells, visibleRows: visibleRows, columns: columns)
            let origin = { (cell: Int) in
                CGSize(width: CGFloat(cell % columns) * pitch, height: CGFloat(cell / columns) * pitch)
            }

            ScrollView {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<cellCount, id: \.self) { cell in
                        Color.tactTileGray.opacity(0.35)
                            .frame(width: squareSize, height: squareSize)
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: cell)
                            } isTargeted: { targeted in
                                target(cell, targeted)
                            }
                            .offset(origin(cell))
                            .accessibilityHidden(true)
                    }

                    ForEach(items.tiles, id: \.person.id) { placed in
                        tile(for: placed.person, size: squareSize)
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: placed.cell)
                            } isTargeted: { targeted in
                                target(placed.cell, targeted)
                            }
                            .offset(origin(placed.cell))
                            .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }

                    NavigationLink(value: Route.games) {
                        GamesTile(size: squareSize)
                    }
                    .buttonStyle(.plain)
                    .offset(origin(items.gamesCell))
                    .accessibilityLabel("Games")
                    .accessibilityHint("Opens Tangram and the Sliding Puzzle")

                    if let dropTarget {
                        Rectangle()
                            .strokeBorder(.tint, lineWidth: 3)
                            .frame(width: squareSize, height: squareSize)
                            .offset(origin(dropTarget))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: CGFloat(cellCount / columns) * pitch, alignment: .topLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: items)
                .padding(.bottom, 80)
            }
        }
    }

    private func drop(_ items: [String], at cell: Int) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
        store.moveTile(personID: id, toCell: cell)
        return true
    }

    private func target(_ cell: Int, _ targeted: Bool) {
        if targeted { dropTarget = cell } else if dropTarget == cell { dropTarget = nil }
    }

    private func tile(for person: Person, size: CGFloat) -> some View {
        let colorIndex = Binding(
            get: { person.tile.colorIndex },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) { $0.colorIndex = newValue }
            }
        )
        return NavigationLink(value: Route.person(person.id)) {
            PersonTile(person: person, size: size)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Menu {
                Picker("Color", selection: colorIndex) {
                    ForEach(TilePalette.menuOrder, id: \.self) { index in
                        Label {
                            Text(TilePalette.name(index).capitalized)
                        } icon: {
                            Image(uiImage: TilePalette.swatch(index))
                        }
                        .tag(index)
                    }
                }
            } label: {
                Label("Color", systemImage: "paintpalette")
            }
            Button { store.updateTile(forPersonID: person.id) { $0.rotate() } } label: {
                Label("Rotate", systemImage: "rotate.right")
            }
        }
        .draggable(person.id.uuidString) {
            PersonTile(person: person, size: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) tile")
        .accessibilityHint("Opens \(person.name). Touch and hold to change the color, turn the tile, or move it.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Change color") {
            let order = TilePalette.menuOrder
            let next = order[((order.firstIndex(of: person.tile.colorIndex) ?? 0) + 1) % order.count]
            store.updateTile(forPersonID: person.id) { $0.colorIndex = next }
        }
        .accessibilityAction(named: "Rotate") {
            store.updateTile(forPersonID: person.id) { $0.rotate() }
        }
    }
}

/// The tile that opens the games: the Tact mark's colours as a small grid
/// of squares, so it reads as the app's own tile rather than a person's.
struct GamesTile: View {
    let size: CGFloat
    @Environment(\.appPalette) private var palette

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Color.tactCardBackground
            TactLogo(variant: .wordmark, height: size * 0.22, tileColor: { palette.tileColor($0) })
                .frame(width: size, height: size)
                .offset(y: -size * 0.06)
            Text("Games")
                .font(.tactBold(size: max(10, size * 0.12)))
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .padding(5)
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityElement(children: .ignore)
    }
}
