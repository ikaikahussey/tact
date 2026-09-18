import SwiftUI
import Contacts
import ContactsUI

// MARK: - Colors

extension Color {
    static let tactBackground = Color(uiColor: .systemGroupedBackground)
    static let tactSecondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tactCardBackground = Color(uiColor: .systemBackground)
    static let tactTileGray = Color(uiColor: UIColor { traitCollection in
        traitCollection.userInterfaceStyle == .dark
            ? UIColor(white: 0.25, alpha: 1)
            : UIColor(white: 0.88, alpha: 1)
    })
}

// MARK: - Entry Point

@main
struct TactApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}


// ============================================================
// MARK: - Core Data Models
// ============================================================

struct Person: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var imageSection: Int
    var gameType: GameGridType
    var gameSettings = GameTypeSettings()
    var photoData: Data?
    var contactIdentifier: String?
    var cachedContactName: String?
    var cachedContactPhone: String?
    var cachedContactEmails: [String]?
    var cachedContactAddresses: [String]?
    var cachedContactBirthday: String?
    var cachedContactOrganization: String?
    var cachedContactJobTitle: String?
    var cachedContactURLs: [String]?
    var cachedContactNote: String?

    init(
        id: UUID = UUID(),
        name: String,
        imageSection: Int? = nil,
        gameType: GameGridType = .people,
        photoData: Data? = nil,
        contactIdentifier: String? = nil
    ) {
        self.id = id
        self.name = name
        self.imageSection = imageSection ?? Int.random(in: 0..<16)
        self.gameType = gameType
        self.gameSettings = GameTypeSettings()
        self.photoData = photoData
        self.contactIdentifier = contactIdentifier
    }

    enum CodingKeys: String, CodingKey {
        case id, name, imageSection, gameType, gameSettings, photoData, contactIdentifier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        imageSection = (try? container.decode(Int.self, forKey: .imageSection)) ?? Int.random(in: 0..<16)
        gameType = (try? container.decode(GameGridType.self, forKey: .gameType)) ?? .people
        gameSettings = (try? container.decode(GameTypeSettings.self, forKey: .gameSettings)) ?? GameTypeSettings()
        photoData = try? container.decode(Data.self, forKey: .photoData)
        contactIdentifier = try? container.decode(String.self, forKey: .contactIdentifier)
    }
}

struct Note: Identifiable, Codable, Equatable {
    var id = UUID()
    var personIds: [UUID] = []
    var text: String
    var date: Date = Date()
}

// MARK: - Game Protocols

protocol GameSettings: Codable, Equatable {
    associatedtype SettingsView: View
    var hasSettings: Bool { get }
    func settingsView(settings: Binding<Self>) -> SettingsView
}

protocol GameGridContent {
    associatedtype Settings: GameSettings
    var settings: Settings { get set }
    func tileView(for person: Person, squareSize: CGFloat) -> AnyView
}

// MARK: - Aggregate Settings Container
// Each game mode's settings are bundled here so a Person can carry
// one copy of all settings without knowing which mode is active.

struct GameTypeSettings: Codable, Equatable {
    var randomColorSettings = RandomColorGameSettings()
    var peopleSettings = PeopleGameSettings()
    var flashcardSettings = FlashcardGameSettings()
    var artSettings = ArtGameSettings()

}

// MARK: - Game Grid Type

enum GameGridType: String, Codable, CaseIterable, Equatable {
    case people
    case randomColor
    case flashcard
    case art

    func tileView(for person: Person, squareSize: CGFloat, settings: GameTypeSettings) -> AnyView {
        switch self {
        case .randomColor:
            return RandomColorGame(settings: settings.randomColorSettings)
                .tileView(for: person, squareSize: squareSize)
        case .people:
            return PeopleGame(settings: settings.peopleSettings)
                .tileView(for: person, squareSize: squareSize)
        case .flashcard:
            return FlashcardGame(settings: settings.flashcardSettings)
                .tileView(for: person, squareSize: squareSize)
        case .art:
            return ArtGame(settings: settings.artSettings)
                .tileView(for: person, squareSize: squareSize)
        }
    }

    var hasSettings: Bool {
        switch self {
        case .randomColor:  return RandomColorGameSettings().hasSettings
        case .people:       return PeopleGameSettings().hasSettings
        case .flashcard:    return FlashcardGameSettings().hasSettings
        case .art:          return ArtGameSettings().hasSettings
        }
    }

    var name: String {
        switch self {
        case .randomColor:  return "Random Colors"
        case .people:       return "Grid"
        case .flashcard:    return "Flashcard"
        case .art:          return "Art"
        }
    }
}


// ============================================================
// MARK: - Game Modes
// ============================================================

// MARK: - Random Color Game
// Each person gets a background color derived mathematically from their
// imageSection number. The same person always gets the same color.
// Seven palettes are available in settings.

enum ColorPalette: String, Codable, CaseIterable {
    case vibrant    = "Vibrant"
    case pastel     = "Pastel"
    case earth      = "Earth Tones"
    case ocean      = "Ocean"
    case sunset     = "Sunset"
    case neon       = "Neon"
    case monochrome = "Monochrome"
}

struct RandomColorGameSettings: GameSettings, Equatable {
    var palette: ColorPalette = .vibrant
    var hasSettings: Bool { true }
    func settingsView(settings: Binding<RandomColorGameSettings>) -> some View {
        RandomColorSettingsView(settings: settings)
    }
}

