import SwiftUI

/// Edits a note in place. Changes are saved as they are made.
struct NoteDetailView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    let noteID: UUID

    @State private var text = ""
    @State private var selectedPersonIds: Set<UUID> = []
    @State private var hasLoaded = false
    @State private var showingDeleteAlert = false
    @State private var showingAddPerson = false
    @State private var newPersonName = ""

    var body: some View {
        if let note = store.note(id: noteID) {
            content(for: note)
        } else {
            ContentUnavailableView("Note Deleted", systemImage: "note.text")
        }
    }

    private func content(for note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("People")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)

                PersonSelectionGrid(selectedPersonIds: $selectedPersonIds) {
                    AnyView(addPersonTile)
                }

                Text("Note")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)

                TextEditor(text: $text)
                    .frame(minHeight: 200)
                    .padding(8)
                    .background(Color.tactCardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Created \(note.date, style: .date)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding()
        }
        .background(Color.tactBackground)
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) { showingDeleteAlert = true } label: {
                    Label("Delete Note", systemImage: "trash")
                }
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            text = note.text
            selectedPersonIds = Set(note.personIds)
            hasLoaded = true
        }
        .onChange(of: text) { _, _ in save() }
        .onChange(of: selectedPersonIds) { _, _ in save() }
        .onDisappear(perform: save)
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deleteNote(id: noteID)
                dismiss()
            }
        } message: {
            Text("This note will be removed from everyone it is linked to.")
        }
        .alert("Add Person", isPresented: $showingAddPerson) {
            TextField("Name", text: $newPersonName)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { newPersonName = "" }
            Button("Add") {
                if let person = store.addPerson(named: newPersonName) {
                    selectedPersonIds.insert(person.id)
                }
                newPersonName = ""
            }
        }
    }

    private var addPersonTile: some View {
        Button { showingAddPerson = true } label: {
            ZStack {
                Color.tactTileGray
                Image(systemName: "plus").font(.title2).foregroundStyle(.primary)
            }
            .frame(height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add Person")
    }

    private func save() {
        guard hasLoaded else { return }
        store.updateNote(id: noteID, text: text, personIds: selectedPersonIds)
    }
}
