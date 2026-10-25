import SwiftUI

/// The Tangram canvas: pattern blocks (triangles, diamonds, half hexagons
/// and hexagons) lying loose on a table four cells wide. Pieces are not
/// snapped to a grid: drag one anywhere and the pieces in its way are pushed
/// along like wooden blocks. Tap a piece to open the person; touch and hold
/// to change its shape, colour or turn. Fit Together packs every piece in
/// snugly, a different way each time. Reached from the Games screen.
struct TangramGridContent: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.pushRoute) private var pushRoute
    let context: TileGameContext
    /// The piece being dragged and where the finger took hold of it.
    @State private var dragging: (id: UUID, grip: CGSize)?
    /// Fit Together is working out an arrangement (it runs off the main thread).
    @State private var isPacking = false

    private let columns = TangramLayout.columns

    var body: some View {
        GeometryReader { geometry in
            let cellSize = (geometry.size.width / CGFloat(columns)).rounded(.down)
            let positions = TangramLayout.positions(for: store.people)
            let placed = store.people.compactMap { person in positions[person.id].map { (centre: $0, person: person) } }
            let lowest = placed.map { $0.centre.y + $0.person.tangram.bounds.max.y }.max() ?? 0
            let visibleRows = Int((geometry.size.height / cellSize).rounded(.up))
            let rows = max(visibleRows, Int((lowest + 1.5).rounded(.up)))
            let height = CGFloat(rows) * cellSize

            ScrollView {
                ZStack(alignment: .topLeading) {
                    TriangularLattice(cellSize: cellSize)
                        .frame(width: cellSize * CGFloat(columns), height: height)
                        .accessibilityHidden(true)

                    ForEach(placed, id: \.person.id) { centre, person in
                        let offset = person.tangram.boundsOffset
                        piece(for: person, centre: centre, cellSize: cellSize)
                            .position(x: (centre.x + offset.x) * cellSize, y: (centre.y + offset.y) * cellSize)
                            .zIndex(dragging?.id == person.id ? 1 : 0)
                    }
                }
                .frame(width: geometry.size.width, height: height, alignment: .topLeading)
                .coordinateSpace(name: "tangram")
                .animation(dragging == nil ? .spring(response: 0.35, dampingFraction: 0.8) : .interactiveSpring(),
                           value: positions)
                .padding(.bottom, 80)
            }
            .scrollDisabled(dragging != nil)
        }
        .overlay(alignment: .bottomTrailing) {
            if store.people.count > 1 {
                fitControls
                    .padding(16)
            }
        }
    }

    /// Packs every piece in snugly, picking a new arrangement each press.
    private var fitControls: some View {
        CanvasActionButton(title: "Fit Together", systemImage: "shuffle",
                           hint: "Packs every piece in snugly, a different way each time. Pieces may turn to fit.",
                           isEnabled: !isPacking) {
            let people = store.people
            isPacking = true
            Task.detached(priority: .userInitiated) {
                var generator = SystemRandomNumberGenerator()
                let pieces = TangramLayout.packed(people, using: &generator)
                await MainActor.run {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                        store.setTangramPieces(pieces)
                    }
                    isPacking = false
                }
            }
        }
    }

    private func piece(for person: Person, centre: TangramPiece.Point, cellSize: CGFloat) -> some View {
        let piece = person.tangram
        let outline = TangramShape(piece: piece)
        let half = piece.halfExtent
        let size = CGSize(width: CGFloat(half.x * 2) * cellSize, height: CGFloat(half.y * 2) * cellSize)
        let shape = Binding(
            get: { piece.shape },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTangram(forPersonID: person.id) { $0.shape = newValue }
            }
        )
        let colorIndex = Binding(
            get: { piece.resolvedColorIndex },
            set: { newValue in
                UISelectionFeedbackGenerator().selectionChanged()
                store.updateTangram(forPersonID: person.id) {
                    $0.colorIndex = newValue == $0.shape.defaultColorIndex ? nil : newValue
                }
            }
        )
        let drag = DragGesture(minimumDistance: 3, coordinateSpace: .named("tangram"))
            .onChanged { value in
                if dragging?.id != person.id {
                    let grip = CGSize(width: value.startLocation.x - CGFloat(centre.x) * cellSize,
                                      height: value.startLocation.y - CGFloat(centre.y) * cellSize)
                    dragging = (person.id, grip)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                let grip = dragging?.grip ?? .zero
                let target = TangramPiece.Point(x: (value.location.x - grip.width) / cellSize,
                                                y: (value.location.y - grip.height) / cellSize)
                store.moveTangram(personID: person.id, to: target)
            }
            .onEnded { _ in
                dragging = nil
            }
        return TangramPieceView(person: person, side: cellSize)
            .frame(width: size.width, height: size.height)
            .contentShape(outline)
            .contentShape(.contextMenuPreview, outline)
            .shadow(color: .black.opacity(dragging?.id == person.id ? 0.25 : 0), radius: 8, y: 4)
            .scaleEffect(dragging?.id == person.id ? 1.06 : 1)
            .onTapGesture { pushRoute(.person(person.id)) }
            .highPriorityGesture(drag)
            .contextMenu {
                Picker("Shape", selection: shape) {
                    ForEach(TangramPiece.Shape.allCases) { option in
                        Label {
                            Text(option.title)
                        } icon: {
                            Image(uiImage: TangramPieceView.menuIcon(Self.piece(piece, as: option),
                                                                     colorIndex: piece.colorIndex ?? option.defaultColorIndex))
                        }
                        .tag(option)
                    }
                }
                Menu {
                    Picker("Color", selection: colorIndex) {
                        ForEach(TilePalette.menuOrder, id: \.self) { index in
                            Label {
                                Text(TilePalette.name(index).capitalized
                                     + (index == piece.shape.defaultColorIndex ? " (Default)" : ""))
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
                        Label("Rotate", systemImage: "rotate.right")
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(person.name), \(TilePalette.name(piece.resolvedColorIndex)) \(piece.shape.title.lowercased())")
            .accessibilityHint("Opens \(person.name). Touch and hold to change the shape, color or turn, or drag to move the piece.")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "Change shape") {
                let shapes = TangramPiece.Shape.allCases
                let next = shapes[(shapes.firstIndex(of: piece.shape)! + 1) % shapes.count]
                store.updateTangram(forPersonID: person.id) { $0.shape = next }
            }
            .accessibilityAction(named: "Change color") {
                let order = TilePalette.menuOrder
                let next = order[((order.firstIndex(of: piece.resolvedColorIndex) ?? 0) + 1) % order.count]
                store.updateTangram(forPersonID: person.id) { $0.colorIndex = next }
            }
            .accessibilityAction(named: "Rotate") {
                store.updateTangram(forPersonID: person.id) { $0.rotate() }
            }
    }

    private static func piece(_ piece: TangramPiece, as shape: TangramPiece.Shape) -> TangramPiece {
        var preview = piece
        preview.shape = shape
        return preview
    }
}

/// A piece's outline, turned, filling its bounding box.
struct TangramShape: Shape {
    let piece: TangramPiece

    func path(in rect: CGRect) -> Path {
        let box = piece.bounds
        let size = box.max - box.min
        guard size.x > 0, size.y > 0 else { return Path() }
        let scale = min(rect.width / CGFloat(size.x), rect.height / CGFloat(size.y))
        var path = Path()
        path.addLines(piece.corners.map {
            CGPoint(x: rect.minX + CGFloat($0.x - box.min.x) * scale, y: rect.minY + CGFloat($0.y - box.min.y) * scale)
        })
        path.closeSubpath()
        return path
    }
}

/// A person's piece, filled with its colour and labelled with their name at
/// its centre. `side` is the size of one canvas cell.
struct TangramPieceView: View {
    let person: Person
    let side: CGFloat
    @Environment(\.appPalette) private var palette

    var body: some View {
        let piece = person.tangram
        let outline = TangramShape(piece: piece)
        let half = piece.halfExtent
        ZStack {
            outline.fill(TilePalette.color(piece.resolvedColorIndex, in: palette))
            outline.stroke(Color.tactBackground, lineWidth: 1)
            Text(person.name)
                .font(.tactBold(size: max(9, side * 0.11)))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
                .frame(maxWidth: CGFloat(half.x * 2) * side - 6)
                .offset(x: -CGFloat(piece.boundsOffset.x) * side, y: -CGFloat(piece.boundsOffset.y) * side)
        }
        .frame(width: CGFloat(half.x * 2) * side, height: CGFloat(half.y * 2) * side)
    }

    /// The piece's outline in a colour, for menus.
    static func menuIcon(_ piece: TangramPiece, colorIndex: Int) -> UIImage {
        let box = CGRect(x: 0, y: 0, width: 24, height: 24)
        let half = piece.halfExtent
        let scale = 22 / CGFloat(max(half.x, half.y) * 2)
        let rect = CGRect(x: box.midX - CGFloat(half.x) * scale, y: box.midY - CGFloat(half.y) * scale,
                          width: CGFloat(half.x * 2) * scale, height: CGFloat(half.y * 2) * scale)
        let path = TangramShape(piece: piece).path(in: rect)
        return UIGraphicsImageRenderer(size: box.size).image { context in
            context.cgContext.addPath(path.cgPath)
            context.cgContext.setFillColor(UIColor(TilePalette.color(colorIndex)).cgColor)
            context.cgContext.fillPath()
        }
        .withRenderingMode(.alwaysOriginal)
    }
}

/// The table the pieces lie on: a faint triangular lattice the size of the
/// pieces' edges, so it is easy to see when they line up.
private struct TriangularLattice: View {
    let cellSize: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.tactTileGray.opacity(0.35)))
            let edge = cellSize * CGFloat(TangramPiece.edge)
            let height = cellSize * CGFloat(TangramPiece.triangleHeight)
            var lines = Path()
            var y: CGFloat = 0
            while y <= size.height {
                lines.move(to: CGPoint(x: 0, y: y))
                lines.addLine(to: CGPoint(x: size.width, y: y))
                y += height
            }
            // Diagonals at ±60°.
            let span = size.height / 3.0.squareRoot()
            var x = -size.height
            while x <= size.width + size.height {
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x + span, y: size.height))
                lines.move(to: CGPoint(x: x, y: 0))
                lines.addLine(to: CGPoint(x: x - span, y: size.height))
                x += edge
            }
            context.stroke(lines, with: .color(Color.secondary.opacity(0.12)), lineWidth: 0.5)
        }
    }
}
