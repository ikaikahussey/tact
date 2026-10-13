import SwiftUI
import PhotosUI

/// Chooses the photo used by the Art Puzzle and previews how it will be cut.
struct ArtSettingsView: View {
    @EnvironmentObject private var store: TactStore
    @State private var pickedItem: PhotosPickerItem?
    @State private var isImporting = false
    @State private var importFailed = false

    private var customImageData: Data? { store.settings.artSettings.imageData }
    private var imageData: Data { store.puzzleImageData }

    var body: some View {
        Form {
            Section {
                if let image = ImageCache.shared.image(for: imageData, maxPixelSize: 1024) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel("Puzzle photo")
                    previewGrid
                }
            } header: {
                Text(customImageData == nil ? "Default Picture" : "Your Photo")
            } footer: {
                Text("The picture is cut into a \(ArtPuzzle.columns)×\(ArtPuzzle.rows) grid. One piece is left out so the others can slide.")
            }

            Section {
                PhotosPicker(selection: $pickedItem, matching: .images) {
                    Label(customImageData == nil ? "Choose Your Own Photo" : "Change Photo", systemImage: "photo.on.rectangle.angled")
                }
                .disabled(isImporting)
                if customImageData != nil {
                    Button("Use Default Picture") {
                        store.settings.artSettings.imageData = nil
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

    private var previewGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: ArtPuzzle.columns), spacing: 2) {
            ForEach(0..<ArtPuzzle.pieceCount, id: \.self) { index in
                if let tile = ArtImageCache.shared.tile(for: imageData, index: index, tileCount: ArtPuzzle.pieceCount) {
                    Image(uiImage: tile)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 60)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .opacity(index == ArtPuzzle.pieceCount - 1 ? 0.25 : 1)
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
        store.settings.artSettings.imageData = jpeg
    }
}
