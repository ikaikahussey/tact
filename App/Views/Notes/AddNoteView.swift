import SwiftUI

/// Creates a note already linked to one person.
struct AddNoteView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    @State private var text = ""
    @FocusState private var isFocused: Bool

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            TextEditor(text: $text)
                .focused($isFocused)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Color.tactCardBackground)
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
                        Button("Save") {
                            store.addNote(text: trimmedText, personIds: [personID])
                            dismiss()
                        }
                        .disabled(trimmedText.isEmpty)
                    }
                }
                .onAppear { isFocused = true }
        }
    }
}
