import Foundation

// MARK: - Intent preview
//
// The moment both screens have something on them, a quick pass asks the model
// what the best fuses would be *right now*. The top one becomes the fold's default; the
// others are one tap away on the seam. This is how the app shows its reasoning before the
// user commits to the fold.

struct FuseSuggestion: Identifiable, Codable, Hashable {
    var title: String
    var instruction: String
    var artifact: String
    var symbol: String

    var id: String { title + "|" + artifact }

    enum CodingKeys: String, CodingKey { case title, instruction, artifact, symbol }

    init(title: String, instruction: String, artifact: String, symbol: String) {
        self.title = title; self.instruction = instruction; self.artifact = artifact; self.symbol = symbol
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Fuse"
        instruction = try c.decodeIfPresent(String.self, forKey: .instruction) ?? ""
        artifact = try c.decodeIfPresent(String.self, forKey: .artifact) ?? "markdown"
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol) ?? "sparkles"
    }

    /// SF Symbol that matches the artifact type, regardless of what the model suggested.
    var resolvedSymbol: String {
        switch artifact.lowercased() {
        case "itinerary": "map"
        case "event": "calendar.badge.plus"
        case "email": "envelope"
        case "quiz": "questionmark.circle"
        case "grade": "graduationcap"
        case "slides": "rectangle.on.rectangle"
        case "code": "chevron.left.forwardslash.chevron.right"
        case "diff": "text.badge.checkmark"
        case "table": "tablecells"
        case "checklist": "checklist"
        case "image_edit", "image": "photo.on.rectangle.angled"
        default: symbol.isEmpty ? "sparkles" : symbol
        }
    }
}

struct IntentPreviewer {
    var client: OpenAIClient

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    static let system = """
    You are the router inside FUSE, an app on a foldable phone. The user has put one thing on each half of the screen and is about to fold the phone to combine them. Before they do, propose the THREE most useful things the fold could produce for exactly these two screens, best first.

    Rules:
    - Each suggestion must need BOTH screens (or the one non-empty screen plus common sense). Be specific to their actual content — name the place, the event, the document.
    - "instruction" is the one-sentence command the engine will execute; concrete, imperative, mentions the content ("Plan one day at Islands of Adventure with ride times and where to eat, pinned on the map").
    - "artifact" is one of: itinerary, event, email, quiz, grade, slides, code, diff, table, checklist, image_edit, markdown.
    - "title" is 2–4 words, verb first ("Plan the day", "Add to calendar", "Grade my answers").
    - "symbol" is an SF Symbol name.
    - When both screens contain images, inspect them. For furniture + room, clothing + person, or a subject + visual style reference, put an image_edit suggestion first. Infer the scene and object from their contents in either left/right order. Name the concrete edit ("Place the green armchair beside the window in this room"). Avoid a generic comparison when a visual composition is the useful result. Documents and message screenshots still need text-based suggestions.
    Respond with JSON only: {"suggestions":[{"title":"…","instruction":"…","artifact":"…","symbol":"…"}, …]}
    """

    func suggest(left: SurfaceSnapshot, right: SurfaceSnapshot) async throws -> [FuseSuggestion] {
        var l = left; l.text = l.text.fuseClipped(2500)
        var r = right; r.text = r.text.fuseClipped(2500)
        // A caption such as "Photo 2048×1536" cannot distinguish a chair from a room.
        // Small visual references keep the preview cheap; the edit uses larger originals.
        var parts: [OpenAIClient.Part] = [.text(Prompts.userPreamble(instruction: nil))]
        parts.append(.text(Prompts.describe(l, side: "left")))
        if let image = left.heroImage ?? left.image { parts.append(.image(image.fuseDownscaled(maxEdge: 512))) }
        parts.append(.text(Prompts.describe(r, side: "right")))
        if let image = right.heroImage ?? right.image { parts.append(.image(image.fuseDownscaled(maxEdge: 512))) }
        parts.append(.text("Respond with the JSON object only."))
        let raw = try await client.chatJSON(system: Self.system, parts: parts)
        return Self.decode(raw)
    }

    static func decode(_ raw: String) -> [FuseSuggestion] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8) else { return [] }
        struct Box: Decodable { var suggestions: [FuseSuggestion]? }
        if let box = try? JSONDecoder().decode(Box.self, from: data), let s = box.suggestions {
            return Array(s.prefix(3)).filter { !$0.instruction.isEmpty }
        }
        return []
    }
}
