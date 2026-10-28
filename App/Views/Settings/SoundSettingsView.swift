import SwiftUI

/// Settings > Games > Sound, styled as a space-age audio console: a dark
/// panel with a phosphor oscilloscope showing the live waveform, an amber
/// power lamp, tick-marked sliders with glowing readouts, and push
/// buttons. Letting go of a slider plays a sample with the new setting.
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
        ScrollView {
            VStack(spacing: 18) {
                header
                Oscilloscope(warmth: warmth, edge: edge, vibrato: vibrato, pitch: pitch, live: soundOn)
                    .frame(height: 150)
                panel("NOTES") {
                    ConsoleSlider(label: "VOLUME", value: $volume, range: 0...1,
                                  readout: String(format: "%3.0f", volume * 100), onRelease: preview)
                    ConsoleSlider(label: "PITCH", value: $pitch, range: -12...12, step: 1,
                                  readout: String(format: "%+3.0f", pitch), onRelease: preview)
                    ConsoleSlider(label: "LENGTH", value: $length, range: 0.5...2,
                                  readout: String(format: "%.2f", length), onRelease: preview)
                }
                panel("TONIC") {
                    SoundTuningControls(part: .tonic, onChange: soundRoot)
                }
                panel("SCALE") {
                    SoundTuningControls(part: .scale, onChange: soundRoot)
                }
                panel("TONE") {
                    ConsoleSlider(label: "WARMTH", value: $warmth, range: 0...1,
                                  readout: String(format: "%3.0f", warmth * 100), onRelease: preview)
                    ConsoleSlider(label: "EDGE", value: $edge, range: 1...4,
                                  readout: String(format: "%.2f", edge), onRelease: preview)
                    ConsoleSlider(label: "VIBRATO", value: $vibrato, range: 0...1,
                                  readout: String(format: "%3.0f", vibrato * 100), onRelease: preview)
                }
                HStack(spacing: 14) {
                    ConsoleButton(title: "TEST", systemImage: "play.fill", tint: Console.green) {
                        preview(force: true)
                    }
                    ConsoleButton(title: "RESET", systemImage: "arrow.counterclockwise", tint: Console.amber,
                                  isEnabled: !isStandard) {
                        withAnimation(.snappy) { SoundTuning.reset() }
                        preview()
                    }
                }
                Text("SIMON AND THE GAMES · TONIC AND SCALE LAY OUT SIMON'S PADS · FOLLOWS THE SILENT SWITCH")
                    .font(Console.font(9))
                    .tracking(1.5)
                    .foregroundStyle(Console.dim)
                    .padding(.top, 4)
            }
            .padding(16)
            .padding(.bottom, 24)
            .disabled(!soundOn)
        }
        .background(Console.panel.ignoresSafeArea())
        .navigationTitle("Sound")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Console.panel, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    /// The nameplate and the power lamp. The lamp is the on/off switch.
    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text("AUDIO CONSOLE")
                    .font(Console.font(15, weight: .bold))
                    .tracking(3)
                    .foregroundStyle(Console.text)
                Text("MK I · 16 LIGHTS")
                    .font(Console.font(9))
                    .tracking(2)
                    .foregroundStyle(Console.dim)
            }
            Spacer()
            Button {
                soundOn.toggle()
                if soundOn { preview() } else { Synth.shared.stop() }
            } label: {
                HStack(spacing: 8) {
                    Text("PWR")
                        .font(Console.font(10, weight: .bold))
                        .tracking(2)
                        .foregroundStyle(soundOn ? Console.amber : Console.dim)
                    Lamp(isOn: soundOn, color: Console.amber)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Console.inset, in: Capsule())
                .overlay(Capsule().strokeBorder(Console.rim, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sounds")
            .accessibilityValue(soundOn ? "On" : "Off")
            .accessibilityAddTraits(.isToggle)
        }
        .disabled(false)
    }

    private func panel<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Console.font(10, weight: .bold))
                .tracking(2.5)
                .foregroundStyle(Console.dim)
            content()
        }
        .padding(14)
        .background(Console.inset, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Console.rim, lineWidth: 1))
        .opacity(soundOn ? 1 : 0.45)
    }

    /// Plays the sample with the current settings (when sounds are on).
    private func preview(force: Bool = false) {
        guard soundOn || force else { return }
        let tuning = SoundTuning.load()
        Synth.shared.timbre = tuning
        Synth.shared.play(tuning.applied(to: GameSounds.sample()))
    }

    private func preview() { preview(force: false) }

    /// Sounds the root of the chosen tonic and scale on Simon's synth, so a
    /// new tuning can be heard.
    private func soundRoot(_ frequency: Double) {
        guard soundOn else { return }
        SimonSynth.shared.noteOn(frequency, duration: 0.3)
    }
}

/// The console's colours and type.
enum Console {
    static let panel = Color(red: 0.08, green: 0.09, blue: 0.12)
    static let inset = Color(red: 0.12, green: 0.14, blue: 0.18)
    static let rim = Color.white.opacity(0.08)
    static let text = Color(red: 0.88, green: 0.9, blue: 0.94)
    static let dim = Color(red: 0.5, green: 0.55, blue: 0.62)
    static let green = Color(red: 0.45, green: 1, blue: 0.62)
    static let amber = Color(red: 1, green: 0.72, blue: 0.3)

