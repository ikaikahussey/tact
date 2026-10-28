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

/// A motif, unturned: a FatBits bitmap when there is one, else a built-in
/// pattern. Every place a tile's motif is drawn goes through here, so a
/// FatBits tile looks the same on the grid, in flight, in lists and in games.
struct TileMotifView: View {
    var bits: FatBits?
    let pattern: TilePattern
    let colorIndex: Int

    init(bits: FatBits? = nil, pattern: TilePattern, colorIndex: Int) {
        self.bits = bits
        self.pattern = pattern
        self.colorIndex = colorIndex
    }

    /// A person's motif.
    init(person: Person) {
        self.init(bits: person.tile.bits, pattern: person.tilePattern, colorIndex: person.tile.colorIndex)
    }

    var body: some View {
        if let bits {
            FatBitsView(bits: bits, colorIndex: colorIndex)
        } else {
            TilePatternView(pattern: pattern, colorIndex: colorIndex)
        }
    }
}

/// A mosaic stamp as it looks unturned: a built-in motif or a FatBits bitmap.
struct MosaicStampView: View {
    let stamp: MosaicStamp

    var body: some View {
        TileMotifView(bits: stamp.bits, pattern: TilePattern(rawValue: stamp.pattern) ?? .cross, colorIndex: stamp.colorIndex)
    }
}

extension Person {
    /// The person's look as a mosaic stamp: their FatBits motif, or their
    /// pattern, in their colour.
    var mosaicStamp: MosaicStamp {
        if let bits = tile.bits { return MosaicStamp(bits: bits, colorIndex: tile.colorIndex) }
        return MosaicStamp(pattern: tilePattern.rawValue, colorIndex: tile.colorIndex)
    }
}

extension FatBits {
    /// A pattern traced into bits: the pattern is drawn and each bit takes
    /// the shade nearest the colour at its middle. The starting point for
    /// editing a tile in FatBits, so the person's motif is forked, not lost.
    @MainActor
    init(tracing pattern: TilePattern, colorIndex: Int, palette: AppPalette = .current) {
        let scale = 8  // sample points per bit
        let side = FatBits.side * scale
        let renderer = ImageRenderer(content: TilePatternView(pattern: pattern, colorIndex: colorIndex)
            .environment(\.appPalette, palette)
            .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let image = renderer.cgImage, let samples = FatBits.rgba(of: image) else {
            self = .cross
            return
        }
        let shades = TileShades(colorIndex: colorIndex, palette: palette)
        let targets = [shades.pale, shades.light, shades.base, shades.dark].map { color -> (CGFloat, CGFloat, CGFloat) in
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            return (r, g, b)
        }
        var bits = [UInt8](repeating: 0, count: FatBits.count)
        for y in 0..<FatBits.side {
            for x in 0..<FatBits.side {
                let px = x * scale + scale / 2, py = y * scale + scale / 2
                let offset = (py * image.width + px) * 4
                let r = CGFloat(samples[offset]) / 255, g = CGFloat(samples[offset + 1]) / 255, b = CGFloat(samples[offset + 2]) / 255
                var best = 0, bestDistance = CGFloat.greatestFiniteMagnitude
                for (index, target) in targets.enumerated() {
                    let distance = pow(r - target.0, 2) + pow(g - target.1, 2) + pow(b - target.2, 2)
                    if distance < bestDistance { best = index; bestDistance = distance }
                }
                bits[y * FatBits.side + x] = UInt8(best)
            }
        }
        self.init(bits: bits)
    }

    /// The image's pixels as RGBA bytes, four per pixel, row by row.
    private static func rgba(of image: CGImage) -> [UInt8]? {
        var data = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        let drawn = data.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(data: buffer.baseAddress, width: image.width, height: image.height,
                                          bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space, bitmapInfo: info)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        return drawn ? data : nil
    }
}

/// The FatBits editor: the motif blown up so each bit is a square the size
/// of a fingertip. Tap a square to paint it the chosen shade, drag to paint
/// a run. The row above the canvas picks the shade, the row below the
/// colour; a strip of the motif tiled three by three shows how it joins up
/// with itself in the mosaic. Edits a mosaic stamp, or a person's tile.
struct FatBitsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    var title = "FatBits"
    /// What the canvas starts as.
    let startingBits: FatBits
    let startingColor: Int
    /// The look this is a fork of, when there is one: Revert brings the
    /// canvas back to it.
    var revertBits: FatBits?
    /// Whether the colour row is shown. A person's tile keeps its colour.
    var choosesColor = true
    let onSave: (FatBits, Int) -> Void
    var onDelete: (() -> Void)?

