import XCTest
@testable import Tact

final class GameSoundsTests: XCTestCase {
    func testWaveformStaysInRangeAndIsPeriodic() {
        for step in 0...100 {
            let value = Synth.sample(phase: Double(step) / 100)
            XCTAssertTrue(value.isFinite && abs(value) <= 1, "phase \(step)")
        }
        XCTAssertEqual(Synth.sample(phase: 0), Synth.sample(phase: 1), accuracy: 1e-9)
        XCTAssertEqual(Synth.sample(phase: 0.25), -Synth.sample(phase: 0.75), accuracy: 1e-9, "odd symmetry")
    }

    func testEnvelopeRisesFastAndEndsSilent() {
        XCTAssertEqual(Synth.envelope(0, duration: 0.1), 0)
        XCTAssertEqual(Synth.envelope(0.006, duration: 0.1), 1, accuracy: 1e-9)
        XCTAssertEqual(Synth.envelope(0.03, duration: 0.1), 1, accuracy: 1e-9, "held after the attack")
        XCTAssertLessThan(Synth.envelope(0.09, duration: 0.1), 0.1)
        XCTAssertEqual(Synth.envelope(0.1, duration: 0.1), 0, "over at the end")
        XCTAssertEqual(Synth.envelope(-0.01, duration: 0.1), 0, "nothing before the start")
    }

    func testPressSoundsBeepThenBoop() {
        let on = GameSounds.lightPressed(cell: 0, lit: true)
        XCTAssertEqual(on.count, 2)
        XCTAssertLessThan(on[0].startHz, on[0].endHz, "the beep rises")
        XCTAssertGreaterThan(on[1].startHz, on[1].endHz, "the boop falls")
        XCTAssertGreaterThan(on[1].delay, on[0].duration, "one after the other")
        let off = GameSounds.lightPressed(cell: 0, lit: false)
        XCTAssertGreaterThan(off[0].startHz, off[0].endHz, "turning a light off starts the other way")
        XCTAssertGreaterThan(GameSounds.lightPressed(cell: 3, lit: true)[0].startHz, on[0].startHz,
                             "cells across the row rise in pitch")
    }

    func testWinAndScrambleRuns() {
        let win = GameSounds.won()
        XCTAssertEqual(win.count, 5)
        XCTAssertTrue(zip(win, win.dropFirst()).allSatisfy { $0.startHz < $1.startHz && $0.delay <= $1.delay }, "rises in order")
        let scramble = GameSounds.scrambled()
        XCTAssertTrue(zip(scramble, scramble.dropFirst()).allSatisfy { $0.startHz > $1.startHz }, "runs down")
    }

    func testSoundsCanBeTurnedOff() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: GameSounds.enabledKey)
        defer { defaults.set(saved, forKey: GameSounds.enabledKey) }
        defaults.removeObject(forKey: GameSounds.enabledKey)
        XCTAssertTrue(GameSounds.isEnabled, "on until turned off")
        defaults.set(false, forKey: GameSounds.enabledKey)
        XCTAssertFalse(GameSounds.isEnabled)
    }
}
