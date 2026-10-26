import SwiftUI
import PhotosUI
import Contacts

struct PersonDetailView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let personID: UUID

    @State private var showingAddNote = false
    @State private var showingDeleteAlert = false
    @State private var showingPhotoPicker = false
    @State private var showingLinkNotes = false
    @State private var showingContactPicker = false
    @State private var showingContactInfo = false
    @State private var showingEditSheet = false
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
                if person.showsPhoto, let image = person.fullPhoto {
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
                } else {
                    ZStack {
                        TileShades(colorIndex: person.tile.colorIndex).pale
                        TileArtView(art: person.tile, pattern: person.tilePattern, side: 150)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                    .onTapGesture { showingPhotoPicker = true }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Tile for \(person.name)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Adds a photo")
                }
                tileChooser(for: person)
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
        .alert("Contact Not Found", isPresented: $showingContactMissingAlert) {
            Button("Unlink", role: .destructive) { store.unlinkContact(fromPersonID: personID) }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("This contact is no longer available in Contacts.")
        }
    }

    // MARK: Tile

    /// A row of choices for what the person's tile shows: their photo or one
    /// of the patterns, in their colour.
    private func tileChooser(for person: Person) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tile").font(.tact(.headline))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    tileChoice(isSelected: person.showsPhoto) {
                        if person.photoData == nil {
                            showingPhotoPicker = true
                        } else {
                            store.updateTile(forPersonID: personID) { $0.showsPhoto = true }
                        }
                    } label: {
                        if let image = person.thumbnail(maxPixelSize: 256) {
                            Image(uiImage: image).resizable().scaledToFill()
                        } else {
                            ZStack {
                                Color.tactTileGray.opacity(0.5)
                                Image(systemName: "photo.badge.plus")
                                    .font(.tact(.title3))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityLabel(person.photoData == nil ? "Add Photo" : "Photo")

                    ForEach(TilePattern.allCases, id: \.self) { pattern in
                        tileChoice(isSelected: !person.showsPhoto && person.tilePattern == pattern) {
                            store.updateTile(forPersonID: personID) {
                                $0.pattern = pattern.rawValue
                                $0.showsPhoto = false
                            }
                        } label: {
                            TilePatternView(pattern: pattern, colorIndex: person.tile.colorIndex)
                                .rotationEffect(.degrees(Double(person.tile.quarterTurns) * 90))
                        }
                        .accessibilityLabel(pattern.title)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(.top, 4)
    }

    private func tileChoice(isSelected: Bool, action: @escaping () -> Void,
                            @ViewBuilder label: () -> some View) -> some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            action()
        } label: {
            label()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(3)
                .overlay {
                    RoundedRectangle(cornerRadius: 11)
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: Contact

    @ViewBuilder
    private func contactSection(for person: Person) -> some View {
        if person.hasLinkedContact {
            // At accessibility text sizes the buttons move under the name so
            // it is not squeezed into a column.
            let stacked = dynamicTypeSize.isAccessibilitySize
            let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                 : AnyLayout(HStackLayout(spacing: 12))
            layout {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.tact(.title3))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(person.contact?.name ?? "Linked Contact")
                        if let phone = person.contact?.phones.first {
                            Text(phone).font(.tact(.caption)).foregroundStyle(.secondary)
                        }
                    }
                    .layoutPriority(1)
                }
                if !stacked { Spacer() }
                HStack(spacing: 16) {
                    Button { showContactInfo(for: person) } label: {
                        Image(systemName: "info.circle").font(.tact(.title3))
                    }
                    .accessibilityLabel("Contact Info")
                    Button { store.unlinkContact(fromPersonID: personID) } label: {
                        Image(systemName: "xmark.circle.fill").font(.tact(.title3)).foregroundStyle(.secondary)
                    }
                    .accessibilityLabel("Unlink Contact")
                }
            }
            .buttonStyle(.plain)
            .padding(.vertical, 12)
        } else {
            Button { showingContactPicker = true } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.badge.plus").font(.tact(.title3))
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
            Text("Notes").font(.tact(.headline))
            Spacer()
            Button { showingAddNote = true } label: {
                Image(systemName: "plus").font(.tact(.subheadline))
            }
            .accessibilityLabel("Add Note")
            Button { showingLinkNotes = true } label: {
                Image(systemName: "link").font(.tact(.subheadline))
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
                    NavigationLink(value: Route.note(note.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text).foregroundStyle(.primary).lineLimit(2)
                                Text(note.date, style: .date).font(.tact(.caption)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.tact(.caption)).foregroundStyle(.secondary)
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
        store.updateTile(forPersonID: personID) { $0.showsPhoto = true }
    }

    /// Shows the saved contact details, refreshing them from Contacts first
    /// when the app is allowed to read the store. The picker itself needs no
    /// permission, so a person can be linked without ever granting access;
    /// their details are then the snapshot taken when they were picked.
    private func showContactInfo(for person: Person) {
        guard let identifier = person.contactIdentifier else { return }
        if Self.canReadContacts,
           let contact = try? CNContactStore().unifiedContact(withIdentifier: identifier,
                                                              keysToFetch: ContactSnapshot.fetchKeys) {
            store.updateContact(forPersonID: personID, snapshot: ContactSnapshot(contact: contact))
        }
        if store.person(id: personID)?.contact != nil {
            showingContactInfo = true
        } else {
            showingContactMissingAlert = true
        }
    }

    /// Whether Contacts can be read directly (full or limited access).
    private static var canReadContacts: Bool {
        switch CNContactStore.authorizationStatus(for: .contacts) {
        case .authorized: return true
        default:
            if #available(iOS 18, *), CNContactStore.authorizationStatus(for: .contacts) == .limited { return true }
            return false
        }
    }
}
