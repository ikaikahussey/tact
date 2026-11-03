import SwiftUI

/// The people linked to a note, compactly: only the linked people show, as
/// chips (tap one to unlink it), followed by a "+" chip that opens a
/// searchable picker. Long-press a chip to open that person.
struct PersonChipRow: View {
    @EnvironmentObject private var store: TactStore
    @Binding var selectedPersonIds: Set<UUID>
    var onOpen: ((UUID) -> Void)? = nil
    @State private var showingPicker = false
    @State private var pendingOpen: UUID?

    private var selectedPeople: [Person] {
        store.people.filter { selectedPersonIds.contains($0.id) }
    }

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(selectedPeople) { person in
                Button {
                    selectedPersonIds.remove(person.id)
                } label: {
                    PersonChip(person: person, isSelected: true, removable: true)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(person.name)
                .accessibilityAddTraits(.isSelected)
                .accessibilityHint("Unlinks this person")
                .contextMenu {
                    if let onOpen {
                        Button { onOpen(person.id) } label: {
                            Label("Open \(person.name)", systemImage: "person.crop.circle")
                        }
                    }
                }
            }
            Button { showingPicker = true } label: {
                Label(selectedPeople.isEmpty ? "Link Person" : "Person", systemImage: "plus")
                    .font(.tact(.subheadline))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .overlay(Capsule().strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3])).foregroundStyle(.secondary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Link Person")
        }
        .sheet(isPresented: $showingPicker, onDismiss: {
            if let id = pendingOpen { pendingOpen = nil; onOpen?(id) }
        }) {
            PersonPickerSheet(selectedPersonIds: $selectedPersonIds, onOpen: openFromPicker)
        }
    }

    /// Opening someone from the picker closes it first, then navigates.
    private var openFromPicker: ((UUID) -> Void)? {
        guard onOpen != nil else { return nil }
        return { id in
            pendingOpen = id
            showingPicker = false
        }
    }
}

/// Searchable list for linking people to a note. People written about most
/// recently come first; typing a name nobody has offers to add them.
struct PersonPickerSheet: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedPersonIds: Set<UUID>
    var onOpen: ((UUID) -> Void)? = nil
    @State private var query = ""
    @State private var searchFocused = true

    var body: some View {
        let people = PersonPickerOrder.people(store.people, notes: store.notes, query: query)
        let newName = PersonPickerOrder.newName(for: query, among: store.people)
        NavigationStack {
            List {
                if let newName {
                    Button {
                        if let person = store.addPerson(named: newName) {
                            selectedPersonIds.insert(person.id)
                        }
                        query = ""
                    } label: {
                        Label("Add \u{201C}\(newName)\u{201D}", systemImage: "plus.circle")
                    }
                }
                ForEach(people) { person in
                    let isSelected = selectedPersonIds.contains(person.id)
                    Button {
                        if isSelected { selectedPersonIds.remove(person.id) } else { selectedPersonIds.insert(person.id) }
                    } label: {
                        HStack(spacing: 10) {
                            PersonAvatar(person: person, size: 28)
                            Text(person.name)
                                .font(.tact(.body))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.tact(.body).weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityLabel(person.name)
                    .accessibilityAddTraits(isSelected ? [.isSelected] : [])
                    .accessibilityHint(isSelected ? "Unlinks this person" : "Links this person")
                    .contextMenu {
                        if let onOpen {
                            Button { onOpen(person.id) } label: {
                                Label("Open \(person.name)", systemImage: "person.crop.circle")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, isPresented: $searchFocused,
                        placement: .navigationBarDrawer(displayMode: .always), prompt: "Name")
            .textInputAutocapitalization(.words)
            .onSubmit(of: .search) {
                if let newName, people.isEmpty {
                    if let person = store.addPerson(named: newName) { selectedPersonIds.insert(person.id) }
                    query = ""
                } else if let first = people.first, !query.isEmpty {
                    selectedPersonIds.insert(first.id)
                    query = ""
                }
            }
            .navigationTitle("People")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

struct PersonChip: View {
    let person: Person
    let isSelected: Bool
    var removable = false
    @Environment(\.appPalette) private var palette

    var body: some View {
        HStack(spacing: 6) {
            PersonAvatar(person: person, size: 22)
            Text(person.name)
                .font(.tact(.subheadline))
                .lineLimit(1)
            if removable {
                Image(systemName: "xmark")
                    .font(.tact(.caption2).weight(.bold))
                    .opacity(0.8)
            } else if isSelected {
                Image(systemName: "checkmark")
                    .font(.tact(.caption).weight(.bold))
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .foregroundStyle(isSelected ? palette.onAccent : .primary)
        .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tactCardBackground), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.primary.opacity(isSelected ? 0 : 0.12)))
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

/// Lays out subviews left to right, wrapping to a new row when the width runs out.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(width: proposal.width ?? .infinity, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let origins = arrange(width: bounds.width, subviews: subviews).origins
        for (subview, origin) in zip(subviews, origins) {
            subview.place(at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y), proposal: .unspecified)
        }
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            widest = max(widest, x - spacing)
        }
        return (CGSize(width: widest, height: y + rowHeight), origins)
    }
}
