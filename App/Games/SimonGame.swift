import SwiftUI

/// Simon on the back of the tiles: the top four rows are sixteen pads, one
/// per cell, each showing the motif of the person whose tile sits there and
/// sounding its own note. Between games the pads are a keyboard: touch one
/// to play it, hold it to sustain, and press several for a chord. The play
/// button starts Simon: the pads light and sound a sequence, one longer each
/// round, and the player plays it back. A wrong pad ends the game, and the
/// pads are a keyboard again. The best run is remembered. The tune button
/// picks the scale and key the pads are laid out on and opens the synth
/// settings; sound follows Settings > Games > Sound.
/// Played on the back of the tiles (`TileGame.simon`): the pads turn into
/// view as the tiles turn over.
struct SimonGame: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.appPalette) private var palette
    @AppStorage(SimonGame.bestKey) private var best = 0
    @AppStorage(SimonTuning.scaleKey) private var scaleID = SimonTuning.standard.scale.rawValue
    @AppStorage(SimonTuning.keyKey) private var keySemitone = SimonTuning.standard.key.semitone
    let context: TileGameContext
    @State private var game = Simon(columns: SimonGame.columns, rows: SimonGame.rows)
    @State private var showingSound = false
    /// Pads lit and sounding now, by the game or the finger.
    @State private var sounding = Set<Int>()
    /// The pad under each finger, by the pad it started on.
    @State private var held = Set<Int>()
    @State private var playback: Task<Void, Never>?

    static let columns = TileLayout.columns
    static let rows = 4
    static let bestKey = "simonBest"
    private let synth = SimonSynth.shared

    private var tuning: SimonTuning {
        SimonTuning(scale: SimonScale(rawValue: scaleID) ?? .majorPentatonic, key: SimonKey(semitone: keySemitone))
    }

    private var anchors: [Int: Person] {
        let byPerson = TileLayout.anchors(for: store.people)
        return Dictionary(uniqueKeysWithValues: store.people.compactMap { person in
            byPerson[person.id].map { ($0, person) }
        })
    }

    var body: some View {
        let people = anchors
        ZStack(alignment: .topLeading) {
            ForEach(0..<game.padCount, id: \.self) { pad in
                padView(pad, person: people[pad])
                    .modifier(TileFlipFace(side: .back, showingBack: context.isShowing, delay: context.flipDelay(pad)))
                    .position(center(of: pad))
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
                    tuneMenu
                    playButton
                }
                .padding(16)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: context.isShowing)
        .onChange(of: context.isShowing) { _, showing in
            if !showing { quiet() }
        }
        .onAppear { game.tuning = tuning }
        .onChange(of: scaleID) { _, _ in retune() }
        .onChange(of: keySemitone) { _, _ in retune() }
        .onDisappear(perform: quiet)
        .sheet(isPresented: $showingSound) {
            NavigationStack {
                SoundSettingsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showingSound = false }
                        }
                    }
            }
        }
    }

    // MARK: Tuning

    /// Scale, key and the way to the synth, behind one round button.
    private var tuneMenu: some View {
        Menu {
            Picker("Scale", selection: $scaleID) {
                ForEach(SimonScale.allCases) { scale in
                    Text(scale.title).tag(scale.rawValue)
                }
            }
            .pickerStyle(.menu)
            Picker("Key", selection: $keySemitone) {
                ForEach(SimonKey.all) { key in
                    Text(key.name(flats: tuning.scale.prefersFlats)).tag(key.semitone)
                }
            }
            .pickerStyle(.menu)
            Divider()
            Button { showingSound = true } label: {
                Label("Synth Settings…", systemImage: "slider.horizontal.3")
            }
        } label: {
            Image(systemName: "tuningfork")
                .font(.tact(.body).weight(.semibold))
                .foregroundStyle(palette.onAccent)
                .frame(width: 44, height: 44)
                .background(.tint, in: Circle())
                .shadow(color: .black.opacity(0.18), radius: 6, y: 3)
        }
        .accessibilityLabel("Tuning, \(tuning.title)")
        .accessibilityHint("Chooses the scale and key, or opens the synth settings.")
    }

    /// A new scale or key: silence what is sounding (its pitches are gone)
    /// and lay the pads out again. A game in progress keeps its sequence.
    private func retune() {
        quiet()
        game.tuning = tuning
        UISelectionFeedbackGenerator().selectionChanged()
        // Sound the root so the change can be heard.
        synth.noteOn(game.frequency(forPad: (Self.rows - 1) * Self.columns), duration: 0.3)
    }

    // MARK: Pads

    /// One pad. With a person on the cell it is their motif in their
    /// colour; otherwise a motif and colour picked from the cell number. Dim
    /// at rest, full when sounding.
    private func padView(_ pad: Int, person: Person?) -> some View {
        let isSounding = sounding.contains(pad)
        let colorIndex = person?.tile.colorIndex ?? pad % TileArt.colorCount
        let pattern = person?.tilePattern ?? TilePattern(seed: pad * 3)
        let turns = person?.tile.quarterTurns ?? 0
        let shades = TileShades(colorIndex: colorIndex, palette: palette)
        return ZStack {
            Color.tactTileGray
            TilePatternView(pattern: pattern, colorIndex: colorIndex)
                .rotationEffect(.degrees(Double(turns) * 90))
                .opacity(isSounding ? 1 : 0.3)
            Rectangle()
                .strokeBorder(shades.dark.opacity(isSounding ? 0 : 0.2), lineWidth: 1)
        }
        .frame(width: context.cellSize, height: context.cellSize)
        .scaleEffect(isSounding ? 0.94 : 1)
        .animation(.easeOut(duration: 0.06), value: isSounding)
        .contentShape(Rectangle())
        .gesture(touch(pad))
        .accessibilityElement()
        .accessibilityLabel(person.map { "\($0.name)" } ?? "Pad \(pad + 1)")
        .accessibilityHint(game.phase == .listening ? "Plays this pad as the next of the sequence." : "Plays a note.")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { tap(pad) }
    }

    /// Touch down sounds the pad, touch up lets it fade. A quick tap is a
    /// short note; a held finger sustains it.
    private func touch(_ pad: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard context.isShowing, !held.contains(pad) else { return }
                held.insert(pad)
                padDown(pad)
            }
            .onEnded { _ in
                held.remove(pad)
                padUp(pad)
            }
    }

    private func tap(_ pad: Int) {
        padDown(pad)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { padUp(pad) }
    }

    private func padDown(_ pad: Int) {
        guard game.phase != .watching else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        synth.noteOn(game.frequency(forPad: pad))
        sounding.insert(pad)
        guard game.phase == .listening else { return }
        switch game.press(pad) {
        case .ignored, .correct:
            break
        case .roundComplete:
            if game.round > best { best = game.round }
            let round = game.round
            DispatchQueue.main.asyncAfter(deadline: .now() + Simon.stepInterval(round: round) + 0.2) {
                guard game.phase == .listening, game.round == round else { return }
                game.extend()
                showSequence()
            }
        case .wrong:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            synth.noteOff(game.frequency(forPad: pad))
            synth.buzz()
        }
    }

    private func padUp(_ pad: Int) {
        synth.noteOff(game.frequency(forPad: pad))
        sounding.remove(pad)
    }

    // MARK: Simon

    private var playButton: some View {
        let inPlay = game.phase == .watching || game.phase == .listening
        return CanvasActionButton(title: inPlay ? "Stop" : "Start Simon",
                                  systemImage: inPlay ? "stop.fill" : "play.fill",
                                  hint: inPlay ? "Ends the game; the pads become a keyboard."
                                               : "Plays a sequence on the pads for you to repeat.") {
            if inPlay {
                quiet()
                game.stop()
            } else {
                quiet()
                game.start()
                showSequence()
            }
        }
    }

    /// Plays the sequence on the pads, then hands over to the player.
    private func showSequence() {
        playback?.cancel()
        let sequence = game.sequence
        let round = game.round
        let step = Simon.stepInterval(round: round)
        let sound = Simon.soundDuration(round: round)
        playback = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.5))
            for pad in sequence {
                guard !Task.isCancelled else { return }
                let frequency = game.frequency(forPad: pad)
                synth.noteOn(frequency)
                sounding.insert(pad)
                try? await Task.sleep(for: .seconds(sound))
                synth.noteOff(frequency)
                sounding.remove(pad)
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(step - sound))
            }
            guard !Task.isCancelled else { return }
            game.listen()
        }
    }

    /// Stops the playback and every note.
    private func quiet() {
        playback?.cancel()
        playback = nil
        synth.allNotesOff()
        sounding = []
        held = []
    }

    // MARK: Status

    private var status: some View {
        VStack(alignment: .leading, spacing: 6) {
            switch game.phase {
            case .idle:
                Text(best > 0 ? "\(tuning.title) · best \(Simon.roundsText(best))" : tuning.title)
                    .foregroundStyle(.secondary)
                Text("Play the pads; \(game.noteName(forPad: (Self.rows - 1) * Self.columns)) at the bottom left, rising to \(game.noteName(forPad: Self.columns - 1)). Press play for Simon.")
                    .font(.tact(.footnote))
                    .foregroundStyle(.secondary)
            case .watching:
                Text("Round \(game.round) · watch")
                    .foregroundStyle(.secondary)
            case .listening:
                Text("Round \(game.round) · your turn")
                    .foregroundStyle(palette.accent)
                    .fontWeight(.semibold)
            case .over:
                Label("Game over · \(Simon.roundsText(game.completedRounds))", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.secondary)
                    .fontWeight(.semibold)
                Text(best > 0 ? "Best \(Simon.roundsText(best)). The pads are a keyboard again." : "The pads are a keyboard again.")
                    .font(.tact(.footnote))
                    .foregroundStyle(.secondary)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: game.phase)
    }

    private func center(of pad: Int) -> CGPoint {
        CGPoint(x: CGFloat(pad % Self.columns) * context.pitch + context.cellSize / 2,
                y: CGFloat(pad / Self.columns) * context.pitch + context.cellSize / 2)
    }
}