struct RandomColorSettingsView: View {
    @Binding var settings: RandomColorGameSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Color Palette")
                .font(.headline)
            ForEach(ColorPalette.allCases, id: \.self) { palette in
                Button {
                    settings.palette = palette
                } label: {
                    HStack {
                        Text(palette.rawValue)
                            .foregroundColor(.primary)
                        Spacer()
                        if settings.palette == palette {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }
}

struct RandomColorGame: GameGridContent {
    var settings = RandomColorGameSettings()

    func tileView(for person: Person, squareSize: CGFloat) -> AnyView {
        AnyView(randomColor(for: person.imageSection, palette: settings.palette))
    }

    func randomColor(for seed: Int, palette: ColorPalette) -> Color {
        let hue: Double
        let saturation: Double
        let brightness: Double

        switch palette {
        case .vibrant:
            hue        = Double(seed * 37 % 360) / 360.0
            saturation = 0.6 + (Double(seed * 17 % 40) / 100.0)
            brightness = 0.5 + (Double(seed * 23 % 40) / 100.0)
        case .pastel:
            hue        = Double(seed * 37 % 360) / 360.0
            saturation = 0.2 + (Double(seed * 17 % 20) / 100.0)
            brightness = 0.8 + (Double(seed * 23 % 20) / 100.0)
        case .earth:
            let hues   = [20, 30, 40, 50, 100, 120]
            hue        = Double(hues[seed % hues.count]) / 360.0
            saturation = 0.3 + (Double(seed * 17 % 30) / 100.0)
            brightness = 0.4 + (Double(seed * 23 % 30) / 100.0)
        case .ocean:
            let hues   = [180, 195, 210, 225, 240]
            hue        = Double(hues[seed % hues.count]) / 360.0
            saturation = 0.4 + (Double(seed * 17 % 40) / 100.0)
            brightness = 0.3 + (Double(seed * 23 % 50) / 100.0)
        case .sunset:
            let hues   = [0, 10, 20, 30, 40, 340, 350]
            hue        = Double(hues[seed % hues.count]) / 360.0
            saturation = 0.5 + (Double(seed * 17 % 40) / 100.0)
            brightness = 0.4 + (Double(seed * 23 % 50) / 100.0)
        case .neon:
            let hues   = [0, 60, 120, 180, 240, 300]
            hue        = Double(hues[seed % hues.count]) / 360.0
            saturation = 0.9 + (Double(seed * 17 % 10) / 100.0)
            brightness = 0.9 + (Double(seed * 23 % 10) / 100.0)
        case .monochrome:
            hue        = 0
            saturation = 0
            brightness = 0.15 + (Double(seed * 37 % 70) / 100.0)
        }

        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

// MARK: - People Game
// Displays the person's photo if available, otherwise shows their name
// on a plain card background.

struct PeopleGameSettings: GameSettings, Equatable {
    var hasSettings: Bool { false }
    func settingsView(settings: Binding<PeopleGameSettings>) -> some View { EmptyView() }
}

struct PeopleGame: GameGridContent {
    var settings = PeopleGameSettings()

    func tileView(for person: Person, squareSize: CGFloat) -> AnyView {
        AnyView(
            ZStack {
                if let photoData = person.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: squareSize, height: squareSize)
                        .clipped()
                } else {
                    Color.tactCardBackground
                    Text(person.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
            }
        )
    }
}

// MARK: - Flashcard Game
// Two components:
//   FlashcardGame      — the tile appearance when shown in the main grid
//   FlashcardView      — the full-screen swipeable study mode

struct FlashcardGameSettings: GameSettings, Equatable {
    var hasSettings: Bool { false }
    func settingsView(settings: Binding<FlashcardGameSettings>) -> some View { EmptyView() }
}

struct FlashcardGame: GameGridContent {
    var settings = FlashcardGameSettings()

    func tileView(for person: Person, squareSize: CGFloat) -> AnyView {
        AnyView(
            ZStack {
                if let photoData = person.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: squareSize, height: squareSize)
                        .clipped()
                    LinearGradient(
                        colors: [Color.black.opacity(0.3), Color.black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    VStack {
                        Spacer()
                        Text(person.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                            .padding(8)
                    }
                } else {
                    LinearGradient(
                        colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    VStack(spacing: 4) {
                        Image(systemName: "person.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        Text(person.name)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(8)
                }
            }
        )
    }
}

// MARK: - Full-Screen Flashcard Study View

struct FlashcardView: View {
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @State private var currentIndex = 0
    @State private var isFlipped = false
    @State private var dragOffset: CGFloat = 0

    var currentPerson: Person? {
        guard !people.isEmpty && currentIndex < people.count else { return nil }
        return people[currentIndex]
    }

    func noteCount(for person: Person) -> Int {
        notes.filter { $0.personIds.contains(person.id) }.count
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                if let person = currentPerson {
                    Spacer()

                    cardView(person: person, geometry: geometry)
                        .offset(x: dragOffset)
                        .animation(.easeInOut(duration: 0.3), value: isFlipped)
                        .onTapGesture {
                            isFlipped.toggle()
                        }
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    dragOffset = value.translation.width
                                }
                                .onEnded { value in
                                    handleSwipe(translation: value.translation.width)
                                }
                        )

                    Spacer()

                    controls
                } else {
                    emptyState
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.tactBackground)
    }

    @ViewBuilder
    func cardView(person: Person, geometry: GeometryProxy) -> some View {
        let size = geometry.size.width - 40
        ZStack {
            if !isFlipped {
                if let photoData = person.photoData,
                   let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(radius: 10)
                } else {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(
                            colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.6)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: size, height: size)
                        .shadow(radius: 10)
                        .overlay(
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.white.opacity(0.8))
                        )
                }
            } else {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.tactCardBackground)
                    .frame(width: size, height: size)
                    .shadow(radius: 10)
                    .overlay(
                        VStack(spacing: 16) {
                            Text(person.name)
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.primary)
                            let count = noteCount(for: person)
                            if count > 0 {
                                Text("\(count) \(count == 1 ? "note" : "notes")")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    )
            }
        }
    }

    var controls: some View {
        VStack(spacing: 20) {
            if !isFlipped {
                Text("Tap to reveal")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 40) {
                Button {
                    guard currentIndex > 0 else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentIndex -= 1
                        isFlipped = false
                    }
                } label: {
                    Image(systemName: "chevron.left.circle")
                        .font(.system(size: 50))
                        .foregroundColor(currentIndex > 0 ? .primary : .gray.opacity(0.3))
                }
                .disabled(currentIndex == 0)

                Text("\(currentIndex + 1) / \(people.count)")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 80)

                Button {
                    guard currentIndex < people.count - 1 else { return }
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        currentIndex += 1
                        isFlipped = false
                    }
                } label: {
                    Image(systemName: "chevron.right.circle")
                        .font(.system(size: 50))
                        .foregroundColor(currentIndex < people.count - 1 ? .primary : .gray.opacity(0.3))
                }
                .disabled(currentIndex >= people.count - 1)
            }
            .padding(.bottom, 40)
        }
    }

    var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No people to show")
                .font(.title3)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    func handleSwipe(translation: CGFloat) {
        let threshold: CGFloat = 100
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if translation < -threshold && currentIndex < people.count - 1 {
                currentIndex += 1
                isFlipped = false
            } else if translation > threshold && currentIndex > 0 {
                currentIndex -= 1
                isFlipped = false
            }
            dragOffset = 0
        }
    }
}

// MARK: - Art Image Cache
// Slices a chosen photo into a 4×4 grid of tiles on first request
// and caches them so they don't need to be recut on every redraw.

class ArtImageCache {
    static let shared = ArtImageCache()
    private var cache: [Data: UIImage] = [:]
    private var tileCache: [String: UIImage] = [:]

    func image(for data: Data) -> UIImage? {
        if let cached = cache[data] { return cached }
        if let img = UIImage(data: data) {
            cache[data] = img
            return img
        }
        return nil
    }

    func tile(for data: Data, section: Int, tileCount: Int = 16) -> UIImage? {
        let cols = 4
        let rows = max(1, Int(ceil(Double(tileCount) / Double(cols))))
        let key = "\(data.hashValue)-\(section)-\(cols)x\(rows)"
        if let cached = tileCache[key] { return cached }
        guard let source = image(for: data), let sourceCG = source.cgImage else { return nil }

        // Crop source to the grid's aspect ratio (cols:rows), centered.
        // This ensures each tile is displayed without stretching.
        let sourceAspect = source.size.width / source.size.height
        let gridAspect   = CGFloat(cols) / CGFloat(rows)
        let cropRect: CGRect
        if sourceAspect > gridAspect {
            // Wider than grid — trim the sides
            let cropW = source.size.height * gridAspect
            cropRect = CGRect(x: (source.size.width - cropW) / 2, y: 0,
                              width: cropW, height: source.size.height)
        } else {
            // Taller than grid — trim top and bottom
            let cropH = source.size.width / gridAspect
            cropRect = CGRect(x: 0, y: (source.size.height - cropH) / 2,
                              width: source.size.width, height: cropH)
        }
        guard let croppedCG = sourceCG.cropping(to: cropRect) else { return nil }

        let tileW = CGFloat(croppedCG.width)  / CGFloat(cols)
        let tileH = CGFloat(croppedCG.height) / CGFloat(rows)
        let row   = section / cols
        let col   = section % cols
        let tileCrop = CGRect(x: CGFloat(col) * tileW, y: CGFloat(row) * tileH,
                              width: tileW, height: tileH)
        guard let tileCG = croppedCG.cropping(to: tileCrop) else { return nil }
        let tile = UIImage(cgImage: tileCG)
        tileCache[key] = tile
        return tile
    }

    func clearCache() {
        cache.removeAll()
        tileCache.removeAll()
    }
}

// MARK: - Art Game Settings

struct ArtGameSettings: GameSettings, Equatable {
    var hasSettings: Bool { true }
    var imageData: Data?
    // Number of tiles the image was sliced into — equals people.count at save time.
    // Used by the cache so it can crop the source image to the right aspect ratio.
    var tileCount: Int = 16
    func settingsView(settings: Binding<ArtGameSettings>) -> some View {
        ArtSettingsView(settings: settings, peopleCount: 16)
    }
}

