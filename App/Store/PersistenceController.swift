import CryptoKit
import Foundation
import os

/// Everything the app persists.
struct PersistedData: Equatable {
    var people: [Person] = []
    var notes: [Note] = []
    var settings = GameTypeSettings()
}

/// Reads and writes the app's data as JSON files, plus one JPEG per person photo,
/// inside Application Support. Writes are atomic so a crash mid-save never
/// leaves a half-written file behind.
///
/// Not thread-safe: `TactStore` serializes all calls on one queue.
final class PersistenceController {
    static let legacyPeopleKey = "people"
    static let legacyNotesKey = "notes"

    let directory: URL
    private let photosDirectory: URL
    private let peopleURL: URL
    private let notesURL: URL
    private let settingsURL: URL
    /// Fingerprint of the photo bytes last written for each person, so unchanged
    /// photos are not rewritten on every save.
    private var photoSignatures: [UUID: Int] = [:]
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tact", category: "Persistence")

    static var defaultDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Tact", isDirectory: true)
    }

    init(directory: URL = PersistenceController.defaultDirectory) {
        self.directory = directory
        photosDirectory = directory.appendingPathComponent("Photos", isDirectory: true)
        peopleURL = directory.appendingPathComponent("people.json")
        notesURL = directory.appendingPathComponent("notes.json")
        settingsURL = directory.appendingPathComponent("settings.json")
        do {
            try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        } catch {
            log.error("Could not create data directory: \(error.localizedDescription, privacy: .public)")
        }
    }

    var hasSavedData: Bool {
        [peopleURL, notesURL, settingsURL].contains { FileManager.default.fileExists(atPath: $0.path) }
    }

    // MARK: Loading

    /// Loads saved data. If nothing has been saved yet and `defaults` still holds
    /// data from the UserDefaults-based 1.0 format, that data is migrated first.
    func load(migratingFrom defaults: UserDefaults? = nil) -> PersistedData {
        if !hasSavedData, let defaults, let legacy = Self.legacyData(from: defaults) {
            do {
                try save(legacy)
                defaults.removeObject(forKey: Self.legacyPeopleKey)
                defaults.removeObject(forKey: Self.legacyNotesKey)
                log.notice("Migrated legacy data: \(legacy.people.count) people, \(legacy.notes.count) notes")
            } catch {
                log.error("Legacy migration failed: \(error.localizedDescription, privacy: .public)")
            }
            return legacy
        }

        var data = PersistedData()
        data.people = decode([Person].self, from: peopleURL) ?? []
        attachPhotos(to: &data.people)
        data.notes = decode([Note].self, from: notesURL) ?? []
        data.settings = decode(GameTypeSettings.self, from: settingsURL) ?? GameTypeSettings()
        return data
    }

    // MARK: Saving

    func save(_ data: PersistedData) throws {
        try savePeople(data.people)
        try saveNotes(data.notes)
        try saveSettings(data.settings)
    }

    func savePeople(_ people: [Person]) throws {
        let encoder = Self.makeEncoder()
        encoder.userInfo[.excludesPhotoData] = true
        try encoder.encode(people).write(to: peopleURL, options: .atomic)
        try syncPhotos(for: people)
    }

    func saveNotes(_ notes: [Note]) throws {
        try Self.makeEncoder().encode(notes).write(to: notesURL, options: .atomic)
    }

    func saveSettings(_ settings: GameTypeSettings) throws {
        try Self.makeEncoder().encode(settings).write(to: settingsURL, options: .atomic)
    }

    // MARK: Photos

    private func photoURL(for personID: UUID) -> URL {
        photosDirectory.appendingPathComponent(personID.uuidString).appendingPathExtension("jpg")
    }

    private func syncPhotos(for people: [Person]) throws {
        var keep = Set<UUID>()
        for person in people {
            guard let data = person.photoData else { continue }
            keep.insert(person.id)
            let signature = data.fingerprint
            if photoSignatures[person.id] != signature {
                try data.write(to: photoURL(for: person.id), options: .atomic)
                photoSignatures[person.id] = signature
            }
        }

        let fileManager = FileManager.default
        let existing = (try? fileManager.contentsOfDirectory(at: photosDirectory, includingPropertiesForKeys: nil)) ?? []
        for url in existing {
            guard let id = UUID(uuidString: url.deletingPathExtension().lastPathComponent) else { continue }
            if !keep.contains(id) {
                try? fileManager.removeItem(at: url)
                photoSignatures[id] = nil
            }
        }
    }

    private func attachPhotos(to people: inout [Person]) {
        for index in people.indices {
            let id = people[index].id
            if let data = try? Data(contentsOf: photoURL(for: id)) {
                people[index].photoData = data
                photoSignatures[id] = data.fingerprint
            }
        }
    }

    // MARK: Codable helpers

    static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static func makeDecoder() -> JSONDecoder {
        JSONDecoder()
    }

    /// Decodes a file, or returns `nil` when it does not exist. A file that
    /// exists but cannot be decoded is moved aside rather than overwritten, so
    /// the user's data can still be recovered.
    private func decode<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        do {
            return try Self.makeDecoder().decode(T.self, from: data)
        } catch {
            log.error("Could not decode \(url.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
            let backup = url.appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970))")
            try? FileManager.default.moveItem(at: url, to: backup)
            return nil
        }
    }

    // MARK: Legacy (1.0) format

    /// Version 1.0 stored both arrays as JSON blobs in UserDefaults, with the
    /// game settings (including the Art photo) copied into every person.
    static func legacyData(from defaults: UserDefaults) -> PersistedData? {
        let peopleData = defaults.data(forKey: legacyPeopleKey)
        let notesData = defaults.data(forKey: legacyNotesKey)
        guard peopleData != nil || notesData != nil else { return nil }

        let decoder = makeDecoder()
        var result = PersistedData()
        if let peopleData {
            result.people = (try? decoder.decode([Person].self, from: peopleData)) ?? []
            if let legacy = try? decoder.decode([LegacyPersonSettings].self, from: peopleData) {
                let all = legacy.compactMap(\.gameSettings)
                result.settings = all.first ?? GameTypeSettings()
            }
        }
        if let notesData {
            result.notes = (try? decoder.decode([Note].self, from: notesData)) ?? []
        }
        return result
    }

    private struct LegacyPersonSettings: Decodable {
        var gameSettings: GameTypeSettings?
    }
}

extension Data {
    /// Stable identity for cache keys and change detection: the leading 64 bits
    /// of the SHA-256 digest of the bytes. Identical across launches.
    var fingerprint: Int {
        let digest = SHA256.hash(data: self)
        return digest.withUnsafeBytes { $0.load(as: Int.self) }
    }
}
