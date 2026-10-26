import AVFoundation
import Foundation

/// A little analog-style synthesiser for the games' beeps and boops: a
/// sine with a touch of triangle, a slow vibrato, a soft clip and a quick
/// envelope, like a sixties computer console. Notes are generated on the
/// fly, so there are no sound files. Honours the silent switch and mixes
/// with whatever is playing.
final class Synth {
    static let shared = Synth()

    /// One tone: it glides from `startHz` to `endHz` over `duration`
    /// seconds, starting `delay` seconds after it is played.
    struct Note: Equatable {
        var startHz: Double
        var endHz: Double
        var duration: Double
        var delay: Double = 0
        var gain: Double = 0.35
    }

    static let sampleRate = 44_100.0

    private struct Voice {
        let note: Note
        var startFrame: Int64
        var phase = 0.0
        var vibratoPhase = 0.0
    }

    /// The waveform settings; read on the audio thread, so set under the lock.
    var timbre: SoundTuning {
        get { lock.lock(); defer { lock.unlock() }; return storedTimbre }
        set { lock.lock(); storedTimbre = newValue; lock.unlock() }
    }
    private var storedTimbre = SoundTuning.standard

    private let engine = AVAudioEngine()
    private var source: AVAudioSourceNode?
    private let lock = NSLock()
    private var voices: [Voice] = []
    private var frame: Int64 = 0
    private var idleStop: DispatchWorkItem?

    private init() {}

    /// Plays `notes` together, each after its own delay.
    func play(_ notes: [Note]) {
        guard !notes.isEmpty, start() else { return }
        lock.lock()
        let now = frame
        for note in notes {
            voices.append(Voice(note: note, startFrame: now + Int64(note.delay * Self.sampleRate)))
        }
        lock.unlock()
        scheduleIdleStop(after: (notes.map { $0.delay + $0.duration }.max() ?? 0) + 3)
    }

    /// Stops the engine; it starts again on the next note.
    func stop() {
        idleStop?.cancel()
        engine.stop()
        lock.lock()
        voices.removeAll()
        lock.unlock()
    }

    // MARK: Engine

    private func start() -> Bool {
        if engine.isRunning { return true }
        if source == nil {
            let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1)!
            let node = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
                guard let self else { return noErr }
                let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
                guard let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
                self.render(into: out, frames: Int(frameCount))
                return noErr
            }
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            engine.mainMixerNode.outputVolume = 0.8
            source = node
        }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)
        do {
            try engine.start()
            return true
        } catch {
            return false
        }
    }

    private func scheduleIdleStop(after seconds: Double) {
        idleStop?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.engine.stop() }
        idleStop = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    // MARK: Rendering

    private func render(into out: UnsafeMutablePointer<Float>, frames: Int) {
        lock.lock()
        defer { lock.unlock() }
        let start = frame
        for i in 0..<frames { out[i] = 0 }
        for index in voices.indices {
            Self.render(voice: &voices[index], from: start, into: out, frames: frames, timbre: storedTimbre)
        }
        frame += Int64(frames)
        voices.removeAll { $0.startFrame + Int64($0.note.duration * Self.sampleRate) <= frame }
    }

    /// Adds one voice's samples for `frames` frames starting at `start`.
    private static func render(voice: inout Voice, from start: Int64, into out: UnsafeMutablePointer<Float>, frames: Int,
                               timbre: SoundTuning) {
        let note = voice.note
        let length = note.duration * sampleRate
        for i in 0..<frames {
            let position = Double(start + Int64(i) - voice.startFrame)
            guard position >= 0, position < length else { continue }
            let t = position / sampleRate
            let progress = position / length
            let hz = note.startHz + (note.endHz - note.startHz) * progress
            voice.vibratoPhase += 5.5 / sampleRate
            let vibrato = 1 + 0.01 * timbre.vibrato * sin(voice.vibratoPhase * 2 * .pi)
            voice.phase += hz * vibrato / sampleRate
            if voice.phase > 1 { voice.phase -= 1 }
            out[i] += Float(sample(phase: voice.phase, warmth: timbre.warmth, edge: timbre.edge)
                            * envelope(t, duration: note.duration) * note.gain)
        }
    }

    /// The waveform at `phase` (0...1): a sine warmed with `warmth` of
    /// triangle and softly clipped, harder the more `edge`.
    static func sample(phase: Double, warmth: Double = SoundTuning.standard.warmth,
                       edge: Double = SoundTuning.standard.edge) -> Double {
        let sine = sin(phase * 2 * .pi)
        let triangle = 4 * abs(phase - 0.5) - 1
        return tanh((sine + warmth * triangle) * edge)
    }

    /// Quick attack, a short hold, then an exponential fall that reaches
    /// nothing by the end of the note.
    static func envelope(_ t: Double, duration: Double) -> Double {
        guard t >= 0, t < duration else { return 0 }
        let attack = min(1, t / 0.006)
        let release = max(0, 1 - max(0, t - duration * 0.55) / (duration * 0.45))
        return attack * release * release
    }
}