struct ArtSettingsView: View {
    @Binding var settings: ArtGameSettings
    let peopleCount: Int
    @State private var showingPhotoPicker = false

    var body: some View {
        VStack(spacing: 16) {
            Text("Photo")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let imageData = settings.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 200)
                    .cornerRadius(12)
                previewGrid(imageData: imageData)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.tactCardBackground)
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.2), lineWidth: 1))
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("No photo selected")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    )
            }

            Button {
                showingPhotoPicker = true
            } label: {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                    Text(settings.imageData == nil ? "Choose Photo" : "Change Photo")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            if settings.imageData != nil {
                Button {
                    settings.imageData = nil
                    ArtImageCache.shared.clearCache()
                } label: {
                    Text("Remove Photo")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .sheet(isPresented: $showingPhotoPicker) {
            ArtPhotoPickerView(imageData: $settings.imageData)
        }
    }

    func previewGrid(imageData: Data) -> some View {
        let cols = 4
        let rows = max(1, Int(ceil(Double(peopleCount) / Double(cols))))
        let tileCount = cols * rows
        return VStack(spacing: 2) {
            Text("Preview (\(peopleCount) tiles, \(cols)×\(rows) grid)")
                .font(.caption)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .leading)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: cols), spacing: 2) {
                ForEach(0..<tileCount, id: \.self) { section in
                    if let tile = ArtImageCache.shared.tile(for: imageData,
                                                             section: section,
                                                             tileCount: peopleCount) {
                        Image(uiImage: tile)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 60)
                            .clipped()
                            .cornerRadius(section < peopleCount ? 4 : 0)
                            .opacity(section < peopleCount ? 1.0 : 0.2)
                    }
                }
            }
        }
    }
}

// MARK: - Art Photo Picker
// Resizes picked photos to a maximum of 1024px on the longest dimension
// before storing, to keep saved data size reasonable.

struct ArtPhotoPickerView: UIViewControllerRepresentable {
    @Binding var imageData: Data?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ArtPhotoPickerView
        init(_ parent: ArtPhotoPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let maxDimension: CGFloat = 1024
                let scale = min(maxDimension / image.size.width,
                                maxDimension / image.size.height,
                                1.0)
                let newSize = CGSize(width: image.size.width * scale,
                                    height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resized = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                ArtImageCache.shared.clearCache()
                parent.imageData = resized?.jpegData(compressionQuality: 0.8)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Art Game

struct ArtGame: GameGridContent {
    var settings = ArtGameSettings()

    func tileView(for person: Person, squareSize: CGFloat) -> AnyView {
        if let imageData = settings.imageData,
           let tileImage = ArtImageCache.shared.tile(for: imageData,
                                                     section: person.imageSection,
                                                     tileCount: settings.tileCount) {
            return AnyView(
                Image(uiImage: tileImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: squareSize, height: squareSize)
                    .clipped()
            )
        }
        // No photo uploaded yet — show a neutral placeholder.
        return AnyView(
            Color.tactTileGray
                .overlay(
                    Image(systemName: "photo")
                        .font(.system(size: squareSize * 0.35))
                        .foregroundColor(.secondary.opacity(0.5))
                )
        )
    }
}


// ============================================================
// MARK: - Root & Persistence
// ============================================================

// MARK: - Content View
// The root of the app. Owns all data, handles persistence,
// and hosts the three-tab navigation structure.

struct ContentView: View {
    @AppStorage("people") private var peopleData: Data = Data()
    @AppStorage("notes")  private var notesData:  Data = Data()
    @State private var people: [Person] = []
    @State private var notes:  [Note]   = []

    var body: some View {
        TabView {
            PeopleTabView(people: $people, notes: $notes)
                .tabItem { Label("People", systemImage: "person.2.fill") }

            NotesListView(notes: $notes, people: $people)
                .tabItem { Label("Notes", systemImage: "note.text") }

            SearchView(people: $people, notes: $notes)
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
        }
        .onAppear  { loadData() }
        .onChange(of: people) { _, _ in saveData() }
        .onChange(of: notes)  { _, _ in saveData() }
    }

    func loadData() {
        if let decoded = try? JSONDecoder().decode([Person].self, from: peopleData) {
            people = decoded
        }
        if let decoded = try? JSONDecoder().decode([Note].self, from: notesData) {
            notes = decoded
        }
    }

    func saveData() {
        if let encoded = try? JSONEncoder().encode(people) { peopleData = encoded }
        if let encoded = try? JSONEncoder().encode(notes)  { notesData  = encoded }
    }
}


// ============================================================
// MARK: - People Screens
// ============================================================

// MARK: - People Tab View
// Coordinator for the People tab. Chooses which layout to show
// and owns all drag-and-drop reordering state.

struct PeopleTabView: View {
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @AppStorage("selectedGameType") private var selectedGameType: GameGridType = .people
    @AppStorage("isListMode")       private var isListMode = true
    @State private var showingAddPerson  = false
    @State private var showingGamePicker = false
    @State private var newPersonName     = ""
    @State private var draggedPerson: Person?
    @State private var dragOffset: CGSize = .zero
    @State private var hoveredIndex: Int?
    @State private var dragStartIndex: Int?
    @State private var isDraggingActive  = false
    @State private var isJiggleMode = false

    var body: some View {
        NavigationStack {
            Group {
                if isListMode {
                    PeopleListContent(people: $people, notes: $notes)
                } else if selectedGameType == .flashcard {
                    FlashcardView(people: $people, notes: $notes)
                } else if selectedGameType == .art {
                    ArtPuzzleView(people: $people, notes: $notes)
                } else {
                    PeopleGridContent(
                        people: $people,
                        notes: $notes,
                        selectedGameType: selectedGameType,
                        showingAddPerson: $showingAddPerson,
                        draggedPerson: $draggedPerson,
                        dragOffset: $dragOffset,
                        hoveredIndex: $hoveredIndex,
                        isDraggingActive: $isDraggingActive,
                        isJiggleMode: $isJiggleMode,
                        noteCount: noteCount,
                        updateHoveredIndex: updateHoveredIndex,
                        finalizeReorder: finalizeReorder
                    )
                }
            }
            .navigationTitle("Tact")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isJiggleMode {
                        Button("Done") { 
                            withAnimation { isJiggleMode = false }
                        }
                    } else {
                        Button { showingGamePicker = true }
                        label: { Image(systemName: "gearshape") }
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showingAddPerson = true }
                    label: { Image(systemName: "plus") }
                }
            }
            .alert("Add Person", isPresented: $showingAddPerson) {
                TextField("Name", text: $newPersonName)
                Button("Cancel", role: .cancel) { newPersonName = "" }
                Button("Add") {
                    guard !newPersonName.isEmpty else { return }
                    var newPerson = Person(name: newPersonName, gameType: selectedGameType)
                    if selectedGameType == .art {
                        let newIndex = people.count
                        newPerson.imageSection = newIndex
                        if let existingSettings = people.first?.gameSettings {
                            var updatedSettings = existingSettings
                            updatedSettings.artSettings.tileCount = newIndex + 1
                            newPerson.gameSettings = updatedSettings
                            for i in people.indices {
                                people[i].gameSettings.artSettings.tileCount = newIndex + 1
                            }
                            ArtImageCache.shared.clearCache()
                        }
                    }
                    people.append(newPerson)
                    newPersonName = ""
                }
            }
            .sheet(isPresented: $showingGamePicker) {
                GamePickerView(selectedGameType: $selectedGameType, people: $people, notes: $notes)
            }
        }
    }

    func noteCount(for person: Person) -> Int {
        notes.filter { $0.personIds.contains(person.id) }.count
    }

    func updateHoveredIndex(translation: CGSize, squareSize: CGFloat) {
        guard let dragged = draggedPerson,
              let currentIdx = people.firstIndex(where: { $0.id == dragged.id })
        else { return }

        if dragStartIndex == nil { dragStartIndex = currentIdx }

        let cols = 4
        let startRow = (dragStartIndex ?? currentIdx) / cols
        let startCol = (dragStartIndex ?? currentIdx) % cols
        let colOffset = Int(round(translation.width  / squareSize))
        let rowOffset = Int(round(translation.height / squareSize))
        let newCol = max(0, min(cols - 1, startCol + colOffset))
        let newRow = max(0, startRow + rowOffset)
        let targetIndex = (newRow * cols) + newCol

        guard targetIndex >= 0,
              targetIndex < people.count,
              targetIndex != currentIdx
        else { return }

        hoveredIndex   = targetIndex
        dragStartIndex = targetIndex

        withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
            people.move(
                fromOffsets: IndexSet(integer: currentIdx),
                toOffset: targetIndex > currentIdx ? targetIndex + 1 : targetIndex
            )
        }
    }

