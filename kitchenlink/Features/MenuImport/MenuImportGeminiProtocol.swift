import Foundation

/// Translation layer between KitchenLink's OpenAI-compatible extraction client
/// and Google's native `generateContent` protocol.
///
/// Why this exists: the Gemini Flash models reachable through the OpenCode Zen
/// gateway do **not** accept OpenAI `chat/completions` bodies. A probe with the
/// normal request returned Google's own error verbatim —
/// `Invalid JSON request body: Missing key at ["contents"]` — so the gateway
/// forwards to Google's API surface unchanged. Rather than fork the whole call
/// path, this type converts one request into Google's shape and converts the
/// answer back into the single value the caller needs: the response text plus
/// token usage.
///
/// Everything here is a pure function so the request shape and the response
/// parsing are unit-testable without a network call.
enum MenuImportGeminiProtocol {

    // MARK: - Protocol selection

    /// True for models that speak Google's native protocol. Kept as a name
    /// check because that is the only signal available before the first call;
    /// `KITCHENLINK_LLM_PROTOCOL` overrides it in the review runner.
    static func usesNativeProtocol(model: String, override: String? = nil) -> Bool {
        if let override = override?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           !override.isEmpty {
            switch override {
            case "gemini", "google", "generatecontent":
                return true
            case "openai", "chatcompletions", "chat_completions":
                return false
            default:
                break
            }
        }

        let normalized = model.lowercased()
        return normalized.hasPrefix("gemini") || normalized.contains("/gemini")
    }

    // MARK: - Authentication

    /// Google's route does not read `Authorization: Bearer`. A probe with the
    /// bearer header returned `AuthError: Missing API key.` on exactly the
    /// request that succeeded with this header, so the header name is
    /// load-bearing, not cosmetic.
    static let apiKeyHeaderField = "x-goog-api-key"

    // MARK: - Endpoint

    /// Google addresses the model in the path, not in the body.
    static func endpointURL(baseURL: String, model: String) -> URL? {
        let trimmedBase = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        guard let encodedModel = model.addingPercentEncoding(
            withAllowedCharacters: .urlPathAllowed
        ) else {
            return nil
        }
        return URL(string: "\(trimmedBase)/models/\(encodedModel):generateContent")
    }

    // MARK: - Request

    struct InlineImage: Equatable, Sendable {
        let mimeType: String
        let base64Data: String

        /// Parses a `data:<mime>;base64,<payload>` URL, which is how the
        /// OpenAI-compatible path already carries page images.
        init?(dataURL: String) {
            guard dataURL.hasPrefix("data:"),
                  let separatorRange = dataURL.range(of: ";base64,")
            else {
                return nil
            }
            let mime = String(dataURL[dataURL.index(dataURL.startIndex, offsetBy: 5)..<separatorRange.lowerBound])
            let payload = String(dataURL[separatorRange.upperBound...])
            guard !mime.isEmpty, !payload.isEmpty else { return nil }
            self.mimeType = mime
            self.base64Data = payload
        }

        init(mimeType: String, base64Data: String) {
            self.mimeType = mimeType
            self.base64Data = base64Data
        }
    }

    /// Builds a `generateContent` body.
    ///
    /// The system prompt becomes `system_instruction` rather than a `contents`
    /// turn, because Google treats a system role in `contents` as an error.
    /// `response_mime_type` is the Gemini equivalent of OpenAI's
    /// `response_format: json_object`, and `temperature: 0` is what keeps the
    /// extraction as close to reproducible as a sampled model gets.
    ///
    /// `thinkingBudget: 0` is required, not an optimization. Gemini 3.x thinks
    /// by default and charges the thinking tokens against the same output
    /// budget: a probe with thinking on returned `finishReason: MAX_TOKENS` and
    /// the prose fragment `Here is` instead of JSON, while the identical request
    /// with the budget at zero returned `STOP` and a clean object.
    static func requestBody(
        systemPrompt: String,
        userText: String,
        images: [InlineImage],
        temperature: Double = 0,
        maximumOutputTokens: Int
    ) throws -> Data {
        var parts: [[String: Any]] = [["text": userText]]
        for image in images {
            parts.append([
                "inline_data": [
                    "mime_type": image.mimeType,
                    "data": image.base64Data
                ]
            ])
        }

        let body: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": [["role": "user", "parts": parts]],
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": maximumOutputTokens,
                "response_mime_type": "application/json",
                "thinkingConfig": ["thinkingBudget": 0]
            ]
        ]

        return try JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])
    }

    // MARK: - Response

    struct Response: Equatable, Sendable {
        let text: String?
        let inputTokens: Int?
        let outputTokens: Int?
        let totalTokens: Int?
        /// Present when the model stopped for a reason other than finishing —
        /// `MAX_TOKENS` and `SAFETY` both produce a truncated or empty answer,
        /// and reporting them beats a generic "no parsable JSON".
        let finishReason: String?
    }

    /// Extracts the answer text and usage from a `generateContent` response.
    ///
    /// All text parts of the first candidate are joined, because Gemini splits
    /// long JSON answers across parts.
    static func decodeResponse(_ data: Data) -> Response? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let usage = root["usageMetadata"] as? [String: Any]
        let candidates = root["candidates"] as? [[String: Any]] ?? []
        let candidate = candidates.first
        let content = candidate?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]] ?? []
        let joined = parts
            .compactMap { $0["text"] as? String }
            .joined()

        return Response(
            text: joined.isEmpty ? nil : joined,
            inputTokens: usage?["promptTokenCount"] as? Int,
            outputTokens: usage?["candidatesTokenCount"] as? Int,
            totalTokens: usage?["totalTokenCount"] as? Int,
            finishReason: candidate?["finishReason"] as? String
        )
    }

    /// A Google-style error body, so a failed call reports the real cause
    /// instead of a truncated blob.
    static func errorMessage(from data: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        if let error = root["error"] as? [String: Any] {
            let message = error["message"] as? String
            let status = error["status"] as? String
            switch (message, status) {
            case let (message?, status?):
                return "\(status): \(message)"
            case let (message?, nil):
                return message
            case let (nil, status?):
                return status
            default:
                return nil
            }
        }
        return nil
    }
}
