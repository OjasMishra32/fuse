import Foundation
import UIKit

// MARK: - FuseEngine
//
// left snapshot + right snapshot (+ spoken instruction) → FuseResult.
// One vision call decides the relationship and writes the artifact; image artifacts get a
// second call to the image model.

struct FuseEngine {
    enum Stage: String {
        case reading = "Reading both screens"
        case relating = "Finding the relationship"
        case composing = "Composing"
        case rendering = "Rendering the image"
    }

    var client: OpenAIClient

    init(client: OpenAIClient = OpenAIClient()) {
        self.client = client
    }

    func fuse(
        left: SurfaceSnapshot,
        right: SurfaceSnapshot,
        instruction: String?,
        suggested: String? = nil,
        progress: @escaping @Sendable (Stage) -> Void
    ) async throws -> FuseResult {
        progress(.reading)

        var parts: [OpenAIClient.Part] = []
        parts.append(.text(Prompts.userPreamble(instruction: instruction, suggested: suggested)))
        parts.append(.text(Prompts.describe(left, side: "left")))
        if let img = left.image { parts.append(.image(img)) }
        parts.append(.text(Prompts.describe(right, side: "right")))
        if let img = right.image { parts.append(.image(img)) }
        parts.append(.text(Prompts.closing))

        progress(.relating)
        let raw = try await client.chatJSON(system: Prompts.system, parts: parts)

        progress(.composing)
        var result = try Self.decode(raw)
        result.inputs = [
            InputSummary(kind: left.kind, title: left.title),
            InputSummary(kind: right.kind, title: right.title)
        ]
        result.instruction = instruction?.isEmpty == false ? instruction : nil

        if case .image(var image) = result.artifact, image.imageBase64 == nil {
            progress(.rendering)
            let sources = [left.image, right.image].compactMap { $0 }
            let data: Data
            if sources.isEmpty {
                data = try await client.imageGenerate(prompt: image.prompt)
            } else {
                data = try await client.imageEdit(prompt: image.prompt, images: sources)
            }
            image.imageBase64 = data.base64EncodedString()
            result.artifact = .image(image)
        }
        return result
    }

    /// Lenient JSON → FuseResult. Strips code fences and finds the outermost object.
    static func decode(_ raw: String) throws -> FuseResult {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text.replacingOccurrences(of: "```json", with: "").replacingOccurrences(of: "```", with: "")
        }
        if let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}") {
            text = String(text[start...end])
        }
        guard let data = text.data(using: .utf8) else {
            throw OpenAIClient.ClientError.malformed("not utf8")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            return try decoder.decode(FuseResult.self, from: data)
        } catch {
            // Last resort: show whatever the model wrote.
            return FuseResult(recipe: "fuse", title: "Fused", summary: "", artifact: .markdown(raw))
        }
    }
}
