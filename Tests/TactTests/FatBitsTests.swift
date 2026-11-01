import XCTest
@testable import Tact

final class FatBitsTests: XCTestCase {
    private func stamp(_ bits: FatBits, color: Int = 0) -> MosaicStamp {
        MosaicStamp(bits: bits, colorIndex: color)
    }

    // MARK: Bitmap

    func testCrossIsTheDefaultAndCoversTheBand() {
        let bits = FatBits()
        XCTAssertEqual(bits, .cross)
        XCTAssertEqual(bits.bits.count, FatBits.count)
        for index in 0..<FatBits.side {
            for band in FatBits.bandRange {
                XCTAssertEqual(bits[band, index], 2, "column \(band) row \(index)")
                XCTAssertEqual(bits[index, band], 2, "row \(band) column \(index)")
            }
        }
        XCTAssertEqual(bits[0, 0], 0)
        XCTAssertEqual(bits[FatBits.side - 1, FatBits.side - 1], 0)
        XCTAssertFalse(bits.isBlank)
    }

    func testTheBandMatchesTheMotifs() {
        // The built-in motifs' band runs from 0.4 to 0.6 of the tile; the
        // FatBits band must cover exactly that, or stamps do not line up.
        let lower = CGFloat(FatBits.bandRange.lowerBound) / CGFloat(FatBits.side)
        let upper = CGFloat(FatBits.bandRange.upperBound + 1) / CGFloat(FatBits.side)
        XCTAssertEqual(lower, (1 - TilePatternView.bandWidth) / 2, accuracy: 1e-9)
        XCTAssertEqual(upper, (1 + TilePatternView.bandWidth) / 2, accuracy: 1e-9)
    }

    func testOldEightByEightBitmapsScaleUp() {
        var old = [UInt8](repeating: 0, count: 64)
        old[0] = 3                      // top-left corner
        old[7 * 8 + 7] = 1              // bottom-right corner
        for i in 0..<8 { old[i * 8 + 3] = 2; old[i * 8 + 4] = 2 }   // the old band
        let bits = FatBits(bits: old)
        XCTAssertEqual(bits.bits.count, FatBits.count)
        XCTAssertEqual(bits[0, 0], 3)
        XCTAssertEqual(bits[FatBits.side - 1, FatBits.side - 1], 1)
        for band in FatBits.bandRange { XCTAssertEqual(bits[band, 0], 2) }
    }

    func testInitPadsCutsAndClampsShades() {
        let short = FatBits(bits: [3, 9])   // not 64 long, so taken as is
        XCTAssertEqual(short.bits.count, FatBits.count)
        XCTAssertEqual(short[0, 0], 3)
        XCTAssertEqual(short[1, 0], 3, "shades above 3 are brought back to 3")
        XCTAssertEqual(short[2, 0], 0)
        let long = FatBits(bits: Array(repeating: 1, count: FatBits.count + 10))
        XCTAssertEqual(long.bits.count, FatBits.count)
    }

    func testSubscriptSetsAndIgnoresOutOfRange() {
        var bits = FatBits.blank
        bits[3, 5] = 2
        XCTAssertEqual(bits[3, 5], 2)
        XCTAssertEqual(bits.bits[5 * FatBits.side + 3], 2, "row-major")
        bits[FatBits.side, 0] = 3
        bits[0, -1] = 3
        XCTAssertEqual(bits[FatBits.side, 0], 0)
        XCTAssertEqual(bits.bits.filter { $0 != 0 }.count, 1)
        bits[1, 1] = 7
        XCTAssertEqual(bits[1, 1], 3)
    }

    func testClearAndBlank() {
        var bits = FatBits.cross
        bits.clear()
        XCTAssertTrue(bits.isBlank)
        XCTAssertEqual(bits, .blank)
    }

    func testFlips() {
        var bits = FatBits.blank
        bits[0, 0] = 3
        bits[2, 1] = 1
        let last = FatBits.side - 1
        let horizontal = bits.flippedHorizontally
        XCTAssertEqual(horizontal[last, 0], 3)
        XCTAssertEqual(horizontal[last - 2, 1], 1)
        XCTAssertEqual(horizontal[0, 0], 0)
        let vertical = bits.flippedVertically
        XCTAssertEqual(vertical[0, last], 3)
        XCTAssertEqual(vertical[2, last - 1], 1)
        XCTAssertEqual(bits.flippedHorizontally.flippedHorizontally, bits)
        XCTAssertEqual(bits.flippedVertically.flippedVertically, bits)
        XCTAssertEqual(FatBits.cross.flippedHorizontally, .cross, "the band is symmetric")
    }

