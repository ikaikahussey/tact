import SwiftUI

/// The People list, which is also the Notes tab. Grouped by person it is
/// one section per person, headed by their name and note count, with their
/// notes beneath, newest first; grouped by recent it is the notes alone,
/// newest first, under Today, Yesterday and so on, each row naming who it
/// is about. A control at the top picks the grouping, and it is remembered.
/// A search keeps the people and notes that match. Edit shows one row per
/// person for reordering and deleting; notes can be swiped away.
struct PeopleListContent: View {
    let query: String
    @Binding var editMode: EditMode
    /// Listen mode: tapping a person's row plays their ditty instead of
    /// opening them.
    var isListening = false

    @EnvironmentObject private var store: TactStore
    @Environment(\.pushRoute) private var pushRoute
    @AppStorage(ListGrouping.storageKey) private var grouping: ListGrouping = .person
    @State private var addingNoteFor: Person?
    @State private var showingNewNote = false

    private var sections: [PersonSection] {
        PeopleSearch.sections(people: store.people, notes: store.notes, query: query)
    }

    private var recentSections: [RecentSection] {
        PeopleSearch.recentSections(people: store.people, notes: store.notes, query: query)
    }

    private var isEmpty: Bool {
        grouping == .recent ? recentSections.isEmpty : sections.isEmpty
    }

    var body: some View {
        List {
            if editMode.isEditing {
                peopleRows
            } else {
                groupingControl
                switch grouping {
                case .person:
                    ForEach(sections) { section in
                        Section {
                            noteRows(section.notes, personID: section.person.id)
                        } header: {
                            sectionHeader(section)
                        }
                    }
                case .recent:
                    ForEach(recentSections) { section in
                        Section {
                            noteRows(section.notes, personID: nil)
                        } header: {
                            Text(section.bucket.title)
                                .font(.tact(.subheadline).weight(.semibold))
                                .textCase(nil)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.snappy, value: editMode)
        .animation(.snappy, value: grouping)
        .overlay {
            if isEmpty && !editMode.isEditing {
                if query.isEmpty {
                    newNoteCursor
                } else {
                    ContentUnavailableView.search(text: query)
                }
            }
        }
        .sheet(item: $addingNoteFor) { person in
            AddNoteView(personID: person.id)
        }
        .sheet(isPresented: $showingNewNote) { NewNoteSheet() }
    }

    /// No notes yet: a + blinks like a cursor, and a tap starts the first note.
    private var newNoteCursor: some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showingNewNote = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 64, weight: .black))
                .foregroundStyle(.tint)
                .cursorBlink()
                .frame(width: 120, height: 120)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Write Your First Note")
    }

    /// By Person or Recent, as a segmented control in the list's first row.
    private var groupingControl: some View {
        Section {
            Picker("Group By", selection: $grouping) {
                ForEach(ListGrouping.allCases) { grouping in
                    Text(grouping.title).tag(grouping)
                }
            }
            .pickerStyle(.segmented)
            .font(.tact(.subheadline))
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
            .accessibilityLabel("Group by")
        }
    }

    /// The notes of a section, each swipeable away.
    private func noteRows(_ notes: [Note], personID: UUID?) -> some View {
        ForEach(notes) { note in
            NoteOutlineRow(note: note, personID: personID)
        }
        .onDelete { offsets in
            offsets.map { notes[$0].id }.forEach { store.deleteNote(id: $0) }
        }
    }

    /// The person's name and note count; the line opens the person and the
    /// + starts a note about them. (A link in a section header would swallow
    /// the button's taps, so the push is done by hand.)
    private func sectionHeader(_ section: PersonSection) -> some View {
        Button {
            if isListening {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                DittyPlayer.play(section.person)
            } else {
                pushRoute(.person(section.person.id))
            }
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
        .accessibilityAction(named: "Play ditty") { DittyPlayer.play(section.person) }
        .textCase(nil)
        .accessibilityElement(children: .contain)
        .accessibilityHint(isListening ? "Plays \(section.person.name)'s ditty" : "Opens \(section.person.name)")
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
