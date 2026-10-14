import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a filled square
/// or right-angle triangle. Free play: tap a tile to turn it and change its
/// colour, double-tap to switch between square and triangle, and touch and
/// hold to drag it to any cell (gaps allowed) or open the person.
struct PeopleGridContent: View {
    @EnvironmentObject private var store: TactStore
    @State private var openPersonID: UUID?
    @State private var dropTarget: Int?

    private let columns = 4
    private let spacing: CGFloat = 1

    /// Cells to draw: enough rows to fill the screen, and always one empty
    /// row below the lowest tile so there is room to build downward.
    static func cellCount(occupied: some Collection<Int>, visibleRows: Int, columns: Int) -> Int {
        let lastRow = occupied.max().map { $0 / columns } ?? -1
        return max(visibleRows, lastRow + 2) * columns
    }

    var body: some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            let visibleRows = Int((geometry.size.height / (squareSize + spacing)).rounded(.up))
            let layout = TileLayout.cells(for: store.people)
            let people = Dictionary(store.people.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(squareSize), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(0..<Self.cellCount(occupied: layout.keys, visibleRows: visibleRows, columns: columns),
                            id: \.self) { cell in
                        Group {
                            if let id = layout[cell], let person = people[id] {
                                tile(for: person, size: squareSize)
                            } else {
                                Color.tactTileGray.opacity(0.35)
                                    .frame(width: squareSize, height: squareSize)
                                    .accessibilityHidden(true)
                            }
                        }
                        .overlay {
                            if dropTarget == cell {
                                Rectangle().strokeBorder(Color.accentColor, lineWidth: 3)
                            }
                        }
                        .dropDestination(for: String.self) { items, _ in
                            guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                store.moveTile(personID: id, toCell: cell)
                            }
                            return true
                        } isTargeted: { targeted in
                            if targeted { dropTarget = cell } else if dropTarget == cell { dropTarget = nil }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.tactBackground)
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "square.grid.2x2")
                } description: {
                    Text("Tap + to add someone. Each person becomes a tile you can turn, recolour and move.")
                }
            }
        }
        .navigationDestination(item: $openPersonID) { id in
            PersonDetailView(personID: id)
        }
    }

    private func tile(for person: Person, size: CGFloat) -> some View {
        PersonTile(person: person, size: size)
            .contentShape(Rectangle())
            .onTapGesture(count: 2) {
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) { $0.toggleShape() }
            }
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                store.updateTile(forPersonID: person.id) { $0.advance() }
            }
            .contextMenu {
                Button { openPersonID = person.id } label: {
                    Label("Open \(person.name)", systemImage: "person.crop.circle")
                }
                Button { store.updateTile(forPersonID: person.id) { $0.toggleShape() } } label: {
                    Label(person.tile.shape == .square ? "Make Triangle" : "Make Square",
                          systemImage: person.tile.shape == .square ? "triangle" : "square")
                }
            }
            .draggable(person.id.uuidString) {
                PersonTile(person: person, size: size)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) \(person.tile.shape.rawValue)")
            .accessibilityHint("Double-tap to turn and change colour. Touch and hold to move or open.")
            .accessibilityAction(named: "Switch shape") {
                store.updateTile(forPersonID: person.id) { $0.toggleShape() }
            }
            .accessibilityAction(named: "Open \(person.name)") { openPersonID = person.id }
    }
}
