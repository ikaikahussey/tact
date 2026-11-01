import SwiftUI

/// Records a person's ditty on the Simon pads. The sixteen pads are laid
/// out as on the back of the tiles, in the person's colour; a tap adds a
/// short note, a held pad a long one, up to `Ditty.maxNotes`. The notes
/// so far are listed above the pads by name, with the last one removable.
/// Done keeps the ditty; Default goes back to the one from the seed.
struct DittyRecorderView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    let personID: UUID

    @State private var ditty: Ditty
    @State private var sounding: Int?
    @State private var held: [Int: Date] = [:]
    @State private var tuning = SimonTuning.load()
    @State private var showingSound = false

    private let synth = SimonSynth.shared
    private static let columns = SimonGame.columns
    private static let rows = SimonGame.rows
    /// A pad held this long records a long note.
    private static let longPressSeconds = 0.35

    init(person: Person) {
        personID = person.id
        _ditty = State(initialValue: person.ditty ?? Ditty(notes: []))
    }

    private var person: Person? { store.person(id: personID) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                notesStrip
                pads
                controls
                Text(ditty.isEmpty
                     ? "Tap a pad for a short note; hold it for a long one. Up to \(Ditty.maxNotes) notes."
                     : "\(ditty.notes.count) of \(Ditty.maxNotes) notes · \(tuning.title)")
                    .font(.tact(.footnote))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Ditty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { finish() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.updateDitty(forPersonID: personID, ditty)
                        finish()
                    }
                    .fontWeight(.semibold)
                }
            }
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
            .onChange(of: showingSound) { _, showing in
                if !showing { tuning = SimonTuning.load() }
            }
            .onDisappear { DittyPlayer.stop() }
        }
    }

    // MARK: Notes so far

    private var notesStrip: some View {
        HStack(spacing: 6) {
            if ditty.isEmpty {
                Text(person.map { "Default: \($0.resolvedDitty.noteNames(tuning: tuning))" } ?? "No notes")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(ditty.notes.enumerated()), id: \.offset) { index, note in
                    Text(tuning.noteName(noteIndex: note.degree))
                        .font(.tact(.callout).monospacedDigit())
                        .padding(.horizontal, note.beats > 1 ? 12 : 8)
                        .padding(.vertical, 5)
                        .background(
                            TilePalette.color(person?.tile.colorIndex ?? 0, in: palette)
                                .opacity(sounding == index ? 1 : 0.25),
                            in: Capsule()
                        )
                        .accessibilityLabel("\(tuning.noteName(noteIndex: note.degree)), \(note.beats > 1 ? "long" : "short")")
                }
            }
            Spacer(minLength: 0)
            if !ditty.isEmpty {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    DittyPlayer.stop()
                    sounding = nil
                    ditty.removeLast()
                } label: {
                    Image(systemName: "delete.left")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove Last Note")
            }
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(ditty.isEmpty ? "No notes recorded" : "Notes: \(ditty.noteNames(tuning: tuning))")
    }

    // MARK: Pads

    private var pads: some View {
        let colorIndex = person?.tile.colorIndex ?? 0
        let pattern = person?.tilePattern ?? TilePattern(seed: 0)
        let shades = TileShades(colorIndex: colorIndex, palette: palette)
        let noteIndexes = Set(ditty.notes.map(\.degree))
        return Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<Self.rows, id: \.self) { row in
                GridRow {
                    ForEach(0..<Self.columns, id: \.self) { column in
                        let pad = row * Self.columns + column
                        let degree = Self.degree(forPad: pad)
                        let playing = sounding.flatMap { $0 < ditty.notes.count ? ditty.notes[$0].degree : nil }
                        let isSounding = held[pad] != nil || playing == degree
                        ZStack {
                            Color.tactTileGray
                            TileMotifView(bits: person?.tile.bits, pattern: pattern, colorIndex: colorIndex)
                                .opacity(isSounding ? 1 : noteIndexes.contains(degree) ? 0.55 : 0.3)
                            Rectangle()
                                .strokeBorder(shades.dark.opacity(isSounding ? 0 : 0.2), lineWidth: 1)
                        }
                        .aspectRatio(1, contentMode: .fit)
                        .scaleEffect(isSounding ? 0.94 : 1)
                        .animation(.easeOut(duration: 0.06), value: isSounding)
                        .contentShape(Rectangle())
                        .gesture(touch(pad))
                        .accessibilityElement()
                        .accessibilityLabel(tuning.noteName(noteIndex: degree))
                        .accessibilityHint("Adds a short note.")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { record(degree: degree, beats: 1) }
                        .accessibilityAction(named: "Add long note") { record(degree: degree, beats: 2) }
                    }
                }
            }
        }
        .disabled(ditty.isFull)
    }

    /// Pads climb the scale from the bottom-left, as on the Simon board.
    private static func degree(forPad pad: Int) -> Int {
        let row = pad / columns, column = pad % columns
        return (rows - 1 - row) * columns + column
    }

    private func touch(_ pad: Int) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                guard held[pad] == nil, !ditty.isFull else { return }
                held[pad] = Date()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                synth.noteOn(tuning.frequency(noteIndex: Self.degree(forPad: pad)))
            }
            .onEnded { _ in
                guard let start = held.removeValue(forKey: pad) else { return }
                synth.noteOff(tuning.frequency(noteIndex: Self.degree(forPad: pad)))
                let long = Date().timeIntervalSince(start) >= Self.longPressSeconds
                ditty.append(degree: Self.degree(forPad: pad), beats: long ? 2 : 1)
            }
    }

    private func record(degree: Int, beats: Int) {
        guard !ditty.isFull else { return }
        synth.noteOn(tuning.frequency(noteIndex: degree), duration: Double(beats) * Ditty.beatSeconds)
        ditty.append(degree: degree, beats: beats)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 16) {
            Button {
                let toPlay = ditty.isEmpty ? person?.resolvedDitty : ditty
                guard let toPlay else { return }
                DittyPlayer.play(toPlay, tuning: tuning) { index in
                    sounding = ditty.isEmpty ? nil : index
                }
            } label: {
                Label("Play", systemImage: "play.fill")
            }
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DittyPlayer.stop()
                sounding = nil
                ditty = Ditty(notes: [])
            } label: {
                Label("Default", systemImage: "arrow.uturn.backward")
            }
            .disabled(ditty.isEmpty)
            Button {
                showingSound = true
            } label: {
                Label("Tuning", systemImage: "tuningfork")
            }
        }
        .font(.tact(.subheadline))
        .buttonStyle(.borderless)
    }

    private func finish() {
        DittyPlayer.stop()
        dismiss()
    }
}
