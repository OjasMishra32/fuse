import Foundation
import UIKit

// MARK: - The photo a page is showing
//
// When someone is looking at a picture in Safari (an image opened on its own, an image
// viewer, a photo page), the thing to fuse is that photo, not a screenshot of the browser.
// The Safari extension's content script and the in-app browser both run the same detection:
// the page is an image document, or one loaded image covers a large part of the viewport.
// The real image is then loaded at full resolution from its URL (or the page's inline data).

enum PageImage {
    enum LoadError: LocalizedError {
        case unreachable(String)

        var errorDescription: String? {
            switch self {
            case .unreachable(let host):
                "Couldn't load the photo from \(host). Tap the photo in Safari so it opens on its own, then fuse again."
            }
        }
    }

    /// A viewport photo must cover at least this share of the visible page to count as "the" photo.
    /// Keep in sync with `FuseSafari/Resources/content.js`.
    static let minimumCoverage = 0.3

    /// Evaluates to a JSON string: `{"src","alt","width","height","coverage"}` for the photo the page
    /// is mainly showing, or `null`. Same rules as the Safari extension's content script.
    static let detectionScript = """
    (function(){
      function pick(){
        var vw = window.innerWidth || document.documentElement.clientWidth;
        var vh = window.innerHeight || document.documentElement.clientHeight;
        if (!vw || !vh) return null;
        if ((document.contentType || "").indexOf("image/") === 0) {
          var only = document.images[0];
          return { src: location.href, alt: "", width: only ? only.naturalWidth : 0, height: only ? only.naturalHeight : 0, coverage: 1 };
        }
        var best = null, bestArea = 0, imgs = document.images;
        for (var i = 0; i < imgs.length; i++) {
          var img = imgs[i];
          if (!img.complete || img.naturalWidth < 256 || img.naturalHeight < 256) continue;
          var r = img.getBoundingClientRect();
          var w = Math.min(r.right, vw) - Math.max(r.left, 0);
          var h = Math.min(r.bottom, vh) - Math.max(r.top, 0);
          if (w <= 0 || h <= 0 || w * h <= bestArea) continue;
          var cs = window.getComputedStyle(img);
          if (cs.visibility === "hidden" || cs.display === "none" || parseFloat(cs.opacity) < 0.2) continue;
          best = img; bestArea = w * h;
        }
        if (!best) return null;
        var coverage = bestArea / (vw * vh);
        if (coverage < \(minimumCoverage)) return null;
        var src = best.currentSrc || best.src || "";
        if (src.indexOf("blob:") === 0) {
          try {
            var c = document.createElement("canvas");
            c.width = best.naturalWidth; c.height = best.naturalHeight;
            c.getContext("2d").drawImage(best, 0, 0);
            src = c.toDataURL("image/jpeg", 0.92);
          } catch (e) { return null; }
        }
        if (!src || (src.indexOf("data:") === 0 && src.length > 6000000)) return null;
        return { src: src, alt: (best.alt || best.title || "").slice(0, 300), width: best.naturalWidth, height: best.naturalHeight, coverage: Math.round(coverage * 100) / 100 };
      }
      try { return JSON.stringify(pick()); } catch (e) { return "null"; }
    })()
    """

    struct Detected: Decodable, Equatable {
        var src: String
        var alt: String?
        var width: Int?
        var height: Int?
        var coverage: Double?
    }

    /// Parses the detection script's result. Nil for `null`, garbage, or unusable sources.
    static func parse(_ json: String) -> Detected? {
        guard let data = json.data(using: .utf8),
              let found = try? JSONDecoder().decode(Detected.self, from: data) else { return nil }
        let src = found.src.lowercased()
        guard src.hasPrefix("http") || src.hasPrefix("data:image/") else { return nil }
        return found
    }

    // MARK: Loading

    /// Decodes a `data:image/…;base64,…` URI.
    static func decodeDataURI(_ uri: String) -> Data? {
        guard uri.lowercased().hasPrefix("data:image/"), let comma = uri.firstIndex(of: ",") else { return nil }
        let header = uri[..<comma].lowercased()
        guard header.contains(";base64") else { return nil }
        return Data(base64Encoded: String(uri[uri.index(after: comma)...]), options: .ignoreUnknownCharacters)
    }

    /// Loads an image from an http(s) URL or a data URI, sending the page as the referrer
    /// because many image hosts refuse hotlinked requests without one.
    static func load(source: String, referer: String?) async throws -> UIImage {
        let host = URL(string: referer ?? source)?.host ?? "the page"
        if source.lowercased().hasPrefix("data:") {
            guard let data = decodeDataURI(source), let image = UIImage(data: data), image.fuseUsablePhoto else {
                throw LoadError.unreachable(host)
            }
            return image
        }
        guard let url = URL(string: source), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw LoadError.unreachable(host)
        }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 27_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.1 Mobile/15E148 Safari/604.1", forHTTPHeaderField: "User-Agent")
        request.setValue("image/avif,image/webp,image/png,image/jpeg,image/*;q=0.8", forHTTPHeaderField: "Accept")
        if let referer { request.setValue(referer, forHTTPHeaderField: "Referer") }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard (200..<300).contains(status), let image = UIImage(data: data), image.fuseUsablePhoto else {
                throw LoadError.unreachable(url.host ?? host)
            }
            return image
        } catch let error as LoadError {
            throw error
        } catch {
            throw LoadError.unreachable(url.host ?? host)
        }
    }

    /// Loads a photo the Safari extension recorded: from the group container, or from its URL.
    static func load(_ ref: SharedInbox.PageImageRef, pageURL: String) async throws -> UIImage {
        let host = URL(string: pageURL)?.host ?? "the page"
        if let file = ref.file {
            guard let url = SharedInbox.pageImageURL(file), let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data), image.fuseUsablePhoto else {
                throw LoadError.unreachable(host)
            }
            return image
        }
        guard let source = ref.url else { throw LoadError.unreachable(host) }
        return try await load(source: source, referer: pageURL)
    }
}

extension UIImage {
    /// Big enough to be worth fusing (thumbnails and tracking pixels are not).
    var fuseUsablePhoto: Bool {
        min(size.width * scale, size.height * scale) >= 128
    }
}

// MARK: - Safari pages as engine input

extension SharedInbox.Visit {
    /// The page as the engine sees it. When the page was mainly showing a photo, that photo is
    /// loaded at full resolution and the snapshot is marked as a photo.
    func snapshot() async throws -> SurfaceSnapshot {
        let body = (selection.isEmpty ? "" : "SELECTED: \(selection)\n\n") + text
        var meta: [String: String] = ["url": url]
        guard let ref = image else {
            return SurfaceSnapshot(kind: .web, title: title, text: body, metadata: meta)
        }
        let photo = try await PageImage.load(ref, pageURL: url)
        meta["content"] = "photo"
        if let src = ref.url { meta["image_url"] = src }
        if !ref.alt.isEmpty { meta["image_alt"] = ref.alt }
        return SurfaceSnapshot(kind: .web, title: title, text: body, metadata: meta, heroImage: photo.fuseDownscaled(maxEdge: 2048))
    }
}
