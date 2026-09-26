import Foundation
import UIKit

// MARK: - Minimal OpenAI client (chat completions with vision + image edits)

struct OpenAIClient {
    enum ClientError: LocalizedError {
        case missingKey
        case http(Int, String)
        case malformed(String)
        case invalidImageCount(Int)
        case invalidReference(Int)

        var errorDescription: String? {
            switch self {
            case .missingKey: "Add your OpenAI API key in Settings."
            case .http(let code, let body): "OpenAI returned \(code): \(body.prefix(300))"
            case .malformed(let why): "Unexpected response: \(why)"
            case .invalidImageCount: "Image edits require between 1 and 4 reference images."
            case .invalidReference(let index): "Reference image \(index) could not be encoded. Choose another image."
            }
        }
    }

    enum Part {
        case text(String)
        case image(UIImage)
    }

    var apiKey: String
    var model: String
    private let session: URLSession

    init(apiKey: String = AppConfig.openAIKey, model: String = AppConfig.openAIModel, session: URLSession? = nil) {
        self.apiKey = apiKey
        self.model = model
        self.session = session ?? Self.makeSession()
    }

    private static func makeSession() -> URLSession {
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
                guard let b64 = img.fuseJPEGBase64 else {
                    throw ClientError.malformed("a source image could not be encoded")
                }
                content.append(["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(b64)", "detail": "auto"]])
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
        try Self.validateHTTPResponse(response)
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

    /// Edits using every supplied reference in order, with the first image as the primary input.
    func imageEdit(prompt: String, images: [UIImage]) async throws -> Data {
        guard !apiKey.isEmpty else { throw ClientError.missingKey }
        guard (1...4).contains(images.count) else { throw ClientError.invalidImageCount(images.count) }
        // Prepare all references before sending anything; never silently omit a failed input.
        let references = try images.enumerated().map { index, image in
            try Self.referencePNG(image, index: index + 1)
        }
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
        field("size", "auto")
        field("quality", "medium")
        for (index, png) in references.enumerated() {
            file("image[]", "image\(index + 1).png", png)
        }
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/edits")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = body

        let (data, response) = try await session.data(for: request)
        return try Self.decodeImageResponse(data, response: response)
    }

    /// Generates an image from a prompt only (fallback when there is nothing to edit).
    func imageGenerate(prompt: String) async throws -> Data {
        guard !apiKey.isEmpty else { throw ClientError.missingKey }
        let body: [String: Any] = ["model": "gpt-image-2", "prompt": prompt, "size": "auto", "quality": "medium"]
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        return try Self.decodeImageResponse(data, response: response)
    }

    private static func referencePNG(_ image: UIImage, index: Int) throws -> Data {
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            throw ClientError.invalidReference(index)
        }
        let prepared: UIImage
        let longest = max(width, height)
        if longest > 2048 || image.imageOrientation != .up {
            // PNG references must contain the displayed orientation in their pixels.
            let factor = min(1, 2048 / longest)
            let target = CGSize(width: max(1, width * factor), height: max(1, height * factor))
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            prepared = UIGraphicsImageRenderer(size: target, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
        } else {
            prepared = image
        }
        guard let png = prepared.pngData(), !png.isEmpty else {
            throw ClientError.invalidReference(index)
        }
        return png
    }

    /// Both image endpoints must return actual decodable pixels, not merely valid base64.
    private static func decodeImageResponse(_ data: Data, response: URLResponse) throws -> Data {
        try validateHTTPResponse(response)
        let json: [String: Any]
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ClientError.malformed("image response is not a JSON object")
            }
            json = object
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError.malformed("image response is not valid JSON")
        }
        if (json["error"] != nil && !(json["error"] is NSNull)) || json["status"] as? String == "failed" {
            throw ClientError.malformed("the image service reported a failed request")
        }
        guard
            let list = json["data"] as? [[String: Any]],
            let b64 = list.first?["b64_json"] as? String,
            let bytes = Data(base64Encoded: b64),
            !bytes.isEmpty
        else {
            throw ClientError.malformed("no image data")
        }
        guard UIImage(data: bytes) != nil else {
            throw ClientError.malformed("image data could not be decoded")
        }
        return bytes
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let reason: String
            switch status {
            case 401: reason = "Authentication failed. Check your OpenAI API key."
            case 403: reason = "Your account does not have access to this request."
            case 429: reason = "The request hit a rate or usage limit. Try again later."
            case 500...599: reason = "The OpenAI service is unavailable. Try again later."
            default: reason = "The request failed (\(HTTPURLResponse.localizedString(forStatusCode: status)))."
            }
            // Error bodies can contain credential or request details. Never surface them.
            throw ClientError.http(status, reason)
        }
    }
}