    @State private var bits: FatBits
    @State private var colorIndex: Int
    @State private var shade: UInt8 = 2
    @State private var painted = Set<Int>()

    init(title: String = "FatBits", startingBits: FatBits = .cross, startingColor: Int = TilePalette.menuOrder[0],
         revertBits: FatBits? = nil, choosesColor: Bool = true,
         onSave: @escaping (FatBits, Int) -> Void, onDelete: (() -> Void)? = nil) {
        self.title = title
        self.startingBits = startingBits
        self.startingColor = startingColor
        self.revertBits = revertBits
        self.choosesColor = choosesColor
        self.onSave = onSave
        self.onDelete = onDelete
        _bits = State(initialValue: startingBits)
        _colorIndex = State(initialValue: startingColor)
    }

    /// An editor for a mosaic stamp: an existing one, or nil for a new one.
    init(original: MosaicStamp?, onSave: @escaping (MosaicStamp) -> Void, onDelete: (() -> Void)? = nil) {
        self.init(startingBits: original?.bits ?? .cross,
                  startingColor: original?.colorIndex ?? TilePalette.menuOrder[0],
                  revertBits: original?.bits,
                  onSave: { bits, color in onSave(MosaicStamp(bits: bits, colorIndex: color)) },
                  onDelete: onDelete)
    }

    private var shades: TileShades { TileShades(colorIndex: colorIndex, palette: palette) }
    private var shadeColors: [Color] { [shades.pale, shades.light, shades.base, shades.dark] }
    private static let shadeNames = ["pale", "light", "color", "dark"]
    private var isUnchanged: Bool { bits == startingBits && colorIndex == startingColor }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    shadePicker
                    canvas
                    tools
                    if choosesColor { colorPicker }
                    tiledPreview
                }
                .padding(16)
            }
            .background(Color.tactCardBackground.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(bits, colorIndex)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(isUnchanged && revertBits != nil)
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
            if let revertBits {
                tool("Revert", "arrow.uturn.backward", isEnabled: bits != revertBits) { bits = revertBits }
            }
            if let onDelete {
                tool("Delete", "xmark.bin") {
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

/// FatBits opened on a person's tile. The canvas starts as their tile looks
/// now: their FatBits motif, or their pattern traced into bits, so the
/// drawing is a fork of the original. Revert in the tools brings the
/// traced pattern back; Done makes the drawing their tile everywhere.
struct PersonFatBitsEditor: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.appPalette) private var palette
    let person: Person
    /// Called with the person's look before and after, for anything that
    /// shows it and needs to follow along.
    var onChange: ((MosaicStamp, MosaicStamp) -> Void)?

    var body: some View {
        let traced = FatBits(tracing: person.tilePattern, colorIndex: person.tile.colorIndex, palette: palette)
        FatBitsEditor(title: "\(person.name)'s Tile",
                      startingBits: person.tile.bits ?? traced,
                      startingColor: person.tile.colorIndex,
                      revertBits: traced,
                      choosesColor: false) { bits, _ in
            let before = person.mosaicStamp
            store.updateTile(forPersonID: person.id) {
                $0.bits = bits
                $0.showsPhoto = false
            }
            onChange?(before, MosaicStamp(bits: bits, colorIndex: person.tile.colorIndex))
        }
    }
}
