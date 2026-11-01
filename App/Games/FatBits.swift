import Foundation

/// A clean circle laid over a FatBits bitmap: drawn as a vector, so its
/// edge is smooth at any size, where a circle made of bits would be
/// stepped. The built-in motifs' circles (the dot at the middle of the
/// Pinwheel, the rings of the Bullseye) are these, so a motif traced into
/// FatBits keeps them exact. Coordinates are fractions of the tile, 0 to 1,
/// so a circle means the same thing whatever the bitmap's grid.
struct FatBitsCircle: Codable, Equatable, Hashable {
    /// Centre, as fractions of the tile's width and height.
    var x: Double
    var y: Double
    /// Radius, as a fraction of the tile's width.
    var radius: Double
    /// Shade, 0 pale to 3 dark, as for the bits.
    var shade: UInt8

    /// Centres snap to half a bit, radii to a quarter of a bit, so circles
    /// drawn by hand sit on the same grid as the bits around them.
    static let centreStep = 0.5 / Double(FatBits.side)
    static let radiusStep = 0.25 / Double(FatBits.side)
    static let minimumRadius = radiusStep * 2
    static let maximumRadius = 0.75
    /// The radius of a circle placed with a tap: the Pinwheel's dot.
    static let defaultRadius = 0.12

    init(x: Double, y: Double, radius: Double, shade: UInt8) {
        self.x = x
        self.y = y
        self.radius = radius
        self.shade = min(shade, FatBits.shadeCount - 1)
    }

    /// A circle snapped to the grid and kept to a size that can be seen.
    static func snapped(x: Double, y: Double, radius: Double, shade: UInt8) -> FatBitsCircle {
        func snap(_ value: Double, to step: Double) -> Double { (value / step).rounded() * step }
        return FatBitsCircle(x: snap(min(max(x, 0), 1), to: centreStep),
                             y: snap(min(max(y, 0), 1), to: centreStep),
                             radius: min(max(snap(radius, to: radiusStep), minimumRadius), maximumRadius),
                             shade: shade)
    }

    private enum CodingKeys: String, CodingKey { case x, y, radius, shade }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try container.decode(Double.self, forKey: .x),
                  y: try container.decode(Double.self, forKey: .y),
                  radius: try container.decode(Double.self, forKey: .radius),
                  shade: try container.decode(UInt8.self, forKey: .shade))
    }
}

/// A FatBits stamp: a 10×10 bitmap in the four shades of a palette colour,
/// drawn big enough to edit one bit at a time, in the manner of MacPaint's
/// FatBits, with clean vector circles laid over it. Shade 0 is pale, 1 light,
/// 2 the colour itself, 3 dark, matching `TileShades`. A stamp made here sits
/// in a Mosaic beside the built-in motifs; the middle two rows and columns
/// are exactly where their connecting band runs (`TilePatternView.bandWidth`,
/// 0.4 to 0.6 of the tile), so a stamp that keeps them joins up with its
/// neighbours.
struct FatBits: Codable, Equatable, Hashable {
    static let side = 10
    static let count = side * side
    static let shadeCount: UInt8 = 4
    /// How many circles a stamp may carry.
    static let circleLimit = 16

    /// Shade per pixel, row-major, top row first.
    private(set) var bits: [UInt8]

    /// Circles drawn over the bits, first underneath, last on top.
    private(set) var circles: [FatBitsCircle] = []

    /// A stamp from `bits`: short arrays are padded with pale, long ones
    /// cut, and shades out of range brought back in. A bitmap saved on the
    /// earlier 8×8 grid is scaled up to fit.
    init(bits: [UInt8], circles: [FatBitsCircle] = []) {
        self.circles = Array(circles.prefix(Self.circleLimit))
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

    private enum CodingKeys: String, CodingKey { case bits, circles }

    /// Decoding goes through `init(bits:)` so a bitmap saved on the 8×8 grid,
    /// or one of any other length, is brought to `count` entries. The
    /// synthesized decoder stored the array as-is, and drawing a short one
    /// read past its end. Stamps saved before circles have none.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let circles = (try? container.decodeIfPresent([FatBitsCircle].self, forKey: .circles)) ?? nil
        self.init(bits: try container.decode([UInt8].self, forKey: .bits), circles: circles ?? [])
    }

    /// Circles are left out when there are none, so a stamp without them
    /// is saved exactly as before.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(bits, forKey: .bits)
        if !circles.isEmpty { try container.encode(circles, forKey: .circles) }
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

    /// Nothing but pale bits and no circles.
    var isBlank: Bool { !bits.contains { $0 != 0 } && circles.isEmpty }

    mutating func clear() {
        bits = Array(repeating: 0, count: Self.count)
        circles = []
    }

    // MARK: Circles

    /// Lays a circle on top. Once the limit is reached the oldest circle
    /// makes room, so drawing never stalls.
    mutating func addCircle(_ circle: FatBitsCircle) {
        circles.append(circle)
        if circles.count > Self.circleLimit { circles.removeFirst(circles.count - Self.circleLimit) }
    }

    /// Takes off the circle laid last.
    mutating func removeLastCircle() {
        guard !circles.isEmpty else { return }
        circles.removeLast()
    }

    mutating func removeAllCircles() {
        circles = []
    }

    /// The stamp mirrored left to right.
    var flippedHorizontally: FatBits {
        var result = self
        for y in 0..<Self.side {
            for x in 0..<Self.side { result[x, y] = self[Self.side - 1 - x, y] }
        }
        result.circles = circles.map { var c = $0; c.x = 1 - c.x; return c }
        return result
    }

    /// The stamp mirrored top to bottom.
    var flippedVertically: FatBits {
        var result = self
        for y in 0..<Self.side {
            for x in 0..<Self.side { result[x, y] = self[x, Self.side - 1 - y] }
        }
        result.circles = circles.map { var c = $0; c.y = 1 - c.y; return c }
        return result
    }

    /// The stamp with every shade swapped for its opposite: pale for dark,
    /// light for the colour.
    var inverted: FatBits {
        FatBits(bits: bits.map { Self.shadeCount - 1 - $0 },
                circles: circles.map { var c = $0; c.shade = Self.shadeCount - 1 - c.shade; return c })
    }
}
