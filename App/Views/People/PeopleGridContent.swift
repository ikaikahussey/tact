import SwiftUI

/// The Tiles canvas: a four-column grid where each person is a square with
/// their geometric pattern. Tap a tile to open the person; touch and hold to
/// start a note, change its color, turn it or delete the person, or drag
/// it to any cell (gaps allowed). Edit puts a delete badge on every tile.
/// Bring Together closes the gaps.
struct PeopleGridContent: View {
    let query: String
    /// Edit mode: each tile wears a delete badge instead of opening.
    var isEditing = false

    @EnvironmentObject private var store: TactStore
    @State private var dropTarget: Int?
    @State private var addingNoteFor: Person?
    @State private var deleting: Person?

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
            .sheet(item: $addingNoteFor) { person in
                AddNoteView(personID: person.id)
            }
            .alert("Delete \(deleting?.name ?? "")?", isPresented: Binding(
                get: { deleting != nil }, set: { if !$0 { deleting = nil } })
            ) {
                Button("Cancel", role: .cancel) { deleting = nil }
                Button("Delete", role: .destructive) {
                    if let deleting { store.deletePerson(id: deleting.id) }
                    deleting = nil
                }
            } message: {
                Text("Notes linked only to this person are deleted too. Notes shared with other people are kept.")
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
                .animation(.snappy, value: isEditing)
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
        .disabled(isEditing)
        .overlay(alignment: .topLeading) {
            if isEditing {
                Button { deleting = person } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.tact(.title2))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .padding(6)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(person.name)")
                .transition(.scale.combined(with: .opacity))
            }
        }
        .contextMenu {
            Button { addingNoteFor = person } label: {
                Label("New Note", systemImage: "square.and.pencil")
            }
            Divider()
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
            Divider()
            Button(role: .destructive) { deleting = person } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .draggable(person.id.uuidString) {
            PersonTile(person: person, size: size)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) tile")
        .accessibilityHint("Opens \(person.name). Touch and hold for a new note, the color, turning, or deleting; drag to move it.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Change color") {
            let order = TilePalette.menuOrder
            let next = order[((order.firstIndex(of: person.tile.colorIndex) ?? 0) + 1) % order.count]
            store.updateTile(forPersonID: person.id) { $0.colorIndex = next }
        }
        .accessibilityAction(named: "Rotate") {
            store.updateTile(forPersonID: person.id) { $0.rotate() }
        }
        .accessibilityAction(named: "New note") { addingNoteFor = person }
        .accessibilityAction(named: "Delete") { deleting = person }
    }
}
