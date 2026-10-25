import SwiftUI

/// The People list, which is also the Notes tab: one section per person,
/// headed by their name and note count, with their notes beneath, newest
/// first. A search keeps the people and notes that match. Edit shows one
/// row per person for reordering and deleting; notes can be swiped away.
struct PeopleListContent: View {
    let query: String
    @Binding var editMode: EditMode

    @EnvironmentObject private var store: TactStore
    @Environment(\.pushRoute) private var pushRoute
    @State private var addingNoteFor: Person?

    private var sections: [PersonSection] {
        PeopleSearch.sections(people: store.people, notes: store.notes, query: query)
    }

    var body: some View {
        List {
            if editMode.isEditing {
                peopleRows
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.notes) { note in
                            NoteOutlineRow(note: note, personID: section.person.id)
                        }
                        .onDelete { offsets in
                            offsets.map { section.notes[$0].id }.forEach { store.deleteNote(id: $0) }
                        }
                    } header: {
                        sectionHeader(section)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: editMode)
        .overlay {
            if store.people.isEmpty {
                ContentUnavailableView {
                    Label("No People Yet", systemImage: "person.2")
                } description: {
                    Text("Tap + to write a note, or switch to the grid to add someone.")
                }
            } else if sections.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .sheet(item: $addingNoteFor) { person in
            AddNoteView(personID: person.id)
        }
    }

    /// The person's name and note count; the line opens the person and the
    /// + starts a note about them. (A link in a section header would swallow
    /// the button's taps, so the push is done by hand.)
    private func sectionHeader(_ section: PersonSection) -> some View {
        Button {
            pushRoute(.person(section.person.id))
        } label: {
            HStack(spacing: 10) {
                PersonAvatar(person: section.person, size: 28)
                // Section headers dim their text; the name is a row, so it stays dark.
                Text(section.person.name)
                    .font(.tact(.headline))
                    .foregroundStyle(Color(uiColor: .label))
                Spacer()
                Text("\(section.notes.count)")
                    .font(.tact(.subheadline))
                    .foregroundStyle(Color(uiColor: .secondaryLabel))
                    .accessibilityLabel("\(section.notes.count) notes")
                Button { addingNoteFor = section.person } label: {
                    Image(systemName: "plus")
                        .font(.tact(.subheadline).weight(.semibold))
                        .foregroundStyle(Color(uiColor: .label))
                        .frame(width: 32, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add a note about \(section.person.name)")
                Image(systemName: "chevron.right")
                    .font(.tact(.caption).weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .textCase(nil)
        .accessibilityElement(children: .contain)
        .accessibilityHint("Opens \(section.person.name)")
    }

    /// Edit mode: everyone as one row, to drag into order or delete.
    private var peopleRows: some View {
        Section {
            ForEach(store.people) { person in
                PersonRow(person: person, noteCount: store.noteCount(for: person.id))
            }
            .onDelete(perform: delete)
            .onMove(perform: move)
        } header: {
            Text("People").textCase(nil)
        }
    }

    private func delete(_ offsets: IndexSet) {
        let ids = offsets.map { store.people[$0].id }
        ids.forEach { store.deletePerson(id: $0) }
    }

    private func move(_ source: IndexSet, _ destination: Int) {
        store.movePeople(fromOffsets: source, toOffset: destination)
    }
}

struct PersonRow: View {
    let person: Person
    let noteCount: Int

    var body: some View {
        HStack(spacing: 12) {
            PersonAvatar(person: person)
            VStack(alignment: .leading, spacing: 2) {
                Text(person.name)
                if let contactName = person.contact?.name, contactName != person.name {
                    Text(contactName).font(.tact(.caption)).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if noteCount > 0 {
                Text("\(noteCount)")
                    .font(.tact(.caption))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.tactTileGray)
                    .clipShape(Capsule())
                    .accessibilityLabel("\(noteCount) notes")
            }
        }
    }
}
