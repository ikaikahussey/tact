import Foundation

/// A person's earcon: a few notes on the Simon synth that identify them by
/// ear, the way their colour and pattern do by eye. Notes are scale degrees
/// on the sixteen-pad Simon board, not pitches, so a ditty follows the key
/// and scale chosen in Settings > Games > Sound and stays in tune with the
/// pads. Every person has one: a default made from their seed, or one
/// recorded on the pads.
struct Ditty: Codable, Equatable, Hashable {
    /// One note: `degree` steps up the scale from the root (a pad on the
    /// Simon board), held for `beats` beats.
    struct Note: Codable, Equatable, Hashable {
        var degree: Int
        var beats: Int

        init(degree: Int, beats: Int = 1) {
            self.degree = Note.clampedDegree(degree)
            self.beats = Note.clampedBeats(beats)
        }

        static func clampedDegree(_ degree: Int) -> Int {
            min(max(degree, 0), Ditty.degreeCount - 1)
        }

        static func clampedBeats(_ beats: Int) -> Int {
            min(max(beats, 1), Ditty.maxBeats)
        }

        private enum CodingKeys: String, CodingKey { case degree, beats }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let degree = (try? container.decodeIfPresent(Int.self, forKey: .degree)) ?? nil ?? 0
            let beats = (try? container.decodeIfPresent(Int.self, forKey: .beats)) ?? nil ?? 1
            self.init(degree: degree, beats: beats)
        }
    }

    /// Pads on the Simon board, so degrees a ditty can use.
    static let degreeCount = 16
    /// Long enough to be a motif, short enough to stay an earcon.
    static let maxNotes = 8
    static let maxBeats = 2
    /// Seconds per beat when a ditty is played.
    static let beatSeconds = 0.18

    var notes: [Note]

    init(notes: [Note]) {
        self.notes = Array(notes.prefix(Self.maxNotes))
    }

    /// The ditty a person starts with, made from their seed so it is
    /// stable: three to five notes stepping about the pads, the last one
    /// held.
    init(seed rawSeed: Int) {
        var state = UInt64(truncatingIfNeeded: abs(rawSeed)) &+ 0x9E37_79B9_7F4A_7C15
        func next() -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int(truncatingIfNeeded: state >> 33)
        }
        let count = 3 + next() % 3
        var notes: [Note] = []
        var degree = next() % 12
        for position in 0..<count {
            notes.append(Note(degree: degree, beats: position == count - 1 ? 2 : 1))
            // Step up or down by one to four degrees, turning back at the ends.
            let step = 1 + next() % 4
            let candidate = next() % 2 == 0 ? degree + step : degree - step
            degree = (0..<Self.degreeCount).contains(candidate) ? candidate : degree + (candidate < 0 ? step : -step)
        }
        self.init(notes: notes)
    }

    var isEmpty: Bool { notes.isEmpty }
    var isFull: Bool { notes.count >= Self.maxNotes }

    /// Total length in beats.
    var beats: Int { notes.reduce(0) { $0 + $1.beats } }

    /// Seconds the ditty takes to play.
    var duration: Double { Double(beats) * Self.beatSeconds }

    /// Adds a note when there is room.
    mutating func append(degree: Int, beats: Int = 1) {
        guard !isFull else { return }
        notes.append(Note(degree: degree, beats: beats))
    }

    mutating func removeLast() {
        guard !notes.isEmpty else { return }
        notes.removeLast()
    }

    /// When to sound each note and for how long, in seconds from the start,
    /// at the pitch the tuning gives its degree.
    func schedule(tuning: SimonTuning) -> [(frequency: Double, start: Double, duration: Double)] {
        var start = 0.0
        return notes.map { note in
            let duration = Double(note.beats) * Self.beatSeconds
            defer { start += duration }
            return (tuning.frequency(noteIndex: note.degree), start, duration * 0.85)
        }
    }

    /// The notes by name, for an outline or a spoken description: "C4 E4 G4".
    func noteNames(tuning: SimonTuning) -> String {
        notes.map { tuning.noteName(noteIndex: $0.degree) }.joined(separator: " ")
    }

    private enum CodingKeys: String, CodingKey { case notes }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let notes = (try? container.decodeIfPresent([Note].self, forKey: .notes)) ?? nil ?? []
        self.init(notes: notes)
    }
}
