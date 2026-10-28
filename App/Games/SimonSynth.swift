import AVFoundation
import os

/// A small polyphonic synthesizer for the Simon pads. Each voice is a sine
/// with a touch of its second and third harmonics for warmth, under an
/// attack-and-release envelope, so a pad sounds like a soft electric organ
/// and never clicks. Voices are mixed in an `AVAudioSourceNode`; up to eight
/// sound at once, and the oldest is replaced when more are needed.
///
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
    private let gain = 0.18

    private var engine: AVAudioEngine?
    private var voices: [Voice] = []
    private var nextSerial: UInt64 = 0
    private let lock = OSAllocatedUnfairLock()
    private var sampleRate = 44_100.0

    private init() {}

    // MARK: Playing

    /// Starts a note at `frequency`. It sounds until `noteOff` for the same
    /// frequency, or `duration` seconds when given.
    func noteOn(_ frequency: Double, duration: Double? = nil) {
        prepare()
        lock.withLock {
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
        for frame in 0..<frames {
            var sample = 0.0
            for index in voices.indices {
                var voice = voices[index]
                if voice.isHeld {
                    voice.level = min(1, voice.level + attackStep)
                } else {
                    voice.level = max(0, voice.level - releaseStep)
                }
                let phase = voice.phase
                let tone = sin(phase) + 0.25 * sin(2 * phase) + 0.1 * sin(3 * phase)
                sample += tone * voice.level * gain
                voice.phase = (phase + 2 * .pi * voice.frequency / sampleRate).truncatingRemainder(dividingBy: 2 * .pi)
                voices[index] = voice
            }
            output[frame] = Float(max(-1, min(1, sample)))
        }
        voices.removeAll { !$0.isHeld && $0.level <= 0 }
    }
}
