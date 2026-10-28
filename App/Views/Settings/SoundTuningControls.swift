import SwiftUI

/// A scale as a picture: the twelve semitones of an octave in a row, the
/// ones in the scale as tall bars, the rest as stubs, the root brightest.
/// Read left to right it is the scale's shape — a pentatonic is sparse,
/// the chromatic is solid.
struct ScaleIcon: View {
    let scale: SimonScale
    var color: Color = Console.green

    var body: some View {
        Canvas { context, size in
            let slots = 12
            let gap: CGFloat = 1.5
            let pitch = (size.width + gap) / CGFloat(slots)
            let width = pitch - gap
            let steps = Set(scale.steps)
            for semitone in 0..<slots {
                let inScale = steps.contains(semitone)
                let height = inScale ? size.height : size.height * 0.22
                let rect = CGRect(x: CGFloat(semitone) * pitch, y: size.height - height, width: width, height: height)
                let shade = semitone == 0 ? 1.0 : (inScale ? 0.7 : 0.2)
                context.fill(Path(roundedRect: rect, cornerRadius: width * 0.3), with: .color(color.opacity(shade)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The TONIC and SCALE panels of the audio console: the tonic as a key on
/// one octave of piano, the scale as a grid of icons. Writes the same
/// `SimonTuning` defaults Simon reads, so the pads re-lay themselves.
struct SoundTuningControls: View {
    enum Part { case tonic, scale }
    let part: Part
    @AppStorage(SimonTuning.scaleKey) private var scaleID = SimonTuning.standard.scale.rawValue
    @AppStorage(SimonTuning.keyKey) private var keySemitone = SimonTuning.standard.key.semitone
    /// Called after a change, with the root's frequency, so the console can
    /// sound it.
    var onChange: (Double) -> Void

    private var scale: SimonScale { SimonScale(rawValue: scaleID) ?? .majorPentatonic }
    private var tuning: SimonTuning { SimonTuning(scale: scale, key: SimonKey(semitone: keySemitone)) }

    private static let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        switch part {
        case .tonic: piano
        case .scale: scaleGrid
        }
    }

    // MARK: Tonic

    private static let whites = [0, 2, 4, 5, 7, 9, 11]
    private static let blacks: [(semitone: Int, after: Int)] = [(1, 0), (3, 1), (6, 3), (8, 4), (10, 5)]

    /// One octave of piano, C to B: white keys in a row, black keys over
    /// the gaps between them.
    private var piano: some View {
        GeometryReader { proxy in
            let whiteWidth = proxy.size.width / CGFloat(Self.whites.count)
            let blackWidth = whiteWidth * 0.62
            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(Self.whites, id: \.self) { semitone in
                        key(semitone, isBlack: false)
                    }
                }
                ForEach(Self.blacks, id: \.semitone) { black in
                    key(black.semitone, isBlack: true)
                        .frame(width: blackWidth, height: proxy.size.height * 0.58)
                        .offset(x: CGFloat(black.after + 1) * whiteWidth - blackWidth / 2)
                }
            }
        }
        .frame(height: 104)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tonic")
    }

    private func key(_ semitone: Int, isBlack: Bool) -> some View {
        let isSelected = semitone == keySemitone
        let name = SimonKey(semitone: semitone).name(flats: scale.prefersFlats)
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: 5, bottomTrailingRadius: 5)
        return Button {
            keySemitone = semitone
            changed()
        } label: {
            ZStack(alignment: .bottom) {
                shape.fill(isBlack ? Color.black.opacity(0.85) : Console.text.opacity(0.92))
                shape.strokeBorder(isSelected ? Console.green : Console.rim, lineWidth: isSelected ? 2 : 1)
                if isSelected {
                    shape.fill(Console.green.opacity(0.28))
                }
                VStack(spacing: 5) {
                    Lamp(isOn: isSelected, color: Console.green)
                    Text(name)
                        .font(Console.font(10, weight: .bold))
                        .foregroundStyle(isBlack ? Console.text : Console.panel)
                }
                .padding(.bottom, 7)
            }
            .shadow(color: isSelected ? Console.green.opacity(0.35) : .clear, radius: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Scale

    private var scaleGrid: some View {
        LazyVGrid(columns: Self.columns, spacing: 8) {
            ForEach(SimonScale.allCases) { candidate in
                let isSelected = candidate == scale
                Button {
                    scaleID = candidate.rawValue
                    changed()
                } label: {
                    VStack(spacing: 7) {
                        ScaleIcon(scale: candidate, color: isSelected ? Console.green : Console.dim)
                            .frame(height: 22)
                        Text(candidate.title.uppercased())
                            .font(Console.font(8, weight: .bold))
                            .tracking(1)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                        Text("\(candidate.steps.count) NOTES")
                            .font(Console.font(7))
                            .tracking(1)
                            .foregroundStyle(Console.dim)
                    }
                    .foregroundStyle(isSelected ? Console.green : Console.text)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, minHeight: 78)
                    .background(Console.panel, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? Console.green.opacity(0.6) : Console.rim, lineWidth: 1))
                    .shadow(color: isSelected ? Console.green.opacity(0.25) : .clear, radius: 8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(candidate.title), \(candidate.steps.count) notes")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func changed() {
        UISelectionFeedbackGenerator().selectionChanged()
        onChange(tuning.frequency(noteIndex: 0))
    }
}
