import XCTest
@testable import Tact

final class SimonTests: XCTestCase {
    func testStartsIdleWithNoSequence() {
        var game = Simon(columns: 4, rows: 4)
        XCTAssertEqual(game.padCount, 16)
        XCTAssertEqual(game.phase, .idle)
        XCTAssertEqual(game.round, 0)
        XCTAssertEqual(game.completedRounds, 0)
        XCTAssertEqual(game.press(3), .ignored)
    }

    func testStartMakesAOnePadSequenceToWatch() {
        var generator = SeededGenerator(seed: 1)
        var game = Simon()
        game.start(using: &generator)
        XCTAssertEqual(game.phase, .watching)
        XCTAssertEqual(game.round, 1)
        XCTAssertEqual(game.sequence.count, 1)
        XCTAssertTrue((0..<16).contains(game.sequence[0]))
        XCTAssertEqual(game.press(game.sequence[0]), .ignored, "presses are ignored while watching")
    }

    func testRepeatingTheSequenceCompletesTheRound() {
        var generator = SeededGenerator(seed: 2)
        var game = Simon()
        game.start(using: &generator)
        game.listen()
        XCTAssertEqual(game.phase, .listening)
        XCTAssertEqual(game.press(game.sequence[0]), .roundComplete)
        XCTAssertEqual(game.phase, .listening, "the round stays finished until extended")
        XCTAssertEqual(game.press(game.sequence[0]), .ignored)
    }

    func testExtendAddsOnePadAndShowsAgain() {
        var generator = SeededGenerator(seed: 3)
        var game = Simon()
        game.start(using: &generator)
        game.listen()
        let first = game.sequence
        game.extend(using: &generator)
        XCTAssertEqual(game.phase, .listening, "cannot extend before the round is complete")
        game.press(first[0])
        game.extend(using: &generator)
        XCTAssertEqual(game.phase, .watching)
        XCTAssertEqual(game.round, 2)
        XCTAssertEqual(Array(game.sequence.prefix(1)), first)
        XCTAssertEqual(game.completedRounds, 1)
    }

    func testWrongPadEndsTheGame() {
        var generator = SeededGenerator(seed: 4)
        var game = Simon()
        game.start(using: &generator)
        game.listen()
        game.press(game.sequence[0])
        game.extend(using: &generator)
        game.listen()
        let wrong = (game.sequence[0] + 1) % 16
        XCTAssertEqual(game.press(wrong), .wrong)
        XCTAssertEqual(game.phase, .over)
        XCTAssertEqual(game.completedRounds, 1)
        XCTAssertEqual(game.press(game.sequence[0]), .ignored)
    }

    func testLongRoundReportsCorrectThenComplete() {
        var generator = SeededGenerator(seed: 5)
        var game = Simon()
        game.start(using: &generator)
        for _ in 0..<4 {
            game.listen()
            for pad in game.sequence { game.press(pad) }
            game.extend(using: &generator)
        }
        XCTAssertEqual(game.round, 5)
        game.listen()
        let sequence = game.sequence
        for pad in sequence.dropLast() {
            XCTAssertEqual(game.press(pad), .correct)
        }
        XCTAssertEqual(game.press(sequence.last!), .roundComplete)
    }

    func testStopFreesThePads() {
        var generator = SeededGenerator(seed: 6)
        var game = Simon()
        game.start(using: &generator)
        game.stop()
        XCTAssertEqual(game, Simon())
    }

    func testTempoSpeedsUpAndSettles() {
        XCTAssertEqual(Simon.stepInterval(round: 1), 0.65, accuracy: 0.001)
        XCTAssertLessThan(Simon.stepInterval(round: 6), Simon.stepInterval(round: 2))
        XCTAssertEqual(Simon.stepInterval(round: 12), 0.3, accuracy: 0.001)
        XCTAssertEqual(Simon.stepInterval(round: 40), 0.3, accuracy: 0.001)
        XCTAssertLessThan(Simon.soundDuration(round: 3), Simon.stepInterval(round: 3))
    }

    func testNotesRiseFromBottomLeftToTopRight() {
        let game = Simon(columns: 4, rows: 4)
        XCTAssertEqual(game.noteIndex(forPad: 12), 0, "bottom-left pad is the lowest")
        XCTAssertEqual(game.noteIndex(forPad: 15), 3)
        XCTAssertEqual(game.noteIndex(forPad: 0), 12)
        XCTAssertEqual(game.noteIndex(forPad: 3), 15, "top-right pad is the highest")
        XCTAssertEqual(Set((0..<16).map(game.noteIndex(forPad:))).count, 16, "every pad has its own note")
        XCTAssertEqual(game.frequency(forPad: 12), 261.6256, accuracy: 0.001, "middle C")
        XCTAssertLessThan(game.frequency(forPad: 12), game.frequency(forPad: 13))
        XCTAssertLessThan(game.frequency(forPad: 4), game.frequency(forPad: 0))
    }

    func testScaleIsMajorPentatonicAcrossOctaves() {
        XCTAssertEqual(SimonTuning.standard.frequency(noteIndex: 1), 293.665, accuracy: 0.01, "D4")
        XCTAssertEqual(SimonTuning.standard.frequency(noteIndex: 2), 329.628, accuracy: 0.01, "E4")
        XCTAssertEqual(SimonTuning.standard.frequency(noteIndex: 3), 391.995, accuracy: 0.01, "G4")
        XCTAssertEqual(SimonTuning.standard.frequency(noteIndex: 4), 440, accuracy: 0.01, "A4")
        XCTAssertEqual(SimonTuning.standard.frequency(noteIndex: 5), 523.251, accuracy: 0.01, "C5, an octave up")
        XCTAssertEqual(SimonTuning.standard.frequency(noteIndex: 15), 2093.005, accuracy: 0.01, "C7, three octaves up")
    }

    func testRoundsText() {
        XCTAssertEqual(Simon.roundsText(1), "1 round")
        XCTAssertEqual(Simon.roundsText(7), "7 rounds")
    }
}