    func finalizeReorder() {
        withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
            dragOffset       = .zero
            isDraggingActive = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            draggedPerson  = nil
            hoveredIndex   = nil
            dragStartIndex = nil
        }
    }
}

// MARK: - People Grid Content

struct PeopleGridContent: View {
    @Binding var people: [Person]
    @Binding var notes: [Note]
    let selectedGameType: GameGridType
    @Binding var showingAddPerson: Bool
    @Binding var draggedPerson: Person?
    @Binding var dragOffset: CGSize
    @Binding var hoveredIndex: Int?
    @Binding var isDraggingActive: Bool
    @Binding var isJiggleMode: Bool
    let noteCount: (Person) -> Int
    let updateHoveredIndex: (CGSize, CGFloat) -> Void
    let finalizeReorder: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let squareSize = geometry.size.width / 4
            ScrollView {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.fixed(squareSize), spacing: 1), count: 4),
                    spacing: 1
                ) {
                    ForEach(Array(people.enumerated()), id: \.element.id) { index, person in
                        PersonSquare(
                            person: person,
                            noteCount: noteCount(person),
                            people: $people,
                            notes: $notes,
                            squareSize: squareSize,
                            selectedGameType: selectedGameType,
                            draggedPerson: $draggedPerson,
                            dragOffset: $dragOffset,
                            hoveredIndex: $hoveredIndex,
                            isDraggingActive: $isDraggingActive,
                            isJiggleMode: $isJiggleMode,
                            currentIndex: index,
                            onDragChanged: { translation in
                                updateHoveredIndex(translation, squareSize)
                            },
                            onDragEnded: finalizeReorder
                        )
                    }
                    Button {
                        showingAddPerson = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.largeTitle)
                            .foregroundColor(.primary)
                            .frame(width: squareSize, height: squareSize)
                            .background(Color.tactTileGray)
                            .opacity(isDraggingActive ? 0.3 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isDraggingActive)
                }
                .padding(.bottom, 20)
                .id(selectedGameType)
            }
            .scrollIndicators(.visible)
        }
        .background(Color.tactBackground)
    }
}

// MARK: - Person Square

struct PersonSquare: View {
    let person: Person
    let noteCount: Int
    @Binding var people: [Person]
    @Binding var notes: [Note]
    let squareSize: CGFloat
    let selectedGameType: GameGridType
    @Binding var draggedPerson: Person?
    @Binding var dragOffset: CGSize
    @Binding var hoveredIndex: Int?
    @Binding var isDraggingActive: Bool
    @Binding var isJiggleMode: Bool
    let currentIndex: Int
    let onDragChanged: (CGSize) -> Void
    let onDragEnded: () -> Void
    
    @State private var jiggleOffset: CGFloat = 0

    var isDragging: Bool { draggedPerson?.id == person.id }

    var body: some View {
        Group {
            if isJiggleMode {
                selectedGameType
                    .tileView(for: person, squareSize: squareSize, settings: person.gameSettings)
                    .frame(width: squareSize, height: squareSize)
            } else {
                NavigationLink(destination: PersonDetailView(person: person, people: $people, notes: $notes)) {
                    selectedGameType
                        .tileView(for: person, squareSize: squareSize, settings: person.gameSettings)
                        .frame(width: squareSize, height: squareSize)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: squareSize, height: squareSize)
        .offset(isDragging ? dragOffset : .zero)
        .rotationEffect(.degrees(isJiggleMode && !isDragging ? jiggleOffset : 0))
        .scaleEffect(isJiggleMode && !isDragging ? 0.92 : (isDragging ? 1.08 : 1.0))
        .opacity(isDragging ? 0.9 : 1.0)
        .shadow(color: .black.opacity(isDragging ? 0.25 : 0),
                radius: isDragging ? 10 : 0,
                y: isDragging ? 4 : 0)
        .zIndex(isDragging ? 100 : 0)
        .animation(.interpolatingSpring(stiffness: 200, damping: 22), value: isDragging)
        .animation(.easeInOut(duration: 0.12), value: isJiggleMode)
        .onAppear {
            if isJiggleMode {
                startJiggling()
            }
        }
        .onChange(of: isJiggleMode) { _, newValue in
            if newValue {
                startJiggling()
            } else {
                withAnimation {
                    jiggleOffset = 0
                }
            }
        }
        .highPriorityGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if !isJiggleMode {
                        withAnimation { isJiggleMode = true }
                    }
                }
        )
        .gesture(
            DragGesture(minimumDistance: isJiggleMode ? 5 : 999)
                .onChanged { value in
                    guard isJiggleMode else { return }
                    if draggedPerson == nil {
                        withAnimation(.interpolatingSpring(stiffness: 200, damping: 22)) {
                            draggedPerson    = person
                            isDraggingActive = true
                        }
                    }
                    if draggedPerson?.id == person.id {
                        dragOffset = value.translation
                        onDragChanged(value.translation)
                    }
                }
                .onEnded { _ in
                    guard isJiggleMode else { return }
                    if draggedPerson?.id == person.id { onDragEnded() }
                }
        )
    }
    
    func startJiggling() {
        let duration = 0.1
        let angle: CGFloat = 2.5
        let delay = Double.random(in: 0...0.2)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(Animation.easeInOut(duration: duration).repeatForever(autoreverses: true)) {
                jiggleOffset = angle
            }
        }
    }
}

// MARK: - Art Puzzle View

struct ArtPuzzleView: View {
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @State private var tilePositions: [UUID?] = []
    @State private var blankIndex: Int = 0
    
