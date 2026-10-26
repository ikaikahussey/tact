import XCTest
@testable import Tact

final class NoteTagsTests: XCTestCase {
    func testTagsAreHashtagsInTheText() {
        XCTAssertEqual(NoteTags.tags(in: "Met at #work, talk about #follow-up and #Q3_plans"), ["work", "follow-up", "Q3_plans"])
        XCTAssertEqual(NoteTags.tags(in: "#Birthday is in May #birthday"), ["Birthday"], "once each, case-insensitively, as first typed")
        XCTAssertEqual(NoteTags.tags(in: "Likes C# and a#b"), [], "a # inside a word is not a tag")
        XCTAssertEqual(NoteTags.tags(in: "(#party) #café!"), ["party", "café"], "punctuation around and accents inside are fine")
        XCTAssertEqual(NoteTags.tags(in: "# not a tag"), [])
        XCTAssertEqual(NoteTags.tags(in: ""), [])
    }

    func testNoteKnowsItsTags() {
        let note = Note(text: "Coffee #work #Coffee")
        XCTAssertEqual(note.tags, ["work", "Coffee"])
        XCTAssertTrue(note.hasTag("coffee"))
        XCTAssertFalse(note.hasTag("cof"), "exact, not prefix")
    }

    func testTagQueries() {
        XCTAssertTrue(NoteTags.isTagQuery("#work"))
        XCTAssertFalse(NoteTags.isTagQuery("work"))
        XCTAssertEqual(NoteTags.queryTag("#Work "), "work")
        XCTAssertNil(NoteTags.queryTag("#"), "nothing typed yet")
        XCTAssertNil(NoteTags.queryTag("work"))
    }

    func testPartialTagAtTheEndOfTheText() {
        XCTAssertEqual(NoteTags.partialTag(endOf: "Lunch #wo"), "wo")
        XCTAssertEqual(NoteTags.partialTag(endOf: "Lunch #"), "")
        XCTAssertNil(NoteTags.partialTag(endOf: "Lunch #work "), "finished with a space")
        XCTAssertNil(NoteTags.partialTag(endOf: "Lunch"), "no tag being typed")
        XCTAssertNil(NoteTags.partialTag(endOf: "C#"), "a # inside a word is not a tag")
        XCTAssertEqual(NoteTags.completing("Lunch #wo", with: "work"), "Lunch #work ")
    }

    func testTagCountsMostUsedFirstThenAlphabetical() {
        let notes = [Note(text: "#work #alpha"), Note(text: "#Work"), Note(text: "#beta #alpha"), Note(text: "#zeta")]
        let counts = TagCount.counts(in: notes)
        XCTAssertEqual(counts.map(\.tag), ["alpha", "work", "beta", "zeta"])
        XCTAssertEqual(counts.map(\.count), [2, 2, 1, 1])
        XCTAssertEqual(TagCount.matching("a", in: counts).map(\.tag), ["alpha"])
        XCTAssertEqual(TagCount.matching("", in: counts).count, 4)
    }

    func testTagSearchIsExactAndSkipsNames() {
        let store = TestSupport.makeStore(directory: TestSupport.temporaryDirectory(), defaults: TestSupport.defaults())
        let ada = store.addPerson(named: "Ada Workman")!
        let grace = store.addPerson(named: "Grace")!
        store.addNote(text: "Standup #work", personIds: [grace.id])
        store.addNote(text: "Gym #workout", personIds: [ada.id])
        store.addNote(text: "No tags, just work", personIds: [ada.id])

        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "#work").map(\.id), [grace.id],
                       "#work is not #workout, and Ada's name does not count")
        XCTAssertEqual(PeopleSearch.people(store.people, notes: store.notes, query: "work").map(\.id), [ada.id, grace.id],
                       "a plain query still matches names and text")
        let sections = PeopleSearch.sections(people: store.people, notes: store.notes, query: "#workout")
        XCTAssertEqual(sections.map(\.person.id), [ada.id])
        XCTAssertEqual(sections[0].notes.map(\.text), ["Gym #workout"])
        XCTAssertEqual(PeopleSearch.sections(people: store.people, notes: store.notes, query: "#").count, 0,
                       "a lone # matches nothing until a tag is typed")
        XCTAssertEqual(store.tagCounts.map(\.tag), ["work", "workout"])
    }
}
