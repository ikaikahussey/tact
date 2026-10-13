import SwiftUI

struct NotesListView: View {
    @EnvironmentObject private var store: TactStore
    @State private var showingAddNote = false

    var body: some View {
        NavigationStack {
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
            .navigationTitle("Notes")
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
