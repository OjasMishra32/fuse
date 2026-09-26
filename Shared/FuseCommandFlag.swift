import Foundation

/// A one-shot command left for the app by a control, widget or intent running in another process.
enum FuseCommandFlag {
    static let key = "fuse.pendingCommand"

    static func set(_ value: String) {
        SharedInbox.defaults?.set(value, forKey: key)
    }

    static func take() -> String? {
        guard let value = SharedInbox.defaults?.string(forKey: key) else { return nil }
        SharedInbox.defaults?.removeObject(forKey: key)
        return value
    }
}
