import SafariServices
import Foundation
import UIKit

// MARK: - Fuse Safari extension (native side)
//
// Two jobs:
//  1. Remember every page the user reads (URL, title, text, selection, and the photo when the
//     page is mainly showing one) in the App Group.
//  2. Fuse on request, right here, without opening the app: the popup asks for "status"
//     (the two most recent pages) and then "fuse" (run the engine and return the result).
//     Two photos (say, one person on each half) come back as one fused photo.
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
                    reply(context, replyPayload(for: cached))
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
                SharedInbox.recordVisit(.init(url: url, title: title, text: String(text.prefix(6000)), selection: String(selection.prefix(2000)), image: pageImage(message["image"])))
            }
            reply(context, ["ok": true])
        }
    }

    // MARK: Status

    private func recent() -> [SharedInbox.Visit] {
        SharedInbox.recentVisits().filter { Date().timeIntervalSince($0.at) < 45 * 60 }
    }

    private func statusPayload() -> [String: Any] {
        let pages = Array(recent().prefix(2))
        return [
            "ok": true,
            "pages": pages.map { visit -> [String: Any] in
                var page: [String: Any] = ["title": visit.title, "url": visit.url]
                if let thumb = thumbnail(for: visit.image) { page["thumb"] = thumb }
                return page
            },
            "photos": pages.count == 2 && pages.allSatisfy { $0.image != nil },
            "hasKey": AppConfig.hasOpenAI
        ]
    }

    /// The photo the content script found on the page, saved so it can be loaded later.
    private func pageImage(_ value: Any?) -> SharedInbox.PageImageRef? {
        guard let info = value as? [String: Any], let src = info["src"] as? String, !src.isEmpty else { return nil }
        let alt = String((info["alt"] as? String ?? "").prefix(300))
        let width = (info["width"] as? NSNumber)?.intValue ?? 0
        let height = (info["height"] as? NSNumber)?.intValue ?? 0
        if src.lowercased().hasPrefix("data:") {
            guard let data = PageImage.decodeDataURI(src), let file = SharedInbox.storePageImage(data) else { return nil }
            return .init(url: nil, file: file, alt: alt, width: width, height: height)
        }
        guard src.lowercased().hasPrefix("http") else { return nil }
        return .init(url: src, file: nil, alt: alt, width: width, height: height)
    }

    /// Something the popup can show next to a page: the image URL, or a small inline copy of a saved one.
    private func thumbnail(for ref: SharedInbox.PageImageRef?) -> String? {
        guard let ref else { return nil }
        if let url = ref.url { return url }
        guard let file = ref.file, let url = SharedInbox.pageImageURL(file),
              let data = try? Data(contentsOf: url), let image = UIImage(data: data) else { return nil }
        return Self.dataURL(image, maxEdge: 120, quality: 0.7)
    }

    private static func dataURL(_ image: UIImage, maxEdge: CGFloat, quality: CGFloat) -> String? {
        guard let jpeg = image.fuseDownscaled(maxEdge: maxEdge).jpegData(compressionQuality: quality) else { return nil }
        return "data:image/jpeg;base64," + jpeg.base64EncodedString()
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
        do {
            // Pages showing a photo come in as that photo, loaded at full resolution.
            async let leftSnapshot = a.snapshot()
            async let rightSnapshot = b.snapshot()
            let (left, right) = try await (leftSnapshot, rightSnapshot)
            var result = try await FuseEngine().fuse(left: left, right: right, instruction: (instruction?.isEmpty == false) ? instruction : nil) { _ in }
            result.inputs = [InputSummary(kind: .web, title: a.title), InputSummary(kind: .web, title: b.title)]
            if let data = try? JSONEncoder().encode(result) {
                SharedInbox.defaults?.set(data, forKey: SharedInbox.lastBackgroundResultKey)
            }
            reply(context, replyPayload(for: result))
        } catch {
            reply(context, ["ok": false, "error": error.localizedDescription])
        }
    }

    /// What the popup and the in-page sheet render. A fused photo travels as a 1024 px JPEG
    /// preview; the full-size photo stays parked for the app.
    private func replyPayload(for result: FuseResult) -> [String: Any] {
        var payload: [String: Any] = [
            "ok": true,
            "title": result.title,
            "summary": result.summary,
            "text": result.artifact.compactText,
            "recipe": result.recipe,
            "followUps": result.followUps,
            "type": result.artifact.typeName
        ]
        if let data = try? JSONEncoder().encode(result.artifact),
           var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            json["image_base64"] = nil
            payload["artifact"] = json
        }
        if case .image(let image) = result.artifact, let ui = image.uiImage,
           let preview = Self.dataURL(ui, maxEdge: 1024, quality: 0.85) {
            payload["image"] = preview
            payload["text"] = ""
        }
        return payload
    }

    private func reply(_ context: NSExtensionContext, _ payload: [String: Any]) {
        let response = NSExtensionItem()
        response.userInfo = [SFExtensionMessageKey: payload]
        context.completeRequest(returningItems: [response], completionHandler: nil)
    }
}
