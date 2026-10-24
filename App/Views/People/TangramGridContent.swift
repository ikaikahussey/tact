import SwiftUI

/// The Tangram canvas: a four-column grid with each cell split along its
/// diagonals, where pieces fit together like a tangram. Two triangles can
/// share a cell, and squares turn 45° into diamonds that four triangles fit
/// around. Tap a piece to open the person; touch and hold to change its
/// shape, colour or turn, or drag it somewhere else. A triangle dropped next
/// to another turns to fill the gap if it can. Fit Together packs every
/// piece in as snugly as it can, a different way each time.
struct TangramGridContent: View {
    @EnvironmentObject private var store: TactStore
    @State private var openPersonID: UUID?
    @State private var dropTarget: Int?

    private let columns = TangramLayout.columns

    var body: some View {
        GeometryReader { geometry in
            let cellSize = (geometry.size.width / CGFloat(columns)).rounded(.down)
            let visibleRows = Int((geometry.size.height / cellSize).rounded(.up))
            let anchors = TangramLayout.anchors(for: store.people)
            let placed = store.people.compactMap { person in anchors[person.id].map { (anchor: $0, person: person) } }
            let occupied = placed.flatMap { TangramLayout.footprint(of: $0.person.tangram, at: $0.anchor) ?? [] }
                .map { $0 / 4 }
            let cellCount = PeopleGridContent.cellCount(occupied: occupied, visibleRows: visibleRows, columns: columns)
            let origin = { (cell: Int) in
                CGSize(width: CGFloat(cell % columns) * cellSize, height: CGFloat(cell / columns) * cellSize)
            }

            ScrollView {
                ZStack(alignment: .topLeading) {
                    ForEach(0..<cellCount, id: \.self) { cell in
                        LatticeCell()
                            .frame(width: cellSize, height: cellSize)
                            .contentShape(Rectangle())
                            .dropDestination(for: String.self) { items, _ in
                                drop(items, at: cell)
                            } isTargeted: { targeted in
                                target(cell, targeted)
                            }
                            .offset(origin(cell))
                            .accessibilityHidden(true)
                    }

                    ForEach(placed, id: \.person.id) { anchor, person in
                        piece(for: person, cellSize: cellSize)
                            .dropDestination(for: String.self) { items, location in
                                drop(items, at: anchor + Int(location.y / cellSize) * columns + Int(location.x / cellSize))
                            } isTargeted: { targeted in
                                target(anchor, targeted)
                            }
                            .offset(origin(anchor))
                    }

                    if let dropTarget {
                        Rectangle()
                            .strokeBorder(Color.accentColor, lineWidth: 3)
                            .frame(width: cellSize, height: cellSize)
                            .offset(origin(dropTarget))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: geometry.size.width, height: CGFloat(cellCount / columns) * cellSize, alignment: .topLeading)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: anchors)
                .padding(.bottom, 80)
            }
        }
        .background(Color.tactBackground)
        .overlay(alignment: .bottomTrailing) {
            if store.people.count > 1 {
                fitControls
                    .padding(16)
            }
        }
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "square.split.diagonal.2x2")
                } description: {
                    Text("Tap + to add someone. Each person becomes a tangram piece: tap it to open them, or touch and hold to change its shape, colour or turn.")
                }
            }
        }
        .navigationDestination(item: $openPersonID) { id in
            PersonDetailView(personID: id)
        }
    }

    /// Packs every piece in snugly, picking a new arrangement each press.
    private var fitControls: some View {
        Button {
            var generator = SystemRandomNumberGenerator()
            let pieces = TangramLayout.packed(store.people, using: &generator)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                store.setTangramPieces(pieces)
            }
        } label: {
            Label("Fit Together", systemImage: "shuffle")
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .accessibilityHint("Packs every piece in snugly, a different way each time. Triangles may turn to fit.")
    }

    private func drop(_ items: [String], at cell: Int) -> Bool {
        guard let id = items.first.flatMap(UUID.init(uuidString:)) else { return false }
        store.moveTangram(personID: id, toCell: cell)
        return true
    }

    private func target(_ cell: Int, _ targeted: Bool) {
        if targeted { dropTarget = cell } else if dropTarget == cell { dropTarget = nil }
    }

    private func piece(for person: Person, cellSize: CGFloat) -> some View {
        let piece = person.tangram
        let side = cellSize * CGFloat(piece.blockSize)
        let outline = TangramShape(piece: piece)
        let shape = Binding(
            get: { piece.shape },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTangram(forPersonID: person.id) { $0.shape = newValue }
            }
        )
        let colorIndex = Binding(
            get: { person.tile.colorIndex },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTile(forPersonID: person.id) { $0.colorIndex = newValue }
            }
        )
        return TangramPieceView(person: person, side: side)
            .contentShape(outline)
            .contentShape(.contextMenuPreview, outline)
            .contentShape(.dragPreview, outline)
            .onTapGesture { openPersonID = person.id }
            .contextMenu {
                Picker("Shape", selection: shape) {
                    ForEach(TangramPiece.Shape.allCases) { option in
                        Label {
                            Text(option.title)
                        } icon: {
                            Image(uiImage: TangramPieceView.menuIcon(Self.piece(piece, as: option),
                                                                     colorIndex: person.tile.colorIndex))
                        }
                        .tag(option)
                    }
                }
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
                if piece.canRotate {
                    Button { store.updateTangram(forPersonID: person.id) { $0.rotate() } } label: {
                        Label(Self.rotateTitle(piece), systemImage: piece.shape.isSquare ? "diamond" : "rotate.right")
                    }
                }
            }
            .draggable(person.id.uuidString) {
                TangramPieceView(person: person, side: side)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(person.name), \(TilePalette.name(person.tile.colorIndex)) \(Self.description(piece))")
            .accessibilityHint("Opens \(person.name). Touch and hold to change the shape, colour or turn, or to move the piece.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Change shape") {
                let shapes = TangramPiece.Shape.allCases
                let next = shapes[(shapes.firstIndex(of: piece.shape)! + 1) % shapes.count]
                store.updateTangram(forPersonID: person.id) { $0.shape = next }
            }
            .accessibilityAction(named: "Change colour") {
                let order = TilePalette.menuOrder
                let next = order[((order.firstIndex(of: person.tile.colorIndex) ?? 0) + 1) % order.count]
                store.updateTile(forPersonID: person.id) { $0.colorIndex = next }
            }
            .accessibilityAction(named: piece.canRotate ? Self.rotateTitle(piece) : "Rotate") {
                store.updateTangram(forPersonID: person.id) { $0.rotate() }
            }
    }

    private static func piece(_ piece: TangramPiece, as shape: TangramPiece.Shape) -> TangramPiece {
        var preview = piece
        preview.shape = shape
        return preview
    }

    private static func rotateTitle(_ piece: TangramPiece) -> String {
        if piece.shape.isSquare { return piece.isTilted ? "Straighten" : "Turn 45°" }
        return "Rotate"
    }

    private static func description(_ piece: TangramPiece) -> String {
        if piece.shape.isSquare && piece.isTilted {
            return piece.shape == .largeSquare ? "large diamond" : "diamond"
        }
        return piece.shape.title.lowercased()
    }
}

