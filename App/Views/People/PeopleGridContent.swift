import SwiftUI

/// Four-column grid of people. Long-press enters "jiggle" mode, where tiles
/// can be dragged to reorder them.
struct PeopleGridContent: View {
    @EnvironmentObject private var store: TactStore
    let tileStyle: TileStyle
    @Binding var isJiggleMode: Bool
    let addPerson: () -> Void

    @State private var draggedID: UUID?
    @State private var dragAnchorIndex: Int?
    @State private var dragOffset: CGSize = .zero
    @State private var isDraggingActive = false

    private let columns = 4
    private let spacing: CGFloat = 1
    private let reorderAnimation = Animation.interpolatingSpring(stiffness: 200, damping: 22)

    var body: some View {
        GeometryReader { geometry in
            let squareSize = ((geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)).rounded(.down)
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(squareSize), spacing: spacing), count: columns),
                    spacing: spacing
                ) {
                    ForEach(store.people) { person in
                        PersonSquare(
                            person: person,
                            tileStyle: tileStyle,
                            squareSize: squareSize,
                            isJiggleMode: $isJiggleMode,
                            isDragging: draggedID == person.id,
                            dragOffset: dragOffset,
                            onDragChanged: { translation in
                                dragChanged(person: person, translation: translation, step: squareSize + spacing)
                            },
                            onDragEnded: finalizeReorder
                        )
                    }
                    Button(action: addPerson) {
                        Image(systemName: "plus")
                            .font(.largeTitle)
                            .foregroundStyle(.primary)
                            .frame(width: squareSize, height: squareSize)
                            .background(Color.tactTileGray)
                            .opacity(isDraggingActive ? 0.3 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDraggingActive)
                    .accessibilityLabel("Add Person")
                }
                .padding(.bottom, 20)
            }
            .scrollDisabled(isDraggingActive)
        }
        .background(Color.tactBackground)
        .onChange(of: isJiggleMode) { _, enabled in
            if !enabled { finalizeReorder() }
        }
    }

    // MARK: Reordering

    private func dragChanged(person: Person, translation: CGSize, step: CGFloat) {
        if draggedID == nil {
            dragAnchorIndex = store.people.firstIndex { $0.id == person.id }
            withAnimation(reorderAnimation) {
                draggedID = person.id
                isDraggingActive = true
            }
        }
        guard draggedID == person.id,
              let anchor = dragAnchorIndex,
              let currentIndex = store.people.firstIndex(where: { $0.id == person.id })
        else { return }

        // Which slot the tile is hovering over, measured from where the drag started.
        let columnOffset = Int((translation.width / step).rounded())
        let rowOffset = Int((translation.height / step).rounded())
        let targetColumn = min(columns - 1, max(0, anchor % columns + columnOffset))
        let targetRow = max(0, anchor / columns + rowOffset)
        let target = min(store.people.count - 1, targetRow * columns + targetColumn)

        // The tile is drawn at its new slot plus an offset, so the offset has to
        // subtract the distance the slot itself moved.
        let compensated = CGSize(
            width: translation.width - CGFloat(target % columns - anchor % columns) * step,
            height: translation.height - CGFloat(target / columns - anchor / columns) * step
        )
        if target != currentIndex {
            withAnimation(reorderAnimation) {
                store.movePeople(fromOffsets: IndexSet(integer: currentIndex),
                                 toOffset: target > currentIndex ? target + 1 : target)
                dragOffset = compensated
            }
        } else {
            dragOffset = compensated
        }
    }

    private func finalizeReorder() {
        guard draggedID != nil else { return }
        withAnimation(reorderAnimation) {
            dragOffset = .zero
            isDraggingActive = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            draggedID = nil
            dragAnchorIndex = nil
        }
    }
}

/// One tile in the grid, with the jiggle animation and drag gesture.
struct PersonSquare: View {
    let person: Person
    let tileStyle: TileStyle
    let squareSize: CGFloat
    @Binding var isJiggleMode: Bool
    let isDragging: Bool
    let dragOffset: CGSize
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void

    @State private var jiggleAngle: Double = 0

    var body: some View {
        Group {
            if isJiggleMode {
                PersonTile(person: person, style: tileStyle, size: squareSize)
            } else {
                NavigationLink {
                    PersonDetailView(personID: person.id)
                } label: {
                    PersonTile(person: person, style: tileStyle, size: squareSize)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: squareSize, height: squareSize)
        .offset(isDragging ? dragOffset : .zero)
        .rotationEffect(.degrees(isJiggleMode && !isDragging ? jiggleAngle : 0))
        .scaleEffect(isJiggleMode && !isDragging ? 0.92 : (isDragging ? 1.08 : 1))
        .opacity(isDragging ? 0.9 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.25 : 0), radius: isDragging ? 10 : 0, y: isDragging ? 4 : 0)
        .zIndex(isDragging ? 100 : 0)
        .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: isDragging)
        .animation(.easeInOut(duration: 0.12), value: isJiggleMode)
        .onAppear { if isJiggleMode { startJiggling() } }
        .onChange(of: isJiggleMode) { _, enabled in
            if enabled {
                startJiggling()
            } else {
                withAnimation(.easeInOut(duration: 0.12)) { jiggleAngle = 0 }
            }
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                guard !isJiggleMode else { return }
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                withAnimation { isJiggleMode = true }
            }
        )
        .gesture(
            DragGesture(minimumDistance: isJiggleMode ? 5 : 1000)
                .onChanged { value in
                    if isJiggleMode { onDragChanged(value.translation) }
                }
                .onEnded { _ in
                    if isJiggleMode && isDragging { onDragEnded() }
                }
        )
        .accessibilityHint(isJiggleMode ? "Drag to reorder" : "Double-tap to open. Touch and hold to reorder.")
    }

    private func startJiggling() {
        let delay = Double.random(in: 0...0.2)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            guard isJiggleMode else { return }
            withAnimation(.easeInOut(duration: 0.1).repeatForever(autoreverses: true)) {
                jiggleAngle = 2.5
            }
        }
    }
}
