import SwiftUI

struct NotesListView: View {
    @EnvironmentObject private var store: TactStore
    @AppStorage(NotesGrouping.storageKey) private var grouping: NotesGrouping = .recent
    @State private var showingAddNote = false

    /// "Notes" with a chevron: tapping picks the grouping.
    private var header: some View {
        Menu {
            Picker("Group", selection: $grouping) {
                ForEach(NotesGrouping.allCases) { option in
                    Label(option.title, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            TabHeader("Notes") {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notes, \(grouping.title)")
        .accessibilityHint("Changes how notes are grouped")
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                if grouping == .person { groupedList } else { notesList }
            }
            .background(Color.tactBackground)
            .navigationTitle("Notes")
            .appTitleBar()
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddNote = true } label: {
                        Label("New Note", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddNote) {
                NewNoteSheet()
            }
        }
    }

    private var rowInsets: EdgeInsets { EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16) }

    /// One section per person, in People order, then notes linked to no one.
    /// A note shared by several people appears under each of them.
    private var groupedList: some View {
        List {
            ForEach(store.people) { person in
                let notes = store.notes(for: person.id)
                if !notes.isEmpty {
                    Section {
                        ForEach(notes) { note in
                            NoteRow(note: note)
                                .listRowInsets(rowInsets)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            offsets.map { notes[$0].id }.forEach { store.deleteNote(id: $0) }
                        }
                    } header: {
                        HStack(spacing: 8) {
                            PersonAvatar(person: person, size: 24)
                            Text(person.name)
                            Spacer()
                            Text("\(notes.count)")
                        }
                        .textCase(nil)
                    }
                }
            }
            let unlinked = store.sortedNotes.filter { $0.personIds.isEmpty }
            if !unlinked.isEmpty {
                Section {
                    ForEach(unlinked) { note in
                        NoteRow(note: note)
                            .listRowInsets(rowInsets)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                    .onDelete { offsets in
                        offsets.map { unlinked[$0].id }.forEach { store.deleteNote(id: $0) }
                    }
                } header: {
                    HStack(spacing: 8) {
                        Image(systemName: "person.slash").frame(width: 24)
                        Text("Not Linked to Anyone")
                        Spacer()
                        Text("\(unlinked.count)")
                    }
                    .textCase(nil)
                }
            }
        }
        .listStyle(.plain)
        .background(Color.tactBackground)
        .scrollContentBackground(.hidden)
        .overlay {
            if store.notes.isEmpty {
                ContentUnavailableView {
                    Label("No Notes Yet", systemImage: "note.text")
                } description: {
                    Text("Tap + to write a note and link it to people.")
                }
            }
        }
    }

    private var notesList: some View {
            List {
                ForEach(store.sortedNotes) { note in
                    NoteRow(note: note)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
                .onDelete { offsets in
                    let sorted = store.sortedNotes
                    offsets.map { sorted[$0].id }.forEach { store.deleteNote(id: $0) }
                }
            }
            .listStyle(.plain)
            .background(Color.tactBackground)
            .scrollContentBackground(.hidden)
            .overlay {
                if store.notes.isEmpty {
                    ContentUnavailableView {
                        Label("No Notes Yet", systemImage: "note.text")
                    } description: {
                        Text("Tap + to write a note and link it to people.")
                    }
                }
            }
    }
}

struct NoteRow: View {
    @EnvironmentObject private var store: TactStore
    let note: Note

    private var personNames: String? {
        let names = store.names(forPersonIDs: note.personIds)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    var body: some View {
        NavigationLink {
            NoteDetailView(noteID: note.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                if let personNames {
                    Text(personNames).font(.caption).foregroundStyle(.secondary)
                }
                Text(note.text).foregroundStyle(.primary).lineLimit(6)
                Text(note.date, style: .date).font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.tactCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .contextMenu {
            ShareLink(item: note.text) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button(role: .destructive) { store.deleteNote(id: note.id) } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

/// Creates a note from the Notes tab, optionally linked to several people.
struct NewNoteSheet: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedPersonIds: Set<UUID> = []
    @FocusState private var textFocused: Bool

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !store.people.isEmpty {
                        Text("People").font(.headline)
                        PersonSelectionGrid(selectedPersonIds: $selectedPersonIds)
                    }
                    Text("Note").font(.headline)
                    TextField("What do you want to remember?", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                        .focused($textFocused)
                        .padding(10)
                        .background(Color.tactCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .padding()
            }
            .background(Color.tactSecondaryBackground)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addNote(text: trimmedText, personIds: Array(selectedPersonIds))
                        dismiss()
                    }
                    .disabled(trimmedText.isEmpty)
                }
            }
            .onAppear { textFocused = store.people.isEmpty }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Grid of person tiles that toggles membership in `selectedPersonIds`.
struct PersonSelectionGrid: View {
    @EnvironmentObject private var store: TactStore
    @Binding var selectedPersonIds: Set<UUID>
    var leading: (() -> AnyView)? = nil

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            if let leading { leading() }
            ForEach(store.people) { person in
                let isSelected = selectedPersonIds.contains(person.id)
                Button {
                    if isSelected { selectedPersonIds.remove(person.id) } else { selectedPersonIds.insert(person.id) }
                } label: {
                    PersonTile(person: person, style: .photo, size: 72)
                        .frame(maxWidth: .infinity)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(person.name)
                .accessibilityAddTraits(isSelected ? [.isSelected] : [])
            }
        }
    }
}
