import SwiftUI

/// A FatBits stamp drawn at any size: each bit a square of one of the
/// four shades of its colour, with the stamp's circles drawn clean on top.
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
        var clipped = context
        clipped.clip(to: Path(rect))
        TilePatternView.drawCircles(bits.circles, shades: shades, in: rect, context: &clipped)
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
    /// A pattern traced into bits: the pattern is drawn without its circles
    /// and each bit takes the shade nearest the colour at its middle; the
    /// circles are then laid over as vectors, so the Pinwheel's dot stays a
    /// round dot. The starting point for editing a tile in FatBits, so the
    /// person's motif is forked, not lost.
    @MainActor
    init(tracing pattern: TilePattern, colorIndex: Int, palette: AppPalette = .current) {
        // Bits are the same whatever the palette, and tracing needs four
        // shades to tell apart, which Monochrome's two can't give.
        let palette = palette.isMonochrome ? .classic : palette
        let scale = 8  // sample points per bit
        let side = FatBits.side * scale
        let renderer = ImageRenderer(content: TilePatternView(pattern: pattern, colorIndex: colorIndex, drawsCircles: false)
            .environment(\.appPalette, palette)
            .frame(width: CGFloat(side), height: CGFloat(side)))
        renderer.scale = 1
        guard let image = renderer.cgImage, let samples = FatBits.rgba(of: image) else {
            self = FatBits(bits: FatBits.cross.bits, circles: pattern.circles)
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
        self.init(bits: bits, circles: pattern.circles)
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
/// of a fingertip. With the Bits tool, tap a square to paint it the chosen
/// shade, drag to paint a run. With the Circle tool, press where the
/// circle's middle goes and drag out to its edge, for a clean round shape
/// no grid of bits can make; a tap drops a dot the size of the Pinwheel's.
/// The row above the canvas picks the shade, the row below the colour; a
/// strip of the motif tiled three by three shows how it joins up with
/// itself in the mosaic. Every stroke, circle and tool is a step that Undo
/// in the bar (or a shake) takes back and Redo puts back. Edits a mosaic
/// stamp, or a person's tile.
struct FatBitsEditor: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appPalette) private var palette
    @EnvironmentObject private var store: TactStore
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
    @State private var tool: Tool = .bits
    /// The circle being dragged out, before it is laid down.
    @State private var draftCircle: FatBitsCircle?
    /// The bits before the stroke under way, recorded as one step when it ends.
    @State private var strokeStart: FatBits?
    @State private var namingPattern = false
    @State private var patternName = ""
    @State private var managingPatterns = false
    /// The canvas as it was before each edit, for Undo and Redo.
    @State private var history = EditHistory<FatBits>()

    enum Tool: String, CaseIterable, Identifiable {
        case bits, circle
        var id: String { rawValue }
        var title: String { self == .bits ? "Bits" : "Circle" }
        var systemImage: String { self == .bits ? "square.grid.3x3.fill" : "circle.fill" }
    }

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
                    toolPicker
                    tools
                    savedPatternsRow
                    if choosesColor && !palette.isMonochrome { colorPicker }
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
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { undo() } label: { Image(systemName: "arrow.uturn.backward") }
                        .disabled(!history.canUndo)
                        .accessibilityLabel("Undo")
                        .keyboardShortcut("z", modifiers: .command)
                    Button { redo() } label: { Image(systemName: "arrow.uturn.forward") }
                        .disabled(!history.canRedo)
                        .accessibilityLabel("Redo")
                        .keyboardShortcut("z", modifiers: [.command, .shift])
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
            .alert(savedMatch == nil ? "Save Pattern" : "Rename Pattern", isPresented: $namingPattern) {
                TextField("Name", text: $patternName)
                    .textInputAutocapitalization(.words)
                Button("Save") {
                    store.savePattern(bits, named: patternName)
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("A saved pattern can be given to anyone from their Tile menu, in their own color.")
            }
            .sheet(isPresented: $managingPatterns) {
                SavedPatternsSheet(colorIndex: colorIndex) { pattern in edit { bits = pattern.bits } }
            }
            .onShake { if history.canUndo { undo() } }
        }
    }

    // MARK: Undo

    /// Makes an edit the user can take back: the canvas as it stands goes
    /// on the history first.
    private func edit(_ change: () -> Void) {
        let before = bits
        change()
        if bits != before { history.record(before) }
    }

    private func undo() {
        guard let previous = history.undo(current: bits) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) { bits = previous }
    }

    private func redo() {
        guard let next = history.redo(current: bits) else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        withAnimation(.easeInOut(duration: 0.15)) { bits = next }
    }

    /// The saved pattern this drawing is, when it is one.
    private var savedMatch: SavedPattern? { store.patternLibrary.pattern(matching: bits) }

    // MARK: Canvas

    private var canvas: some View {
        GeometryReader { proxy in
            let pitch = proxy.size.width / CGFloat(FatBits.side)
            ZStack {
                FatBitsView(bits: bits, colorIndex: colorIndex)
                gridLines(pitch: pitch)
                if let draftCircle { draftOutline(draftCircle, side: proxy.size.width) }
            }
            .contentShape(Rectangle())
            .gesture(canvasGesture(pitch: pitch, side: proxy.size.width))
            .accessibilityElement()
            .accessibilityLabel("FatBits canvas, \(FatBits.side) by \(FatBits.side)")
            .accessibilityHint(tool == .bits ? "Tap or drag to paint with the chosen shade."
                                             : "Press where the circle's middle goes and drag out to its edge.")
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

    /// The circle being dragged, in its shade, with a dashed edge so it can
    /// be seen over bits of the same shade.
    private func draftOutline(_ circle: FatBitsCircle, side: CGFloat) -> some View {
        let radius = CGFloat(circle.radius) * side
        return Circle()
            .fill(shadeColors[Int(circle.shade)].opacity(0.7))
            .overlay(Circle().strokeBorder(.black.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
            .frame(width: radius * 2, height: radius * 2)
            .position(x: CGFloat(circle.x) * side, y: CGFloat(circle.y) * side)
            .allowsHitTesting(false)
    }

    /// One drag gesture for both tools, so switching tools mid-session does
    /// not rebuild the gesture under a finger. Bits: each square the drag
    /// passes over takes the shade. Circle: press at the middle, drag out to
    /// the edge; a tap, with no drag to speak of, drops a dot of the default
    /// size.
    private func canvasGesture(pitch: CGFloat, side: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                switch tool {
                case .bits:
                    let x = Int(value.location.x / pitch), y = Int(value.location.y / pitch)
                    guard FatBits.contains(x, y) else { return }
                    let index = y * FatBits.side + x
                    guard !painted.contains(index) else { return }
                    if painted.isEmpty {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        strokeStart = bits
                    }
                    painted.insert(index)
                    bits[x, y] = shade
                case .circle:
                    let centre = value.startLocation
                    let dx = value.location.x - centre.x, dy = value.location.y - centre.y
                    let distance = Double(sqrt(dx * dx + dy * dy) / side)
                    let radius = distance < FatBitsCircle.minimumRadius ? FatBitsCircle.defaultRadius : distance
                    if draftCircle == nil { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                    draftCircle = FatBitsCircle.snapped(x: Double(centre.x / side), y: Double(centre.y / side),
                                                        radius: radius, shade: shade)
                }
            }
            .onEnded { _ in
                painted = []
                // A whole stroke is one step: the bits before it went down.
                if let strokeStart, strokeStart != bits { history.record(strokeStart) }
                strokeStart = nil
                if let draftCircle { edit { bits.addCircle(draftCircle) } }
                draftCircle = nil
            }
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

    private var toolPicker: some View {
        Picker("Tool", selection: $tool) {
            ForEach(Tool.allCases) { tool in
                Label(tool.title, systemImage: tool.systemImage).tag(tool)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: tool) { _, _ in UISelectionFeedbackGenerator().selectionChanged() }
    }

    private var tools: some View {
        HStack(spacing: 10) {
            tool("Flip Left and Right", "arrow.left.and.right") { edit { bits = bits.flippedHorizontally } }
            tool("Flip Up and Down", "arrow.up.and.down") { edit { bits = bits.flippedVertically } }
            tool("Invert", "circle.lefthalf.filled") { edit { bits = bits.inverted } }
            tool("Band", "plus") { edit { bits = .cross } }
            tool("Remove Last Circle", "circle.slash", isEnabled: !bits.circles.isEmpty) { edit { bits.removeLastCircle() } }
            tool("Clear", "trash", isEnabled: !bits.isBlank) { edit { bits.clear() } }
            if let revertBits {
                tool("Revert", "arrow.counterclockwise", isEnabled: bits != revertBits) { edit { bits = revertBits } }
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

    // MARK: Saved patterns

    /// Saving the drawing under a name, and the saved patterns to start
    /// from: each a small tile in the current colour, the one the canvas
    /// shows marked.
    private var savedPatternsRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(savedMatch.map { "Saved as \($0.name)" } ?? "Saved patterns")
                    .font(.tact(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                if !store.patternLibrary.isEmpty {
                    Button("Manage") { managingPatterns = true }
                        .font(.tact(.footnote))
                }
                Button(savedMatch == nil ? "Save…" : "Rename…") {
                    patternName = savedMatch?.name ?? ""
                    namingPattern = true
                }
                .font(.tact(.footnote).weight(.semibold))
            }
            if !store.patternLibrary.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.patternLibrary.patterns) { pattern in
                            let isCurrent = pattern.bits == bits
                            Button {
                                UISelectionFeedbackGenerator().selectionChanged()
                                withAnimation(.easeInOut(duration: 0.15)) { edit { bits = pattern.bits } }
                            } label: {
                                VStack(spacing: 4) {
                                    FatBitsView(bits: pattern.bits, colorIndex: colorIndex)
                                        .frame(width: 44, height: 44)
                                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                        .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .strokeBorder(isCurrent ? palette.accent : Color.tactTileGray, lineWidth: isCurrent ? 3 : 1))
                                    Text(pattern.name)
                                        .font(.tact(.caption2))
                                        .lineLimit(1)
                                        .frame(width: 56)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Saved pattern \(pattern.name)")
                            .accessibilityAddTraits(isCurrent ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
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

/// The pencil that opens FatBits, as on the Mosaic palette strip: a dashed
/// swatch at the end of a row of stamps, in the accent colour. The same
/// control on the person page, so drawing a tile is found the same way
/// everywhere.
struct FatBitsPencilSwatch: View {
    @Environment(\.appPalette) private var palette
    var size: CGFloat = 40
    var cornerRadius: CGFloat = 6
    var isEnabled = true
    let label: String
    let hint: String
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Image(systemName: "pencil.and.outline")
                .font(.tact(.body).weight(.semibold))
                .foregroundStyle(isEnabled ? palette.accent : Color.secondary)
                .frame(width: size, height: size)
                .background(Color.tactCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.tactTileGray, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
        .accessibilityHint(hint)
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
