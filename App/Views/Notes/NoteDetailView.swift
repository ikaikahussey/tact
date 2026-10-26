import SwiftUI

/// Edits a note in place. Changes are saved as they are made.
struct NoteDetailView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.pushRoute) private var pushRoute
    let noteID: UUID

    @State private var text = ""
    @State private var selectedPersonIds: Set<UUID> = []
    @State private var hasLoaded = false
    @State private var showingDeleteAlert = false
    @State private var showingAddPerson = false
    @State private var showingDatePicker = false
    @State private var draftDate = Date()
    @State private var newPersonName = ""
    @FocusState private var editorFocused: Bool

    var body: some View {
        if let note = store.note(id: noteID) {
            content(for: note)
        } else {
            ContentUnavailableView("Note Deleted", systemImage: "note.text")
        }
    }

    private func content(for note: Note) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                editor
                let tags = NoteTags.tags(in: text)
                if !tags.isEmpty {
                    TagChips(tags: tags)
                        .padding(.top, -8)
                }
                metadata(for: note)
                section("People") {
                    PersonChipRow(selectedPersonIds: $selectedPersonIds,
                                  onAdd: { showingAddPerson = true },
                                  onOpen: { pushRoute(.person($0)) })
                }
                Button(role: .destructive) { showingDeleteAlert = true } label: {
                    Label("Delete Note", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.top, 12)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.tactBackground)
        .navigationTitle(store.title(for: note))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: text) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            ToolbarItemGroup(placement: .keyboard) {
                TagSuggestionStrip(text: $text)
                Spacer()
                Button("Done") { editorFocused = false }
                    .fontWeight(.semibold)
            }
        }
        .onAppear {
            guard !hasLoaded else { return }
            text = note.text
            selectedPersonIds = Set(note.personIds)
            hasLoaded = true
            if note.text.isEmpty { editorFocused = true }
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
        .sheet(isPresented: $showingDatePicker) {
            datePickerSheet
        }
    }

    // MARK: Pieces

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("What do you want to remember?")
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 13)
                    .padding(.vertical, 16)
                    .accessibilityHidden(true)
            }
            TextEditor(text: $text)
                .focused($editorFocused)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
                .padding(8)
                .frame(minHeight: 180)
        }
        .background(Color.tactCardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { editorFocused = true }
    }

    private func metadata(for note: Note) -> some View {
        HStack(spacing: 12) {
            Button {
                draftDate = note.date
                showingDatePicker = true
            } label: {
                Label(note.date.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.tact(.subheadline))
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Date, \(note.date.formatted(date: .long, time: .omitted))")
            .accessibilityHint("Changes when this happened")

            if note.wasEdited {
                Text("Edited \(note.modifiedDate, style: .relative) ago")
                    .font(.tact(.footnote))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.tact(.caption)).foregroundStyle(.secondary).textCase(.uppercase)
            content()
        }
    }

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker("When it happened", selection: $draftDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()
                Spacer()
            }
            .navigationTitle("Date")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingDatePicker = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        store.setNoteDate(id: noteID, to: draftDate)
                        showingDatePicker = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        guard hasLoaded else { return }
        store.updateNote(id: noteID, text: text, personIds: selectedPersonIds)
    }
}
