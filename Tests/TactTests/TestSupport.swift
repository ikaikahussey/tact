import Foundation
import UIKit
@testable import Tact

enum TestSupport {
    static func temporaryDirectory(_ name: String = #function) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("TactTests-\(name)-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func defaults(_ name: String = #function) -> UserDefaults {
        let suite = "TactTests-\(name)-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    /// A small solid-colour JPEG.
    static func jpeg(width: Int = 64, height: Int = 48, color: UIColor = .red) -> Data {
        let size = CGSize(width: width, height: height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
        return image.jpegData(compressionQuality: 0.9)!
    }

    static func makeStore(directory: URL, defaults: UserDefaults) -> TactStore {
        TactStore(persistence: PersistenceController(directory: directory), defaults: defaults, saveDelay: 0)
    }
}
