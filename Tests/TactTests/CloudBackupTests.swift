import Combine
import XCTest
@testable import Tact

/// Uses plain temporary folders in place of the iCloud container.
final class CloudBackupTests: XCTestCase {
    private func makeBackup(_ directory: URL) -> CloudBackup {
        let backup = CloudBackup(directory: directory)
        backup.emptyListingWait = 0
        backup.downloadTimeout = 1
        return backup
    }

    func testPlaceholderNamesMapToTheRealFile() {
        XCTAssertEqual(CloudBackup.logicalName(".people.json.icloud"), "people.json")
        XCTAssertEqual(CloudBackup.logicalName("people.json"), "people.json")
        XCTAssertEqual(CloudBackup.logicalName(".icloud"), ".icloud")
    }

    func testMirrorCopiesDataAndRemovesDeletedPhotos() throws {
        let local = TestSupport.temporaryDirectory()
        let cloud = TestSupport.temporaryDirectory()
        let controller = PersistenceController(directory: local)
        let ada = Person(name: "Ada", photoData: TestSupport.jpeg())
        try controller.save(PersistedData(people: [ada], notes: [Note(text: "Hi")]))

        let backup = makeBackup(cloud)
        try backup.mirror(from: local)
        let photo = cloud.appendingPathComponent("Photos/\(ada.id.uuidString).jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: photo.path))
        XCTAssertEqual(PersistenceController(directory: cloud).load().people.map(\.name), ["Ada"])

        try controller.savePeople([])
        try backup.mirror(from: local)
        XCTAssertFalse(FileManager.default.fileExists(atPath: photo.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: cloud.appendingPathComponent("notes.json").path))
    }

    func testRestoreCopiesBackupIntoDestination() throws {
        let cloud = TestSupport.temporaryDirectory()
        let data = PersistedData(people: [Person(name: "Grace", photoData: TestSupport.jpeg())], notes: [Note(text: "Navy")])
        try PersistenceController(directory: cloud).save(data)

        let backup = makeBackup(cloud)
        XCTAssertTrue(backup.hasBackup())
        let destination = TestSupport.temporaryDirectory()
        try backup.restore(into: destination)
        XCTAssertEqual(PersistenceController(directory: destination).load(), data)
    }

    func testEmptyFolderIsNotABackup() {
        XCTAssertFalse(makeBackup(TestSupport.temporaryDirectory()).hasBackup())
    }

    func testExistingDataIsBackedUpOnLaunch() throws {
        let local = TestSupport.temporaryDirectory()
        let cloud = TestSupport.temporaryDirectory()
        try PersistenceController(directory: local).save(PersistedData(people: [Person(name: "Ada")]))

        let store = makeStore(local: local, cloud: cloud, defaults: TestSupport.defaults())
        waitUntilOn(store)
        store.flush(waitUntilDone: true)
        XCTAssertEqual(PersistenceController(directory: cloud).load().people.map(\.name), ["Ada"])
    }

    func testReinstallRestoresFromBackupAndKeepsNewEdits() throws {
        let cloud = TestSupport.temporaryDirectory()
        let first = makeStore(local: TestSupport.temporaryDirectory(), cloud: cloud, defaults: TestSupport.defaults())
        waitUntilOn(first)
        let ada = first.addPerson(named: "Ada")!
        first.updatePhoto(forPersonID: ada.id, data: TestSupport.jpeg())
        first.addNote(text: "Met at the conference", personIds: [ada.id])
        first.flush(waitUntilDone: true)

        // A fresh install: empty sandbox and defaults, same iCloud container.
        let second = makeStore(local: TestSupport.temporaryDirectory(), cloud: cloud, defaults: TestSupport.defaults())
        second.addPerson(named: "Grace")
        waitUntilOn(second)
        XCTAssertEqual(Set(second.people.map(\.name)), ["Ada", "Grace"])
        XCTAssertNotNil(second.person(id: ada.id)?.photoData)
        XCTAssertEqual(second.notes.map(\.text), ["Met at the conference"])

        second.flush(waitUntilDone: true)
        XCTAssertEqual(Set(PersistenceController(directory: cloud).load().people.map(\.name)), ["Ada", "Grace"])
    }

    func testBackupIsMergedOnlyOncePerInstall() throws {
        let cloud = TestSupport.temporaryDirectory()
        try PersistenceController(directory: cloud).save(PersistedData(people: [Person(name: "Ada")]))
        let local = TestSupport.temporaryDirectory()
        let defaults = TestSupport.defaults()

        let store = makeStore(local: local, cloud: cloud, defaults: defaults)
        waitUntilOn(store)
        store.deletePerson(id: store.people[0].id)
        store.flush(waitUntilDone: true)

        let relaunched = makeStore(local: local, cloud: cloud, defaults: defaults)
        waitUntilOn(relaunched)
        XCTAssertTrue(relaunched.people.isEmpty, "deleted person came back from the backup")
    }

    func testNoICloudLeavesBackupOff() {
        let store = TactStore(
            persistence: PersistenceController(directory: TestSupport.temporaryDirectory()),
            defaults: TestSupport.defaults(),
            saveDelay: 0,
            backup: { nil }
        )
        let expectation = expectation(description: "unavailable")
        let cancellable = store.$backupStatus.first { $0 == .unavailable }.sink { _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 5)
        cancellable.cancel()
    }

    // MARK: Helpers

    private func makeStore(local: URL, cloud: URL, defaults: UserDefaults) -> TactStore {
        TactStore(
            persistence: PersistenceController(directory: local),
            defaults: defaults,
            saveDelay: 0,
            backup: { [unowned self] in self.makeBackup(cloud) }
        )
    }

    private func waitUntilOn(_ store: TactStore) {
        let expectation = expectation(description: "backup on")
        let cancellable = store.$backupStatus.first { $0 == .on }.sink { _ in expectation.fulfill() }
        wait(for: [expectation], timeout: 5)
        cancellable.cancel()
    }
}
