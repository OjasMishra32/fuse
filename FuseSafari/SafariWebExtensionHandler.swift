import SafariServices
import Foundation

// MARK: - Fuse Safari extension (native side)
//
// The page script sends every page the user reads (and any "put this on a half" tap from the
// popup) here. We park it in the App Group so Fuse can pick it up the moment it comes to the
// front — from Control Center, the cover display, Spotlight or the app icon.

@objc(SafariWebExtensionHandler)
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any] ?? [:]
        let kind = message["kind"] as? String ?? "visit"
        let url = message["url"] as? String ?? ""
        let title = message["title"] as? String ?? url
        let text = message["text"] as? String ?? ""
        let selection = message["selection"] as? String ?? ""

        var reply: [String: Any] = ["ok": true]
        switch kind {
        case "stage":
            let side: SharedInbox.Item.Side = (message["side"] as? String) == "right" ? .right : .left
            let body = selection.isEmpty ? text : "SELECTED: \(selection)\n\n\(text)"
            SharedInbox.enqueue(.init(side: side, kind: .url, title: title, text: body, url: url))
            reply["staged"] = side.rawValue
        default:
            guard !url.isEmpty, url.hasPrefix("http") else { break }
            SharedInbox.recordVisit(.init(url: url, title: title, text: String(text.prefix(6000)), selection: String(selection.prefix(2000))))
        }

        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: reply]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
