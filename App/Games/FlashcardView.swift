import SwiftUI

/// Full-screen study mode: swipe between people, tap to reveal the name.
struct FlashcardView: View {
    @EnvironmentObject private var store: TactStore
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0

    private var people: [Person] { store.people }
    private var safeIndex: Int { min(currentIndex, max(0, people.count - 1)) }
    private var currentPerson: Person? { people.isEmpty ? nil : people[safeIndex] }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let person = currentPerson {
                    Spacer()
                    card(for: person, size: geometry.size.width - 40)
                        .offset(x: dragOffset)
                        .animation(.easeInOut(duration: 0.3), value: isFlipped)
                        .onTapGesture { isFlipped.toggle() }
                        .gesture(
                            DragGesture()
                                .onChanged { dragOffset = $0.translation.width }
                                .onEnded { handleSwipe(translation: $0.translation.width) }
                        )
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(isFlipped ? person.name : "Flashcard")
                        .accessibilityHint("Double-tap to flip")
                    Spacer()
                    controls
                } else {
                    ContentUnavailableView {
                        Label("No People Yet", systemImage: "rectangle.stack")
                    } description: {
                        Text("Add people to study them as flashcards.")
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.tactBackground)
        .onChange(of: people.count) { _, _ in
            currentIndex = safeIndex
            isFlipped = false
        }
    }

    @ViewBuilder
    private func card(for person: Person, size: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        if !isFlipped {
            if let image = person.fullPhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(shape)
                    .shadow(radius: 10)
            } else {
                shape
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: size, height: size)
                    .shadow(radius: 10)
                    .overlay(
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.white.opacity(0.8))
                    )
            }
        } else {
            shape
                .fill(Color.tactCardBackground)
                .frame(width: size, height: size)
                .shadow(radius: 10)
                .overlay(
                    VStack(spacing: 16) {
                        Text(person.name)
                            .font(.tactBold(size: 32))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        let count = store.noteCount(for: person.id)
                        if count > 0 {
                            Text("\(count) \(count == 1 ? "note" : "notes")")
                                .font(.tact(.subheadline))
                                .foregroundStyle(.secondary)
                        }
                    }
                )
        }
    }

    private var controls: some View {
        VStack(spacing: 20) {
            Text(isFlipped ? " " : "Tap to reveal")
                .font(.tact(.subheadline))
                .foregroundStyle(.secondary)
            HStack(spacing: 40) {
                Button { step(-1) } label: {
                    Image(systemName: "chevron.left.circle").font(.system(size: 50))
                }
                .disabled(safeIndex == 0)
                .accessibilityLabel("Previous")

                Text("\(safeIndex + 1) / \(people.count)")
                    .font(.tact(.headline))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80)

                Button { step(1) } label: {
                    Image(systemName: "chevron.right.circle").font(.system(size: 50))
                }
                .disabled(safeIndex >= people.count - 1)
                .accessibilityLabel("Next")
            }
            .foregroundStyle(.primary)
            .padding(.bottom, 40)
        }
    }

    private func step(_ delta: Int) {
        let target = safeIndex + delta
        guard people.indices.contains(target) else { return }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            currentIndex = target
            isFlipped = false
        }
    }

    private func handleSwipe(translation: CGFloat) {
        let threshold: CGFloat = 100
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if translation < -threshold {
                step(1)
            } else if translation > threshold {
                step(-1)
            }
            dragOffset = 0
        }
    }
}
