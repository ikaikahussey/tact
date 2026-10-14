import XCTest
@testable import Tact

final class PersistenceTests: XCTestCase {
    func testRoundTripStoresPhotosAsSeparateFiles() throws {
        let directory = TestSupport.temporaryDirectory()
        let controller = PersistenceController(directory: directory)
        let photo = TestSupport.jpeg()
        var data = PersistedData()
        data.people = [Person(name: "Ada", photoData: photo), Person(name: "Grace")]
        data.notes = [Note(personIds: [data.people[0].id], text: "Met at the conference")]
        data.settings.randomColorSettings.palette = .sunset
        try controller.save(data)

        let peopleJSON = try String(contentsOf: directory.appendingPathComponent("people.json"), encoding: .utf8)
        XCTAssertFalse(peopleJSON.contains("photoData"), "photo bytes must not be inlined in people.json")
        let photoFile = directory.appendingPathComponent("Photos/\(data.people[0].id.uuidString).jpg")
        XCTAssertEqual(try Data(contentsOf: photoFile), photo)

        let reloaded = PersistenceController(directory: directory).load()
        XCTAssertEqual(reloaded, data)
    }

    func testRemovingAPersonDeletesTheirPhotoFile() throws {
        let directory = TestSupport.temporaryDirectory()
        let controller = PersistenceController(directory: directory)
        let person = Person(name: "Ada", photoData: TestSupport.jpeg())
        try controller.savePeople([person])
        let photoFile = directory.appendingPathComponent("Photos/\(person.id.uuidString).jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: photoFile.path))

        try controller.savePeople([])
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoFile.path))
    }

    func testCorruptFileIsMovedAsideInsteadOfOverwritten() throws {
        let directory = TestSupport.temporaryDirectory()
        let peopleURL = directory.appendingPathComponent("people.json")
        try "not json".data(using: .utf8)!.write(to: peopleURL)

        let loaded = PersistenceController(directory: directory).load()
        XCTAssertTrue(loaded.people.isEmpty)
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertTrue(files.contains { $0.hasPrefix("people.json.corrupt-") }, "backup missing: \(files)")
        XCTAssertFalse(FileManager.default.fileExists(atPath: peopleURL.path))
    }

    func testMigratesLegacyUserDefaultsData() throws {
        let directory = TestSupport.temporaryDirectory()
        let defaults = TestSupport.defaults()
        let artPhoto = TestSupport.jpeg(color: .blue)
        let personID = UUID()
        let legacyPeople = """
        [{"id":"\(personID.uuidString)","name":"Ada","imageSection":2,"gameType":"people",
          "gameSettings":{"randomColorSettings":{"palette":"Neon"},"peopleSettings":{},"flashcardSettings":{},
                          "artSettings":{"imageData":"\(artPhoto.base64EncodedString())","tileCount":1}},
          "photoData":"\(TestSupport.jpeg().base64EncodedString())"}]
        """.data(using: .utf8)!
        let legacyNotes = try JSONEncoder().encode([Note(personIds: [personID], text: "Legacy note")])
        defaults.set(legacyPeople, forKey: PersistenceController.legacyPeopleKey)
        defaults.set(legacyNotes, forKey: PersistenceController.legacyNotesKey)

        let loaded = PersistenceController(directory: directory).load(migratingFrom: defaults)
        XCTAssertEqual(loaded.people.map(\.name), ["Ada"])
        XCTAssertNotNil(loaded.people[0].photoData)
        XCTAssertEqual(loaded.notes.map(\.text), ["Legacy note"])
        XCTAssertEqual(loaded.settings.randomColorSettings.palette, .neon)

        // Migrated once: the legacy keys are gone and the files are the source of truth now.
        XCTAssertNil(defaults.data(forKey: PersistenceController.legacyPeopleKey))
        XCTAssertNil(defaults.data(forKey: PersistenceController.legacyNotesKey))
        XCTAssertEqual(PersistenceController(directory: directory).load(migratingFrom: defaults), loaded)
    }

    func testLayoutPreferenceMigration() {
        let defaults = TestSupport.defaults()
        defaults.set(false, forKey: "isListMode")
        defaults.set("randomColor", forKey: "selectedGameType")
        TactStore.migrateLayoutPreference(in: defaults)
        XCTAssertEqual(defaults.string(forKey: PeopleLayout.storageKey), PeopleLayout.colors.rawValue)
        XCTAssertNil(defaults.object(forKey: "isListMode"))

        let untouched = TestSupport.defaults()
        TactStore.migrateLayoutPreference(in: untouched)
        XCTAssertNil(untouched.object(forKey: PeopleLayout.storageKey))
    }
}