/// A piece's outline in a square of its block size: a polygon on the
/// diagonal lattice, or a circle.
struct TangramShape: Shape {
    let piece: TangramPiece

    func path(in rect: CGRect) -> Path {
        if piece.shape == .circle { return Path(ellipseIn: rect) }
        let unit = rect.width / CGFloat(piece.blockSize)
        var path = Path()
        path.addLines(piece.polygon.map { CGPoint(x: rect.minX + $0.x * unit, y: rect.minY + $0.y * unit) })
        path.closeSubpath()
        return path
    }
}

/// A person's piece, filled with their colour and labelled with their name
/// at its centre.
struct TangramPieceView: View {
    let person: Person
    let side: CGFloat

    var body: some View {
        let piece = person.tangram
        let outline = TangramShape(piece: piece)
        let corners = piece.shape == .circle ? [] : piece.polygon
        let unit = side / CGFloat(piece.blockSize)
        let centre = corners.isEmpty
            ? CGPoint(x: side / 2, y: side / 2)
            : CGPoint(x: corners.map(\.x).reduce(0, +) / Double(corners.count) * unit,
                      y: corners.map(\.y).reduce(0, +) / Double(corners.count) * unit)
        ZStack(alignment: .topLeading) {
            outline.fill(TilePalette.color(person.tile.colorIndex))
            outline.stroke(Color.tactBackground, lineWidth: 1)
            Text(person.name)
                .font(.system(size: max(9, unit * 0.11), weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .position(centre)
        }
        .frame(width: side, height: side)
    }

    /// The piece's outline in a colour, for menus. Pieces one cell across are
    /// drawn smaller than bigger ones.
    static func menuIcon(_ piece: TangramPiece, colorIndex: Int) -> UIImage {
        let box = CGRect(x: 0, y: 0, width: 24, height: 24)
        let side: CGFloat = piece.blockSize == 1 && piece.shape != .circle ? 14 : 22
        let rect = CGRect(x: 1, y: box.maxY - 1 - side, width: side, height: side)
        let path = TangramShape(piece: piece).path(in: rect)
        return UIGraphicsImageRenderer(size: box.size).image { context in
            context.cgContext.addPath(path.cgPath)
            context.cgContext.setFillColor(UIColor(TilePalette.color(colorIndex)).cgColor)
            context.cgContext.fillPath()
        }
        .withRenderingMode(.alwaysOriginal)
    }
}

/// An empty cell, with faint diagonals showing where pieces can meet.
private struct LatticeCell: View {
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(Color.tactTileGray.opacity(0.35)))
            var lines = Path()
            lines.addRect(rect)
            lines.move(to: .zero)
            lines.addLine(to: CGPoint(x: size.width, y: size.height))
            lines.move(to: CGPoint(x: size.width, y: 0))
            lines.addLine(to: CGPoint(x: 0, y: size.height))
            context.stroke(lines, with: .color(Color.secondary.opacity(0.15)), lineWidth: 0.5)
        }
    }
}
