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
