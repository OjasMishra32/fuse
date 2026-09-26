import Foundation
import Observation

// MARK: - History
//
// Every fuse result is kept as JSON in Application Support so the demo can reopen past
// results (and their generated images, which travel as base64 inside the artifact).

@MainActor
@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    /// Hard cap so base64 images can't grow the file without bound.
    static let maxItems = 50

    private(set) var items: [FuseResult] = []

    private let fileURL: URL

    private init() {
        fileURL = Self.storeURL()
        items = Self.load(from: fileURL)
    }

    // MARK: Mutations

    func add(_ result: FuseResult) {
        items.removeAll { $0.id == result.id }
        items.insert(result, at: 0)
        if items.count > Self.maxItems {
            items = Array(items.prefix(Self.maxItems))
        }
        save()
    }

    func remove(_ result: FuseResult) {
        items.removeAll { $0.id == result.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    // MARK: Persistence

    private static func storeURL() -> URL {
        let fm = FileManager.default
        let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Fuse", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("history.json")
    }

    private static func load(from url: URL) -> [FuseResult] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let decoded = try decoder.decode([FuseResult].self, from: data)
            return decoded.sorted { $0.createdAt > $1.createdAt }
        } catch {
            // A corrupt file should never take the app down; start fresh.
            return []
        }
    }

    private func save() {
        let snapshot = items
        let url = fileURL
        Task.detached(priority: .utility) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                #if DEBUG
                print("HistoryStore: failed to save — \(error.localizedDescription)")
                #endif
            }
        }
    }
}
