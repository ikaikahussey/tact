import Foundation
import os

/// A copy of the app's data files in the user's iCloud container. Unlike the
/// app's own sandbox, the container is not removed when the app is deleted, so
/// a reinstall (or a new phone signed in to the same Apple Account) can bring
/// everything back.
///
/// The local directory stays the working copy: `mirror(from:)` copies it here
/// after each save, and `restore(into:)` copies it back. Whole files are copied,
/// so with two devices the last one to save wins.
///
/// Not thread-safe: `TactStore` calls it from one queue at a time.
final class CloudBackup {
    static let containerIdentifier = "iCloud.app.bitrig.ikaikahussey.tact"
    static let dataFileNames = ["people.json", "notes.json", "settings.json"]
    static let photosFolder = "Photos"

    let directory: URL
    /// How long `hasBackup()` keeps looking when the folder is empty. On a fresh
    /// install iCloud can take a moment to list files saved by an earlier one.
    var emptyListingWait: TimeInterval = 10
    /// How long `restore(into:)` waits for files to download.
    var downloadTimeout: TimeInterval = 60

    /// Fingerprint of each file last copied, keyed by path relative to `directory`.
    private var copied: [String: Int] = [:]
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Tact", category: "CloudBackup")

    init(directory: URL) {
        self.directory = directory
    }

    /// The backup in the user's iCloud container, or `nil` when they are not
    /// signed in to iCloud or have turned iCloud off for Tact. Can block on
    /// first use, so never call it on the main thread.
    static func iCloud() -> CloudBackup? {
        let fileManager = FileManager.default
        guard fileManager.ubiquityIdentityToken != nil,
              let container = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else { return nil }
        return CloudBackup(directory: container.appendingPathComponent("Tact", isDirectory: true))
    }

    // MARK: Restoring

    /// Whether an earlier install saved any data here.
    func hasBackup() -> Bool {
        let deadline = Date().addingTimeInterval(emptyListingWait)
        while true {
            if relativePaths(in: directory).contains(where: Self.dataFileNames.contains) { return true }
            if Date() >= deadline { return false }
            Thread.sleep(forTimeInterval: 1)
        }
    }

    /// Downloads the backup if needed and copies it into `destination`.
    /// Throws if the files cannot be downloaded within `downloadTimeout`.
    func restore(into destination: URL) throws {
        let fileManager = FileManager.default
        let paths = relativePaths(in: directory)
        for path in paths {
            try? fileManager.startDownloadingUbiquitousItem(at: directory.appendingPathComponent(path))
        }
        let deadline = Date().addingTimeInterval(downloadTimeout)
        for path in paths {
            while !isDownloaded(path) {
                guard Date() < deadline else { throw CocoaError(.ubiquitousFileUnavailable) }
                Thread.sleep(forTimeInterval: 0.5)
            }
            let data = try coordinatedRead(directory.appendingPathComponent(path))
            let target = destination.appendingPathComponent(path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: target, options: .atomic)
            copied[path] = data.fingerprint
        }
        log.notice("Restored \(paths.count) files from iCloud")
    }

    // MARK: Backing up

    /// Copies files from `source` that differ from the backup, and removes
    /// backed-up photos that no longer exist there. Data files are never
    /// removed, so a partial local save cannot empty the backup.
    func mirror(from source: URL) throws {
        let local = Set(relativePaths(in: source))
        for path in local.sorted() {
            let data = try Data(contentsOf: source.appendingPathComponent(path))
            let fingerprint = data.fingerprint
            if copied[path] == nil, let existing = try? Data(contentsOf: directory.appendingPathComponent(path)) {
                copied[path] = existing.fingerprint
            }
            guard copied[path] != fingerprint else { continue }
            try coordinatedWrite(data, to: directory.appendingPathComponent(path))
            copied[path] = fingerprint
        }
        for path in relativePaths(in: directory) where path.hasPrefix(Self.photosFolder + "/") && !local.contains(path) {
            try coordinatedDelete(directory.appendingPathComponent(path))
            copied[path] = nil
        }
    }

    // MARK: Files

    /// Data files and photos in `folder`, as paths relative to it.
    private func relativePaths(in folder: URL) -> [String] {
        func names(in url: URL) -> [String] {
            ((try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []).map(Self.logicalName)
        }
        let topLevel = Set(names(in: folder))
        let photos = names(in: folder.appendingPathComponent(Self.photosFolder))
            .filter { $0.hasSuffix(".jpg") }
            .map { "\(Self.photosFolder)/\($0)" }
        return Self.dataFileNames.filter(topLevel.contains) + photos.sorted()
    }

    /// iCloud lists a file that is not downloaded yet as ".name.icloud".
    static func logicalName(_ name: String) -> String {
        let suffix = ".icloud"
        guard name.hasPrefix("."), name.hasSuffix(suffix), name.count > suffix.count + 1 else { return name }
        return String(name.dropFirst().dropLast(suffix.count))
    }

    private func isDownloaded(_ path: String) -> Bool {
        // A fresh URL each time, so resource values are not served from cache.
        let url = directory.appendingPathComponent(path)
        let keys: Set<URLResourceKey> = [.isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        guard let values = try? url.resourceValues(forKeys: keys), values.isUbiquitousItem == true else {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return values.ubiquitousItemDownloadingStatus != .notDownloaded
    }

    private func coordinatedRead(_ url: URL) throws -> Data {
        var result: Result<Data, Error> = .failure(CocoaError(.fileReadUnknown))
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { url in
            result = Result { try Data(contentsOf: url) }
        }
        if let coordinationError { throw coordinationError }
        return try result.get()
    }

    private func coordinatedWrite(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var result: Result<Void, Error> = .success(())
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { url in
            result = Result { try data.write(to: url, options: .atomic) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }

    private func coordinatedDelete(_ url: URL) throws {
        var result: Result<Void, Error> = .success(())
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { url in
            result = Result { try FileManager.default.removeItem(at: url) }
        }
        if let coordinationError { throw coordinationError }
        try result.get()
    }
}
