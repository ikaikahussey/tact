import Foundation

/// A FatBits stamp: a 10×10 bitmap in the four shades of a palette colour,
/// drawn big enough to edit one bit at a time, in the manner of MacPaint's
/// FatBits. Shade 0 is pale, 1 light, 2 the colour itself, 3 dark, matching
/// `TileShades`. A stamp made here sits in a Mosaic beside the built-in
/// motifs; the middle two rows and columns are exactly where their
/// connecting band runs (`TilePatternView.bandWidth`, 0.4 to 0.6 of the
/// tile), so a stamp that keeps them joins up with its neighbours.
struct FatBits: Codable, Equatable, Hashable {
    static let side = 10
    static let count = side * side
    static let shadeCount: UInt8 = 4

    /// Shade per pixel, row-major, top row first.
    private(set) var bits: [UInt8]

    /// A stamp from `bits`: short arrays are padded with pale, long ones
    /// cut, and shades out of range brought back in. A bitmap saved on the
    /// earlier 8×8 grid is scaled up to fit.
    init(bits: [UInt8]) {
        var bits = bits
        if bits.count == 64 {
            bits = (0..<Self.count).map { index in
                let x = (index % Self.side) * 8 / Self.side, y = (index / Self.side) * 8 / Self.side
                return bits[y * 8 + x]
            }
        }
        var fixed = bits.prefix(Self.count).map { min($0, Self.shadeCount - 1) }
        fixed.append(contentsOf: Array(repeating: 0, count: Self.count - fixed.count))
        self.bits = fixed
    }

    /// The starting stamp: the band straight across and straight down.
    init() {
        self = .cross
    }

    private enum CodingKeys: String, CodingKey { case bits }

    /// Decoding goes through `init(bits:)` so a bitmap saved on the 8×8 grid,
    /// or one of any other length, is brought to `count` entries. The
    /// synthesized decoder stored the array as-is, and drawing a short one
    /// read past its end.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(bits: try container.decode([UInt8].self, forKey: .bits))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bits, forKey: .bits)
    }

    /// The pixel rows and columns the band covers: the middle two.
    static let bandRange = (side / 2 - 1)...(side / 2)

    static let cross: FatBits = {
        var stamp = FatBits(bits: [])
        for index in 0..<side {
            for band in bandRange {
                stamp[band, index] = 2
                stamp[index, band] = 2
            }
        }
        return stamp
    }()

    /// Everything pale.
    static let blank = FatBits(bits: [])

    subscript(x: Int, y: Int) -> UInt8 {
        get {
            guard Self.contains(x, y), bits.indices.contains(y * Self.side + x) else { return 0 }
            return bits[y * Self.side + x]
        }
        set {
            guard Self.contains(x, y), bits.indices.contains(y * Self.side + x) else { return }
            bits[y * Self.side + x] = min(newValue, Self.shadeCount - 1)
        }
    }

    static func contains(_ x: Int, _ y: Int) -> Bool {
        (0..<side).contains(x) && (0..<side).contains(y)
    }

    var isBlank: Bool { !bits.contains { $0 != 0 } }

    mutating func clear() {
        bits = Array(repeating: 0, count: Self.count)
    }

    /// The stamp mirrored left to right.
    var flippedHorizontally: FatBits {
        var result = self
        for y in 0..<Self.side {
            for x in 0..<Self.side { result[x, y] = self[Self.side - 1 - x, y] }
        }
        return result
    }

    /// The stamp mirrored top to bottom.
    var flippedVertically: FatBits {
        var result = self
        for y in 0..<Self.side {
            for x in 0..<Self.side { result[x, y] = self[x, Self.side - 1 - y] }
        }
        return result
    }

    /// The stamp with every shade swapped for its opposite: pale for dark,
    /// light for the colour.
    var inverted: FatBits {
        FatBits(bits: bits.map { Self.shadeCount - 1 - $0 })
    }
}
