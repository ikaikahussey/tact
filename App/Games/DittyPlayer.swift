import Foundation
import UIKit

/// Plays ditties on the Simon synth, one at a time, in the key and scale
/// the pads are tuned to. Sound follows Settings > Games > Sound.
@MainActor
enum DittyPlayer {
    /// Settings > Games: whether opening a person plays their ditty. Unset,
    /// it is on only while VoiceOver is running, so sighted users are not
    /// surprised by a sound and VoiceOver users get the earcon by default.
    nonisolated static let playOnOpenKey = "dittyPlaysOnOpen"

    static var playsOnOpen: Bool {
        UserDefaults.standard.object(forKey: playOnOpenKey) as? Bool ?? UIAccessibility.isVoiceOverRunning
    }

    private static var playback: Task<Void, Never>?

    /// Plays `ditty`, stopping any that is sounding. `onNote` is called on
    /// the main actor as each note starts (its position in the ditty) and
    /// with `nil` when it plays through, for lighting pads. A ditty that is
    /// stopped early does not get the `nil`; `stop()`'s caller clears up.
    static func play(_ ditty: Ditty, tuning: SimonTuning = SimonTuning.load(),
                     onNote: @escaping (Int?) -> Void = { _ in }) {
        stop()
        guard GameSounds.isEnabled, !ditty.isEmpty else { return }
        let schedule = ditty.schedule(tuning: tuning)
        let synth = SimonSynth.shared
        playback = Task { @MainActor in
            var elapsed = 0.0
            for (index, note) in schedule.enumerated() {
                guard !Task.isCancelled else { break }
                if note.start > elapsed {
                    try? await Task.sleep(for: .seconds(note.start - elapsed))
                    elapsed = note.start
                }
                guard !Task.isCancelled else { break }
                onNote(index)
                synth.noteOn(note.frequency, duration: note.duration)
            }
            if let last = schedule.last, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(last.start + last.duration - elapsed))
            }
            // A stopped playback leaves its lights to whoever stopped it, so
            // a ditty started in its place is not switched off by mistake.
            guard !Task.isCancelled else { return }
            onNote(nil)
        }
    }

    /// Plays a person's ditty.
    static func play(_ person: Person, tuning: SimonTuning = SimonTuning.load(),
                     onNote: @escaping (Int?) -> Void = { _ in }) {
        play(person.resolvedDitty, tuning: tuning, onNote: onNote)
    }

    static func stop() {
        playback?.cancel()
        playback = nil
        SimonSynth.shared.allNotesOff()
    }
}