    static func font(_ size: CGFloat, weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

/// A small round lamp that glows when on.
struct Lamp: View {
    let isOn: Bool
    let color: Color

    var body: some View {
        Circle()
            .fill(isOn ? color : Color.black.opacity(0.5))
            .frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(Color.white.opacity(isOn ? 0.5 : 0.15), lineWidth: 1))
            .shadow(color: isOn ? color.opacity(0.9) : .clear, radius: 6)
            .animation(.easeInOut(duration: 0.2), value: isOn)
    }
}

/// A phosphor screen tracing the waveform the sliders make, with a slow
/// vibrato wobble while the console is on.
struct Oscilloscope: View {
    let warmth: Double
    let edge: Double
    let vibrato: Double
    let pitch: Double
    let live: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !live)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                // Graticule.
                var grid = Path()
                for i in 0...8 {
                    let x = size.width * CGFloat(i) / 8
                    grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
                }
                for i in 0...4 {
                    let y = size.height * CGFloat(i) / 4
                    grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
                }
                context.stroke(grid, with: .color(Console.green.opacity(0.12)), lineWidth: 0.5)

                // The trace: two cycles, wobbling with the vibrato and the
                // pitch; brighter and taller when on.
                let cycles = 2 * pow(2, pitch / 24)
                let wobble = 1 + 0.08 * vibrato * sin(time * 5.5 * 2 * .pi)
                var trace = Path()
                let steps = 240
                for step in 0...steps {
                    let x = size.width * CGFloat(step) / CGFloat(steps)
                    let phase = (Double(step) / Double(steps) * cycles * wobble + time * 0.2).truncatingRemainder(dividingBy: 1)
                    let value = live ? Synth.sample(phase: phase, warmth: warmth, edge: edge) : 0
                    let y = size.height / 2 - CGFloat(value) * size.height * 0.4
                    if step == 0 { trace.move(to: CGPoint(x: x, y: y)) } else { trace.addLine(to: CGPoint(x: x, y: y)) }
                }
                context.stroke(trace, with: .color(Console.green.opacity(0.35)), style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))
                context.stroke(trace, with: .color(Console.green), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
            }
        }
        .background(Color(red: 0.03, green: 0.07, blue: 0.05), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Console.rim, lineWidth: 1))
        .overlay(alignment: .topLeading) {
            Text(live ? "WAVEFORM" : "STANDBY")
                .font(Console.font(9, weight: .bold))
                .tracking(2)
                .foregroundStyle(Console.green.opacity(0.7))
                .padding(10)
        }
        .accessibilityHidden(true)
    }
}

/// A console slider: a tick-marked track with a glowing thumb, the label
/// on the left and a readout on the right.
struct ConsoleSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double? = nil
    let readout: String
    let onRelease: () -> Void

    @State private var isDragging = false

    private var fraction: Double { (value - range.lowerBound) / (range.upperBound - range.lowerBound) }

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(label)
                    .font(Console.font(10, weight: .bold))
                    .tracking(2)
                    .foregroundStyle(Console.text)
                Spacer()
                Text(readout)
                    .font(Console.font(12, weight: .bold))
                    .foregroundStyle(Console.green)
                    .shadow(color: Console.green.opacity(0.7), radius: 4)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(0.5), in: RoundedRectangle(cornerRadius: 5))
            }
            GeometryReader { geometry in
                let width = geometry.size.width
                let thumbX = CGFloat(fraction) * (width - 22) + 11
                ZStack(alignment: .leading) {
                    // Ticks.
                    HStack(spacing: 0) {
                        ForEach(0..<21, id: \.self) { tick in
                            Rectangle()
                                .fill(Console.dim.opacity(tick.isMultiple(of: 5) ? 0.6 : 0.25))
                                .frame(width: 1, height: tick.isMultiple(of: 5) ? 10 : 5)
                            if tick < 20 { Spacer(minLength: 0) }
                        }
                    }
                    .padding(.horizontal, 11)
                    .frame(height: 10)
                    .offset(y: 13)
                    // Track and fill.
                    Capsule().fill(Color.black.opacity(0.6)).frame(height: 6)
                    Capsule().fill(Console.green.opacity(0.8)).frame(width: max(0, thumbX), height: 6)
                        .shadow(color: Console.green.opacity(0.6), radius: 4)
                    // Thumb.
                    Circle()
                        .fill(LinearGradient(colors: [Color(white: 0.95), Color(white: 0.7)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 22, height: 22)
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.4), lineWidth: 1))
                        .shadow(color: .black.opacity(0.5), radius: 3, y: 2)
                        .scaleEffect(isDragging ? 1.15 : 1)
                        .position(x: thumbX, y: 11)
                }
                .frame(height: 22)
                .contentShape(Rectangle().inset(by: -8))
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { drag in
                            isDragging = true
                            let raw = Double((drag.location.x - 11) / (width - 22))
                            var new = range.lowerBound + min(1, max(0, raw)) * (range.upperBound - range.lowerBound)
                            if let step { new = (new / step).rounded() * step }
                            value = new
                        }
                        .onEnded { _ in
                            isDragging = false
                            onRelease()
                        }
                )
                .animation(.easeOut(duration: 0.12), value: isDragging)
            }
            .frame(height: 28)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label.capitalized)
        .accessibilityValue(readout)
        .accessibilityAdjustableAction { direction in
            let increment = step ?? (range.upperBound - range.lowerBound) / 20
            value = min(range.upperBound, max(range.lowerBound, value + (direction == .increment ? increment : -increment)))
            onRelease()
        }
    }
}

/// A console push button.
struct ConsoleButton: View {
    let title: String
    let systemImage: String
    let tint: Color
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                Text(title).tracking(2)
            }
            .font(Console.font(12, weight: .bold))
            .foregroundStyle(isEnabled ? tint : Console.dim)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Console.inset, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(isEnabled ? tint.opacity(0.5) : Console.rim, lineWidth: 1))
            .shadow(color: isEnabled ? tint.opacity(0.25) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title.capitalized)
    }
}