    var body: some View {
        GeometryReader { geometry in
            let squareSize = geometry.size.width / 4
            
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.fixed(squareSize), spacing: 1), count: 4), spacing: 1) {
                    ForEach(0..<tilePositions.count, id: \.self) { index in
                        if tilePositions[index] == nil {
                            Color.tactTileGray
                                .frame(width: squareSize, height: squareSize)
                        } else if let personId = tilePositions[index],
                                  let person = people.first(where: { $0.id == personId }) {
                            Button {
                                slideTile(at: index)
                            } label: {
                                if let imageData = person.gameSettings.artSettings.imageData {
                                    if let tileImage = ArtImageCache.shared.tile(
                                        for: imageData,
                                        section: person.imageSection,
                                        tileCount: person.gameSettings.artSettings.tileCount
                                    ) {
                                        Image(uiImage: tileImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: squareSize, height: squareSize)
                                            .clipped()
                                    }
                                } else {
                                    Color.tactTileGray
                                        .frame(width: squareSize, height: squareSize)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .background(Color.tactBackground)
        .onAppear {
            if tilePositions.isEmpty {
                initializePuzzle()
            }
        }
        .onChange(of: people.count) { _, _ in
            initializePuzzle()
        }
    }
    
    func initializePuzzle() {
        tilePositions = people.map { Optional($0.id) } + [nil]
        blankIndex = people.count
    }
    
    func slideTile(at index: Int) {
        guard let currentBlank = tilePositions.firstIndex(where: { $0 == nil }) else { return }
        
        let cols = 4
        let tapRow = index / cols, tapCol = index % cols
        let blankRow = currentBlank / cols, blankCol = currentBlank % cols
        
        var tilesToSlide: [Int] = []
        
        if tapRow == blankRow {
            if tapCol < blankCol {
                tilesToSlide = (tapCol..<blankCol).map { tapRow * cols + $0 }
            } else if tapCol > blankCol {
                tilesToSlide = ((blankCol + 1)...tapCol).map { tapRow * cols + $0 }.reversed()
            }
        } else if tapCol == blankCol {
            if tapRow < blankRow {
                tilesToSlide = (tapRow..<blankRow).map { $0 * cols + tapCol }
            } else if tapRow > blankRow {
                tilesToSlide = ((blankRow + 1)...tapRow).map { $0 * cols + tapCol }.reversed()
            }
        }
        
        guard !tilesToSlide.isEmpty else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            var positions = tilePositions
            let firstTile = positions[tilesToSlide.first!]
            
            for i in 0..<(tilesToSlide.count - 1) {
                positions[tilesToSlide[i]] = positions[tilesToSlide[i + 1]]
            }
            
            positions[tilesToSlide.last!] = positions[currentBlank]
            positions[currentBlank] = firstTile
            
            tilePositions = positions
        }
    }
    
    func isAdjacent(_ a: Int, _ b: Int) -> Bool {
        let cols = 4
        let rowA = a / cols, colA = a % cols
        let rowB = b / cols, colB = b % cols
        return (rowA == rowB && abs(colA - colB) == 1) || (colA == colB && abs(rowA - rowB) == 1)
    }
}

// MARK: - People List Content

struct PeopleListContent: View {
    @Binding var people: [Person]
    @Binding var notes: [Note]

    var body: some View {
        List {
            ForEach(people) { person in
                NavigationLink(destination: PersonDetailView(person: person, people: $people, notes: $notes)) {
                    HStack(spacing: 12) {
                        if let photoData = person.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 40, height: 40)
                                .clipShape(Circle())
                        } else {
                            Circle()
                                .fill(Color.tactTileGray)
                                .frame(width: 40, height: 40)
                                .overlay(Image(systemName: "person.fill").foregroundColor(.secondary))
                        }
                        Text(person.name).font(.body)
                        Spacer()
                        let count = notes.filter { $0.personIds.contains(person.id) }.count
                        if count > 0 {
                            Text("\(count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.tactTileGray)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .onDelete { offsets in
                let toDelete = offsets.map { people[$0] }
                for person in toDelete {
                    notes.removeAll { $0.personIds.contains(person.id) }
                }
                people.remove(atOffsets: offsets)
            }
            .onMove { from, to in
                people.move(fromOffsets: from, toOffset: to)
            }
        }
        .listStyle(.insetGrouped)
    }
}

// MARK: - Game Picker View

struct GamePickerView: View {
    @Binding var selectedGameType: GameGridType
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @AppStorage("isListMode") private var isListMode = true
    @State private var showingSettings  = false
    @State private var editingGameSettings = GameTypeSettings()
    @State private var showingExportSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // List mode option
                    Button {
                        isListMode = true
                        dismiss()
                    } label: {
                        HStack {
                            Text("List").font(.headline).foregroundColor(.primary)
                            Spacer()
                            if isListMode { Image(systemName: "checkmark").foregroundColor(.blue) }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.top)

                    Divider().padding(.vertical, 16).padding(.horizontal)

                    // Grid mode options
                    VStack(spacing: 12) {
                        ForEach(GameGridType.allCases, id: \.self) { gameType in
                            HStack(spacing: 0) {
                                Button {
                                    isListMode = false
                                    selectedGameType = gameType
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(gameType.name).font(.headline).foregroundColor(.primary)
                                        Spacer()
                                        if !isListMode && selectedGameType == gameType {
                                            Image(systemName: "checkmark").foregroundColor(.blue)
                                        }
                                    }
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                if gameType.hasSettings {
                                    Button {
                                        editingGameSettings = people.first?.gameSettings ?? GameTypeSettings()
                                        showingSettings = true
                                    } label: {
                                        Image(systemName: "gearshape.fill")
                                            .foregroundColor(.secondary)
                                            .padding()
                                            .background(Color.tactTileGray)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                    Divider().padding(.vertical, 16).padding(.horizontal)
                    
                    Button {
                        showingExportSheet = true
                    } label: {
                        HStack {
                            Text("Export Outline").font(.headline).foregroundColor(.primary)
                            Spacer()
                            Image(systemName: "square.and.arrow.up").foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(Color.tactBackground)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                        .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showingSettings) {
                GameSettingsView(gameType: selectedGameType,
                                 settings: $editingGameSettings,
                                 people: $people)
            }
            .sheet(isPresented: $showingExportSheet) {
                ShareSheet(items: [generateOutline()])
            }
        }
    }
    
    func generateOutline() -> String {
        var outline = "TACT OUTLINE\n"
        outline += "Generated: \(Date().formatted(date: .long, time: .shortened))\n\n"
        outline += "=" + String(repeating: "=", count: 50) + "\n\n"
        
        if people.isEmpty {
            outline += "No people added yet.\n\n"
        } else {
            outline += "PEOPLE (\(people.count))\n\n"
            
            for person in people {
                outline += "• \(person.name)\n"
                
                let personNotes = notes.filter { $0.personIds.contains(person.id) }
                    .sorted { $0.date > $1.date }
                
                if !personNotes.isEmpty {
                    outline += "  Notes (\(personNotes.count)):\n"
                    for note in personNotes {
                        let dateStr = note.date.formatted(date: .abbreviated, time: .omitted)
                        let preview = note.text.prefix(100)
                        let truncated = note.text.count > 100 ? "..." : ""
                        outline += "    - [\(dateStr)] \(preview)\(truncated)\n"
                    }
                }
                outline += "\n"
            }
        }
        
        let unlinkedNotes = notes.filter { $0.personIds.isEmpty }
        if !unlinkedNotes.isEmpty {
            outline += "UNLINKED NOTES (\(unlinkedNotes.count))\n\n"
            for note in unlinkedNotes.sorted(by: { $0.date > $1.date }) {
                let dateStr = note.date.formatted(date: .abbreviated, time: .omitted)
                let preview = note.text.prefix(100)
                let truncated = note.text.count > 100 ? "..." : ""
                outline += "  - [\(dateStr)] \(preview)\(truncated)\n"
            }
        }
        
        return outline
    }
}

// MARK: - Game Settings View

struct GameSettingsView: View {
    let gameType: GameGridType
    @Binding var settings: GameTypeSettings
    @Binding var people: [Person]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack {
                    switch gameType {
                    case .randomColor:
                        RandomColorSettingsView(settings: $settings.randomColorSettings)
                    case .art:
                        ArtSettingsView(settings: $settings.artSettings,
                                        peopleCount: people.count)
                    default:
                        Text("No settings available").foregroundColor(.gray)
                    }
                }
            }
            .background(Color.tactSecondaryBackground)
            .navigationTitle("\(gameType.name) Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var finalSettings = settings
                        if gameType == .art && finalSettings.artSettings.imageData != nil {
                            finalSettings.artSettings.tileCount = people.count
                            ArtImageCache.shared.clearCache()
                        }
                        for index in people.indices {
                            people[index].gameSettings = finalSettings
                            if gameType == .art && finalSettings.artSettings.imageData != nil {
                                people[index].imageSection = index
                            }
                        }
                        dismiss()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}


// ============================================================
// MARK: - Person Detail Screen
// ============================================================

// MARK: - Person Detail View

struct PersonDetailView: View {
    let person: Person
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @State private var showingAddNote      = false
    @State private var showingDeleteAlert  = false
    @State private var showingPhotoPicker  = false
    @State private var showingLinkNotes    = false
    @State private var showingContactPicker = false
    @State private var showingContactInfo  = false
    @State private var showingEditSheet    = false
    @State private var linkedContact: CNContact?

    var personNotes: [Note] {
        notes.filter { $0.personIds.contains(person.id) }.sorted { $0.date > $1.date }
    }

    var unlinkableNotes: [Note] {
        notes.filter { !$0.personIds.contains(person.id) }
    }

    var currentPerson: Person? {
        people.first(where: { $0.id == person.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if person.photoData != nil {
                    photoSection
                }
                contactSection
                Divider()
                notesSection
            }
            .padding()
        }
        .navigationTitle(person.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        showingEditSheet = true
                    } label: {
                        Label("Edit Name", systemImage: "pencil")
                    }
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        Label(person.photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo")
                    }
                    if person.photoData != nil {
                        Button(role: .destructive) {
                            removePhoto()
                        } label: {
                            Label("Remove Photo", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) { showingDeleteAlert = true }
                label: { Image(systemName: "trash") }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditPersonView(person: person, people: $people)
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView(personId: person.id, notes: $notes)
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PersonPhotoPickerView(person: person, people: $people)
        }
        .sheet(isPresented: $showingLinkNotes) {
            LinkNotesView(person: person, notes: $notes, availableNotes: unlinkableNotes)
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPickerView { contact in
                linkContact(contact)
            }
        }
        .sheet(isPresented: $showingContactInfo) {
            if linkedContact != nil {
                LinkedContactInfoView(contact: linkedContact!)
            }
        }
        .alert("Delete Person", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                notes.removeAll { $0.personIds.contains(person.id) }
                people.removeAll { $0.id == person.id }
            }
        } message: {
            Text("This will delete this person and all their notes.")
        }
    }

    // MARK: Photo

    @ViewBuilder
    var photoSection: some View {
        if let photoData = person.photoData,
           let uiImage = UIImage(data: photoData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 200)
                .clipped()
                .cornerRadius(12)
                .onTapGesture { showingPhotoPicker = true }
        }
    }

    // MARK: Contact

    @ViewBuilder
    var contactSection: some View {
        HStack(spacing: 0) {
            if currentPerson?.contactIdentifier != nil {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title3).foregroundColor(.primary)

                    if let cachedName = currentPerson?.cachedContactName {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cachedName).font(.body).foregroundColor(.primary)
                            if let phone = currentPerson?.cachedContactPhone {
                                Text(phone).font(.caption).foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Text("Linked Contact")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button { 
                        if linkedContact == nil {
                            loadContactInfo()
                        }
                        showingContactInfo = true
                    }
                    label: { Image(systemName: "info.circle").font(.title3).foregroundColor(.primary) }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 12)

                Button { unlinkContact() }
                label: { Image(systemName: "xmark.circle.fill").foregroundColor(.primary).padding(.leading, 8) }
                .buttonStyle(.plain)
            } else {
                Button { requestContactsAccess() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.title3).foregroundColor(.primary)
                        Text("Link Contact").font(.body).foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Notes

    @ViewBuilder
    var notesSection: some View {
        HStack {
            Text("Notes").font(.headline)
            Spacer()
            Button { showingAddNote = true }
            label: { Image(systemName: "plus").font(.subheadline).foregroundColor(.primary) }
            Button { showingLinkNotes = true }
            label: { Image(systemName: "link").font(.subheadline).foregroundColor(.primary) }
        }

        if personNotes.isEmpty {
            Text("No notes yet")
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(personNotes) { note in
                    VStack(spacing: 0) {
                        NavigationLink(destination: NoteDetailView(note: note, notes: $notes, people: $people)) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.text).font(.body).foregroundColor(.primary).lineLimit(2)
                                    Text(note.date, style: .date).font(.caption).foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption).foregroundColor(.secondary)
                            }
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) { unlinkNote(note) }
                            label: { Label("Unlink", systemImage: "link.badge.xmark") }
                        }
                        if note.id != personNotes.last?.id {
                            Divider().padding(.leading)
                        }
                    }
                }
            }
        }
    }

    // MARK: Helpers

    func unlinkNote(_ note: Note) {
        if let index = notes.firstIndex(where: { $0.id == note.id }) {
            notes[index].personIds.removeAll { $0 == person.id }
        }
    }

    func requestContactsAccess() {
        CNContactStore().requestAccess(for: .contacts) { granted, _ in
            DispatchQueue.main.async {
                if granted { showingContactPicker = true }
            }
        }
    }

    func linkContact(_ contact: CNContact) {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
        let fullName = [contact.givenName, contact.familyName]
            .filter { !$0.isEmpty }.joined(separator: " ")
        
        people[index].contactIdentifier = contact.identifier
        people[index].cachedContactName = fullName
        people[index].cachedContactPhone = contact.phoneNumbers.first?.value.stringValue
        people[index].cachedContactEmails = contact.emailAddresses.map { $0.value as String }
        people[index].cachedContactAddresses = contact.postalAddresses.map {
            CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)
        }
        if let birthday = contact.birthday {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            if let date = Calendar.current.date(from: birthday) {
                people[index].cachedContactBirthday = formatter.string(from: date)
            }
        }
        people[index].cachedContactOrganization = contact.organizationName.isEmpty ? nil : contact.organizationName
        people[index].cachedContactJobTitle = contact.jobTitle.isEmpty ? nil : contact.jobTitle
        people[index].cachedContactURLs = contact.urlAddresses.map { $0.value as String }
        people[index].cachedContactNote = contact.note.isEmpty ? nil : contact.note
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            linkedContact = contact
        }
    }

    func unlinkContact() {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
        people[index].contactIdentifier = nil
        people[index].cachedContactName = nil
        people[index].cachedContactPhone = nil
        people[index].cachedContactEmails = nil
        people[index].cachedContactAddresses = nil
        people[index].cachedContactBirthday = nil
        people[index].cachedContactOrganization = nil
        people[index].cachedContactJobTitle = nil
        people[index].cachedContactURLs = nil
        people[index].cachedContactNote = nil
        linkedContact = nil
    }
    
    func removePhoto() {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
        people[index].photoData = nil
    }

    func loadContactInfo() {
        guard let contactId = people.first(where: { $0.id == person.id })?.contactIdentifier
        else { 
            linkedContact = nil
            return 
        }

        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactPostalAddressesKey as CNKeyDescriptor,
            CNContactBirthdayKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactJobTitleKey as CNKeyDescriptor,
            CNContactUrlAddressesKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor,
        ]
        do {
            let contact = try store.unifiedContact(withIdentifier: contactId, keysToFetch: keys)
            guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
            
            let fullName = [contact.givenName, contact.familyName]
                .filter { !$0.isEmpty }.joined(separator: " ")
            people[index].cachedContactName = fullName
            people[index].cachedContactPhone = contact.phoneNumbers.first?.value.stringValue
            people[index].cachedContactEmails = contact.emailAddresses.map { $0.value as String }
            people[index].cachedContactAddresses = contact.postalAddresses.map {
                CNPostalAddressFormatter.string(from: $0.value, style: .mailingAddress)
            }
            if let birthday = contact.birthday {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                if let date = Calendar.current.date(from: birthday) {
                    people[index].cachedContactBirthday = formatter.string(from: date)
                }
            }
            people[index].cachedContactOrganization = contact.organizationName.isEmpty ? nil : contact.organizationName
            people[index].cachedContactJobTitle = contact.jobTitle.isEmpty ? nil : contact.jobTitle
            people[index].cachedContactURLs = contact.urlAddresses.map { $0.value as String }
            people[index].cachedContactNote = contact.note.isEmpty ? nil : contact.note
            
            DispatchQueue.main.async { self.linkedContact = contact }
        } catch {
            DispatchQueue.main.async { self.linkedContact = nil }
        }
    }
}

// MARK: - Edit Person View

struct EditPersonView: View {
    let person: Person
    @Binding var people: [Person]
    @State private var editedName: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $editedName)
                        .font(.body)
                } header: {
                    Text("Basic Information")
                }
            }
            .navigationTitle("Edit Person")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePerson()
                        dismiss()
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                editedName = person.name
            }
        }
    }
    
    func savePerson() {
        guard let index = people.firstIndex(where: { $0.id == person.id }) else { return }
        people[index].name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Person Photo Picker

struct PersonPhotoPickerView: UIViewControllerRepresentable {
    let person: Person
    @Binding var people: [Person]
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate   = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PersonPhotoPickerView
        init(_ parent: PersonPhotoPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                let maxDimension: CGFloat = 1024
                let scale   = min(maxDimension / image.size.width,
                                  maxDimension / image.size.height, 1.0)
                let newSize = CGSize(width: image.size.width * scale,
                                    height: image.size.height * scale)
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                image.draw(in: CGRect(origin: .zero, size: newSize))
                let resized = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                if let index = parent.people.firstIndex(where: { $0.id == parent.person.id }) {
                    parent.people[index].photoData = resized?.jpegData(compressionQuality: 0.8)
                }
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Contact Picker

struct ContactPickerView: UIViewControllerRepresentable {
    var onSelectContact: (CNContact) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, CNContactPickerDelegate {
        let parent: ContactPickerView
        init(_ parent: ContactPickerView) { self.parent = parent }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            parent.onSelectContact(contact)
            parent.dismiss()
        }

        func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
            parent.dismiss()
        }
    }
}

// MARK: - Linked Contact Info View

struct LinkedContactInfoView: View {
    let contact: CNContact
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    let fullName = [contact.givenName, contact.familyName]
                        .filter { !$0.isEmpty }.joined(separator: " ")

                    if !fullName.isEmpty {
                        field(label: "Name") { Text(fullName).font(.title2).fontWeight(.semibold) }
                    }
                    if !contact.phoneNumbers.isEmpty {
                        field(label: "Phone") {
                            ForEach(contact.phoneNumbers, id: \.identifier) { phone in
                                HStack {
                                    Text(phone.value.stringValue).font(.body)
                                    Spacer()
                                    actionButton(icon: "phone.fill", url: "tel://\(cleaned(phone.value.stringValue))")
                                    actionButton(icon: "message.fill", url: "sms://\(cleaned(phone.value.stringValue))")
                                }
                            }
                        }
                    }
                    if !contact.emailAddresses.isEmpty {
                        field(label: "Email") {
                            ForEach(contact.emailAddresses, id: \.identifier) { email in
                                HStack {
                                    Text(email.value as String).font(.body)
                                    Spacer()
                                    actionButton(icon: "envelope.fill", url: "mailto:\(email.value)")
                                }
                            }
                        }
                    }
                    if !contact.postalAddresses.isEmpty {
                        field(label: "Address") {
                            ForEach(contact.postalAddresses, id: \.identifier) { item in
                                let a = item.value
                                HStack(alignment: .top) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        if !a.street.isEmpty     { Text(a.street) }
                                        HStack(spacing: 4) {
                                            if !a.city.isEmpty       { Text(a.city) }
                                            if !a.state.isEmpty      { Text(a.state) }
                                            if !a.postalCode.isEmpty { Text(a.postalCode) }
                                        }
                                        if !a.country.isEmpty    { Text(a.country) }
                                    }
                                    .font(.body)
                                    Spacer()
                                    actionButton(icon: "map.fill", url: mapURL(for: a))
                                }
                            }
                        }
                    }
                    if let bday = contact.birthday, let month = bday.month, let day = bday.day {
                        field(label: "Birthday") {
                            Text(bday.year.map { "\(month)/\(day)/\($0)" } ?? "\(month)/\(day)").font(.body)
                        }
                    }
                    if !contact.organizationName.isEmpty {
                        field(label: "Organization") { Text(contact.organizationName).font(.body) }
                    }
                    if !contact.jobTitle.isEmpty {
                        field(label: "Job Title") { Text(contact.jobTitle).font(.body) }
                    }
                    if !contact.urlAddresses.isEmpty {
                        field(label: "URLs") {
                            ForEach(contact.urlAddresses, id: \.identifier) { url in
                                HStack {
                                    Text(url.value as String).font(.body)
                                    Spacer()
                                    actionButton(icon: "safari.fill", url: httpsURL(url.value as String))
                                }
                            }
                        }
                    }
                    if !contact.note.isEmpty {
                        field(label: "Notes") { Text(contact.note).font(.body) }
                    }
                }
                .padding()
            }
            .background(Color.tactSecondaryBackground)
            .navigationTitle("Contact Info")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { dismiss() } label: { Image(systemName: "checkmark") }
                }
            }
        }
    }

    @ViewBuilder
    func field<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption).foregroundColor(.secondary)
            content()
        }
    }

    func actionButton(icon: String, url: String) -> some View {
        Button {
            if let u = URL(string: url) { UIApplication.shared.open(u) }
        } label: {
            Image(systemName: icon).foregroundColor(.primary)
        }
    }

    func cleaned(_ phone: String) -> String {
        phone.replacingOccurrences(of: " ", with: "")
             .replacingOccurrences(of: "-", with: "")
             .replacingOccurrences(of: "(", with: "")
             .replacingOccurrences(of: ")", with: "")
    }

    func mapURL(for address: CNPostalAddress) -> String {
        let parts = [address.street, address.city, address.state,
                     address.postalCode, address.country].filter { !$0.isEmpty }
        let encoded = parts.joined(separator: ", ")
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return "http://maps.apple.com/?address=\(encoded)"
    }

    func httpsURL(_ raw: String) -> String {
        raw.hasPrefix("http") ? raw : "https://\(raw)"
    }
}


