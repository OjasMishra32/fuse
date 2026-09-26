import Foundation
import UIKit
import CryptoKit

// MARK: - SharedInbox
//
// The bridge between the "Send to Fuse" share extension and the app. Real apps (Safari,
// Photos, Files, Messages…) hand content to the extension through the share sheet; the
// extension parks it here (an App Group container); the app picks it up the next time it
// comes to the front and puts it on the chosen half of the phone.

enum SharedInbox {
    static let groupID = "group.com.ojasvamishra.fuse"
    private static let key = "fuse.inbox.items"

    struct Item: Codable {
        enum Side: String, Codable { case left, right, both }
        enum Kind: String, Codable { case url, text, image, file, screen }   // screen = a screenshot of two apps side by side; split at the fold
        var side: Side
        var kind: Kind
        var title: String
        var text: String?
        var url: String?
        var fileName: String?      // relative to the group container
        var createdAt: Date = Date()
    }

    static var defaults: UserDefaults? { UserDefaults(suiteName: groupID) }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    static func enqueue(_ item: Item) {
        var items = pending()
        items.append(item)
        if let data = try? JSONEncoder().encode(items) {
            defaults?.set(data, forKey: key)
        }
    }

    static func pending() -> [Item] {
        guard let data = defaults?.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([Item].self, from: data)) ?? []
    }

    /// Returns and clears everything waiting.
    static func drain() -> [Item] {
        let items = pending()
        defaults?.removeObject(forKey: key)
        return items
    }

    /// Copies a file into the group container and returns its relative name.
    static func store(data: Data, preferredName: String) -> String? {
        guard let container = containerURL else { return nil }
        let dir = container.appendingPathComponent("inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = UUID().uuidString + "-" + preferredName.replacingOccurrences(of: "/", with: "_")
        let url = dir.appendingPathComponent(name)
        do {
            try data.write(to: url)
            return name
        } catch {
            return nil
        }
    }

    // MARK: Recents — pages the Safari extension saw the user read

    struct Visit: Codable, Equatable {
        var url: String
        var title: String
        var text: String
        var selection: String
        var at: Date = Date()
        /// Set when the page was mainly showing one photo (an image opened in Safari, an image viewer, a photo page).
        var image: PageImageRef? = nil
    }

    /// The photo a page was showing. `url` for http(s) images; `file` (relative to the group
    /// container) for inline images the page only had as data, saved by `storePageImage`.
    struct PageImageRef: Codable, Equatable {
        var url: String?
        var file: String?
        var alt: String
        var width: Int
        var height: Int
    }

    private static let recentsKey = "fuse.recents"
    /// A FuseResult (JSON) produced outside the app, e.g. by the Safari extension.
    static let lastBackgroundResultKey = "fuse.lastBackgroundResult"

    static func recordVisit(_ visit: Visit) {
        var list = recentVisits().filter { $0.url != visit.url }
        list.insert(visit, at: 0)
        list = Array(list.prefix(12))
        if let data = try? JSONEncoder().encode(list) { defaults?.set(data, forKey: recentsKey) }
    }

    static func recentVisits() -> [Visit] {
        guard let data = defaults?.data(forKey: recentsKey) else { return [] }
        return (try? JSONDecoder().decode([Visit].self, from: data)) ?? []
    }

    static func clearRecents() {
        defaults?.removeObject(forKey: recentsKey)
    }

    /// Saves an inline page image once (named by its content hash) and returns its relative name.
    static func storePageImage(_ data: Data) -> String? {
        guard let container = containerURL, !data.isEmpty else { return nil }
        let dir = container.appendingPathComponent("pages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: data).prefix(12).map { String(format: "%02x", $0) }.joined()
        let name = "pages/\(digest).img"
        let url = container.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) { return name }
        do {
            try data.write(to: url)
            return name
        } catch {
            return nil
        }
    }

    static func pageImageURL(_ name: String) -> URL? {
        containerURL?.appendingPathComponent(name)
    }

    /// Returns and clears a result produced outside the app (the Safari extension), if any.
    static func takeBackgroundResult() -> Data? {
        guard let data = defaults?.data(forKey: lastBackgroundResultKey) else { return nil }
        defaults?.removeObject(forKey: lastBackgroundResultKey)
        return data
    }

    static func fileURL(for item: Item) -> URL? {
        guard let name = item.fileName, let container = containerURL else { return nil }
        return container.appendingPathComponent("inbox", isDirectory: true).appendingPathComponent(name)
    }
}
