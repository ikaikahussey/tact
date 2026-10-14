import SwiftUI

/// A tangram made of people: seven people become the seven pieces. In Shapes
/// mode they fill a silhouette; in Free Play they make whatever you like.
/// Drag to move, tap to turn, double-tap the parallelogram to flip, and touch
/// and hold a piece to open that person.
struct TangramGameView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case shapes = "Shapes"
        case freePlay = "Free Play"
        var id: String { rawValue }
    }

    static let piecesPerSet = TangramPiece.allCases.count

    @EnvironmentObject private var store: TactStore
    @State private var mode: Mode = .shapes
    @State private var figureIndex = 0
    @State private var setIndex = 0
    @State private var puzzle = TangramPuzzle(figure: TangramFigure.all[0])
    @State private var dragging: (id: Int, translation: CGSize)?
    @State private var showsOutline = false
    @State private var isSolved = false
    @State private var celebrate = false
    @State private var openPersonID: UUID?

    private var setCount: Int { store.people.count / Self.piecesPerSet }

    /// The people playing this round, one per piece.
    private var players: [Person] {
        let start = min(setIndex, max(0, setCount - 1)) * Self.piecesPerSet
        return Array(store.people.dropFirst(start).prefix(Self.piecesPerSet))
    }

    var body: some View {
        Group {
            if setCount == 0 {
                let missing = Self.piecesPerSet - store.people.count
                ContentUnavailableView {
                    Label("Tangram", systemImage: Game.tangram.systemImage)
                } description: {
                    Text("Seven people make one tangram. Add \(missing) more \(missing == 1 ? "person" : "people") to play.")
                }
            } else {
                game
            }
        }
        .background(Color.tactBackground)
        .navigationTitle("Tangram")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $openPersonID) { id in
            PersonDetailView(personID: id)
        }
    }

    private var game: some View {
        VStack(spacing: 12) {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            status
                .frame(minHeight: 22)

            GeometryReader { geometry in
                let scale = min(geometry.size.width / TangramPuzzle.width,
                                geometry.size.height / TangramPuzzle.height)
                board(scale: scale)
                    .frame(width: TangramPuzzle.width * scale, height: TangramPuzzle.height * scale)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            controls
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .padding(.top, 8)
        .onChange(of: mode) { _, _ in newRound() }
        .onChange(of: store.people.count) { _, _ in
            if setIndex >= setCount { setIndex = 0 }
        }
    }

    // MARK: Status and controls

    @ViewBuilder
    private var status: some View {
        if mode == .freePlay {
            Text("Make anything you like.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else if isSolved, let figure = puzzle.figure {
            Label("You made the \(figure.name.lowercased())!", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.green)
                .transition(.scale.combined(with: .opacity))
        } else if let figure = puzzle.figure {
            Text("Make the \(figure.name.lowercased())")
                .font(.subheadline.weight(.semibold))
        }
    }

    private var controls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 10) {
                if mode == .shapes {
                    Button {
                        withAnimation { showsOutline.toggle() }
                    } label: {
                        Label("Hint", systemImage: showsOutline ? "lightbulb.fill" : "lightbulb")
                    }
                    .accessibilityHint("Shows where each piece goes")
                    Button {
                        figureIndex = (figureIndex + 1) % TangramFigure.all.count
                        newRound()
                    } label: {
                        Label("Next Shape", systemImage: "arrow.forward")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { puzzle.reset() }
                    isSolved = false
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                if setCount > 1 {
                    Button {
                        setIndex = (setIndex + 1) % setCount
                    } label: {
                        Label("Next 7", systemImage: "person.2")
                    }
                    .accessibilityLabel("Next seven people")
                }
            }
            .buttonStyle(.bordered)
            .labelStyle(.titleAndIcon)
            .font(.subheadline)

            Text("Drag to move · tap to turn · double-tap the parallelogram to flip · hold to open a person")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    // MARK: Board

    private func board(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            Color.clear
            if !puzzle.target.isEmpty {
                silhouette(scale: scale)
            }
            ForEach(puzzle.order, id: \.self) { id in
                if let piece = puzzle.pieces.first(where: { $0.id == id }), players.indices.contains(id) {
                    pieceView(piece, person: players[id], scale: scale)
                }
            }
        }
        .coordinateSpace(name: "board")
    }

    private func silhouette(scale: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            // One path, so neighbouring pieces fill without hairline seams.
            Path { path in
                for polygon in puzzle.target {
                    path.addLines(polygon.map { CGPoint(x: $0.x * scale, y: $0.y * scale) })
                    path.closeSubpath()
                }
            }
            .fill(isSolved ? Color.green.opacity(0.25) : Color.primary.opacity(0.12))
            if showsOutline {
                Path { path in
                    for polygon in puzzle.target {
                        path.addLines(polygon.map { CGPoint(x: $0.x * scale, y: $0.y * scale) })
                        path.closeSubpath()
                    }
                }
                .stroke(Color.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel(puzzle.figure.map { "Silhouette of a \($0.name.lowercased())" } ?? "")
    }

    private func pieceView(_ piece: TangramPuzzle.Piece, person: Person, scale: CGFloat) -> some View {
        let design = TangramDesign(seed: person.colorSeed)
        let local = piece.localPolygon.map { CGPoint(x: $0.x * scale, y: $0.y * scale) }
        let extent = (local.map { max(abs($0.x), abs($0.y)) }.max() ?? 1) * 2
        let isDragged = dragging?.id == piece.id
        let offset = isDragged ? dragging!.translation : .zero
        let center = CGPoint(x: piece.center.x * scale + offset.width, y: piece.center.y * scale + offset.height)
        let isParallelogram = piece.shape == .parallelogram

        return ZStack {
            PolygonShape(points: local)
                .fill(Color(design.background))
                .overlay(PolygonShape(points: local).stroke(Color.white.opacity(0.55), lineWidth: 1))
                .frame(width: extent, height: extent)
                .scaleEffect(x: piece.flipped ? -1 : 1, y: 1)
                .rotationEffect(.degrees(Double(piece.rotation) * 45))
                .contentShape(PolygonShape(points: local))
                .shadow(color: .black.opacity(isDragged ? 0.3 : 0), radius: isDragged ? 8 : 0, y: isDragged ? 4 : 0)
                .scaleEffect(celebrate ? 1.08 : 1)
                .animation(.spring(response: 0.3, dampingFraction: 0.5).delay(Double(piece.id) * 0.04), value: celebrate)
            Text(Self.label(for: person, shape: piece.shape))
                .font(.system(size: max(9, scale * Self.fontScale(piece.shape)), weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: scale * Self.labelWidth(piece.shape))
                .foregroundStyle(design.textIsDark ? Color.black.opacity(0.85) : Color.white)
                .allowsHitTesting(false)
        }
        .frame(width: extent, height: extent)
        .position(center)
        .gesture(dragGesture(for: piece.id, scale: scale))
        .modifier(PieceTaps(canFlip: isParallelogram,
                            turn: { rotate(piece.id) },
                            flip: { flip(piece.id) }))
        .onLongPressGesture(minimumDuration: 0.45) {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            openPersonID = person.id
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(person.name), \(Self.pieceName(piece.shape))")
        .accessibilityAction(named: "Turn") { rotate(piece.id) }
        .accessibilityAction(named: "Turn back") { rotate(piece.id, by: -1) }
        .accessibilityAction(named: "Flip") { flip(piece.id) }
        .accessibilityAction(named: "Open person") { openPersonID = person.id }
    }

    private func dragGesture(for id: Int, scale: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .named("board"))
            .onChanged { value in
                if dragging?.id != id {
                    withAnimation(.easeOut(duration: 0.1)) { puzzle.move(id, by: .zero) }
                }
                dragging = (id, value.translation)
            }
            .onEnded { value in
                dragging = nil
                puzzle.move(id, by: CGPoint(x: value.translation.width / scale, y: value.translation.height / scale))
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    if puzzle.snap(id) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                }
                checkSolved()
            }
    }

    // MARK: Actions

    private func rotate(_ id: Int, by eighths: Int = 1) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            puzzle.rotate(id, by: eighths)
            puzzle.snap(id, within: 0.2)
        }
        checkSolved()
    }

    private func flip(_ id: Int) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            puzzle.flip(id)
            puzzle.snap(id, within: 0.2)
        }
        checkSolved()
    }

    private func checkSolved() {
        let solved = puzzle.isSolved
        guard solved != isSolved else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) { isSolved = solved }
        guard solved else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        celebrate = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { celebrate = false }
    }

    private func newRound() {
        showsOutline = false
        isSolved = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            puzzle = TangramPuzzle(figure: mode == .shapes ? TangramFigure.all[figureIndex] : nil)
        }
    }

    // MARK: Labels

    /// First name on the bigger pieces, initials on the small triangles.
    static func label(for person: Person, shape: TangramPiece) -> String {
        let words = person.name.split(separator: " ")
        switch shape {
        case .smallTriangleA, .smallTriangleB:
            return words.prefix(2).compactMap(\.first).map(String.init).joined().uppercased()
        default:
            return words.first.map(String.init) ?? person.name
        }
    }

    private static func fontScale(_ shape: TangramPiece) -> CGFloat {
        switch shape {
        case .largeTriangleA, .largeTriangleB: return 0.42
        case .smallTriangleA, .smallTriangleB: return 0.3
        default: return 0.34
        }
    }

    private static func labelWidth(_ shape: TangramPiece) -> CGFloat {
        switch shape {
        case .largeTriangleA, .largeTriangleB: return 2.2
        case .mediumTriangle, .parallelogram: return 1.5
        case .square: return 1.3
        case .smallTriangleA, .smallTriangleB: return 0.8
        }
    }

    private static func pieceName(_ shape: TangramPiece) -> String {
        switch shape {
        case .largeTriangleA, .largeTriangleB: return "large triangle"
        case .mediumTriangle: return "medium triangle"
        case .smallTriangleA, .smallTriangleB: return "small triangle"
        case .square: return "square"
        case .parallelogram: return "parallelogram"
        }
    }
}

/// Tap to turn. Only the parallelogram also listens for a double tap (to
/// flip), so the other pieces turn without waiting to rule one out.
private struct PieceTaps: ViewModifier {
    let canFlip: Bool
    let turn: () -> Void
    let flip: () -> Void

    func body(content: Content) -> some View {
        if canFlip {
            content
                .onTapGesture(count: 2, perform: flip)
                .onTapGesture(perform: turn)
        } else {
            content.onTapGesture(perform: turn)
        }
    }
}

/// A closed polygon whose points are relative to the centre of its frame.
struct PolygonShape: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: CGPoint(x: rect.midX + first.x, y: rect.midY + first.y))
        for point in points.dropFirst() {
            path.addLine(to: CGPoint(x: rect.midX + point.x, y: rect.midY + point.y))
        }
        path.closeSubpath()
        return path
    }
}