// ============================================================
// MARK: - Note Screens
// ============================================================

// MARK: - Notes List View

struct NotesListView: View {
    @Binding var notes: [Note]
    @Binding var people: [Person]
    @State private var showingAddNote   = false
    @State private var newNoteText      = ""
    @State private var selectedPersonIds: Set<UUID> = []

    var sortedNotes: [Note] {
        notes.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedNotes) { note in
                    NoteWithPersonRow(note: note, people: $people, notes: $notes)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .onDelete { indexSet in
                    let toDelete = indexSet.map { sortedNotes[$0] }
                    notes.removeAll { note in toDelete.contains(where: { $0.id == note.id }) }
                }
            }
            .listStyle(.plain)
            .background(Color.tactBackground)
            .scrollContentBackground(.hidden)
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        selectedPersonIds = []
                        showingAddNote = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddNote) {
                addNoteSheet
            }
        }
    }

    var addNoteSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    Text("Select People").font(.headline)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
                        ForEach(people) { person in
                            Button {
                                if selectedPersonIds.contains(person.id) {
                                    selectedPersonIds.remove(person.id)
                                } else {
                                    selectedPersonIds.insert(person.id)
                                }
                            } label: {
                                person.gameType
                                    .tileView(for: person, squareSize: 60, settings: person.gameSettings)
                                    .frame(height: 60)
                                    .clipped()
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(selectedPersonIds.contains(person.id) ? Color.blue : Color.clear,
                                                    lineWidth: 3)
                                    )
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)

                    TextField("Note", text: $newNoteText, axis: .vertical)
                        .lineLimit(5...10)
                        .padding(.horizontal)
                }
                .padding()
            }
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newNoteText = ""
                        selectedPersonIds = []
                        showingAddNote = false
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard !newNoteText.isEmpty else { return }
                        notes.append(Note(personIds: Array(selectedPersonIds), text: newNoteText))
                        newNoteText = ""
                        selectedPersonIds = []
                        showingAddNote = false
                    }
                    .disabled(newNoteText.isEmpty)
                    .buttonStyle(.plain)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Note With Person Row

