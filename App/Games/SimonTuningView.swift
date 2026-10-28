import SwiftUI

/// A scale as a picture: the twelve semitones of an octave in a row, the
/// ones in the scale filled, the root marked. Read left to right it is the
/// scale's shape — a pentatonic is sparse, the chromatic is solid.
struct ScaleIcon: View {
    let scale: SimonScale
    var color: Color = .accentColor

    var body: some View {
        Canvas { context, size in
            let slots = 12
            let gap: CGFloat = 1.5
            let pitch = (size.width + gap) / CGFloat(slots)
            let width = pitch - gap
            let steps = Set(scale.steps)
            for semitone in 0..<slots {
                let x = CGFloat(semitone) * pitch
                // A tall bar for a note in the scale, a stub for one that is not.
                let height = steps.contains(semitone) ? size.height : size.height * 0.22
                let rect = CGRect(x: x, y: size.height - height, width: width, height: height)
                let path = Path(roundedRect: rect, cornerRadius: width * 0.3)
                let shade = semitone == 0 ? 1.0 : (steps.contains(semitone) ? 0.7 : 0.22)
                context.fill(path, with: .color(color.opacity(shade)))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Picks the tonic and the scale the Simon pads are laid out on. The tonic
/// is a key on a small piano; the scale is one of a grid of icons, each the
/// scale's shape across an octave.
struct SimonTuningView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @Binding var scaleID: String
    @Binding var keySemitone: Int
    var openSynth: () -> Void

    private var scale: SimonScale { SimonScale(rawValue: scaleID) ?? .majorPentatonic }
    private var tuning: SimonTuning { SimonTuning(scale: scale, key: SimonKey(semitone: keySemitone)) }

    private static let columns = [GridItem(.adaptive(minimum: 104), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section("Tonic") { piano }
                    section("Scale") { scaleGrid }
                    Button(action: openSynth) {
                        Label("Synth Settings…", systemImage: "slider.horizontal.3")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(16)
            }
            .background(Color.tactCardBackground.ignoresSafeArea())
            .navigationTitle(tuning.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.tact(.headline))
            content()
        }
    }

    // MARK: Tonic

    /// One octave of piano, C to B. White keys in a row; black keys laid
    /// over the gaps between them.
    private var piano: some View {
        let whites = [0, 2, 4, 5, 7, 9, 11]
        let blacks: [(semitone: Int, after: Int)] = [(1, 0), (3, 1), (6, 3), (8, 4), (10, 5)]
        return GeometryReader { proxy in
            let whiteWidth = proxy.size.width / CGFloat(whites.count)
            let blackWidth = whiteWidth * 0.62
            ZStack(alignment: .topLeading) {
                HStack(spacing: 0) {
                    ForEach(whites, id: \.self) { semitone in
                        key(semitone, isBlack: false)
                            .frame(width: whiteWidth)
                    }
                }
                ForEach(blacks, id: \.semitone) { black in
                    key(black.semitone, isBlack: true)
                        .frame(width: blackWidth, height: proxy.size.height * 0.6)
                        .offset(x: CGFloat(black.after + 1) * whiteWidth - blackWidth / 2)
                }
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Tonic")
    }

    private func key(_ semitone: Int, isBlack: Bool) -> some View {
        let isSelected = semitone == keySemitone
        let name = SimonKey(semitone: semitone).name(flats: scale.prefersFlats)
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            keySemitone = semitone
        } label: {
            ZStack(alignment: .bottom) {
                UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                    .fill(isSelected ? palette.accent : (isBlack ? Color.primary.opacity(0.85) : Color.white))
                    .overlay(UnevenRoundedRectangle(bottomLeadingRadius: 6, bottomTrailingRadius: 6)
                        .strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                    .shadow(color: .black.opacity(isBlack ? 0.3 : 0.1), radius: 2, y: 1)
                Text(name)
                    .font(.tact(.caption).weight(.semibold))
                    .foregroundStyle(isSelected ? palette.onAccent : (isBlack ? Color.white : Color.black))
                    .padding(.bottom, 8)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: Scale

    private var scaleGrid: some View {
        LazyVGrid(columns: Self.columns, spacing: 10) {
            ForEach(SimonScale.allCases) { candidate in
                let isSelected = candidate == scale
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    scaleID = candidate.rawValue
                } label: {
                    VStack(spacing: 8) {
                        ScaleIcon(scale: candidate, color: isSelected ? palette.onAccent : palette.accent)
                            .frame(height: 28)
                        Text(candidate.title)
                            .font(.tact(.caption).weight(.semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity)
                        Text(Self.sizeText(candidate))
                            .font(.tact(.caption2))
                            .opacity(0.7)
                    }
                    .foregroundStyle(isSelected ? palette.onAccent : Color.primary)
                    .padding(10)
                    .frame(maxWidth: .infinity, minHeight: 92)
                    .background(isSelected ? AnyShapeStyle(palette.accent) : AnyShapeStyle(Color.tactTileGray.opacity(0.25)),
                                in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(candidate.title), \(Self.sizeText(candidate))")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    /// "5 notes", "12 notes": how far up the sixteen pads will reach.
    private static func sizeText(_ scale: SimonScale) -> String {
        "\(scale.steps.count) notes"
    }
}
