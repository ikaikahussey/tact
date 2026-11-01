import XCTest
@testable import Tact

final class DittyTests: XCTestCase {
    func testDefaultFromSeedIsStableShortAndOnThePads() {
        for seed in [0, 1, 17, 359, 4096, -5, Int.max, Int.min + 1] {
            let a = Ditty(seed: seed), b = Ditty(seed: seed)
            XCTAssertEqual(a, b, "seed \(seed) is stable")
            XCTAssertTrue((3...5).contains(a.notes.count), "seed \(seed) gives three to five notes")
            XCTAssertTrue(a.notes.allSatisfy { (0..<Ditty.degreeCount).contains($0.degree) }, "seed \(seed) stays on the pads")
            XCTAssertEqual(a.notes.last?.beats, 2, "seed \(seed) holds the last note")
            XCTAssertTrue(a.notes.dropLast().allSatisfy { $0.beats == 1 })
        }
        XCTAssertNotEqual(Ditty(seed: 1), Ditty(seed: 2))
    }

    func testDefaultsAreMostlyDistinct() {
        let ditties = Set((0..<360).map(Ditty.init(seed:)))
        XCTAssertGreaterThan(ditties.count, 300, "the 360 possible seeds give well over 300 motifs")
    }

    func testNotesAreCappedAndClamped() {
        var ditty = Ditty(notes: (0..<12).map { Ditty.Note(degree: $0) })
        XCTAssertEqual(ditty.notes.count, Ditty.maxNotes)
        XCTAssertTrue(ditty.isFull)
        ditty.append(degree: 3)
        XCTAssertEqual(ditty.notes.count, Ditty.maxNotes, "a full ditty ignores more notes")
        ditty.removeLast()
        XCTAssertFalse(ditty.isFull)
        ditty.append(degree: 99, beats: 9)
        XCTAssertEqual(ditty.notes.last, Ditty.Note(degree: Ditty.degreeCount - 1, beats: Ditty.maxBeats))
        XCTAssertEqual(Ditty.Note(degree: -4, beats: 0), Ditty.Note(degree: 0, beats: 1))
    }

    func testScheduleAndNamesFollowTheTuning() {
        let ditty = Ditty(notes: [Ditty.Note(degree: 0), Ditty.Note(degree: 2), Ditty.Note(degree: 4, beats: 2)])
        XCTAssertEqual(ditty.beats, 4)
        XCTAssertEqual(ditty.duration, 4 * Ditty.beatSeconds, accuracy: 1e-9)
        XCTAssertEqual(ditty.noteNames(tuning: .standard), "C4 E4 A4")
        var tuning = SimonTuning.standard
        tuning.key = SimonKey(semitone: 7)
        XCTAssertEqual(ditty.noteNames(tuning: tuning), "G4 B4 E5", "a new key transposes the ditty")

        let schedule = ditty.schedule(tuning: .standard)
        XCTAssertEqual(schedule.map(\.start), [0, Ditty.beatSeconds, 2 * Ditty.beatSeconds])
        XCTAssertEqual(schedule[0].frequency, 261.6256, accuracy: 1e-3)
        XCTAssertEqual(schedule[2].duration, 2 * Ditty.beatSeconds * 0.85, accuracy: 1e-9)
        XCTAssertTrue(ditty.schedule(tuning: .standard).allSatisfy { $0.duration < Ditty.beatSeconds * Double(Ditty.maxBeats) },
                      "notes leave a gap before the next one")
    }

    func testCodingRoundTripsAndToleratesBadValues() throws {
        let ditty = Ditty(notes: [Ditty.Note(degree: 5, beats: 2), Ditty.Note(degree: 1)])
        let data = try JSONEncoder().encode(ditty)
        XCTAssertEqual(try JSONDecoder().decode(Ditty.self, from: data), ditty)

        let bad = Data("""
        {"notes":[{"degree":40,"beats":7},{"beats":1},{"degree":2}]}
        """.utf8)
        let decoded = try JSONDecoder().decode(Ditty.self, from: bad)
        XCTAssertEqual(decoded.notes, [Ditty.Note(degree: 15, beats: 2), Ditty.Note(degree: 0), Ditty.Note(degree: 2)])
        XCTAssertEqual(try JSONDecoder().decode(Ditty.self, from: Data("{}".utf8)).notes, [])
    }

    func testPersonFallsBackToTheSeedDitty() throws {
        var person = Person(name: "Ada", colorSeed: 42)
        XCTAssertNil(person.ditty)
        XCTAssertEqual(person.resolvedDitty, Ditty(seed: 42))

        person.ditty = Ditty(notes: [])
        XCTAssertEqual(person.resolvedDitty, Ditty(seed: 42), "an empty ditty is the default")

        person.ditty = Ditty(notes: [Ditty.Note(degree: 7)])
        XCTAssertEqual(person.resolvedDitty.notes.count, 1)

        let data = try JSONEncoder().encode(person)
        let decoded = try JSONDecoder().decode(Person.self, from: data)
        XCTAssertEqual(decoded.ditty, person.ditty)

        // People saved before ditties existed decode without one.
        let legacy = Data("""
        {"id":"\(UUID().uuidString)","name":"Old","imageSection":3}
        """.utf8)
        XCTAssertNil(try JSONDecoder().decode(Person.self, from: legacy).ditty)
    }

    func testStoreUpdatesDittiesAndFindsTwins() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada")!
        let bob = store.addPerson(named: "Bob")!
        let tune = Ditty(notes: [Ditty.Note(degree: 1), Ditty.Note(degree: 3, beats: 2)])
        store.updateDitty(forPersonID: ada.id, tune)
        XCTAssertEqual(store.person(id: ada.id)?.ditty, tune)
        XCTAssertTrue(store.peopleSharingDitty(with: ada.id).isEmpty)

        store.updateDitty(forPersonID: bob.id, tune)
        XCTAssertEqual(store.peopleSharingDitty(with: ada.id).map(\.id), [bob.id])

        store.updateDitty(forPersonID: bob.id, Ditty(notes: []))
        XCTAssertNil(store.person(id: bob.id)?.ditty, "an empty ditty clears the recording")
        store.updateDitty(forPersonID: ada.id, nil)
        XCTAssertNil(store.person(id: ada.id)?.ditty)
    }

    func testOutlineListsTheDitty() {
        let ada = Person(name: "Ada", colorSeed: 7)
        let outline = OutlineExporter.outline(people: [ada], notes: [], tuning: .standard)
        XCTAssertTrue(outline.contains("  Ditty: \(Ditty(seed: 7).noteNames(tuning: .standard))"))
    }
}
