import SwiftUI
import PhotosUI
import Contacts

struct PersonDetailView: View {
    @EnvironmentObject private var store: TactStore
    @Environment(\.appPalette) private var palette
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let personID: UUID

    @State private var showingAddNote = false
    @State private var showingDeleteAlert = false
    @State private var showingPhotoPicker = false
    @State private var showingFatBits = false
    @State private var showingLinkNotes = false
    @State private var showingContactPicker = false
    @State private var showingContactInfo = false
    /// The edit sheet, opened on the name or on the tags.
    @State private var editing: EditPersonView.Field?
    @State private var showingDittyRecorder = false
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
            VStack(alignment: .leading, spacing: 14) {
                nameHeading(for: person)
                header(for: person)
                dittyRow(for: person)
                tagsRow(for: person)
                contactSection(for: person)
                Divider()
                notesSection(for: person)
            }
            .padding()
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { editing = .name } label: {
                        Label("Edit Name", systemImage: "pencil")
                    }
                    Button { editing = .tags } label: {
                        Label("Edit Tags", systemImage: "number")
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
        .sheet(item: $editing) { field in EditPersonView(personID: personID, focus: field) }
        .sheet(isPresented: $showingDittyRecorder) { DittyRecorderView(person: person) }
        .onAppear {
            if DittyPlayer.playsOnOpen { DittyPlayer.play(person) }
        }
        .onDisappear { DittyPlayer.stop() }
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

    // MARK: Name

    /// The name, large, at the top of the page. Touch and hold it to edit
    /// it; the bar's title stays small so the name is not shown twice.
    private func nameHeading(for person: Person) -> some View {
        Text(person.name)
            .font(.tact(.largeTitle).weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 0.4) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                editing = .name
            }
            .accessibilityAddTraits(.isHeader)
            .accessibilityHint("Touch and hold to edit the name.")
            .accessibilityAction(named: "Edit name") { editing = .name }
    }

    // MARK: Header

