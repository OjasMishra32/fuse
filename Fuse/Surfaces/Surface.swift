import SwiftUI
import UIKit
import Observation

// MARK: - Surface contract
//
// A *surface* is a live mini-app that lives on one half of the iPhone Duo (browser, maps,
// notes, photo, file, calendar, clipboard…). Fuse never reads other apps' screens — iOS
// doesn't allow that — so every surface is ours, and every surface knows how to describe
// its own live state to the model through `capture()`.
//
// To add a surface: add a `SurfaceKind` case, a `<Name>SurfaceModel` (`@MainActor @Observable`,
// conforming to `SurfaceModel`) and a `<Name>SurfaceView(model:)`, then wire both into
// `SurfaceRegistry`. Nothing else in the app needs to change.

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

    init(kind: SurfaceKind, title: String, text: String = "", image: UIImage? = nil, metadata: [String: String] = [:]) {
        self.kind = kind
        self.title = title
        self.text = text
        self.image = image
        self.metadata = metadata
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && image == nil && metadata.isEmpty
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

@MainActor
protocol SurfaceModel: AnyObject, Observable {
    var kind: SurfaceKind { get }
    /// One line describing the live state: page title, place name, first line of the note…
    var headline: String { get }
    /// True once the user has put something on this screen.
    var hasContent: Bool { get }
    /// Cheap live preview used by the melt animation. May be nil; the app falls back to the kind's glyph.
    var thumbnail: UIImage? { get }
    /// Produce the snapshot the model will read. May take a moment (web page text, PDF parsing…).
    func capture() async -> SurfaceSnapshot
    /// Seed content (demo scenarios, intents).
    func apply(_ preset: SurfacePreset)
    /// Clear the surface.
    func reset()
}

// MARK: - Pane

/// One half of the device. Owns one model per surface kind so switching kinds keeps state.
@MainActor
@Observable
final class Pane: Identifiable {
    enum Side: String, Codable, CaseIterable {
        case left, right
        var title: String { self == .left ? "Left" : "Right" }
    }

    let side: Side
    var kind: SurfaceKind
    /// True while this half shows the home screen instead of an app.
    var isHome: Bool = true
    private var models: [SurfaceKind: any SurfaceModel] = [:]

    init(side: Side, kind: SurfaceKind) {
        self.side = side
        self.kind = kind
    }

    /// Open an app on this half.
    func open(_ kind: SurfaceKind) {
        self.kind = kind
        isHome = false
    }

    /// Back to the home screen; the app keeps its state.
    func goHome() {
        isHome = true
    }

    nonisolated var id: String { side.rawValue }

    var model: any SurfaceModel { model(for: kind) }

    func model(for kind: SurfaceKind) -> any SurfaceModel {
        if let existing = models[kind] { return existing }
        let created = SurfaceRegistry.makeModel(kind)
        models[kind] = created
        return created
    }

    func apply(_ preset: SurfacePreset, as kind: SurfaceKind) {
        self.kind = kind
        isHome = false
        model(for: kind).apply(preset)
    }

    func reset() {
        models[kind]?.reset()
        isHome = true
    }
}

// MARK: - Registry

enum SurfaceRegistry {
    /// Order of the surface dock.
    static let dockOrder: [SurfaceKind] = [.web, .maps, .notes, .photo, .document, .calendar, .clipboard]

    @MainActor
    static func makeModel(_ kind: SurfaceKind) -> any SurfaceModel {
        switch kind {
        case .web: WebSurfaceModel()
        case .maps: MapSurfaceModel()
        case .notes: NotesSurfaceModel()
        case .photo: PhotoSurfaceModel()
        case .document: DocumentSurfaceModel()
        case .calendar: CalendarSurfaceModel()
        case .clipboard: ClipboardSurfaceModel()
        }
    }

    @MainActor
    @ViewBuilder
    static func view(for model: any SurfaceModel) -> some View {
        switch model.kind {
        case .web:
            if let m = model as? WebSurfaceModel { WebSurfaceView(model: m) }
        case .maps:
            if let m = model as? MapSurfaceModel { MapSurfaceView(model: m) }
        case .notes:
            if let m = model as? NotesSurfaceModel { NotesSurfaceView(model: m) }
        case .photo:
            if let m = model as? PhotoSurfaceModel { PhotoSurfaceView(model: m) }
        case .document:
            if let m = model as? DocumentSurfaceModel { DocumentSurfaceView(model: m) }
        case .calendar:
            if let m = model as? CalendarSurfaceModel { CalendarSurfaceView(model: m) }
        case .clipboard:
            if let m = model as? ClipboardSurfaceModel { ClipboardSurfaceView(model: m) }
        }
    }
}

// MARK: - Helpers shared by surfaces

extension UIImage {
    /// Downscale so the longest edge is `maxEdge` points. Keeps model payloads small.
    func fuseDownscaled(maxEdge: CGFloat = 1024) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxEdge else { return self }
        let scale = maxEdge / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
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
