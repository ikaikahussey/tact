import SwiftUI

/// Creates a note from the list, optionally linked to several people; the
/// + chip adds someone new.
struct NewNoteSheet: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var selectedPersonIds: Set<UUID> = []
    @State private var showingAddPerson = false
    @State private var newPersonName = ""
    @FocusState private var textFocused: Bool

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    TextField("What do you want to remember?", text: $text, axis: .vertical)
                        .lineLimit(5...12)
                        .focused($textFocused)
                        .padding(12)
                        .background(Color.tactCardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 10) {
                        Text("People")
                            .font(.tact(.caption)).foregroundStyle(.secondary).textCase(.uppercase)
                        PersonChipRow(selectedPersonIds: $selectedPersonIds, onAdd: { showingAddPerson = true })
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.tactBackground)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    TagSuggestionStrip(text: $text)
                    Spacer()
                }
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
            .onAppear { textFocused = true }
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
        .presentationDetents([.medium, .large])
    }
}
