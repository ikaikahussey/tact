import SwiftUI

/// Lights Out on the back of the tiles: the top four rows are a board of
/// sixteen lights, one per cell. A lit cell shows the motif of the person
/// whose tile sits there, in their colour; an unlit cell is a dim square.
/// Tapping a light toggles it and its four neighbours. Turn every light off
/// to win. Touch and hold a light to open the person. Played on the back of
/// the tiles (`TileGame.lightsOut`): the lights turn into view as the tiles
/// turn over. The board stays as it is while the tiles are open.
struct LightsOutGame: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.pushRoute) private var pushRoute
    @Environment(\.appPalette) private var palette
    @AppStorage(GameSounds.enabledKey) private var soundOn = true
    let context: TileGameContext
    @State private var board: LightsOut = {
        var board = LightsOut(columns: LightsOutGame.columns, rows: LightsOutGame.rows)
        board.scramble(presses: LightsOutGame.scramblePresses)
        return board
    }()
    /// The cell last pressed, so its neighbours can flash with it.
    @State private var pressed: Int?

    static let columns = TileLayout.columns
    static let rows = 4
    /// Lights pressed to scramble a new game: enough to light most of the
    /// board, few enough that it can be seen through.
    static let scramblePresses = 5

    private var anchors: [Int: Person] {
        let byPerson = TileLayout.anchors(for: store.people)
        return Dictionary(uniqueKeysWithValues: store.people.compactMap { person in
            byPerson[person.id].map { ($0, person) }
        })
    }

    var body: some View {
        let people = anchors
        ZStack(alignment: .topLeading) {
            ForEach(0..<board.count, id: \.self) { cell in
                light(cell, person: people[cell])
                    .modifier(TileFlipFace(side: .back, showingBack: context.isShowing, delay: context.flipDelay(cell)))
                    .position(center(of: cell))
            }

            status
                .frame(width: context.size.width - 32, alignment: .leading)
                .offset(x: 16, y: CGFloat(Self.rows) * context.pitch + 12)
                .opacity(context.isShowing ? 1 : 0)
                .animation(.easeInOut(duration: 0.2).delay(context.isShowing ? 0.35 : 0), value: context.isShowing)
                .accessibilityHidden(!context.isShowing)
        }
        .frame(width: context.size.width, height: context.size.height, alignment: .topLeading)
        .overlay(alignment: .bottomTrailing) {
            if context.isShowing {
                HStack(spacing: 12) {
                    CanvasActionButton(title: soundOn ? "Sound On" : "Sound Off",
                                       systemImage: soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                       hint: "Turns the beeps on or off.") {
                        soundOn.toggle()
                        if soundOn { GameSounds.play(GameSounds.lightPressed(cell: 0, lit: true)) } else { Synth.shared.stop() }
                    }
                    CanvasActionButton(title: "New Game", systemImage: "shuffle",
                                       hint: "Scrambles the lights and starts again.") {
                        withAnimation(.easeInOut(duration: 0.3)) { board.scramble(presses: Self.scramblePresses) }
                        GameSounds.play(GameSounds.scrambled())
                    }
                }
                .padding(16)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: context.isShowing)
    }

    /// One light. With a person on the cell it is their motif in their
    /// colour; otherwise a motif and colour picked from the cell number.
    private func light(_ cell: Int, person: Person?) -> some View {
        let isLit = board.isLit(cell)
        let colorIndex = person?.tile.colorIndex ?? cell % TileArt.colorCount
        let pattern = person?.tilePattern ?? TilePattern(seed: cell * 3)
        let turns = person?.tile.quarterTurns ?? 0
        let shades = TileShades(colorIndex: colorIndex, palette: palette)
        return ZStack {
            Color.tactTileGray
            TileMotifView(bits: person?.tile.bits, pattern: pattern, colorIndex: colorIndex)
                .rotationEffect(.degrees(Double(turns) * 90))
                .opacity(isLit ? 1 : 0)
            Rectangle()
                .strokeBorder(shades.dark.opacity(isLit ? 0 : 0.25), lineWidth: 1)
        }
        .frame(width: context.cellSize, height: context.cellSize)
        .scaleEffect(pressed == cell ? 0.92 : 1)
        .animation(.easeInOut(duration: 0.18), value: isLit)
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: pressed)
        .contentShape(Rectangle())
        .onTapGesture { press(cell) }
        .onLongPressGesture(minimumDuration: 0.4) {
            if let person { pushRoute(.person(person.id)) }
        }
        .accessibilityElement()
        .accessibilityLabel(person.map { "\($0.name), \(isLit ? "on" : "off")" } ?? "Light \(cell + 1), \(isLit ? "on" : "off")")
        .accessibilityHint("Toggles this light and its neighbours. Touch and hold to open the person.")
        .accessibilityAddTraits(.isButton)
    }

    private func press(_ cell: Int) {
        guard !board.isSolved else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        pressed = cell
        board.press(cell)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if pressed == cell { pressed = nil }
        }
        if board.isSolved {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            GameSounds.play(GameSounds.won())
        } else {
            GameSounds.play(GameSounds.lightPressed(cell: cell, lit: board.isLit(cell)))
        }
    }

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            if board.isSolved {
                Label("Lights out in \(board.movesText)", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .fontWeight(.semibold)
            } else {
                Text("\(board.litCount) on · \(board.movesText)")
                    .foregroundStyle(.secondary)
            }
            if board.moveCount == 0 || board.isSolved {
                Text("Tap a light to flip it and its neighbours. Turn them all off.")
                    .font(.tact(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: board.isSolved)
    }

    private func center(of cell: Int) -> CGPoint {
        CGPoint(x: CGFloat(cell % Self.columns) * context.pitch + context.cellSize / 2,
                y: CGFloat(cell / Self.columns) * context.pitch + context.cellSize / 2)
    }
}