    func testInvert() {
        var bits = FatBits.blank
        bits[0, 0] = 1
        bits[1, 0] = 3
        let inverted = bits.inverted
        XCTAssertEqual(inverted[0, 0], 2)
        XCTAssertEqual(inverted[1, 0], 0)
        XCTAssertEqual(inverted[2, 0], 3)
        XCTAssertEqual(inverted.inverted, bits)
    }

    func testBitmapRoundTripsThroughJSON() throws {
        var bits = FatBits.cross
        bits[6, 1] = 3
        let data = try JSONEncoder().encode(bits)
        XCTAssertEqual(try JSONDecoder().decode(FatBits.self, from: data), bits)
    }

    func testBitmapsSavedOnTheOldGridDecodeToTheFullGrid() throws {
        // TestFlight 202610282209 crashed at launch drawing a stamp saved
        // with 64 bits: the synthesized decoder kept the short array and
        // the 10×10 draw loop read past its end.
        var old = [UInt8](repeating: 0, count: 64)
        old[0] = 3
        for i in 0..<8 { old[i * 8 + 3] = 2; old[i * 8 + 4] = 2 }
        let json = try JSONEncoder().encode(["bits": old])
        let bits = try JSONDecoder().decode(FatBits.self, from: json)
        XCTAssertEqual(bits.bits.count, FatBits.count)
        XCTAssertEqual(bits, FatBits(bits: old))
        XCTAssertEqual(bits[0, 0], 3)
        XCTAssertEqual(bits[FatBits.side - 1, FatBits.side - 1], 0)

        let short = try JSONDecoder().decode(FatBits.self, from: Data(#"{"bits":[1,2]}"#.utf8))
        XCTAssertEqual(short.bits.count, FatBits.count)
        let long = try JSONDecoder().decode(FatBits.self, from: JSONEncoder().encode(["bits": [UInt8](repeating: 9, count: 150)]))
        XCTAssertEqual(long.bits.count, FatBits.count)
        XCTAssertEqual(long[0, 0], 3, "shades are clamped")

        // Drawing every cell, as FatBitsView.draw does, must not trap.
        for stamp in [bits, short, long] {
            for y in 0..<FatBits.side { for x in 0..<FatBits.side { _ = stamp[x, y] } }
        }
    }

    // MARK: Circles

    func testCirclesSnapToTheGridAndStayVisible() {
        let step = FatBitsCircle.centreStep
        let circle = FatBitsCircle.snapped(x: 0.512, y: 0.263, radius: 0.1234, shade: 3)
        XCTAssertEqual(circle.x, 0.5, accuracy: 1e-9)
        XCTAssertEqual(circle.y, (0.263 / step).rounded() * step, accuracy: 1e-9)
        XCTAssertEqual(circle.radius, 0.125, accuracy: 1e-9, "radii snap to a quarter bit")
        XCTAssertEqual(FatBitsCircle.snapped(x: 1.4, y: -0.3, radius: 0, shade: 9).x, 1, "centres stay on the tile")
        XCTAssertEqual(FatBitsCircle.snapped(x: 1.4, y: -0.3, radius: 0, shade: 9).y, 0)
        XCTAssertEqual(FatBitsCircle.snapped(x: 0, y: 0, radius: 0, shade: 9).radius, FatBitsCircle.minimumRadius)
        XCTAssertEqual(FatBitsCircle.snapped(x: 0, y: 0, radius: 5, shade: 9).radius, FatBitsCircle.maximumRadius)
        XCTAssertEqual(FatBitsCircle.snapped(x: 0, y: 0, radius: 0, shade: 9).shade, 3, "shades are clamped")
    }

    func testCirclesAreAddedRemovedAndLimited() throws {
        var bits = FatBits.blank
        XCTAssertTrue(bits.isBlank)
        bits.addCircle(FatBitsCircle(x: 0.5, y: 0.5, radius: 0.12, shade: 3))
        XCTAssertFalse(bits.isBlank, "a circle alone is not blank")
        XCTAssertEqual(bits.circles.count, 1)
        bits.removeLastCircle()
        XCTAssertTrue(bits.isBlank)
        bits.removeLastCircle()
        XCTAssertTrue(bits.circles.isEmpty, "removing from none is harmless")
        for index in 0..<(FatBits.circleLimit + 3) {
            bits.addCircle(FatBitsCircle(x: 0.5, y: 0.5, radius: Double(index + 1) * 0.01, shade: 1))
        }
        XCTAssertEqual(bits.circles.count, FatBits.circleLimit)
        XCTAssertEqual(try XCTUnwrap(bits.circles.first).radius, 0.04, accuracy: 1e-9, "the oldest make room")
        bits.clear()
        XCTAssertTrue(bits.circles.isEmpty, "clear takes the circles too")
    }

    func testCirclesFollowFlipsAndInvert() {
        var bits = FatBits.blank
        bits.addCircle(FatBitsCircle(x: 0.2, y: 0.3, radius: 0.1, shade: 3))
        let horizontal = bits.flippedHorizontally
        XCTAssertEqual(horizontal.circles[0].x, 0.8, accuracy: 1e-9)
        XCTAssertEqual(horizontal.circles[0].y, 0.3, accuracy: 1e-9)
        let vertical = bits.flippedVertically
        XCTAssertEqual(vertical.circles[0].x, 0.2, accuracy: 1e-9)
        XCTAssertEqual(vertical.circles[0].y, 0.7, accuracy: 1e-9)
        XCTAssertEqual(bits.inverted.circles[0].shade, 0)
        XCTAssertEqual(bits.inverted.inverted, bits)
        XCTAssertEqual(bits.flippedVertically.flippedVertically, bits)
    }

    func testCirclesRoundTripThroughJSONAndAreOptional() throws {
        var bits = FatBits.cross
        bits.addCircle(FatBitsCircle(x: 0.5, y: 0.5, radius: 0.12, shade: 3))
        let data = try JSONEncoder().encode(bits)
        XCTAssertEqual(try JSONDecoder().decode(FatBits.self, from: data), bits)

        let plain = try JSONEncoder().encode(FatBits.cross)
        XCTAssertFalse(String(decoding: plain, as: UTF8.self).contains("circles"),
                       "a stamp without circles is saved as before")
        XCTAssertEqual(try JSONDecoder().decode(FatBits.self, from: plain), .cross)

        let broken = Data(#"{"bits":[2,2,2],"circles":"nonsense"}"#.utf8)
        let decoded = try JSONDecoder().decode(FatBits.self, from: broken)
        XCTAssertTrue(decoded.circles.isEmpty, "broken circles are dropped, not fatal")
        XCTAssertEqual(decoded[0, 0], 2)
    }

    func testPatternCirclesStayWithinTheTileShades() {
        for pattern in TilePattern.allCases {
            for circle in pattern.circles {
                XCTAssertLessThan(circle.shade, FatBits.shadeCount, "\(pattern)")
                XCTAssertGreaterThan(circle.radius, 0, "\(pattern)")
                XCTAssertTrue((0...1).contains(circle.x) && (0...1).contains(circle.y), "\(pattern)")
            }
        }
        XCTAssertEqual(TilePattern.pinwheel.circles, [FatBitsCircle(x: 0.5, y: 0.5, radius: 0.12, shade: 3)])
        XCTAssertEqual(TilePattern.bullseye.circles.count, 3)
        XCTAssertTrue(TilePattern.cross.circles.isEmpty)
    }

    @MainActor
    func testTracingKeepsThePatternsCirclesAsVectors() {
        let pinwheel = FatBits(tracing: .pinwheel, colorIndex: 5)
        XCTAssertEqual(pinwheel.circles, TilePattern.pinwheel.circles, "the dot is a circle, not bits")
        let middle = FatBits.side / 2
        XCTAssertEqual(pinwheel[middle, middle], 2, "under the dot the band is the colour itself")
        let bullseye = FatBits(tracing: .bullseye, colorIndex: 5)
        XCTAssertEqual(bullseye.circles.count, 3)
        XCTAssertFalse(bullseye.bits.contains(3), "the rings are not traced into dark bits")
        XCTAssertTrue(FatBits(tracing: .cross, colorIndex: 0).circles.isEmpty)
    }

    // MARK: Stamps

    func testFatBitsStampLooksDifferentFromMotifsAndOtherBitmaps() {
        let a = stamp(.cross)
        var other = FatBits.cross
        other[0, 0] = 3
        let b = stamp(other)
        let motif = MosaicStamp(pattern: 1, colorIndex: 0)
        XCTAssertTrue(a.isFatBits)
        XCTAssertFalse(motif.isFatBits)
        XCTAssertEqual(a.pattern, MosaicStamp.fatBitsPattern)
        XCTAssertFalse(a.sameLook(as: b))
        XCTAssertFalse(a.sameLook(as: motif))
        XCTAssertTrue(a.sameLook(as: a.turned))
        XCTAssertFalse(a.sameLook(as: stamp(.cross, color: 1)))
    }

    func testTurningKeepsTheBitmap() {
        let a = stamp(.cross)
        XCTAssertEqual(a.turned.bits, .cross)
        XCTAssertEqual(a.turned.quarterTurns, 1)
        XCTAssertEqual(a.turned.turned.turned.turned.quarterTurns, 0)
        XCTAssertEqual(a.turned.unturned, a)
    }

    func testStampingAFatBitsCellTwiceTurnsIt() {
        var mosaic = Mosaic()
        let a = stamp(.cross)
        mosaic.stamp(a, at: 0)
        mosaic.stamp(a, at: 0)
        XCTAssertEqual(mosaic[0]?.quarterTurns, 1)
        XCTAssertEqual(mosaic[0]?.bits, .cross)
    }

    func testFillKeepsBitmaps() {
        var mosaic = Mosaic(columns: 4, rows: 2)
        var generator = SystemRandomNumberGenerator()
        mosaic.fill(from: [stamp(.cross)], using: &generator)
        XCTAssertEqual(mosaic.filledCount, 8)
        for index in 0..<8 {
            XCTAssertEqual(mosaic[index]?.bits, .cross)
        }
    }

    func testSwapAndRemoveFollowTheLook() {
        var mosaic = Mosaic(columns: 4, rows: 1)
        let a = stamp(.cross)
        var changed = FatBits.cross
        changed[0, 0] = 3
        let b = stamp(changed)
        let motif = MosaicStamp(pattern: 2, colorIndex: 4)
        mosaic.stamp(a, at: 0)
        mosaic.stamp(a, at: 1)
        mosaic.stamp(a, at: 1)   // turned once
        mosaic.stamp(motif, at: 2)
        mosaic.swap(a, for: b)
        XCTAssertEqual(mosaic[0], b)
        XCTAssertEqual(mosaic[1]?.bits, changed)
        XCTAssertEqual(mosaic[1]?.quarterTurns, 1, "the turn is kept")
        XCTAssertEqual(mosaic[2], motif)
        mosaic.remove(b)
        XCTAssertNil(mosaic[0])
        XCTAssertNil(mosaic[1])
        XCTAssertEqual(mosaic[2], motif)
    }

    func testOldSavedMosaicsWithoutBitsStillDecode() throws {
        let json = """
        {"columns":2,"rows":1,"cells":[{"pattern":3,"colorIndex":5,"quarterTurns":2},null]}
        """
        let mosaic = try XCTUnwrap(Mosaic.decoded(from: Data(json.utf8)))
        XCTAssertEqual(mosaic[0], MosaicStamp(pattern: 3, colorIndex: 5, quarterTurns: 2))
        XCTAssertNil(mosaic[0]?.bits)
        XCTAssertNil(mosaic[1])
    }

    func testMosaicWithFatBitsRoundTripsThroughJSON() throws {
        var mosaic = Mosaic(columns: 2, rows: 1)
        var bits = FatBits.cross
        bits[7, 7] = 1
        mosaic.stamp(stamp(bits, color: 9), at: 1)
        let data = try XCTUnwrap(mosaic.encoded())
        let back = try XCTUnwrap(Mosaic.decoded(from: data))
        XCTAssertEqual(back, mosaic)
        XCTAssertEqual(back[1]?.bits, bits)
    }

    // MARK: Shelf

    func testShelfAddsUnturnedAndDeduplicates() {
        var shelf = FatBitsShelf()
        let a = stamp(.cross)
        XCTAssertEqual(shelf.add(a.turned), a)
        XCTAssertEqual(shelf.count, 1)
        XCTAssertEqual(shelf.stamps[0].quarterTurns, 0)
        shelf.add(a)
        XCTAssertEqual(shelf.count, 1, "the same look is not added twice")
        XCTAssertNil(shelf.add(MosaicStamp(pattern: 0, colorIndex: 0)), "motifs do not go on the shelf")
        XCTAssertEqual(shelf.count, 1)
    }

    func testShelfReplaceAndRemove() {
        var shelf = FatBitsShelf()
        let a = stamp(.cross)
        var changed = FatBits.cross
        changed[0, 0] = 3
        let b = stamp(changed)
        shelf.add(a)
        shelf.replace(a, with: b.turned)
        XCTAssertEqual(shelf.stamps, [b])
        shelf.add(a)
        shelf.replace(a, with: b)
        XCTAssertEqual(shelf.stamps, [b], "replacing with a look already held merges them")
        shelf.remove(b)
        XCTAssertTrue(shelf.isEmpty)
    }

    func testShelfHasALimit() {
        var shelf = FatBitsShelf()
        for index in 0..<(FatBitsShelf.limit + 5) {
            var bits = FatBits.blank
            bits[index % FatBits.side, index / FatBits.side] = 3
            shelf.add(stamp(bits))
        }
        XCTAssertEqual(shelf.count, FatBitsShelf.limit)
        XCTAssertTrue(shelf.isFull)
    }

    func testShelfRoundTripsThroughJSON() throws {
        var shelf = FatBitsShelf()
        shelf.add(stamp(.cross, color: 3))
        let data = try XCTUnwrap(shelf.encoded())
        XCTAssertEqual(FatBitsShelf.decoded(from: data), shelf)
        XCTAssertNil(FatBitsShelf.decoded(from: nil))
    }

    // MARK: Tiles

    func testTileKeepsItsPatternUnderTheBitsAndReverts() throws {
        var person = Person(name: "Ada", colorSeed: 7)
        person.tile.pattern = TilePattern.diamond.rawValue
        var bits = FatBits.cross
        bits[0, 0] = 3
        person.tile.bits = bits
        XCTAssertTrue(person.tile.isFatBits)
        XCTAssertEqual(person.tilePattern, .diamond, "the pattern stays underneath")
        XCTAssertEqual(person.mosaicStamp, MosaicStamp(bits: bits, colorIndex: person.tile.colorIndex))

        let decoded = try JSONDecoder().decode(Person.self, from: JSONEncoder().encode(person))
        XCTAssertEqual(decoded.tile, person.tile)
        XCTAssertEqual(decoded.tile.bits, bits)

        person.tile.revertToPattern()
        XCTAssertFalse(person.tile.isFatBits)
        XCTAssertEqual(person.tilePattern, .diamond)
        XCTAssertEqual(person.mosaicStamp, MosaicStamp(pattern: TilePattern.diamond.rawValue, colorIndex: person.tile.colorIndex))
    }

    func testTilesSavedWithoutBitsDecode() throws {
        let json = #"{"quarterTurns":1,"colorIndex":2,"pattern":4,"showsPhoto":false}"#.data(using: .utf8)!
        let art = try JSONDecoder().decode(TileArt.self, from: json)
        XCTAssertNil(art.bits)
        XCTAssertEqual(art, TileArt(quarterTurns: 1, colorIndex: 2, pattern: 4, showsPhoto: false))
        let bad = #"{"colorIndex":2,"bits":"nonsense"}"#.data(using: .utf8)!
        XCTAssertNil(try JSONDecoder().decode(TileArt.self, from: bad).bits, "a broken bitmap is dropped, not fatal")
    }

    @MainActor
    func testTracingAPatternKeepsTheBand() {
        for pattern in TilePattern.allCases {
            let traced = FatBits(tracing: pattern, colorIndex: 5)
            XCTAssertFalse(traced.isBlank, "\(pattern)")
            // Every pattern carries the band to the middle of each edge.
            for band in FatBits.bandRange {
                XCTAssertNotEqual(traced[band, 0], 0, "\(pattern) top edge")
                XCTAssertNotEqual(traced[band, FatBits.side - 1], 0, "\(pattern) bottom edge")
                XCTAssertNotEqual(traced[0, band], 0, "\(pattern) left edge")
                XCTAssertNotEqual(traced[FatBits.side - 1, band], 0, "\(pattern) right edge")
            }
        }
        let cross = FatBits(tracing: .cross, colorIndex: 0)
        XCTAssertEqual(cross[0, 0], 0, "corners of the cross are pale")
        XCTAssertEqual(cross[0, FatBits.side / 2], 2, "the band is the colour itself")
        XCTAssertEqual(cross[FatBits.side / 2, FatBits.side / 2], 1, "the middle of the cross is light")
    }
}
