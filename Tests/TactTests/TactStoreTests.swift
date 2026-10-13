import XCTest
@testable import Tact

final class TactStoreTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!
    private var store: TactStore!

    override func setUp() {
        super.setUp()
        directory = TestSupport.temporaryDirectory()
        defaults = TestSupport.defaults()
        store = TestSupport.makeStore(directory: directory, defaults: defaults)
    }

    func testAddPersonTrimsAndRejectsBlankNames() {
        XCTAssertNil(store.addPerson(named: "   \n"))
        let person = store.addPerson(named: "  Ada  ")
        XCTAssertEqual(person?.name, "Ada")
        XCTAssertEqual(store.people.map(\.name), ["Ada"])
    }

    func testDeletingAPersonKeepsSharedNotesAndDeletesExclusiveOnes() {
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        let shared = store.addNote(text: "Both", personIds: [ada.id, grace.id])!
        let onlyAda = store.addNote(text: "Only Ada", personIds: [ada.id])!
        let unlinked = store.addNote(text: "Nobody")!

        store.deletePerson(id: ada.id)

        XCTAssertEqual(store.people.map(\.id), [grace.id])
        XCTAssertNil(store.note(id: onlyAda.id))
        XCTAssertEqual(store.note(id: shared.id)?.personIds, [grace.id])
        XCTAssertNotNil(store.note(id: unlinked.id))
    }

    func testNotePersonIdsFollowPeopleOrderWithoutDuplicates() {
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        let note = store.addNote(text: "Hi", personIds: [grace.id, ada.id, grace.id])!
        XCTAssertEqual(note.personIds, [ada.id, grace.id])

        store.movePeople(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        store.updateNote(id: note.id, text: "Hi", personIds: Set([ada.id, grace.id]))
        XCTAssertEqual(store.note(id: note.id)?.personIds, [grace.id, ada.id])
    }

    func testLinkAndUnlinkNotes() {
        let ada = store.addPerson(named: "Ada")!
        let note = store.addNote(text: "Hi")!
        store.linkNote(id: note.id, toPersonID: ada.id)
        XCTAssertEqual(store.notes(for: ada.id).map(\.id), [note.id])
        store.linkNote(id: note.id, toPersonID: ada.id)
        XCTAssertEqual(store.note(id: note.id)?.personIds.count, 1)
        store.unlinkNote(id: note.id, fromPersonID: ada.id)
        XCTAssertEqual(store.noteCount(for: ada.id), 0)
        XCTAssertNotNil(store.note(id: note.id))
    }

    func testContactLinking() {
        let ada = store.addPerson(named: "Ada")!
        let snapshot = ContactSnapshot(name: "Ada Lovelace", phones: ["555"])
        store.linkContact(toPersonID: ada.id, identifier: "ID", snapshot: snapshot)
        XCTAssertEqual(store.person(id: ada.id)?.contact, snapshot)
        XCTAssertTrue(store.person(id: ada.id)!.hasLinkedContact)
        store.unlinkContact(fromPersonID: ada.id)
        XCTAssertNil(store.person(id: ada.id)?.contact)
        XCTAssertFalse(store.person(id: ada.id)!.hasLinkedContact)
        store.updateContact(forPersonID: ada.id, snapshot: snapshot)
        XCTAssertNil(store.person(id: ada.id)?.contact, "updates are ignored once unlinked")
    }

    func testChangesSurviveReload() {
        let ada = store.addPerson(named: "Ada")!
        store.updatePhoto(forPersonID: ada.id, data: TestSupport.jpeg())
        store.addNote(text: "Remember this", personIds: [ada.id])
        store.settings.randomColorSettings.palette = .earth
        store.flush(waitUntilDone: true)

        let reloaded = TestSupport.makeStore(directory: directory, defaults: defaults)
        XCTAssertEqual(reloaded.people, store.people)
        XCTAssertEqual(reloaded.notes, store.notes)
        XCTAssertEqual(reloaded.settings, store.settings)
    }

    func testDebouncedSaveEventuallyWrites() {
        let slowStore = TactStore(persistence: PersistenceController(directory: directory), defaults: defaults, saveDelay: 0.05)
        slowStore.addPerson(named: "Ada")
        let peopleURL = directory.appendingPathComponent("people.json")
        let expectation = expectation(description: "people.json written")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            slowStore.flush(waitUntilDone: true)
            if FileManager.default.fileExists(atPath: peopleURL.path) { expectation.fulfill() }
        }
        wait(for: [expectation], timeout: 2)
    }
}
