import SwiftUI
import UIKit

// MARK: - Surface types shared with the extensions
//
// These are the data types the engine needs. They compile into the app, the Safari
// extension (which can run a fuse by itself) and the share extension.

enum SurfaceKind: String, CaseIterable, Codable, Identifiable, Hashable {
    case web, maps, notes, photo, document, calendar, clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .web: "Browser"
        case .maps: "Maps"
        case .notes: "Notes"
        case .photo: "Photo"
        case .document: "Files"
        case .calendar: "Calendar"
        case .clipboard: "Clipboard"
        }
    }

    var symbol: String {
        switch self {
        case .web: "safari"
        case .maps: "map"
        case .notes: "note.text"
        case .photo: "photo"
        case .document: "doc.text"
        case .calendar: "calendar"
        case .clipboard: "doc.on.clipboard"
        }
    }

    var tint: Color {
        switch self {
        case .web: Color(uiColor: .systemBlue)
        case .maps: Color(uiColor: .systemGreen)
        case .notes: Color(uiColor: .systemYellow)
        case .photo: Color(uiColor: .systemPink)
        case .document: Color(uiColor: .systemGray)
        case .calendar: Color(uiColor: .systemRed)
        case .clipboard: Color(uiColor: .systemTeal)
        }
    }
}

/// Everything the model gets to see about one screen at the moment of the fuse.
struct SurfaceSnapshot {
    var kind: SurfaceKind
    /// Short human label, e.g. "Universal Orlando — Tickets" or "Pin: Café Tu Tu Tango".
    var title: String
    /// Extracted text. Keep it under ~8k characters; surfaces should trim intelligently.
    var text: String
    /// A visual capture (page screenshot, the photo itself, a rendered PDF page, a map snapshot).
    var image: UIImage?
    /// Structured facts the model can rely on (url, latitude, longitude, dates, page count…).
    var metadata: [String: String]
    /// The main photo on this screen (a page's og:image, the photo itself…). Used for image fusion
    /// so the image model works from the actual picture, not a screenshot of it.
    var heroImage: UIImage? = nil

    init(kind: SurfaceKind, title: String, text: String = "", image: UIImage? = nil, metadata: [String: String] = [:], heroImage: UIImage? = nil) {
        self.kind = kind
        self.title = title
        self.text = text
        self.image = image
        self.metadata = metadata
        self.heroImage = heroImage
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil && heroImage == nil && metadata.isEmpty
    }

    /// The same selection drives both binary uploads and prompt reference numbering.
    /// Web edits use extracted photos, avoiding browser chrome in the rendered result.
    var imageEditReference: UIImage? {
        heroImage ?? (kind == .web ? nil : image)
    }

    static func empty(_ kind: SurfaceKind) -> SurfaceSnapshot {
        SurfaceSnapshot(kind: kind, title: "Empty \(kind.title.lowercased())")
    }
}

/// Seeds a surface with content. Used by the demo scenarios, deep links and App Intents.
enum SurfacePreset {
    case url(URL)
    case text(String)
    case image(UIImage)
    case place(name: String, latitude: Double, longitude: Double)
    case document(URL)
}

// MARK: - Helpers shared by surfaces

extension UIImage {
    /// Downscale so the longest edge is `maxEdge` pixels, including Retina images.
    func fuseDownscaled(maxEdge: CGFloat = 1024) -> UIImage {
        let longest = max(size.width, size.height)
        guard maxEdge > 0, longest * scale > maxEdge else { return self }
        let ratio = maxEdge / longest
        let target = CGSize(width: size.width * ratio, height: size.height * ratio)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    var fuseJPEGBase64: String? {
        fuseDownscaled().jpegData(compressionQuality: 0.72)?.base64EncodedString()
    }
}

extension String {
    /// Trim to `limit` characters, cutting on a whitespace boundary and marking the cut.
    func fuseClipped(_ limit: Int = 8000) -> String {
        guard count > limit else { return self }
        let idx = index(startIndex, offsetBy: limit)
        var head = String(self[..<idx])
        if let lastSpace = head.lastIndex(where: { $0.isWhitespace }) {
            head = String(head[..<lastSpace])
        }
        return head + "\n…[trimmed]"
    }

    var fuseCollapsedWhitespace: String {
        let lines = components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }
}
