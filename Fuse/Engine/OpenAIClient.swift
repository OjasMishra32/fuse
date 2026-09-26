import Foundation
import UIKit

// MARK: - Minimal OpenAI client (chat completions with vision + image edits)

struct OpenAIClient {
    enum ClientError: LocalizedError {
        case missingKey
        case http(Int, String)
        case malformed(String)

        var errorDescription: String? {
            switch self {
            case .missingKey: "Add your OpenAI API key in Settings."
            case .http(let code, let body): "OpenAI returned \(code): \(body.prefix(300))"
            case .malformed(let why): "Unexpected response: \(why)"
            }
        }
    }

    enum Part {
        case text(String)
        case image(UIImage)
    }

    var apiKey: String
    var model: String

    init(apiKey: String = AppConfig.openAIKey, model: String = AppConfig.openAIModel) {
        self.apiKey = apiKey
        self.model = model
    }

    private var session: URLSession {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 180
        return URLSession(configuration: config)
    }

    /// Chat completion that must answer with a JSON object. Returns the raw JSON text.
    func chatJSON(system: String, parts: [Part]) async throws -> String {
        guard !apiKey.isEmpty else { throw ClientError.missingKey }

        var content: [[String: Any]] = []
        for part in parts {
            switch part {
            case .text(let t):
                content.append(["type": "text", "text": t])
            case .image(let img):
                if let b64 = img.fuseJPEGBase64 {
                    content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "auto"]])
                }
            }
        }

        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": content]
            ],
            "response_format": ["type": "json_object"]
        ]
        let lower = model.lowercased()
        if lower.hasPrefix("gpt-5") || lower.hasPrefix("gpt-6") || lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4") {
            body["reasoning_effort"] = "low"
        }

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any],
            let text = message["content"] as? String
        else {
            throw ClientError.malformed("no choices")
        }
        return text
    }

    /// Edits the first image toward the prompt, optionally using additional reference images (gpt-image-1).
    func imageEdit(prompt: String, images: [UIImage]) async throws -> Data {
        guard !apiKey.isEmpty else { throw ClientError.missingKey }
        let boundary = "fuse-\(UUID().uuidString)"
        var body = Data()

        func field(_ name: String, _ value: String) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }
        func file(_ name: String, _ filename: String, _ data: Data) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: image/png\r\n\r\n".data(using: .utf8)!)
            body.append(data)
            body.append("\r\n".data(using: .utf8)!)
        }

        field("model", "gpt-image-2")
        field("prompt", prompt)
        field("size", "1024x1024")
        field("quality", "medium")
        for (i, img) in images.prefix(4).enumerated() {
            if let png = img.fuseDownscaled(maxEdge: 1024).pngData() {
                file("image[]", "image\(i).png", png)
            }
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]],
            let b64 = list.first?["b64_json"] as? String,
            let bytes = Data(base64Encoded: b64)
        else {
            throw ClientError.malformed("no image data")
        }
        return bytes
    }

    /// Generates an image from a prompt only (fallback when there is nothing to edit).
    func imageGenerate(prompt: String) async throws -> Data {
        guard !apiKey.isEmpty else { throw ClientError.missingKey }
        let body: [String: Any] = ["model": "gpt-image-2", "prompt": prompt, "size": "1024x1024", "quality": "medium"]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw ClientError.http(status, String(data: data, encoding: .utf8) ?? "")
        }
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let list = json["data"] as? [[String: Any]],
            let b64 = list.first?["b64_json"] as? String,
            let bytes = Data(base64Encoded: b64)
        else {
            throw ClientError.malformed("no image data")
        }
        return bytes
    }
}
