import SwiftUI
import PhotosUI
import Contacts

struct PersonDetailView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    let personID: UUID

    @State private var showingAddNote = false
    @State private var showingDeleteAlert = false
    @State private var showingPhotoPicker = false
    @State private var showingLinkNotes = false
    @State private var showingContactPicker = false
    @State private var showingContactInfo = false
    @State private var showingEditSheet = false
    @State private var showingAccessDeniedAlert = false
    @State private var showingContactMissingAlert = false
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        if let person = store.person(id: personID) {
            content(for: person)
        } else {
            ContentUnavailableView("Person Removed", systemImage: "person.slash")
        }
    }

    private func content(for person: Person) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let image = person.fullPhoto {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onTapGesture { showingPhotoPicker = true }
                        .accessibilityLabel("Photo of \(person.name)")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityHint("Changes the photo")
                }
                contactSection(for: person)
                Divider()
                notesSection(for: person)
            }
            .padding()
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { showingEditSheet = true } label: {
                        Label("Edit Name", systemImage: "pencil")
                    }
                    Button { showingPhotoPicker = true } label: {
                        Label(person.photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }
                    if person.photoData != nil {
                        Button(role: .destructive) {
                            store.updatePhoto(forPersonID: personID, data: nil)
                        } label: {
                            Label("Remove Photo", systemImage: "xmark.circle")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { showingDeleteAlert = true } label: {
                        Label("Delete Person", systemImage: "trash")
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $pickedPhoto, matching: .images)
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .sheet(isPresented: $showingEditSheet) { EditPersonView(personID: personID) }
        .sheet(isPresented: $showingAddNote) { AddNoteView(personID: personID) }
        .sheet(isPresented: $showingLinkNotes) { LinkNotesView(personID: personID) }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView { contact in
                store.linkContact(toPersonID: personID, identifier: contact.identifier,
                                  snapshot: ContactSnapshot(contact: contact))
            }
        }
        .sheet(isPresented: $showingContactInfo) {
            if let snapshot = store.person(id: personID)?.contact {
                LinkedContactInfoView(contact: snapshot) {
                    store.unlinkContact(fromPersonID: personID)
                }
            }
        }
        .alert("Delete \(person.name)?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                store.deletePerson(id: personID)
                dismiss()
            }
        } message: {
            Text("Notes linked only to this person are deleted too. Notes shared with other people are kept.")
        }
        .alert("Contacts Access Needed", isPresented: $showingAccessDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Allow Tact to access Contacts in Settings to link this person to a contact.")
        }
        .alert("Contact Not Found", isPresented: $showingContactMissingAlert) {
            Button("Unlink", role: .destructive) { store.unlinkContact(fromPersonID: personID) }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This contact is no longer available in Contacts.")
        }
    }

    // MARK: Contact

    @ViewBuilder
    private func contactSection(for person: Person) -> some View {
        if person.hasLinkedContact {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text(person.contact?.name ?? "Linked Contact")
                    if let phone = person.contact?.phones.first {
                        Text(phone).font(.caption).foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { showContactInfo(for: person) } label: {
                    Image(systemName: "info.circle").font(.title3)
                }
                .accessibilityLabel("Contact Info")
                Button { store.unlinkContact(fromPersonID: personID) } label: {
                    Image(systemName: "xmark.circle.fill").font(.title3).foregroundStyle(.secondary)
                }
                .accessibilityLabel("Unlink Contact")
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)
        } else {
            Button(action: linkContactTapped) {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus").font(.title3)
                    Text("Link Contact")
                    Spacer()
                }
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: Notes

    @ViewBuilder
    private func notesSection(for person: Person) -> some View {
        let personNotes = store.notes(for: personID)
        HStack {
            Text("Notes").font(.headline)
            Spacer()
            Button { showingAddNote = true } label: {
                Image(systemName: "plus").font(.subheadline)
            }
            .accessibilityLabel("Add Note")
            Button { showingLinkNotes = true } label: {
                Image(systemName: "link").font(.subheadline)
            }
            .accessibilityLabel("Link Existing Note")
        }
        .buttonStyle(.plain)

        if personNotes.isEmpty {
            Text("No notes yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(personNotes) { note in
                    NavigationLink {
                        NoteDetailView(noteID: note.id)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text).foregroundStyle(.primary).lineLimit(2)
                                Text(note.date, style: .date).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            store.unlinkNote(id: note.id, fromPersonID: personID)
                        } label: {
                            Label("Unlink from \(person.name)", systemImage: "link.badge.xmark")
                        }
                    }
                    if note.id != personNotes.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: Actions

    private func importPhoto(_ item: PhotosPickerItem) async {
        defer { pickedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = await Task.detached(priority: .userInitiated, operation: { ImageProcessing.storableJPEG(from: data) }).value
        else { return }
        store.updatePhoto(forPersonID: personID, data: jpeg)
    }

    private func linkContactTapped() {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .notDetermined:
            CNContactStore().requestAccess(for: .contacts) { granted, _ in
                DispatchQueue.main.async {
                    if granted { showingContactPicker = true } else { showingAccessDeniedAlert = true }
                }
            }
        case .denied, .restricted:
            showingAccessDeniedAlert = true
        default:
            showingContactPicker = true
        }
    }

    /// Refreshes the cached details from Contacts when possible, then shows them.
    private func showContactInfo(for person: Person) {
        guard let identifier = person.contactIdentifier else { return }
        do {
            let contact = try CNContactStore().unifiedContact(withIdentifier: identifier,
                                                              keysToFetch: ContactSnapshot.fetchKeys)
            store.updateContact(forPersonID: personID, snapshot: ContactSnapshot(contact: contact))
            showingContactInfo = true
        } catch {
            if person.contact != nil {
                showingContactInfo = true
            } else {
                showingContactMissingAlert = true
            }
        }
    }
}
