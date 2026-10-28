import SwiftUI

/// A FatBits stamp drawn at any size: each bit a square of one of the
/// four shades of its colour.
struct FatBitsView: View {
    let bits: FatBits
    let colorIndex: Int
    @Environment(\.appPalette) private var palette

    var body: some View {
        Canvas { context, size in
            Self.draw(bits, shades: TileShades(colorIndex: colorIndex, palette: palette),
                      in: CGRect(origin: .zero, size: size), context: &context)
        }
    }

    static func draw(_ bits: FatBits, shades: TileShades, in rect: CGRect, context: inout GraphicsContext) {
        let pitch = rect.width / CGFloat(FatBits.side)
        let colors = [shades.pale, shades.light, shades.base, shades.dark]
        for y in 0..<FatBits.side {
            for x in 0..<FatBits.side {
                // Half a point of overlap so no seam shows between bits.
                let square = CGRect(x: rect.minX + CGFloat(x) * pitch, y: rect.minY + CGFloat(y) * pitch,
                                    width: pitch + 0.5, height: pitch + 0.5)
                context.fill(Path(square), with: .color(colors[Int(bits[x, y])]))
            }
        }
    }
}

/// A mosaic stamp as it looks unturned: a built-in motif or a FatBits bitmap.
struct MosaicStampView: View {
    let stamp: MosaicStamp

    var body: some View {
        if let bits = stamp.bits {
            FatBitsView(bits: bits, colorIndex: stamp.colorIndex)
        } else {
            TilePatternView(pattern: TilePattern(rawValue: stamp.pattern) ?? .cross, colorIndex: stamp.colorIndex)
        }
    }
}

