import UIKit

/// Resizes photos before they are stored so the data on disk stays small.
enum ImageProcessing {
    static let maxStoredDimension: CGFloat = 1024
    static let jpegQuality: CGFloat = 0.8

    /// Decodes any image format the system supports and returns a JPEG no larger
    /// than `maxDimension` on its longest side, drawn upright and opaque.
    static func storableJPEG(from data: Data, maxDimension: CGFloat = maxStoredDimension) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return storableJPEG(from: image, maxDimension: maxDimension)
    }

    static func storableJPEG(from image: UIImage, maxDimension: CGFloat = maxStoredDimension) -> Data? {
        guard image.size.width > 0, image.size.height > 0 else { return nil }
        let scale = min(maxDimension / image.size.width, maxDimension / image.size.height, 1)
        let size = CGSize(width: max(1, (image.size.width * scale).rounded(.down)),
                          height: max(1, (image.size.height * scale).rounded(.down)))
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.jpegData(compressionQuality: jpegQuality)
    }
}

/// Caches decoded (and optionally downsampled) images so grids and lists do not
/// re-decode JPEG data on every redraw. Main-thread only.
final class ImageCache {
    static let shared = ImageCache()

    private let cache = NSCache<NSString, UIImage>()

    init(countLimit: Int = 500) {
        cache.countLimit = countLimit
    }

    func image(for data: Data, maxPixelSize: CGFloat? = nil) -> UIImage? {
        let key = "\(data.fingerprint)-\(Int(maxPixelSize ?? 0))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        guard let image = UIImage(data: data) else { return nil }

        var result = image
        if let maxPixelSize {
            let longest = max(image.size.width, image.size.height)
            if longest > maxPixelSize {
                let ratio = maxPixelSize / longest
                let target = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
                result = image.preparingThumbnail(of: target) ?? image
            }
        }
        cache.setObject(result, forKey: key)
        return result
    }

    func removeAll() {
        cache.removeAllObjects()
    }
}

extension Person {
    /// A downsampled copy of the photo suitable for tiles and rows.
    func thumbnail(maxPixelSize: CGFloat = 512) -> UIImage? {
        guard let photoData else { return nil }
        return ImageCache.shared.image(for: photoData, maxPixelSize: maxPixelSize)
    }

    var fullPhoto: UIImage? {
        guard let photoData else { return nil }
        return ImageCache.shared.image(for: photoData)
    }
}

/// Slices the Puzzle photo into a grid of tiles and caches the results.
/// Main-thread only.
final class ArtImageCache {
    static let shared = ArtImageCache()
    static let columns = 4

    private var tiles: [String: UIImage] = [:]

    static func rows(forTileCount count: Int) -> Int {
        max(1, Int((Double(count) / Double(columns)).rounded(.up)))
    }

    /// The crop of the source image that fills a `columns × rows` grid without
    /// stretching, centred on the image.
    static func cropRect(for imageSize: CGSize, tileCount: Int) -> CGRect {
        let rows = rows(forTileCount: tileCount)
        let gridAspect = CGFloat(columns) / CGFloat(rows)
        let imageAspect = imageSize.width / imageSize.height
        if imageAspect > gridAspect {
            let width = imageSize.height * gridAspect
            return CGRect(x: (imageSize.width - width) / 2, y: 0, width: width, height: imageSize.height)
        } else {
            let height = imageSize.width / gridAspect
            return CGRect(x: 0, y: (imageSize.height - height) / 2, width: imageSize.width, height: height)
        }
    }

    /// The `index`th tile (row-major) of the image, for a grid that holds `tileCount` tiles.
    func tile(for data: Data, index: Int, tileCount: Int) -> UIImage? {
        guard index >= 0, tileCount > 0 else { return nil }
        let key = "\(data.fingerprint)-\(index)-\(tileCount)"
        if let cached = tiles[key] { return cached }

        guard let source = ImageCache.shared.image(for: data), let sourceCG = source.cgImage else { return nil }
        let pixelSize = CGSize(width: sourceCG.width, height: sourceCG.height)
        guard let gridCG = sourceCG.cropping(to: Self.cropRect(for: pixelSize, tileCount: tileCount)) else { return nil }

        let rows = Self.rows(forTileCount: tileCount)
        let tileWidth = CGFloat(gridCG.width) / CGFloat(Self.columns)
        let tileHeight = CGFloat(gridCG.height) / CGFloat(rows)
        let row = index / Self.columns
        let column = index % Self.columns
        guard row < rows else { return nil }
        let rect = CGRect(x: CGFloat(column) * tileWidth, y: CGFloat(row) * tileHeight,
                          width: tileWidth, height: tileHeight)
        guard let tileCG = gridCG.cropping(to: rect) else { return nil }
        let tile = UIImage(cgImage: tileCG)
        tiles[key] = tile
        return tile
    }

    func removeAll() {
        tiles.removeAll()
    }
}

/// The picture the Puzzle uses until the user picks their own.
enum PuzzleDefaultImage {
    static let assetName = "PuzzleDefault"

    static let data: Data = {
        if let image = UIImage(named: assetName), let jpeg = ImageProcessing.storableJPEG(from: image) {
            return jpeg
        }
        assertionFailure("Missing \(assetName) asset")
        return Data()
    }()
}
