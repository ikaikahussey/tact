import Foundation

/// The state of a game of Simon on a set of pads, one per cell of the
/// grid that has a tile. Each round the game plays its sequence, one pad
/// longer than the last, and the player plays it back. A wrong pad ends the
/// game. The same pads are also a keyboard: each has a note, rising from
/// the lowest, leftmost pad to the highest, rightmost, on a pentatonic
/// scale so that anything played on them sounds in tune.
struct Simon: Equatable {
    enum Phase: Equatable {
        /// No game in progress; the pads are a free keyboard.
        case idle
        /// The game is playing its sequence; presses are ignored.
        case watching
        /// The player is repeating the sequence.
        case listening
        /// The player missed; the round reached is the score.
        case over
    }

    /// What a press in `listening` led to.
    enum Outcome: Equatable {
        case ignored
        case correct
        case roundComplete
        case wrong
    }

    let columns: Int
    /// The grid cells the pads sit on, in cell order. A pad is its index
    /// in this list.
    private(set) var cells: [Int]
    private(set) var sequence: [Int] = []
    /// How many pads of the sequence the player has matched this round.
    private(set) var position = 0
    private(set) var phase: Phase = .idle

    /// Pads on every cell of a `columns` × `rows` grid.
    init(columns: Int = 4, rows: Int = 4) {
        self.init(cells: Array(0..<(max(1, columns) * max(1, rows))), columns: columns)
    }

    /// Pads on the given cells of a grid `columns` wide.
    init(cells: [Int], columns: Int = 4) {
        self.columns = max(1, columns)
        self.cells = cells.sorted()
        noteIndices = Self.noteIndices(for: self.cells, columns: self.columns)
    }

    var padCount: Int { cells.count }
    /// Rows the pads span: down to the lowest cell.
    var rows: Int { cells.last.map { $0 / columns + 1 } ?? 0 }

    /// Moves the pads to `cells`. Different cells end any game in
    /// progress, since its sequence was on the old pads.
    mutating func setCells(_ newCells: [Int]) {
        let sorted = newCells.sorted()
        guard sorted != cells else { return }
        cells = sorted
        noteIndices = Self.noteIndices(for: cells, columns: columns)
        stop()
    }
    /// The length of the sequence being played back; 0 before a game.
    var round: Int { sequence.count }
    /// The last round the player completed. During a round that is the
    /// round before; after a miss it is the score.
    var completedRounds: Int {
        switch phase {
        case .idle: return 0
        case .watching, .listening, .over: return max(0, sequence.count - 1)
        }
    }

    // MARK: Playing

    /// Starts a new game with a one-pad sequence, ready to be shown.
    mutating func start<G: RandomNumberGenerator>(using generator: inout G) {
        guard padCount > 0 else { return }
        sequence = [Int.random(in: 0..<padCount, using: &generator)]
        position = 0
        phase = .watching
    }

    mutating func start() {
        var generator = SystemRandomNumberGenerator()
        start(using: &generator)
    }

    /// The sequence has been shown; the player's turn.
    mutating func listen() {
        guard phase == .watching else { return }
        position = 0
        phase = .listening
    }

    /// Adds one pad to the sequence for the next round and shows it again.
    /// Pads may repeat, as in the original game.
    mutating func extend<G: RandomNumberGenerator>(using generator: inout G) {
        guard phase == .listening, position == sequence.count else { return }
        sequence.append(Int.random(in: 0..<padCount, using: &generator))
        position = 0
        phase = .watching
    }

    mutating func extend() {
        var generator = SystemRandomNumberGenerator()
        extend(using: &generator)
    }

    /// The player presses a pad. Only counts while listening.
    @discardableResult
    mutating func press(_ pad: Int) -> Outcome {
        guard phase == .listening, position < sequence.count else { return .ignored }
        guard pad == sequence[position] else {
            phase = .over
            return .wrong
        }
        position += 1
        return position == sequence.count ? .roundComplete : .correct
    }

    /// Ends the game and frees the pads.
    mutating func stop() {
        sequence = []
        position = 0
        phase = .idle
    }

    // MARK: Tempo

    /// Seconds from one pad of the playback to the next. Starts leisurely and
    /// settles at a brisk pace by round 12.
    static func stepInterval(round: Int) -> Double {
        let slow = 0.65, fast = 0.3
        let t = min(max(Double(round - 1) / 11, 0), 1)
        return slow + (fast - slow) * t
    }

    /// How long a pad sounds during playback: most of the step, with a gap
    /// so repeated pads can be heard as separate.
    static func soundDuration(round: Int) -> Double {
        stepInterval(round: round) * 0.7
    }

    // MARK: Notes

    /// The scale the pads are laid out on, chosen under the tune button.
    var tuning = SimonTuning.standard

    /// Each pad's scale degree, counting from the lowest row's leftmost pad
    /// across the row and up, so pitch rises left to right and bottom to
    /// top over the pads there are.
    private var noteIndices: [Int]

    private static func noteIndices(for cells: [Int], columns: Int) -> [Int] {
        let rising = cells.indices.sorted { a, b in
            let (rowA, rowB) = (cells[a] / columns, cells[b] / columns)
            return rowA != rowB ? rowA > rowB : cells[a] < cells[b]
        }
        var indices = Array(repeating: 0, count: cells.count)
        for (degree, pad) in rising.enumerated() { indices[pad] = degree }
        return indices
    }

    /// The scale degree of a pad: 0 for the lowest-leftmost pad, rising to
    /// the right and up.
    func noteIndex(forPad pad: Int) -> Int {
        noteIndices.indices.contains(pad) ? noteIndices[pad] : 0
    }

    /// The pad with the lowest note, and the one with the highest.
    var lowestPad: Int? { noteIndices.firstIndex(of: 0) }
    var highestPad: Int? { noteIndices.firstIndex(of: padCount - 1) }

    /// The grid cell a pad sits on.
    func cell(forPad pad: Int) -> Int {
        cells.indices.contains(pad) ? cells[pad] : 0
    }

    /// The pitch of a pad in hertz.
    func frequency(forPad pad: Int) -> Double {
        tuning.frequency(noteIndex: noteIndex(forPad: pad))
    }

    /// Where a pad's note is, for a label.
    func noteName(forPad pad: Int) -> String {
        tuning.noteName(noteIndex: noteIndex(forPad: pad))
    }

    /// Text for the round, for the status line.
    static func roundsText(_ count: Int) -> String {
        count == 1 ? "1 round" : "\(count) rounds"
    }
}