/// The FatBits editor: the stamp blown up so each bit is a square the size
/// of a fingertip. Tap a square to paint it the chosen shade, drag to paint
/// a run. The row above the canvas picks the shade, the row below the
/// colour; a strip of the stamp tiled three by three shows how it joins up
/// with itself in the mosaic.
struct FatBitsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    /// The stamp being edited; nil to draw a new one.
    let original: MosaicStamp?
    let onSave: (MosaicStamp) -> Void
    var onDelete: (() -> Void)?

    @State private var bits: FatBits
    @State private var colorIndex: Int
    @State private var shade: UInt8 = 2
    @State private var painted = Set<Int>()

    init(original: MosaicStamp? = nil, onSave: @escaping (MosaicStamp) -> Void, onDelete: (() -> Void)? = nil) {
        self.original = original
        self.onSave = onSave
        self.onDelete = onDelete
        _bits = State(initialValue: original?.bits ?? .cross)
        _colorIndex = State(initialValue: original?.colorIndex ?? TilePalette.menuOrder[0])
    }

    private var shades: TileShades { TileShades(colorIndex: colorIndex, palette: palette) }
    private var shadeColors: [Color] { [shades.pale, shades.light, shades.base, shades.dark] }
    private static let shadeNames = ["pale", "light", "color", "dark"]
    private var stamp: MosaicStamp { MosaicStamp(bits: bits, colorIndex: colorIndex) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    shadePicker
                    canvas
                    tools
                    colorPicker
                    tiledPreview
                }
                .padding(16)
            }
            .background(Color.tactCardBackground.ignoresSafeArea())
            .navigationTitle("FatBits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(stamp)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let pitch = proxy.size.width / CGFloat(FatBits.side)
            ZStack {
                FatBitsView(bits: bits, colorIndex: colorIndex)
                gridLines(pitch: pitch)
            }
            .contentShape(Rectangle())
            .gesture(paintGesture(pitch: pitch))
            .accessibilityElement()
            .accessibilityLabel("FatBits canvas, \(FatBits.side) by \(FatBits.side)")
            .accessibilityHint("Tap or drag to paint with the chosen shade.")
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Color.tactTileGray, lineWidth: 1))
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }

    /// Thin lines between the bits, with the band's rows and columns marked
    /// a touch darker so it is clear where neighbours will join.
    private func gridLines(pitch: CGFloat) -> some View {
        Canvas { context, size in
            var lines = Path()
            for index in 1..<FatBits.side {
                let offset = CGFloat(index) * pitch
                lines.move(to: CGPoint(x: offset, y: 0)); lines.addLine(to: CGPoint(x: offset, y: size.height))
                lines.move(to: CGPoint(x: 0, y: offset)); lines.addLine(to: CGPoint(x: size.width, y: offset))
            }
            context.stroke(lines, with: .color(.black.opacity(0.18)), lineWidth: 1)
            var band = Path()
            let lower = CGFloat(FatBits.bandRange.lowerBound) * pitch
            let upper = CGFloat(FatBits.bandRange.upperBound + 1) * pitch
            band.addRect(CGRect(x: lower, y: 0, width: upper - lower, height: size.height))
            band.addRect(CGRect(x: 0, y: lower, width: size.width, height: upper - lower))
            context.stroke(band, with: .color(.black.opacity(0.3)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
        .allowsHitTesting(false)
    }

    private func paintGesture(pitch: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let x = Int(value.location.x / pitch), y = Int(value.location.y / pitch)
                guard FatBits.contains(x, y) else { return }
                let index = y * FatBits.side + x
                guard !painted.contains(index) else { return }
                if painted.isEmpty { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                painted.insert(index)
                bits[x, y] = shade
            }
            .onEnded { _ in painted = [] }
    }

    // MARK: Pickers

    private var shadePicker: some View {
        HStack(spacing: 10) {
            ForEach(0..<4, id: \.self) { index in
                let isSelected = UInt8(index) == shade
                Button {
                    UISelectionFeedbackGenerator().selectionChanged()
                    shade = UInt8(index)
                } label: {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(shadeColors[index])
                        .frame(height: 44)
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(isSelected ? palette.accent : Color.tactTileGray, lineWidth: isSelected ? 3 : 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(Self.shadeNames[index]) shade")
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private var colorPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TilePalette.menuOrder, id: \.self) { index in
                    let isSelected = index == colorIndex
                    Button {
                        UISelectionFeedbackGenerator().selectionChanged()
                        colorIndex = index
                    } label: {
                        Circle()
                            .fill(TilePalette.color(index, in: palette))
                            .frame(width: 36, height: 36)
                            .overlay(Circle().strokeBorder(isSelected ? palette.accent : .clear, lineWidth: 3))
                            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(TilePalette.name(index))
                    .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
    }

    // MARK: Tools

    private var tools: some View {
        HStack(spacing: 10) {
            tool("Flip Left and Right", "arrow.left.and.right") { bits = bits.flippedHorizontally }
            tool("Flip Up and Down", "arrow.up.and.down") { bits = bits.flippedVertically }
            tool("Invert", "circle.lefthalf.filled") { bits = bits.inverted }
            tool("Band", "plus") { bits = .cross }
            tool("Clear", "trash", isEnabled: !bits.isBlank) { bits.clear() }
            if original != nil, let onDelete {
                tool("Delete Stamp", "xmark.bin") {
                    onDelete()
                    dismiss()
                }
            }
        }
    }

    private func tool(_ title: String, _ systemImage: String, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeInOut(duration: 0.15)) { action() }
        } label: {
            Image(systemName: systemImage)
                .font(.tact(.body).weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.tactTileGray.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(title)
    }

    // MARK: Preview

    private var tiledPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("In the mosaic")
                .font(.tact(.footnote))
                .foregroundStyle(.secondary)
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(spacing: 0) {
                        ForEach(0..<3, id: \.self) { _ in
                            FatBitsView(bits: bits, colorIndex: colorIndex)
                                .aspectRatio(1, contentMode: .fit)
                        }
                    }
                }
            }
            .frame(maxWidth: 180)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .accessibilityLabel("The stamp tiled three by three")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
