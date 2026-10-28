import XCTest
@testable import Tact

final class SimonTuningTests: XCTestCase {
    func testStandardIsCMajorPentatonicFromMiddleC() {
        let tuning = SimonTuning.standard
        XCTAssertEqual(tuning.frequency(noteIndex: 0), 261.6256, accuracy: 1e-3)
        XCTAssertEqual(tuning.frequency(noteIndex: 5), 523.2512, accuracy: 1e-3, "five steps up is the octave")
        XCTAssertEqual(tuning.noteName(noteIndex: 0), "C4")
        XCTAssertEqual(tuning.noteName(noteIndex: 4), "A4")
        XCTAssertEqual(tuning.noteName(noteIndex: 15), "C7", "sixteen pentatonic pads reach three octaves up")
        XCTAssertEqual(tuning.title, "C Major Pentatonic")
    }

    func testScalesRiseWithinAnOctave() {
        for scale in SimonScale.allCases {
            let steps = scale.steps
            XCTAssertEqual(steps.first, 0, "\(scale) starts on the root")
            XCTAssertTrue(zip(steps, steps.dropFirst()).allSatisfy { $0 < $1 }, "\(scale) rises")
            XCTAssertLessThan(steps.last!, 12, "\(scale) stays within the octave")
        }
        XCTAssertEqual(SimonScale.chromatic.steps.count, 12)
        XCTAssertEqual(SimonScale.major.steps, [0, 2, 4, 5, 7, 9, 11])
    }

    func testKeyTransposesEverything() {
        var tuning = SimonTuning.standard
        tuning.key = SimonKey(semitone: 7)
        XCTAssertEqual(tuning.frequency(noteIndex: 0), 391.9954, accuracy: 1e-3, "G4")
        XCTAssertEqual(tuning.noteName(noteIndex: 0), "G4")
        XCTAssertEqual(tuning.noteName(noteIndex: 3), "D5")
        XCTAssertEqual(tuning.title, "G Major Pentatonic")
    }

    func testChromaticPadsAreSemitonesAndMinorKeysUseFlats() {
        var tuning = SimonTuning(scale: .chromatic, key: .c)
        XCTAssertEqual((0..<16).map(tuning.semitones(noteIndex:)), Array(0..<16))
        XCTAssertEqual(tuning.noteName(noteIndex: 1), "C♯4")
        XCTAssertEqual(tuning.noteName(noteIndex: 12), "C5")
        tuning = SimonTuning(scale: .naturalMinor, key: SimonKey(semitone: 10))
        XCTAssertEqual(tuning.title, "B♭ Natural Minor")
        XCTAssertEqual(tuning.noteName(noteIndex: 2), "D♭5")
    }

    func testTuningRoundTripsThroughDefaults() {
        let defaults = TestSupport.defaults()
        XCTAssertEqual(SimonTuning.load(from: defaults), .standard)
        SimonTuning(scale: .blues, key: SimonKey(semitone: 9)).save(to: defaults)
        let loaded = SimonTuning.load(from: defaults)
        XCTAssertEqual(loaded.scale, .blues)
        XCTAssertEqual(loaded.key.semitone, 9)
    }

    func testSimonPadsFollowTheTuning() {
        var game = Simon(columns: 4, rows: 4)
        XCTAssertEqual(game.noteName(forPad: 12), "C4", "bottom-left pad is the root")
        game.tuning = SimonTuning(scale: .major, key: SimonKey(semitone: 2))
        XCTAssertEqual(game.noteName(forPad: 12), "D4")
        XCTAssertEqual(game.noteName(forPad: 3), "E6", "top-right pad is the sixteenth note of D major: two octaves and a step")
        XCTAssertEqual(game.frequency(forPad: 12), SimonTuning.middleC * pow(2, 2.0 / 12), accuracy: 1e-6)
    }
}
