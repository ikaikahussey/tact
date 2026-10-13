import SwiftUI
import PhotosUI

/// Chooses the photo used by the Art Puzzle and previews how it will be sliced.
struct ArtSettingsView: View {
    @EnvironmentObject private var store: TactStore
    @State private var pickedItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importFailed = false

    private var imageData: Data? { store.settings.artSettings.imageData }
    private var tileCount: Int { store.people.count }

    var body: some View {
        Form {
            Section {
                if let imageData, let image = ImageCache.shared.image(for: imageData, maxPixelSize: 1024) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Puzzle photo")
                    if tileCount > 0 {
                        previewGrid(imageData: imageData)
                    }
                } else {
                    ContentUnavailableView("No Photo Selected", systemImage: "photo")
                        .frame(height: 160)
                }
            } header: {
                Text("Photo")
            } footer: {
                Text(tileCount > 0
                     ? "The photo is cut into \(tileCount) tiles, one per person, in a \(ArtImageCache.columns)×\(ArtImageCache.rows(forTileCount: tileCount)) grid."
                     : "Add people to see how the photo will be cut into tiles.")
            }

            Section {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(imageData == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(isImporting)
                if imageData != nil {
                    Button("Remove Photo", role: .destructive) {
                        store.settings.artSettings.imageData = nil
                        ArtImageCache.shared.removeAll()
                    }
                }
            }
        }
        .navigationTitle("Art Puzzle")
        .navigationBarTitleDisplayMode(.inline)
        .overlay { if isImporting { ProgressView().controlSize(.large) } }
        .onChange(of: pickedItem) { _, item in
            guard let item else { return }
            Task { await importPhoto(item) }
        }
        .alert("Couldn't Use That Photo", isPresented: $importFailed) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Try choosing a different photo.")
        }
    }

    private func previewGrid(imageData: Data) -> some View {
        let rows = ArtImageCache.rows(forTileCount: tileCount)
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: ArtImageCache.columns), spacing: 2) {
            ForEach(0..<(ArtImageCache.columns * rows), id: \.self) { index in
                if let tile = ArtImageCache.shared.tile(for: imageData, index: index, tileCount: tileCount) {
                    Image(uiImage: tile)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(index < tileCount ? 1 : 0.2)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func importPhoto(_ item: PhotosPickerItem) async {
        isImporting = true
        defer {
            isImporting = false
            pickedItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let jpeg = await Task.detached(priority: .userInitiated, operation: { ImageProcessing.storableJPEG(from: data) }).value
        else {
            importFailed = true
            return
        }
        ArtImageCache.shared.removeAll()
        store.settings.artSettings.imageData = jpeg
    }
}
