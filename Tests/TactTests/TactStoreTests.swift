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

    func testAddPersonTakesAChosenColorAndPattern() {
        let chosen = store.addPerson(named: "Ada", colorIndex: 3, pattern: .petals)!
        XCTAssertEqual(chosen.tile.colorIndex, 3)
        XCTAssertEqual(chosen.tilePattern, .petals)
        XCTAssertEqual(store.person(id: chosen.id)?.tilePattern, .petals, "the choice is kept in the store")
        let plain = store.addPerson(named: "Grace")!
        XCTAssertEqual(plain.tile, TileArt(seed: plain.colorSeed), "with nothing chosen the tile comes from the seed as before")
    }

    func testUpdatingSeveralTilesAtOnce() {
        let ada = store.addPerson(named: "Ada", colorIndex: 1, pattern: .arcs)!
        let bob = store.addPerson(named: "Bob", colorIndex: 2, pattern: .cross)!
        let cy = store.addPerson(named: "Cy", colorIndex: 3, pattern: .frame)!
        store.updateTiles(forPersonIDs: [ada.id, cy.id, UUID()]) { $0.colorIndex = 9; $0.rotate() }
        XCTAssertEqual(store.person(id: ada.id)?.tile.colorIndex, 9)
        XCTAssertEqual(store.person(id: cy.id)?.tile.colorIndex, 9)
        XCTAssertEqual(store.person(id: cy.id)?.tile.quarterTurns, cy.tile.quarterTurns + 1)
        XCTAssertEqual(store.person(id: bob.id)?.tile, bob.tile, "the unselected tile is untouched")
        XCTAssertEqual(store.people.map(\.id), [ada.id, bob.id, cy.id], "order is kept")

        var bits = FatBits.cross
        bits[0, 0] = 3
        let saved = store.savePattern(bits, named: "Shared")!
        store.applyPattern(id: saved.id, toPersonIDs: [ada.id, bob.id])
        XCTAssertEqual(store.person(id: ada.id)?.tile.bits, bits)
        XCTAssertEqual(store.person(id: bob.id)?.tile.bits, bits)
        XCTAssertEqual(store.person(id: bob.id)?.tile.colorIndex, 2, "each keeps their own colour")
        XCTAssertNil(store.person(id: cy.id)?.tile.bits)

        let before = store.people
        store.updateTiles(forPersonIDs: []) { $0.colorIndex = 0 }
        XCTAssertEqual(store.people, before, "nothing selected changes nothing")
    }

    func testDeletingSeveralPeopleKeepsSharedNotesAndDeletesExclusiveOnes() {
        let ada = store.addPerson(named: "Ada")!
        let bob = store.addPerson(named: "Bob")!
        let cy = store.addPerson(named: "Cy")!
        let adaOnly = store.addNote(text: "Ada", personIds: [ada.id])!
        let adaBob = store.addNote(text: "Ada and Bob", personIds: [ada.id, bob.id])!
        let adaCy = store.addNote(text: "Ada and Cy", personIds: [ada.id, cy.id])!
        let loose = store.addNote(text: "Nobody", personIds: [])!
        store.deletePeople(ids: [ada.id, bob.id, UUID()])
        XCTAssertEqual(store.people.map(\.id), [cy.id])
        XCTAssertEqual(Set(store.notes.map(\.id)), [adaCy.id, loose.id])
        XCTAssertEqual(store.note(id: adaCy.id)?.personIds, [cy.id], "unlinked from the deleted")
        XCTAssertFalse(store.notes.contains { $0.id == adaOnly.id || $0.id == adaBob.id })
        let count = store.people.count
        store.deletePeople(ids: [])
        XCTAssertEqual(store.people.count, count)
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

    func testModifiedDateMovesOnlyWhenSomethingChanges() {
        let ada = store.addPerson(named: "Ada")!
        let note = store.addNote(text: "Hi", personIds: [ada.id])!
        XCTAssertEqual(note.modifiedDate, note.date)
        XCTAssertFalse(note.wasEdited)

        let later = note.date.addingTimeInterval(600)
        store.updateNote(id: note.id, text: "Hi", personIds: [ada.id], now: later)
        XCTAssertEqual(store.note(id: note.id)?.modifiedDate, note.date, "no-op must not bump")

        store.updateNote(id: note.id, text: "Hi there", personIds: [ada.id], now: later)
        XCTAssertEqual(store.note(id: note.id)?.modifiedDate, later)
        XCTAssertTrue(store.note(id: note.id)!.wasEdited)

        let yesterday = Date(timeIntervalSinceNow: -86_400)
        store.setNoteDate(id: note.id, to: yesterday)
        XCTAssertEqual(store.note(id: note.id)?.date, yesterday)
        XCTAssertEqual(store.note(id: note.id)?.modifiedDate, later, "changing the date is not an edit")
        XCTAssertEqual(store.title(for: store.note(id: note.id)!), "Ada")
        XCTAssertEqual(store.title(for: Note(text: "x", date: Date(timeIntervalSince1970: 0))),
                       Date(timeIntervalSince1970: 0).formatted(date: .abbreviated, time: .omitted))
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

    func testSettingTangramPositionsMovesOnlyThePiecesGiven() {
        let ada = store.addPerson(named: "Ada")!
        let grace = store.addPerson(named: "Grace")!
        store.setTangramPositions([ada.id: .init(x: 2, y: 3)])
        XCTAssertEqual(store.person(id: ada.id)?.tangram.position, .init(x: 2, y: 3))
        XCTAssertNil(store.person(id: grace.id)?.tangram.position)
        XCTAssertEqual(store.person(id: ada.id)?.tangram.shape, ada.tangram.shape, "the piece itself is untouched")
    }
}
