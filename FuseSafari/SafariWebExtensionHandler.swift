import SafariServices
import Foundation

// MARK: - Fuse Safari extension (native side)
//
// Two jobs:
//  1. Remember every page the user reads (URL, title, text, selection) in the App Group.
//  2. Fuse on request, right here, without opening the app: the popup asks for "status"
//     (the two most recent pages) and then "fuse" (run the engine and return the result).
// The result is also parked for the app, so opening Fuse later shows it in full.

@objc(SafariWebExtensionHandler)
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        let item = context.inputItems.first as? NSExtensionItem
        let message = item?.userInfo?[SFExtensionMessageKey] as? [String: Any] ?? [:]
        let kind = message["kind"] as? String ?? "visit"

        switch kind {
        case "status":
            reply(context, statusPayload())
        case "fuse", "fold":
            // "fold": the page saw the phone fold. One fuse per fold; ignore echoes from the other window.
            if kind == "fold" {
                let last = SharedInbox.defaults?.double(forKey: "fuse.lastFoldFuseAt") ?? 0
                let now = Date().timeIntervalSince1970
                if now - last < 15, let data = SharedInbox.defaults?.data(forKey: SharedInbox.lastBackgroundResultKey),
                   let cached = try? JSONDecoder().decode(FuseResult.self, from: data) {
                    reply(context, ["ok": true, "title": cached.title, "summary": cached.summary, "text": cached.artifact.compactText, "recipe": cached.recipe])
                    return
                }
                SharedInbox.defaults?.set(now, forKey: "fuse.lastFoldFuseAt")
            }
            let instruction = (message["instruction"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await self.fuse(instruction: instruction, context: context) }
        case "stage":
            let url = message["url"] as? String ?? ""
            let title = message["title"] as? String ?? url
            let text = message["text"] as? String ?? ""
            let selection = message["selection"] as? String ?? ""
            let side: SharedInbox.Item.Side = (message["side"] as? String) == "right" ? .right : .left
            let body = selection.isEmpty ? text : "SELECTED: \(selection)\n\n\(text)"
            SharedInbox.enqueue(.init(side: side, kind: .url, title: title, text: body, url: url))
            reply(context, ["ok": true, "staged": side.rawValue])
        default:
            let url = message["url"] as? String ?? ""
            let title = message["title"] as? String ?? url
            let text = message["text"] as? String ?? ""
            let selection = message["selection"] as? String ?? ""
            if !url.isEmpty, url.hasPrefix("http") {
                SharedInbox.recordVisit(.init(url: url, title: title, text: String(text.prefix(6000)), selection: String(selection.prefix(2000))))
            }
            reply(context, ["ok": true])
        }
    }

    // MARK: Status

    private func recent() -> [SharedInbox.Visit] {
        SharedInbox.recentVisits().filter { Date().timeIntervalSince($0.at) < 45 * 60 }
    }

    private func statusPayload() -> [String: Any] {
        let visits = recent()
        return [
            "ok": true,
            "pages": visits.prefix(2).map { ["title": $0.title, "url": $0.url] },
            "hasKey": AppConfig.hasOpenAI
        ]
    }

    // MARK: Fuse

    private func fuse(instruction: String?, context: NSExtensionContext) async {
        let visits = recent()
        guard visits.count >= 2 else {
            reply(context, ["ok": false, "error": "Read two pages first, then tap Fuse."])
            return
        }
        guard AppConfig.hasOpenAI else {
            reply(context, ["ok": false, "error": "Open Fuse once to set the OpenAI key."])
            return
        }
        let a = visits[0], b = visits[1]
        let left = SurfaceSnapshot(kind: .web, title: a.title, text: (a.selection.isEmpty ? "" : "SELECTED: \(a.selection)\n\n") + a.text, metadata: ["url": a.url])
        let right = SurfaceSnapshot(kind: .web, title: b.title, text: (b.selection.isEmpty ? "" : "SELECTED: \(b.selection)\n\n") + b.text, metadata: ["url": b.url])
        do {
            var result = try await FuseEngine().fuse(left: left, right: right, instruction: (instruction?.isEmpty == false) ? instruction : nil) { _ in }
            if case .image = result.artifact { result.artifact = .markdown(result.summary) }
            result.inputs = [InputSummary(kind: .web, title: a.title), InputSummary(kind: .web, title: b.title)]
            if let data = try? JSONEncoder().encode(result) {
                SharedInbox.defaults?.set(data, forKey: SharedInbox.lastBackgroundResultKey)
            }
            reply(context, [
                "ok": true,
                "title": result.title,
                "summary": result.summary,
                "text": result.artifact.compactText,
                "recipe": result.recipe,
                "followUps": result.followUps
            ])
        } catch {
            reply(context, ["ok": false, "error": error.localizedDescription])
        }
    }

    private func reply(_ context: NSExtensionContext, _ payload: [String: Any]) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: payload]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