struct NoteWithPersonRow: View {
    let note: Note
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @State private var showingShareSheet = false

    var personNames: String? {
        let names = note.personIds.compactMap { id in
            people.first(where: { $0.id == id })?.name
        }
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    var body: some View {
        NavigationLink(destination: NoteDetailView(note: note, notes: $notes, people: $people)) {
            VStack(alignment: .leading, spacing: 4) {
                if let names = personNames {
                    Text(names).font(.caption).foregroundColor(.gray)
                }
                Text(note.text).font(.body).foregroundColor(.primary)
                Text(note.date, style: .date).font(.caption).foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.tactCardBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                showingShareSheet = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [note.text])
        }
    }
}

// MARK: - Note Detail View

struct NoteDetailView: View {
    let note: Note
    @Binding var notes: [Note]
    @Binding var people: [Person]
    @State private var editedText = ""
    @State private var selectedPersonIds: Set<UUID>
    @State private var showingDeleteAlert = false
    @State private var showingAddPerson  = false
    @State private var newPersonName     = ""
    @State private var showingShareSheet = false
    @Environment(\.dismiss) private var dismiss

    init(note: Note, notes: Binding<[Note]>, people: Binding<[Person]>) {
        self.note    = note
        self._notes  = notes
        self._people = people
        self._selectedPersonIds = State(initialValue: Set(note.personIds))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("People")
                    .font(.caption).foregroundColor(.gray).textCase(.uppercase)

                personPickerGrid

                Text("Note")
                    .font(.caption).foregroundColor(.gray).textCase(.uppercase)

                TextEditor(text: $editedText)
                    .frame(minHeight: 200)
                    .padding(8)

                Text("Created: \(note.date, style: .date)")
                    .font(.caption).foregroundColor(.gray)
            }
            .padding()
        }
        .navigationTitle("Edit Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingShareSheet = true }
                label: { Image(systemName: "square.and.arrow.up") }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) { showingDeleteAlert = true }
                label: { Image(systemName: "trash") }
            }
        }
        .onAppear    { editedText = note.text }
        .onDisappear { saveNote() }
        .onChange(of: selectedPersonIds) { _, _ in saveNote() }
        .alert("Delete Note", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                notes.removeAll { $0.id == note.id }
                dismiss()
            }
        }
        .alert("Add Person", isPresented: $showingAddPerson) {
            TextField("Name", text: $newPersonName)
            Button("Cancel", role: .cancel) { newPersonName = "" }
            Button("Add") {
                guard !newPersonName.isEmpty else { return }
                let newPerson = Person(name: newPersonName)
                people.append(newPerson)
                selectedPersonIds.insert(newPerson.id)
                newPersonName = ""
            }
        }
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(items: [note.text])
        }
    }

    var personPickerGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 4), spacing: 4) {
            // "None" button
            Button { selectedPersonIds.removeAll() } label: {
                ZStack {
                    Color.tactTileGray
                    Text("None").font(.caption).foregroundColor(.black)
                }
                .frame(height: 60)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(selectedPersonIds.isEmpty ? Color.black : Color.clear, lineWidth: 3)
                )
            }

            // "Add person" button
            Button { showingAddPerson = true } label: {
                ZStack {
                    Color.tactTileGray
                    Image(systemName: "plus").font(.title2).foregroundColor(.black)
                }
                .frame(height: 60)
            }

            ForEach(people) { person in
                Button {
                    if selectedPersonIds.contains(person.id) {
                        selectedPersonIds.remove(person.id)
                    } else {
                        selectedPersonIds.insert(person.id)
                    }
                } label: {
                    ZStack {
                        if let photoData = person.photoData,
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 60)
                                .clipped()
                        } else {
                            Color.tactCardBackground
                            Text(person.name)
                                .font(.caption2).foregroundColor(.primary)
                                .lineLimit(1).minimumScaleFactor(0.5).padding(4)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selectedPersonIds.contains(person.id) ? Color.black : Color.clear,
                                    lineWidth: 3)
                    )
                }
            }
        }
        .id(people.count)
        .buttonStyle(.plain)
    }

    func saveNote() {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index].text      = editedText
        notes[index].personIds = Array(selectedPersonIds)
    }
}

