import XCTest
@testable import Tact

final class PatternLibraryTests: XCTestCase {
    private var directory: URL!
    private var defaults: UserDefaults!
    private var store: TactStore!

    override func setUp() {
        super.setUp()
        directory = TestSupport.temporaryDirectory()
        defaults = TestSupport.defaults()
        store = TestSupport.makeStore(directory: directory, defaults: defaults)
    }

    private func drawing(_ mark: Int) -> FatBits {
        var bits = FatBits.cross
        bits[mark % FatBits.side, mark / FatBits.side] = 3
        return bits
    }

    // MARK: Library

    func testAddNamesAndCleansAndKeepsBlank() {
        var library = PatternLibrary()
        let saved = library.add(drawing(0), named: "  Lei  ")
        XCTAssertEqual(saved?.name, "Lei")
        XCTAssertEqual(library.count, 1)
        XCTAssertEqual(library.add(drawing(1), named: "   ")?.name, "Pattern", "an empty name gets a stand-in")
        XCTAssertEqual(library.add(.blank, named: "Nothing")?.bits, .blank, "a blank drawing is a plain tile, and kept")
        XCTAssertEqual(library.count, 3)
        XCTAssertEqual(library.add(drawing(2), named: String(repeating: "x", count: 100))?.name.count, 40)
    }

    func testSavingTheSameDrawingAgainRenamesIt() {
        var library = PatternLibrary()
        let first = library.add(drawing(0), named: "One")!
        let again = library.add(drawing(0), named: "Uno")!
        XCTAssertEqual(again.id, first.id)
        XCTAssertEqual(library.count, 1)
        XCTAssertEqual(library[first.id]?.name, "Uno")
        XCTAssertEqual(library.pattern(matching: drawing(0))?.id, first.id)
        XCTAssertNil(library.pattern(matching: drawing(5)))
    }

    func testRenameUpdateRemoveAndMove() {
        var library = PatternLibrary()
        let a = library.add(drawing(0), named: "A")!
        let b = library.add(drawing(1), named: "B")!
        library.rename(id: a.id, to: "Alpha")
        XCTAssertEqual(library[a.id]?.name, "Alpha")
        library.update(id: a.id, bits: drawing(7))
        XCTAssertEqual(library[a.id]?.bits, drawing(7))
        library.update(id: a.id, bits: .blank)
        XCTAssertEqual(library[a.id]?.bits, .blank, "a pattern can be made blank")
        library.move(fromOffsets: IndexSet(integer: 1), toOffset: 0)
        XCTAssertEqual(library.patterns.map(\.id), [b.id, a.id])
        library.remove(id: b.id)
        XCTAssertEqual(library.patterns.map(\.id), [a.id])
        library.remove(id: UUID())
        XCTAssertEqual(library.count, 1, "removing an unknown id is harmless")
    }

    func testLibraryHasALimit() {
        var library = PatternLibrary()
        for index in 0..<(PatternLibrary.limit + 2) {
            library.add(drawing(index), named: "P\(index)")
        }
        XCTAssertEqual(library.count, PatternLibrary.limit)
        XCTAssertTrue(library.isFull)
        XCTAssertEqual(library.patterns.first?.name, "P2", "the oldest make room")
    }

    func testLibraryRoundTripsThroughJSONAndDropsBrokenEntries() throws {
        var library = PatternLibrary()
        var withCircle = drawing(3)
        withCircle.addCircle(FatBitsCircle(x: 0.5, y: 0.5, radius: 0.12, shade: 3))
        library.add(withCircle, named: "Dot")
        library.add(drawing(4), named: "Plain")
        let data = try JSONEncoder().encode(library)
        XCTAssertEqual(try JSONDecoder().decode(PatternLibrary.self, from: data), library)

        let broken = Data(#"{"patterns":[{"id":"not-a-uuid","name":"Odd","bits":{"bits":[1,2,3]}},"junk",{"name":"NoBits"},{"id":"00000000-0000-0000-0000-000000000001","name":"Good","bits":{"bits":[2]}}]}"#.utf8)
        let decoded = try JSONDecoder().decode(PatternLibrary.self, from: broken)
        XCTAssertEqual(decoded.patterns.map(\.name), ["Odd", "Good"], "entries without bits are dropped; a bad id gets a fresh one")
    }

    func testSettingsWithoutALibraryDecodeToAnEmptyOne() throws {
        let json = Data(#"{"randomColorSettings":{"palette":"Earth Tones"}}"#.utf8)
        let settings = try JSONDecoder().decode(GameTypeSettings.self, from: json)
        XCTAssertTrue(settings.patternLibrary.isEmpty)
        XCTAssertEqual(settings.randomColorSettings.palette, .earth)
    }

    // MARK: Store

    func testStoreSavesAppliesAndReusesPatterns() {
        let ada = store.addPerson(named: "Ada", colorIndex: 2, pattern: .pinwheel)!
        let bits = drawing(9)
        store.updateTile(forPersonID: ada.id) { $0.bits = bits; $0.showsPhoto = false }
        let saved = store.savePattern(bits, named: "Lei")!
        XCTAssertEqual(store.patternLibrary.patterns, [saved])

        let grace = store.addPerson(named: "Grace", colorIndex: 7, pattern: .frame)!
        store.applyPattern(id: saved.id, toPersonID: grace.id)
        let worn = store.person(id: grace.id)!
        XCTAssertEqual(worn.tile.bits, bits, "the drawing is shared")
        XCTAssertEqual(worn.tile.colorIndex, 7, "in Grace's own colour")
        XCTAssertFalse(worn.showsPhoto)
        XCTAssertEqual(worn.tilePattern, .frame, "her built-in pattern stays underneath for Revert")

        store.applyPattern(id: UUID(), toPersonID: grace.id)
        XCTAssertEqual(store.person(id: grace.id)?.tile.bits, bits, "an unknown pattern changes nothing")

        store.renamePattern(id: saved.id, to: "Lei Hulu")
        XCTAssertEqual(store.patternLibrary[saved.id]?.name, "Lei Hulu")
        store.deletePattern(id: saved.id)
        XCTAssertTrue(store.patternLibrary.isEmpty)
        XCTAssertEqual(store.person(id: grace.id)?.tile.bits, bits, "deleting the saved pattern leaves the tiles wearing it alone")
    }

    func testNewPersonCanStartWithASavedPattern() {
        let bits = drawing(4)
        let person = store.addPerson(named: "Ada", colorIndex: 3, pattern: .arcs, bits: bits)!
        XCTAssertEqual(person.tile.bits, bits)
        XCTAssertEqual(person.tile.colorIndex, 3)
        XCTAssertEqual(person.tilePattern, .arcs)
        XCTAssertFalse(person.showsPhoto)
        XCTAssertTrue(person.tile.isFatBits)
    }

    func testSavedPatternsSurviveReload() {
        store.savePattern(drawing(1), named: "Kept")
        store.flush(waitUntilDone: true)
        let reloaded = TestSupport.makeStore(directory: directory, defaults: defaults)
        XCTAssertEqual(reloaded.patternLibrary, store.patternLibrary)
        XCTAssertEqual(reloaded.patternLibrary.patterns.first?.name, "Kept")
    }
}
