import SwiftUI

/// Edits a person's name and their tags. Tags are typed as in a note,
/// `#birthday #work`, with the same completions above the keyboard, and
/// kept on the person; a tag search then finds them by these.
struct EditPersonView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID
    /// Which field opens focused.
    var focus: Field = .name
    @State private var name = ""
    @State private var tagText = ""
    @FocusState private var focused: Field?

    enum Field { case name, tags }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    /// The tags typed, a `#` put on any word that lacks one. The field is
    /// left as typed: rewriting it while typing loses keystrokes.
    private var tags: [String] { NoteTags.tags(in: NoteTags.hashingWords(tagText)) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Name") {
                    TextField("Name", text: $name)
                        .textInputAutocapitalization(.words)
                        .focused($focused, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focused = .tags }
                }
                Section {
                    TextField("#birthday #work", text: $tagText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focused, equals: .tags)
                        .submitLabel(.done)
                        .onSubmit(save)
                    if !tags.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(tags, id: \.self) { TagChip(tag: $0) }
                        }
                        .accessibilityLabel("Tags: \(tags.joined(separator: ", "))")
                    }
                } header: {
                    Text("Tags")
                } footer: {
                    Text("Type tags as words; each gets a #, as in a note. Searching for a tag finds this person by them.")
                }
            }
            .navigationTitle("Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if focused == .tags {
                        TagSuggestionStrip(text: $tagText)
                        Spacer()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(trimmedName.isEmpty)
                }
            }
            .onAppear {
                let person = store.person(id: personID)
                name = person?.name ?? ""
                tagText = (person?.tags ?? []).map { "#" + $0 }.joined(separator: " ")
                if !tagText.isEmpty { tagText += " " }
                focused = focus
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else { return }
        store.renamePerson(id: personID, to: trimmedName)
        store.updateTags(forPersonID: personID, tags)
        dismiss()
    }
}

extension EditPersonView.Field: Identifiable {
    var id: Self { self }
}
