import SwiftUI

/// Settings > Games > Sound: whether the beeps play and how they sound.
/// Letting go of a slider plays a sample with the new setting.
struct SoundSettingsView: View {
    @AppStorage(GameSounds.enabledKey) private var soundOn = true
    @AppStorage(SoundTuning.Key.volume.rawValue) private var volume = SoundTuning.standard.volume
    @AppStorage(SoundTuning.Key.pitch.rawValue) private var pitch = SoundTuning.standard.pitch
    @AppStorage(SoundTuning.Key.length.rawValue) private var length = SoundTuning.standard.length
    @AppStorage(SoundTuning.Key.warmth.rawValue) private var warmth = SoundTuning.standard.warmth
    @AppStorage(SoundTuning.Key.edge.rawValue) private var edge = SoundTuning.standard.edge
    @AppStorage(SoundTuning.Key.vibrato.rawValue) private var vibrato = SoundTuning.standard.vibrato

    private var isStandard: Bool { SoundTuning.load() == .standard }

    var body: some View {
        Form {
            Section {
                Toggle("Sounds", isOn: $soundOn)
                    .onChange(of: soundOn) { _, on in
                        if on { preview() } else { Synth.shared.stop() }
                    }
            } footer: {
                Text("Beeps and boops in Lights Out. They follow the silent switch.")
            }

            Section {
                slider("Volume", value: $volume, in: 0...1, low: "speaker.fill", high: "speaker.wave.3.fill")
                slider("Pitch", value: $pitch, in: -12...12, step: 1, low: "arrow.down", high: "arrow.up",
                       detail: pitch == 0 ? "Standard" : String(format: "%+.0f semitones", pitch))
                slider("Length", value: $length, in: 0.5...2, low: "hare", high: "tortoise",
                       detail: String(format: "%.1f×", length))
            } header: {
                Text("Notes")
            }

            Section {
                slider("Warmth", value: $warmth, in: 0...1, low: "circle", high: "triangle")
                slider("Edge", value: $edge, in: 1...4, low: "waveform", high: "bolt")
                slider("Vibrato", value: $vibrato, in: 0...1, low: "minus", high: "water.waves")
            } header: {
                Text("Tone")
            } footer: {
                Text("Warmth mixes in a triangle wave; Edge drives it harder; Vibrato wobbles the pitch. The standard setting is a soft sixties console.")
            }

            Section {
                Button {
                    preview(force: true)
                } label: {
                    Label("Play Sample", systemImage: "play.circle")
                }
                Button("Reset to Standard") {
                    withAnimation { SoundTuning.reset() }
                    preview()
                }
                .disabled(isStandard)
            }
        }
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func slider(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double? = nil,
                        low: String, high: String, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                Spacer()
                if let detail {
                    Text(detail).foregroundStyle(.secondary).font(.tact(.footnote))
                }
            }
            HStack(spacing: 10) {
                Image(systemName: low).foregroundStyle(.secondary).font(.tact(.caption))
                if let step {
                    Slider(value: value, in: range, step: step) { editing in if !editing { preview() } }
                } else {
                    Slider(value: value, in: range) { editing in if !editing { preview() } }
                }
                Image(systemName: high).foregroundStyle(.secondary).font(.tact(.caption))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .disabled(!soundOn)
        .opacity(soundOn ? 1 : 0.4)
    }

    /// Plays the sample with the current settings (when sounds are on).
    private func preview(force: Bool = false) {
        guard soundOn || force else { return }
        let tuning = SoundTuning.load()
        Synth.shared.timbre = tuning
        Synth.shared.play(tuning.applied(to: GameSounds.sample()))
    }
}