// MARK: - Add Note View

struct AddNoteView: View {
    let personId: UUID
    @Binding var notes: [Note]
    @State private var noteText = ""
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                TextEditor(text: $noteText)
                    .frame(minHeight: 300)
                    .padding(8)
                    .focused($isFocused)
            }
            .padding()
            .background(Color.tactSecondaryBackground)
            .navigationTitle("New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        guard !noteText.isEmpty else { return }
                        notes.append(Note(personIds: [personId], text: noteText))
                        dismiss()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(noteText.isEmpty)
                    .buttonStyle(.plain)
                }
            }
            .onAppear { isFocused = true }
        }
    }
}

// MARK: - Link Notes View

struct LinkNotesView: View {
    let person: Person
    @Binding var notes: [Note]
    let availableNotes: [Note]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if availableNotes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "link.badge.plus").font(.system(size: 60)).foregroundColor(.secondary)
                    Text("No notes to link").font(.headline).foregroundColor(.secondary)
                    Text("All notes are already linked to this person")
                        .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.tactSecondaryBackground)
            } else {
                List {
                    ForEach(availableNotes) { note in
                        Button { linkNote(note) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.text).font(.body).foregroundColor(.primary).lineLimit(2)
                                    Text(note.date, style: .date).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill").foregroundColor(.blue).font(.title3)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Link Notes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }.buttonStyle(.plain)
            }
        }
    }

    func linkNote(_ note: Note) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        if !notes[index].personIds.contains(person.id) {
            notes[index].personIds.append(person.id)
        }
    }
}


// ============================================================
// MARK: - Search
// ============================================================

// MARK: - Search View
// Real-time filtering across both people and notes as the user types.

struct SearchView: View {
    @Binding var people: [Person]
    @Binding var notes: [Note]
    @State private var searchText = ""

    var filteredPeople: [Person] {
        guard !searchText.isEmpty else { return [] }
        return people.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var filteredNotes: [Note] {
        guard !searchText.isEmpty else { return [] }
        return notes.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !searchText.isEmpty {
                        if !filteredPeople.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("People").font(.headline)
                                ForEach(filteredPeople) { person in
                                    NavigationLink(destination: PersonDetailView(person: person, people: $people, notes: $notes)) {
                                        Text(person.name)
                                            .foregroundColor(.primary)
                                            .padding()
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color.tactCardBackground)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if !filteredNotes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Notes").font(.headline)
                                ForEach(filteredNotes) { note in
                                    NavigationLink(destination: NoteDetailView(note: note, notes: $notes, people: $people)) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(note.text).font(.body).foregroundColor(.primary)
                                            Text(note.date, style: .date).font(.caption).foregroundColor(.gray)
                                        }
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.tactCardBackground)
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if filteredPeople.isEmpty && filteredNotes.isEmpty {
                            Text("No results found")
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 40)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "Search people and notes")
        }
    }
}


// ============================================================
// MARK: - Utilities
// ============================================================

// MARK: - Share Sheet
// Wraps UIActivityViewController so any view can share text
// via the system share sheet.

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}