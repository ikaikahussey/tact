import AVFoundation
import os

/// A small polyphonic synthesizer for the Simon pads. Each voice uses the
/// same waveform as the games' beeps (`Synth.sample`, a warmed and softly
/// clipped sine) under an attack-and-release envelope, so a held pad
/// sustains like a soft electric organ and never clicks. Voices are mixed
/// in an `AVAudioSourceNode`; up to eight sound at once, and the oldest is
/// replaced when more are needed.
///
/// Follows Settings > Games > Sound: off means silence, and volume, pitch,
/// warmth, edge and vibrato are read from `SoundTuning` on every note.
/// Uses the ambient session category, so the pads respect the silent
/// switch and do not stop music playing in another app.
final class SimonSynth {
    static let shared = SimonSynth()

    private struct Voice {
        var frequency: Double
        var phase: Double = 0
        var level: Double = 0
        var isHeld = true
        /// Order of starting, to find the oldest when all voices are busy.
        var serial: UInt64
    }

    static let maxVoices = 8
    private let attackSeconds = 0.008
    private let releaseSeconds = 0.22
    private let gain = 0.22

    private var engine: AVAudioEngine?
    private var voices: [Voice] = []
    private var nextSerial: UInt64 = 0
    private let lock = OSAllocatedUnfairLock()
    private var sampleRate = 44_100.0
    /// The tuning in force, read on the audio thread; set under the lock.
    private var tuning = SoundTuning.standard
    private var vibratoPhase = 0.0

    private init() {}

    // MARK: Playing

    /// Starts a note at `frequency`. It sounds until `noteOff` for the same
    /// frequency, or `duration` seconds when given.
    func noteOn(_ frequency: Double, duration: Double? = nil) {
        guard GameSounds.isEnabled else { return }
        prepare()
        let tuning = SoundTuning.load()
        lock.withLock {
            self.tuning = tuning
            if let index = voices.firstIndex(where: { $0.frequency == frequency }) {
                voices[index].isHeld = true
                voices[index].serial = nextSerial
            } else {
                if voices.count >= Self.maxVoices,
                   let oldest = voices.indices.min(by: { voices[$0].serial < voices[$1].serial }) {
                    voices.remove(at: oldest)
                }
                voices.append(Voice(frequency: frequency, serial: nextSerial))
            }
            nextSerial += 1
        }
        if let duration {
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
                self?.noteOff(frequency)
            }
        }
    }

    /// Lets the note at `frequency` fade out.
    func noteOff(_ frequency: Double) {
        lock.withLock {
            for index in voices.indices where voices[index].frequency == frequency {
                voices[index].isHeld = false
            }
        }
    }

    /// Lets every note fade out.
    func allNotesOff() {
        lock.withLock {
            for index in voices.indices { voices[index].isHeld = false }
        }
    }

    /// A short low buzz for a wrong pad.
    func buzz() {
        noteOn(Simon.rootFrequency / 4, duration: 0.35)
        noteOn(Simon.rootFrequency / 4 * 1.06, duration: 0.35)
    }

    // MARK: Engine

    private func prepare() {
        guard engine == nil else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        let engine = AVAudioEngine()
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44_100
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)

        let source = AVAudioSourceNode { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self else { return noErr }
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            let frames = Int(frameCount)
            guard let channel = buffers.first?.mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            self.render(into: channel, frames: frames)
            for extra in buffers.dropFirst() {
                extra.mData?.assumingMemoryBound(to: Float.self).update(from: channel, count: frames)
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        do {
            try engine.start()
            self.engine = engine
        } catch {
            // No audio: the pads still light.
        }
    }

    /// Mixes every voice into `output`. Runs on the audio thread.
    private func render(into output: UnsafeMutablePointer<Float>, frames: Int) {
        lock.lock()
        defer { lock.unlock() }
        let attackStep = 1 / (attackSeconds * sampleRate)
        let releaseStep = 1 / (releaseSeconds * sampleRate)
        let transpose = pow(2, tuning.pitch / 12)
        let level = gain * tuning.volume
        for frame in 0..<frames {
            vibratoPhase += 5.5 / sampleRate
            if vibratoPhase > 1 { vibratoPhase -= 1 }
            let vibrato = 1 + 0.01 * tuning.vibrato * sin(vibratoPhase * 2 * .pi)
            var sample = 0.0
            for index in voices.indices {
                var voice = voices[index]
                if voice.isHeld {
                    voice.level = min(1, voice.level + attackStep)
                } else {
                    voice.level = max(0, voice.level - releaseStep)
                }
                sample += Synth.sample(phase: voice.phase, warmth: tuning.warmth, edge: tuning.edge) * voice.level * level
                voice.phase += voice.frequency * transpose * vibrato / sampleRate
                if voice.phase > 1 { voice.phase -= 1 }
                voices[index] = voice
            }
            output[frame] = Float(max(-1, min(1, sample)))
        }
        voices.removeAll { !$0.isHeld && $0.level <= 0 }
    }
}
