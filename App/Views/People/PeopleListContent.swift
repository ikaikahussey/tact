import SwiftUI

/// The People list. The outline button by the People header
/// (`OutlineToggle`) slides each person's notes in beneath them, newest
/// first, with a chevron to hide one person's notes. Outside outline mode
/// people can be reordered and deleted.
struct PeopleListContent: View {
    static let showsNotesKey = "peopleListShowsNotes"

    @EnvironmentObject private var store: TactStore
    @AppStorage(showsNotesKey) private var showsNotes = false
    @State private var collapsed: Set<UUID> = []
    @State private var addingNoteFor: Person?

    var body: some View {
        List {
            ForEach(store.people) { person in
                let isExpanded = !collapsed.contains(person.id)
                PersonOutlineRow(person: person, noteCount: store.noteCount(for: person.id),
                                 showsChevron: showsNotes, isExpanded: isExpanded,
                                 toggle: { withAnimation(.snappy) { toggle(person.id) } },
                                 addNote: { addingNoteFor = person })
                if showsNotes && isExpanded {
                    ForEach(store.notes(for: person.id)) { note in
                        NoteOutlineRow(note: note, personID: person.id)
                    }
                }
            }
            // Each person is one row only outside outline mode.
            .onDelete(perform: showsNotes ? nil : delete)
            .onMove(perform: showsNotes ? nil : move)
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: showsNotes)
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "person.2")
                } description: {
                    Text("Tap + to add someone, then keep notes about them.")
                }
            }
        }
        .toolbar {
            if !store.people.isEmpty && !showsNotes {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .sheet(item: $addingNoteFor) { person in
            AddNoteView(personID: person.id)
        }
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { store.people[$0].id }
        ids.forEach { store.deletePerson(id: $0) }
    }

    private func move(_ source: IndexSet, _ destination: Int) {
        store.movePeople(fromOffsets: source, toOffset: destination)
    }

    private func toggle(_ id: UUID) {
        if collapsed.contains(id) { collapsed.remove(id) } else { collapsed.insert(id) }
    }
}

/// A small round button that opens or closes the People list's outline of
/// notes. Lives on the People header line so the toolbar stays uncluttered.
struct OutlineToggle: View {
    @AppStorage(PeopleListContent.showsNotesKey) private var showsNotes = false

    var body: some View {
        Button {
            withAnimation(.snappy) { showsNotes.toggle() }
        } label: {
            Image(systemName: "list.bullet.indent")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(showsNotes ? Color.white : Color.secondary)
                .frame(width: 32, height: 32)
                .background(showsNotes ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.tactTileGray), in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(showsNotes ? "Hide Notes" : "Show Notes")
        .accessibilityHint("Shows or hides each person's notes beneath them")
    }
}

struct PersonRow: View {
    let person: Person
    let noteCount: Int
    /// When set, a + button on the row starts a note about the person.
    var addNote: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(person: person)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                if let contactName = person.contact?.name, contactName != person.name {
                    Text(contactName).font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.tactTileGray)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(noteCount) notes")
            }
            if let addNote {
                Button(action: addNote) {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add a note about \(person.name)")
            }
        }
    }
}