/// How the beeps sound, set under Settings > Games > Sound. Each value is
/// a plain number in UserDefaults so the sliders bind to it directly.
struct SoundTuning: Equatable {
    /// Loudness, 0 to 1.
    var volume = 1.0
    /// Transposition in semitones, -12 to 12.
    var pitch = 0.0
    /// Note length multiplier, 0.5 to 2.
    var length = 1.0
    /// How much triangle wave is mixed in, 0 to 1.
    var warmth = 0.35
    /// How hard the soft clip is driven, 1 to 4.
    var edge = 1.3
    /// Vibrato depth, 0 to 1 (as a fraction of 1%).
    var vibrato = 0.4

    static let standard = SoundTuning()

    enum Key: String, CaseIterable {
        case volume = "soundVolume", pitch = "soundPitch", length = "soundLength"
        case warmth = "soundWarmth", edge = "soundEdge", vibrato = "soundVibrato"
    }

    static func load(from defaults: UserDefaults = .standard) -> SoundTuning {
        var tuning = SoundTuning()
        func read(_ key: Key, _ keyPath: WritableKeyPath<SoundTuning, Double>) {
            if let value = defaults.object(forKey: key.rawValue) as? Double { tuning[keyPath: keyPath] = value }
        }
        read(.volume, \.volume); read(.pitch, \.pitch); read(.length, \.length)
        read(.warmth, \.warmth); read(.edge, \.edge); read(.vibrato, \.vibrato)
        return tuning
    }

    /// Back to the standard sound.
    static func reset(in defaults: UserDefaults = .standard) {
        Key.allCases.forEach { defaults.removeObject(forKey: $0.rawValue) }
    }

    /// `notes` transposed, lengthened and scaled by this tuning.
    func applied(to notes: [Synth.Note]) -> [Synth.Note] {
        let factor = pow(2, pitch / 12)
        return notes.map { note in
            var note = note
            note.startHz *= factor
            note.endHz *= factor
            note.duration *= length
            note.delay *= length
            note.gain *= volume
            return note
        }
    }
}

/// The games' sounds, and whether they are on. Off, nothing is played.
enum GameSounds {
    static let enabledKey = "gameSoundsEnabled"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
    }

    /// A light was pressed: a rising beep, then a falling boop, pitched a
    /// little by the cell so a board has some tune to it.
    static func lightPressed(cell: Int, lit: Bool) -> [Synth.Note] {
        let pitch = pow(2, Double(cell % 4) / 12)
        if lit {
            return [Synth.Note(startHz: 740 * pitch, endHz: 988 * pitch, duration: 0.07, gain: 0.3),
                    Synth.Note(startHz: 494 * pitch, endHz: 440 * pitch, duration: 0.09, delay: 0.08, gain: 0.3)]
        }
        return [Synth.Note(startHz: 988 * pitch, endHz: 740 * pitch, duration: 0.07, gain: 0.3),
                Synth.Note(startHz: 440 * pitch, endHz: 392 * pitch, duration: 0.09, delay: 0.08, gain: 0.3)]
    }

    /// A new scramble: a quick run down.
    static func scrambled() -> [Synth.Note] {
        [988, 880, 784, 659, 587].enumerated().map { index, hz in
            Synth.Note(startHz: hz, endHz: hz * 0.97, duration: 0.06, delay: Double(index) * 0.06, gain: 0.25)
        }
    }

    /// Every light off: a rising arpeggio with a long last note.
    static func won() -> [Synth.Note] {
        let notes = [523.0, 659, 784, 1047].enumerated().map { index, hz in
            Synth.Note(startHz: hz, endHz: hz, duration: 0.18, delay: Double(index) * 0.12, gain: 0.3)
        }
        return notes + [Synth.Note(startHz: 1319, endHz: 1319 * 1.005, duration: 0.6, delay: 0.5, gain: 0.3)]
    }

    static func play(_ notes: [Synth.Note]) {
        guard isEnabled else { return }
        let tuning = SoundTuning.load()
        Synth.shared.timbre = tuning
        Synth.shared.play(tuning.applied(to: notes))
    }

    /// A beep and boop then a short run, for trying a tuning out.
    static func sample() -> [Synth.Note] {
        lightPressed(cell: 0, lit: true) + lightPressed(cell: 2, lit: false).map { note in
            var note = note
            note.delay += 0.26
            return note
        }
    }
}
