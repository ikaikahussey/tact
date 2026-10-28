import Foundation

/// The state of a game of Simon on a grid of pads. Each round the game
/// plays its sequence, one pad longer than the last, and the player plays it
/// back. A wrong pad ends the game. The same pads are also a keyboard: each
/// has a note, rising from the bottom-left pad to the top-right, on a
/// pentatonic scale so that anything played on them sounds in tune.
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
    let rows: Int
    private(set) var sequence: [Int] = []
    /// How many pads of the sequence the player has matched this round.
    private(set) var position = 0
    private(set) var phase: Phase = .idle

    init(columns: Int = 4, rows: Int = 4) {
        self.columns = max(1, columns)
        self.rows = max(1, rows)
    }

    var padCount: Int { columns * rows }
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

    /// The scale degree of a pad, counting from the bottom-left pad across
    /// each row and up, so pitch rises left to right and bottom to top.
    func noteIndex(forPad pad: Int) -> Int {
        let row = pad / columns, column = pad % columns
        return (rows - 1 - row) * columns + column
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
