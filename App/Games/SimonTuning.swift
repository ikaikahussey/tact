import Foundation

/// The scale the Simon pads are laid out on, and the key it starts from.
/// Pads climb the scale from the bottom-left, wrapping into the next
/// octave, so a sixteen-pad board spans more octaves of a pentatonic
/// scale than of a chromatic one.
enum SimonScale: String, CaseIterable, Identifiable {
    case majorPentatonic, minorPentatonic, major, naturalMinor, harmonicMinor
    case dorian, mixolydian, blues, wholeTone, chromatic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .majorPentatonic: "Major Pentatonic"
        case .minorPentatonic: "Minor Pentatonic"
        case .major:           "Major"
        case .naturalMinor:    "Natural Minor"
        case .harmonicMinor:   "Harmonic Minor"
        case .dorian:          "Dorian"
        case .mixolydian:      "Mixolydian"
        case .blues:           "Blues"
        case .wholeTone:       "Whole Tone"
        case .chromatic:       "Chromatic"
        }
    }

    /// Semitones above the root, within one octave, in rising order.
    var steps: [Int] {
        switch self {
        case .majorPentatonic: [0, 2, 4, 7, 9]
        case .minorPentatonic: [0, 3, 5, 7, 10]
        case .major:           [0, 2, 4, 5, 7, 9, 11]
        case .naturalMinor:    [0, 2, 3, 5, 7, 8, 10]
        case .harmonicMinor:   [0, 2, 3, 5, 7, 8, 11]
        case .dorian:          [0, 2, 3, 5, 7, 9, 10]
        case .mixolydian:      [0, 2, 4, 5, 7, 9, 10]
        case .blues:           [0, 3, 5, 6, 7, 10]
        case .wholeTone:       [0, 2, 4, 6, 8, 10]
        case .chromatic:       Array(0..<12)
        }
    }

    /// Whether the scale's names are usually spelt with flats.
    var prefersFlats: Bool {
        switch self {
        case .minorPentatonic, .naturalMinor, .harmonicMinor, .dorian, .blues: true
        default: false
        }
    }
}

/// A key: the pitch class the lowest pad starts on, in the octave of middle C.
struct SimonKey: Equatable, Identifiable {
    /// Semitones above C.
    let semitone: Int
    var id: Int { semitone }

    static let all = (0..<12).map(SimonKey.init(semitone:))
    static let c = SimonKey(semitone: 0)

    private static let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    private static let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]

    func name(flats: Bool = false) -> String {
        (flats ? Self.flatNames : Self.sharpNames)[((semitone % 12) + 12) % 12]
    }
}

/// Scale and key together, as remembered between games.
struct SimonTuning: Equatable {
    var scale: SimonScale = .majorPentatonic
    var key: SimonKey = .c

    static let standard = SimonTuning()
    static let scaleKey = "simonScale"
    static let keyKey = "simonKey"

    /// Middle C, the root when the key is C.
    static let middleC = 261.6256

    static func load(from defaults: UserDefaults = .standard) -> SimonTuning {
        var tuning = SimonTuning()
        if let raw = defaults.string(forKey: scaleKey), let scale = SimonScale(rawValue: raw) { tuning.scale = scale }
        if let semitone = defaults.object(forKey: keyKey) as? Int { tuning.key = SimonKey(semitone: semitone) }
        return tuning
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(scale.rawValue, forKey: Self.scaleKey)
        defaults.set(key.semitone, forKey: Self.keyKey)
    }

    /// Semitones above the key's root for the note `index` steps up the scale.
    func semitones(noteIndex: Int) -> Int {
        let steps = scale.steps
        return (noteIndex / steps.count) * 12 + steps[noteIndex % steps.count]
    }

    /// The pitch in hertz of the note `index` steps up the scale from the root.
    func frequency(noteIndex: Int) -> Double {
        Self.middleC * pow(2, Double(key.semitone + semitones(noteIndex: noteIndex)) / 12)
    }

    /// The note's name with its octave, as on a piano: the root in C is C4.
    func noteName(noteIndex: Int) -> String {
        let absolute = key.semitone + semitones(noteIndex: noteIndex)
        let pitchClass = SimonKey(semitone: absolute % 12)
        return pitchClass.name(flats: scale.prefersFlats) + String(4 + absolute / 12)
    }

    /// The key and scale in a word or two, for the status line.
    var title: String { "\(key.name(flats: scale.prefersFlats)) \(scale.title)" }
}