    /// The tile at the left, the controls at the right: Tile and Color are
    /// menus, then Rotate and the FatBits pencil. The same choices are on
    /// the tile's long-press menu; a tap on the tile picks a photo.
    private func header(for person: Person) -> some View {
        HStack(alignment: .top, spacing: 14) {
            hero(for: person)
                .frame(width: 132, height: 132)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
                .onTapGesture { showingPhotoPicker = true }
                .contextMenu { tileMenuItems(for: person) }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(person.showsPhoto ? "Photo of \(person.name)" : "Tile for \(person.name)")
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Changes the photo. Touch and hold for the tile, color, turning, and FatBits.")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Menu {
                        tilePicker(for: person)
                    } label: {
                        control("Tile", systemImage: "square.on.square")
                    }
                    .accessibilityLabel("Tile")
                    .accessibilityHint("Photo, FatBits, or a pattern")
                    Menu {
                        colorPicker(for: person)
                    } label: {
                        control("Color", systemImage: "paintpalette", tint: TilePalette.color(person.tile.colorIndex))
                    }
                    .accessibilityLabel("Color, \(TilePalette.name(person.tile.colorIndex))")
                }
                HStack(spacing: 8) {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        store.updateTile(forPersonID: personID) { $0.rotate() }
                    } label: {
                        control("Rotate", systemImage: "rotate.right")
                    }
                    .accessibilityHint("Turns the tile a quarter turn clockwise.")
                    FatBitsPencilSwatch(size: 36, cornerRadius: 8,
                                        label: person.tile.isFatBits ? "Edit in FatBits" : "Draw in FatBits",
                                        hint: "Opens FatBits to draw \(person.name)'s tile bit by bit.") {
                        showingFatBits = true
                    }
                    if person.tile.isFatBits {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            store.updateTile(forPersonID: personID) { $0.revertToPattern() }
                        } label: {
                            control("Revert", systemImage: "arrow.uturn.backward")
                        }
                        .accessibilityHint("Takes the FatBits drawing off, back to the pattern.")
                    }
                }
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showingFatBits) {
            PersonFatBitsEditor(person: person)
        }
    }

    @ViewBuilder
    private func hero(for person: Person) -> some View {
        if person.showsPhoto, let image = person.fullPhoto {
            Image(uiImage: image).resizable().scaledToFill()
        } else {
            ZStack {
                TileShades(colorIndex: person.tile.colorIndex).pale
                TileArtView(art: person.tile, pattern: person.tilePattern, side: 100)
            }
        }
    }

    /// A small bordered control: an icon with a short title under it.
    private func control(_ title: String, systemImage: String, tint: Color? = nil) -> some View {
        VStack(spacing: 2) {
            Image(systemName: systemImage)
                .font(.tact(.body).weight(.semibold))
                .foregroundStyle(tint ?? .primary)
            Text(title)
                .font(.tact(.caption2))
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 56, minHeight: 44)
        .padding(.horizontal, 6)
        .background(Color.tactTileGray.opacity(0.25), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contentShape(Rectangle())
    }

    // MARK: Tile and color menus

    /// What the tile shows: the photo, the FatBits drawing when there is
    /// one, or a pattern. The current choice is checked.
    private func tilePicker(for person: Person) -> some View {
        let fatBits = -1, photo = -2
        let current = person.showsPhoto ? photo : person.tile.isFatBits ? fatBits : person.tilePattern.rawValue
        let choice = Binding<Int>(get: { current }, set: { value in
            UISelectionFeedbackGenerator().selectionChanged()
            switch value {
            case photo:
                if person.photoData == nil {
                    showingPhotoPicker = true
                } else {
                    store.updateTile(forPersonID: personID) { $0.showsPhoto = true }
                }
            case fatBits:
                store.updateTile(forPersonID: personID) { $0.showsPhoto = false }
            default:
                store.updateTile(forPersonID: personID) {
                    $0.pattern = value
                    $0.showsPhoto = false
                    $0.revertToPattern()
                }
            }
        })
        let colorIndex = person.tile.colorIndex
        return Picker("Tile", selection: choice) {
            if let thumbnail = person.thumbnail(maxPixelSize: 128) {
                Label { Text("Photo") } icon: { Image(uiImage: TileMenuImage.photo(thumbnail)) }.tag(photo)
            } else {
                Label("Add Photo…", systemImage: "photo").tag(photo)
            }
            if let bits = person.tile.bits {
                Label { Text("FatBits") } icon: {
                    Image(uiImage: TileMenuImage.motif(bits: bits, pattern: person.tilePattern, colorIndex: colorIndex))
                }
                .tag(fatBits)
            }
            ForEach(TilePattern.allCases, id: \.self) { pattern in
                Label { Text(pattern.title) } icon: {
                    Image(uiImage: TileMenuImage.motif(pattern: pattern, colorIndex: colorIndex))
                }
                .tag(pattern.rawValue)
            }
        }
    }

    /// The palette as swatches; picking one recolours the pattern, the
    /// FatBits motif and the pale backing everywhere the person appears.
    private func colorPicker(for person: Person) -> some View {
        let choice = Binding<Int>(get: { person.tile.colorIndex }, set: { index in
            guard index != person.tile.colorIndex else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            store.updateTile(forPersonID: personID) { $0.colorIndex = index }
        })
        return Picker("Color", selection: choice) {
            ForEach(TilePalette.menuOrder, id: \.self) { index in
                Image(uiImage: TilePalette.swatch(index))
                    .accessibilityLabel(TilePalette.name(index).capitalized)
                    .tag(index)
            }
        }
    }

    /// The long-press menu on the tile: the same choices as the controls.
    @ViewBuilder
    private func tileMenuItems(for person: Person) -> some View {
        Menu { tilePicker(for: person) } label: { Label("Tile", systemImage: "square.on.square") }
        Menu { colorPicker(for: person) } label: { Label("Color", systemImage: "paintpalette") }
        Button { store.updateTile(forPersonID: personID) { $0.rotate() } } label: {
            Label("Rotate", systemImage: "rotate.right")
        }
        Button { showingFatBits = true } label: {
            Label(person.tile.isFatBits ? "Edit in FatBits" : "Draw in FatBits", systemImage: "pencil.and.outline")
        }
        if person.tile.isFatBits {
            Button { store.updateTile(forPersonID: personID) { $0.revertToPattern() } } label: {
                Label("Revert to Original", systemImage: "arrow.uturn.backward")
            }
        }
        Divider()
        Button { showingPhotoPicker = true } label: {
            Label(person.photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
        }
    }

    // MARK: Ditty

    /// One row: the ditty's notes, Play, and a menu to record or change it
    /// or go back to the default. Says when someone else sounds the same.
    private func dittyRow(for person: Person) -> some View {
        let tuning = SimonTuning.load()
        let twins = store.peopleSharingDitty(with: personID)
        let names = person.resolvedDitty.noteNames(tuning: tuning)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 12) {
                Text("Ditty").font(.tact(.headline))
                Text(names)
                    .font(.tact(.caption).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .accessibilityLabel("Notes: \(names)")
                Spacer()
                Button {
                    DittyPlayer.play(person, tuning: tuning)
                } label: {
                    Image(systemName: "play.fill")
                        .font(.tact(.subheadline))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Play")
                .accessibilityHint("Plays the notes that stand for \(person.name).")
                Menu {
                    Button { showingDittyRecorder = true } label: {
                        Label(person.ditty == nil ? "Record" : "Change", systemImage: "music.note")
                    }
                    if person.ditty != nil {
                        Button {
                            store.updateDitty(forPersonID: personID, nil)
                        } label: {
                            Label("Default", systemImage: "arrow.uturn.backward")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.tact(.subheadline))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Ditty options")
            }
            .buttonStyle(.plain)
            if !twins.isEmpty {
                Label("Sounds the same as \(ListFormatter.localizedString(byJoining: twins.map(\.name))).",
                      systemImage: "exclamationmark.triangle")
                    .font(.tact(.caption))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Tags

    /// One row: the person's tags as chips, each a search, with an edit
    /// button; or a single Add Tags button.
    private func tagsRow(for person: Person) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Tags").font(.tact(.headline)).frame(minHeight: 44)
            if person.tags.isEmpty {
                Text("None").foregroundStyle(.secondary).font(.tact(.subheadline)).frame(minHeight: 44)
            } else {
                TagChips(tags: person.tags).padding(.vertical, 10)
            }
            Spacer()
            Button { editing = .tags } label: {
                Image(systemName: person.tags.isEmpty ? "plus" : "pencil")
                    .font(.tact(.subheadline))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(person.tags.isEmpty ? "Add Tags" : "Edit Tags")
        }
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
            Button { showingLinkNotes = true } label: {
                Image(systemName: "link")
                    .font(.tact(.subheadline))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Link Existing Note")
        }

        // A full-width button, the height of a row, so a new note is one
        // easy tap rather than a hunt for a small plus.
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            showingAddNote = true
        } label: {
            Label("New Note", systemImage: "square.and.pencil")
                .font(.tact(.body).weight(.semibold))
                // Classic's accent is white in dark mode; the button's own
                // white label would vanish on it.
                .foregroundStyle(palette.onAccent)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 50)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .accessibilityLabel("New Note")
        .accessibilityHint("Writes a note about \(person.name).")

        if personNotes.isEmpty {
            Text("No notes yet")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 24)
        } else {
            VStack(spacing: 0) {
                ForEach(personNotes) { note in
                    NavigationLink(value: Route.note(note.id)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.text).foregroundStyle(.primary).lineLimit(2)
                                if !note.tags.isEmpty {
                                    TagChips(tags: note.tags)
                                }
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
