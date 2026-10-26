import XCTest
@testable import Tact

final class MosaicTests: XCTestCase {
    private let coral = MosaicStamp(pattern: 0, colorIndex: 0)
    private let blue = MosaicStamp(pattern: 3, colorIndex: 5)

    func testStartsEmpty() {
        let mosaic = Mosaic(columns: 4, rows: 3)
        XCTAssertEqual(mosaic.count, 12)
        XCTAssertTrue(mosaic.isEmpty)
        XCTAssertEqual(mosaic.filledCount, 0)
        XCTAssertNil(mosaic[0])
        XCTAssertNil(mosaic[99])
    }

    func testStampFillsACell() {
        var mosaic = Mosaic()
        mosaic.stamp(coral, at: 5)
        XCTAssertEqual(mosaic[5], coral)
        XCTAssertEqual(mosaic.filledCount, 1)
        XCTAssertFalse(mosaic.isEmpty)
    }

    func testStampingTheSameLookTurnsIt() {
        var mosaic = Mosaic()
        mosaic.stamp(coral, at: 2)
        mosaic.stamp(coral, at: 2)
        XCTAssertEqual(mosaic[2]?.quarterTurns, 1)
        mosaic.stamp(coral, at: 2)
        mosaic.stamp(coral, at: 2)
        mosaic.stamp(coral, at: 2)
        XCTAssertEqual(mosaic[2]?.quarterTurns, 0, "four turns come back round")
    }

    func testStampingADifferentLookReplacesWithoutTurning() {
        var mosaic = Mosaic()
        mosaic.stamp(coral, at: 2)
        mosaic.stamp(coral, at: 2)
        mosaic.stamp(blue, at: 2)
        XCTAssertEqual(mosaic[2], blue)
        XCTAssertEqual(mosaic[2]?.quarterTurns, 0)
    }

    func testPlaceDoesNotTurn() {
        var mosaic = Mosaic()
        mosaic.place(coral, at: 1)
        mosaic.place(coral, at: 1)
        XCTAssertEqual(mosaic[1]?.quarterTurns, 0)
    }

    func testEraseAndClear() {
        var mosaic = Mosaic()
        mosaic.stamp(coral, at: 0)
        mosaic.stamp(blue, at: 1)
        mosaic.erase(at: 0)
        XCTAssertNil(mosaic[0])
        XCTAssertEqual(mosaic[1], blue)
        mosaic.clear()
        XCTAssertTrue(mosaic.isEmpty)
    }

    func testOutOfRangeIsIgnored() {
        var mosaic = Mosaic(columns: 4, rows: 1)
        mosaic.stamp(coral, at: 4)
        mosaic.stamp(coral, at: -1)
        mosaic.erase(at: 7)
        XCTAssertTrue(mosaic.isEmpty)
    }

    func testFillUsesOnlyThePalette() {
        var generator = SeededGenerator(seed: 3)
        var mosaic = Mosaic(columns: 4, rows: 4)
        mosaic.fill(from: [coral, blue], using: &generator)
        XCTAssertEqual(mosaic.filledCount, 16)
        for index in 0..<16 {
            let stamp = mosaic[index]!
            XCTAssertTrue(stamp.sameLook(as: coral) || stamp.sameLook(as: blue))
            XCTAssertTrue((0..<4).contains(stamp.quarterTurns))
        }
    }

    func testFillWithEmptyPaletteDoesNothing() {
        var mosaic = Mosaic()
        mosaic.fill(from: [])
        XCTAssertTrue(mosaic.isEmpty)
    }

    func testResizeKeepsWhatFits() {
        var mosaic = Mosaic(columns: 4, rows: 2)
        mosaic.stamp(coral, at: 0)
        mosaic.stamp(blue, at: 7)
        let taller = mosaic.resized(rows: 3)
        XCTAssertEqual(taller.count, 12)
        XCTAssertEqual(taller[0], coral)
        XCTAssertEqual(taller[7], blue)
        XCTAssertNil(taller[11])
        let shorter = taller.resized(rows: 1)
        XCTAssertEqual(shorter.count, 4)
        XCTAssertEqual(shorter[0], coral)
        XCTAssertEqual(mosaic.resized(rows: 2), mosaic)
    }

    func testStampNormalisesTurns() {
        XCTAssertEqual(MosaicStamp(pattern: 1, colorIndex: 1, quarterTurns: 5).quarterTurns, 1)
        XCTAssertEqual(MosaicStamp(pattern: 1, colorIndex: 1, quarterTurns: -1).quarterTurns, 3)
        XCTAssertEqual(MosaicStamp(pattern: 1, colorIndex: 1, quarterTurns: 3).turned.quarterTurns, 0)
    }

    func testRoundTripsThroughJSON() throws {
        var mosaic = Mosaic(columns: 4, rows: 2)
        mosaic.stamp(coral, at: 3)
        mosaic.stamp(blue, at: 6)
        mosaic.stamp(blue, at: 6)
        let data = try XCTUnwrap(mosaic.encoded())
        XCTAssertEqual(Mosaic.decoded(from: data), mosaic)
        XCTAssertNil(Mosaic.decoded(from: nil))
        XCTAssertNil(Mosaic.decoded(from: Data("junk".utf8)))
    }
}
