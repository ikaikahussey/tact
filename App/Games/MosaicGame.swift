import SwiftUI

/// Mosaic on the back of the tiles: a quilt you lay out from everyone's
/// motifs. The palette along the bottom holds one stamp per person (their
/// motif in their colour) and an eraser. Tap a cell to stamp it; tap the
/// same stamp again to turn it a quarter turn; drag across cells to paint a
/// run. Fill lays a random quilt from the palette, Clear empties the canvas.
/// The pencil at the end of the palette opens FatBits, where a stamp of
/// your own is drawn bit by bit; those stamps join the palette and can be
/// edited or removed by holding them. The mosaic and the stamps are saved,
/// so they are there next time. Played on the back of the
/// tiles (`TileGame.mosaic`): the cells turn into view as the tiles turn over.
struct MosaicGame: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.appPalette) private var palette
    @AppStorage(Mosaic.storageKey) private var savedData = Data()
    @AppStorage(FatBitsShelf.storageKey) private var savedShelfData = Data()
    let context: TileGameContext
    @State private var mosaic = Mosaic(columns: TileLayout.columns, rows: 4)
    @State private var shelf = FatBitsShelf()
    @State private var selected: MosaicStamp?   // nil is the eraser
    @State private var hasLoaded = false
    /// What the FatBits sheet is open on: a new stamp, or one to edit.
    @State private var editing: FatBitsTarget?
    /// Cells painted so far in the current drag, so each is stamped once.
    @State private var painted = Set<Int>()

    static let columns = TileLayout.columns
    /// Height kept clear under the canvas for the palette strip and buttons.
    static let stripHeight: CGFloat = 68

    /// One stamp for every look among the people, in list order, with a
    /// spread of motifs and colours when there are few people.
    private var stamps: [MosaicStamp] {
        var seen = Set<MosaicStamp>()
        var result: [MosaicStamp] = []
        for person in store.people {
            let stamp = MosaicStamp(pattern: person.tilePattern.rawValue, colorIndex: person.tile.colorIndex)
            if seen.insert(stamp).inserted { result.append(stamp) }
        }
        if result.count < 4 {
            for (offset, pattern) in TilePattern.allCases.enumerated() {
                let stamp = MosaicStamp(pattern: pattern.rawValue, colorIndex: TilePalette.menuOrder[offset % TilePalette.menuOrder.count])
                if seen.insert(stamp).inserted { result.append(stamp) }
            }
        }
        return result
    }

    /// Everything on the palette strip: everyone's looks, then FatBits stamps.
    private var allStamps: [MosaicStamp] { stamps + shelf.stamps }

    private var rows: Int {
        max(4, Int(((context.size.height - Self.stripHeight) / context.pitch).rounded(.down)))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<mosaic.count, id: \.self) { cell in
                cellView(cell)
                    .modifier(TileFlipFace(side: .back, showingBack: context.isShowing, delay: context.flipDelay(cell)))
                    .position(center(of: cell))
            }
        }
        .frame(width: context.size.width, height: context.size.height, alignment: .topLeading)
        .contentShape(Rectangle())
        .coordinateSpace(name: "mosaic")
        .gesture(paintGesture)
        .overlay(alignment: .bottom) {
            if context.isShowing {
                strip
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: context.isShowing)
        .onAppear(perform: load)
        .onChange(of: rows) { _, newRows in mosaic = mosaic.resized(rows: newRows) }
        .onChange(of: mosaic) { _, newValue in savedData = newValue.encoded() ?? Data() }
        .onChange(of: shelf) { _, newValue in savedShelfData = newValue.encoded() ?? Data() }
        .sheet(item: $editing) { target in
            FatBitsEditor(original: target.stamp,
                          onSave: { stamp in save(stamp, replacing: target.stamp) },
                          onDelete: target.stamp.map { old -> () -> Void in { remove(old) } })
        }
    }

    /// Keeps a stamp from FatBits: a new one on the shelf, or an edited one
    /// in place of `old`, on the shelf and across the canvas.
    private func save(_ stamp: MosaicStamp, replacing old: MosaicStamp?) {
        if let old {
            shelf.replace(old, with: stamp)
            mosaic.swap(old, for: stamp)
        } else {
            shelf.add(stamp)
        }
        selected = stamp.unturned
    }

    /// Takes a FatBits stamp off the shelf and out of the canvas.
    private func remove(_ stamp: MosaicStamp) {
        shelf.remove(stamp)
        mosaic.remove(stamp)
        if selected?.sameLook(as: stamp) == true { selected = stamps.first }
    }

    private func load() {
        guard !hasLoaded else { return }
        hasLoaded = true
        let saved = Mosaic.decoded(from: savedData.isEmpty ? nil : savedData)
        mosaic = (saved ?? Mosaic(columns: Self.columns, rows: rows)).resized(rows: rows)
        shelf = FatBitsShelf.decoded(from: savedShelfData.isEmpty ? nil : savedShelfData) ?? FatBitsShelf()
        if selected == nil { selected = stamps.first }
    }

    // MARK: Cells

    private func cellView(_ cell: Int) -> some View {
        ZStack {
            Color.tactTileGray.opacity(0.35)
            if let stamp = mosaic[cell] {
                MosaicStampView(stamp: stamp)
                    .rotationEffect(.degrees(Double(stamp.quarterTurns) * 90))
                    .transition(.opacity)
            }
        }
        .frame(width: context.cellSize, height: context.cellSize)
        .clipped()
        .animation(.easeInOut(duration: 0.15), value: mosaic[cell])
        .contentShape(Rectangle())
        .onTapGesture { tap(cell) }
        .accessibilityElement()
        .accessibilityLabel(mosaic[cell].map { "Cell \(cell + 1), \(TilePalette.name($0.colorIndex))" } ?? "Cell \(cell + 1), empty")
        .accessibilityHint(selected == nil ? "Erases the cell." : "Stamps the chosen motif. Tap again to turn it.")
        .accessibilityAddTraits(.isButton)
    }

    private func tap(_ cell: Int) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if let selected {
            mosaic.stamp(selected, at: cell)
        } else {
            mosaic.erase(at: cell)
        }
    }

    /// Dragging paints every cell the finger crosses with the chosen stamp,
    /// without turning cells that already show it.
    private var paintGesture: some Gesture {
        DragGesture(minimumDistance: 8, coordinateSpace: .named("mosaic"))
            .onChanged { value in
                guard context.isShowing, let cell = cell(at: value.location), !painted.contains(cell) else { return }
                if painted.isEmpty { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
                painted.insert(cell)
                mosaic.place(selected, at: cell)
            }
            .onEnded { _ in painted = [] }
    }

    // MARK: Palette strip

    private var strip: some View {
        HStack(alignment: .center, spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    swatch(nil)
                    ForEach(allStamps, id: \.self) { stamp in swatch(stamp) }
                    fatBitsButton
                }
                .padding(.horizontal, 4)
            }
            CanvasActionButton(title: "Fill", systemImage: "shuffle",
                               hint: "Lays a random quilt from the palette.") {
                withAnimation(.easeInOut(duration: 0.3)) { mosaic.fill(from: allStamps) }
            }
            CanvasActionButton(title: "Clear", systemImage: "trash",
                               hint: "Empties the canvas.", isEnabled: !mosaic.isEmpty) {
                withAnimation(.easeInOut(duration: 0.3)) { mosaic.clear() }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .frame(height: Self.stripHeight, alignment: .bottom)
    }

    private func swatch(_ stamp: MosaicStamp?) -> some View {
        let isSelected = stamp == selected
        return Button {
            UISelectionFeedbackGenerator().selectionChanged()
            selected = stamp
        } label: {
            Group {
                if let stamp {
                    MosaicStampView(stamp: stamp)
                } else {
                    Image(systemName: "eraser")
                        .font(.tact(.body).weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.tactCardBackground)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(isSelected ? palette.accent : Color.tactTileGray, lineWidth: isSelected ? 3 : 1))
            .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if let stamp, stamp.isFatBits {
                Button("Edit in FatBits", systemImage: "pencil") { editing = FatBitsTarget(stamp: stamp) }
                Button("Remove Stamp", systemImage: "trash", role: .destructive) { remove(stamp) }
            }
        }
        .accessibilityLabel(stamp.map {
            $0.isFatBits ? "\(TilePalette.name($0.colorIndex)) FatBits stamp"
                         : "\(TilePalette.name($0.colorIndex)) \(TilePattern(rawValue: $0.pattern)?.title ?? "")"
        } ?? "Eraser")
        .accessibilityHint(stamp?.isFatBits == true ? "Hold to edit or remove." : "")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Opens FatBits on a new stamp.
    private var fatBitsButton: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            editing = FatBitsTarget(stamp: nil)
        } label: {
            Image(systemName: "pencil.and.outline")
                .font(.tact(.body).weight(.semibold))
                .foregroundStyle(shelf.isFull ? Color.secondary : palette.accent)
                .frame(width: 40, height: 40)
                .background(Color.tactCardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(Color.tactTileGray, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(shelf.isFull)
        .accessibilityLabel("New FatBits stamp")
        .accessibilityHint(shelf.isFull ? "The palette is full. Remove a stamp to draw another."
                                        : "Opens FatBits to draw a stamp of your own.")
    }

    // MARK: Geometry

    private func center(of cell: Int) -> CGPoint {
        CGPoint(x: CGFloat(cell % Self.columns) * context.pitch + context.cellSize / 2,
                y: CGFloat(cell / Self.columns) * context.pitch + context.cellSize / 2)
    }

    private func cell(at point: CGPoint) -> Int? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let column = Int(point.x / context.pitch), row = Int(point.y / context.pitch)
        guard column < Self.columns, row < mosaic.rows else { return nil }
        return row * Self.columns + column
    }
}

/// What the FatBits sheet is opened on.
private struct FatBitsTarget: Identifiable {
    /// The stamp to edit, or nil for a new one.
    let stamp: MosaicStamp?
    var id: String { stamp.map { "\($0.hashValue)" } ?? "new" }
}
