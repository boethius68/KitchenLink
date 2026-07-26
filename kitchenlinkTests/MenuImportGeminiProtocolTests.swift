import Foundation
import Testing
@testable import kitchenlink

/// The Gemini Flash models behind the OpenCode Zen gateway reject
/// OpenAI-compatible bodies: a probe with the normal request returned Google's
/// own error, `Invalid JSON request body: Missing key at ["contents"]`. These
/// tests pin the translated request shape and the response parsing so the
/// adapter cannot silently drift back into an unusable body.
struct MenuImportGeminiProtocolTests {

    private func decodedBody(
        systemPrompt: String = "Extract the page.",
        userText: String = "OCR lines follow.",
        images: [MenuImportGeminiProtocol.InlineImage] = [],
        maximumOutputTokens: Int = 10_000
    ) throws -> [String: Any] {
        let data = try MenuImportGeminiProtocol.requestBody(
            systemPrompt: systemPrompt,
            userText: userText,
            images: images,
            maximumOutputTokens: maximumOutputTokens
        )
        return try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    // MARK: - Protocol selection

    @Test
    func geminiModelsAreDetectedByName() {
        #expect(MenuImportGeminiProtocol.usesNativeProtocol(model: "gemini-3.5-flash"))
        #expect(MenuImportGeminiProtocol.usesNativeProtocol(model: "gemini-3.6-flash"))
        #expect(MenuImportGeminiProtocol.usesNativeProtocol(model: "google/gemini-3-flash"))
    }

    @Test
    func openAICompatibleModelsKeepTheChatCompletionsProtocol() {
        for model in ["big-pickle", "deepseek-v4-flash", "gpt-4.1", "claude-haiku-4-5"] {
            #expect(
                !MenuImportGeminiProtocol.usesNativeProtocol(model: model),
                "\(model) must not use the Gemini protocol"
            )
        }
    }

    @Test
    func anExplicitOverrideWinsOverTheModelName() {
        #expect(
            MenuImportGeminiProtocol.usesNativeProtocol(
                model: "big-pickle",
                override: "gemini"
            )
        )
        #expect(
            !MenuImportGeminiProtocol.usesNativeProtocol(
                model: "gemini-3.5-flash",
                override: "openai"
            )
        )
    }

    @Test
    func anUnknownOverrideFallsBackToTheModelName() {
        #expect(
            MenuImportGeminiProtocol.usesNativeProtocol(
                model: "gemini-3.5-flash",
                override: "quatsch"
            )
        )
        #expect(
            !MenuImportGeminiProtocol.usesNativeProtocol(
                model: "big-pickle",
                override: "  "
            )
        )
    }

    // MARK: - Endpoint

    @Test
    func theModelIsAddressedInThePathNotTheBody() {
        let url = MenuImportGeminiProtocol.endpointURL(
            baseURL: "https://opencode.ai/zen/v1",
            model: "gemini-3.5-flash"
        )

        #expect(url?.absoluteString == "https://opencode.ai/zen/v1/models/gemini-3.5-flash:generateContent")
    }

    @Test
    func aTrailingSlashInTheBaseURLDoesNotDoubleUp() {
        let url = MenuImportGeminiProtocol.endpointURL(
            baseURL: "https://opencode.ai/zen/v1/",
            model: "gemini-3.5-flash"
        )

        #expect(url?.absoluteString == "https://opencode.ai/zen/v1/models/gemini-3.5-flash:generateContent")
    }

    // MARK: - Request shape

    @Test
    func theRequestCarriesTheContentsKeyGoogleDemanded() throws {
        let body = try decodedBody()

        // The exact key whose absence produced the observed 400.
        let contents = try #require(body["contents"] as? [[String: Any]])
        #expect(contents.count == 1)
        #expect(contents[0]["role"] as? String == "user")
    }

    @Test
    func theSystemPromptBecomesSystemInstructionNotAContentsTurn() throws {
        // Google rejects a `system` role inside `contents`.
        let body = try decodedBody(systemPrompt: "Extract losslessly.")

        let instruction = try #require(body["system_instruction"] as? [String: Any])
        let parts = try #require(instruction["parts"] as? [[String: Any]])
        #expect(parts.first?["text"] as? String == "Extract losslessly.")

        let contents = try #require(body["contents"] as? [[String: Any]])
        #expect(contents.allSatisfy { ($0["role"] as? String) != "system" })
    }

    @Test
    func jsonOutputAndZeroTemperatureAreRequested() throws {
        let body = try decodedBody(maximumOutputTokens: 4242)

        let config = try #require(body["generationConfig"] as? [String: Any])
        #expect(config["response_mime_type"] as? String == "application/json")
        #expect((config["temperature"] as? NSNumber)?.doubleValue == 0)
        #expect(config["maxOutputTokens"] as? Int == 4242)
    }

    @Test
    func thinkingIsDisabledSoTheOutputBudgetGoesToJSON() throws {
        // Measured: with thinking on, a 64-token probe returned
        // finishReason MAX_TOKENS and the prose fragment "Here is"; with the
        // budget at zero the identical request returned STOP and clean JSON.
        let body = try decodedBody()

        let config = try #require(body["generationConfig"] as? [String: Any])
        let thinking = try #require(config["thinkingConfig"] as? [String: Any])
        #expect(thinking["thinkingBudget"] as? Int == 0)
    }

    @Test
    func theGoogleRouteUsesItsOwnAPIKeyHeader() {
        // A bearer header on this route answered `AuthError: Missing API key.`
        #expect(MenuImportGeminiProtocol.apiKeyHeaderField == "x-goog-api-key")
    }

    @Test
    func pageImagesTravelAsInlineData() throws {
        let image = MenuImportGeminiProtocol.InlineImage(
            mimeType: "image/jpeg",
            base64Data: "QUJD"
        )
        let body = try decodedBody(images: [image, image])

        let contents = try #require(body["contents"] as? [[String: Any]])
        let parts = try #require(contents[0]["parts"] as? [[String: Any]])
        // One text part plus both images, text first.
        #expect(parts.count == 3)
        #expect(parts[0]["text"] as? String == "OCR lines follow.")
        let inline = try #require(parts[1]["inline_data"] as? [String: Any])
        #expect(inline["mime_type"] as? String == "image/jpeg")
        #expect(inline["data"] as? String == "QUJD")
    }

    @Test
    func aTextOnlyRequestHasNoInlineDataParts() throws {
        let body = try decodedBody()

        let contents = try #require(body["contents"] as? [[String: Any]])
        let parts = try #require(contents[0]["parts"] as? [[String: Any]])
        #expect(parts.count == 1)
        #expect(parts[0]["inline_data"] == nil)
    }

    // MARK: - Data URL parsing

    @Test
    func inlineImagesAreParsedFromTheExistingDataURLs() {
        let image = MenuImportGeminiProtocol.InlineImage(
            dataURL: "data:image/jpeg;base64,QUJD"
        )

        #expect(image?.mimeType == "image/jpeg")
        #expect(image?.base64Data == "QUJD")
    }

    @Test
    func malformedDataURLsAreRejectedRatherThanSentAsGarbage() {
        let malformed = [
            "https://example.com/page.jpg",
            "data:image/jpeg,QUJD",
            "data:;base64,QUJD",
            "data:image/jpeg;base64,"
        ]

        for candidate in malformed {
            #expect(
                MenuImportGeminiProtocol.InlineImage(dataURL: candidate) == nil,
                "\(candidate) should not parse"
            )
        }
    }

    // MARK: - Response

    @Test
    func theAnswerTextAndUsageAreExtracted() throws {
        let payload = """
        {
          "candidates": [{
            "content": {"parts": [{"text": "{\\"page_index\\": 0}"}], "role": "model"},
            "finishReason": "STOP"
          }],
          "usageMetadata": {
            "promptTokenCount": 1200,
            "candidatesTokenCount": 340,
            "totalTokenCount": 1540
          }
        }
        """

        let response = try #require(
            MenuImportGeminiProtocol.decodeResponse(Data(payload.utf8))
        )

        #expect(response.text == "{\"page_index\": 0}")
        #expect(response.inputTokens == 1200)
        #expect(response.outputTokens == 340)
        #expect(response.totalTokens == 1540)
        #expect(response.finishReason == "STOP")
    }

    @Test
    func splitTextPartsAreJoinedIntoOneAnswer() throws {
        // Gemini splits long JSON answers across parts; concatenating them is
        // the difference between a parsable draft and a truncation error.
        let payload = """
        {"candidates": [{"content": {"parts": [
          {"text": "{\\"sections\\":"},
          {"text": " []}"}
        ]}}]}
        """

        let response = try #require(
            MenuImportGeminiProtocol.decodeResponse(Data(payload.utf8))
        )

        #expect(response.text == "{\"sections\": []}")
    }

    @Test
    func aTruncatedAnswerReportsItsFinishReason() throws {
        let payload = """
        {"candidates": [{"content": {"parts": []}, "finishReason": "MAX_TOKENS"}]}
        """

        let response = try #require(
            MenuImportGeminiProtocol.decodeResponse(Data(payload.utf8))
        )

        #expect(response.text == nil)
        #expect(response.finishReason == "MAX_TOKENS")
    }

    @Test
    func nonJSONResponsesDoNotCrashTheDecoder() {
        #expect(MenuImportGeminiProtocol.decodeResponse(Data("<html>502</html>".utf8)) == nil)
    }

    @Test
    func googleErrorBodiesAreReportedWithStatusAndMessage() {
        // The exact body shape that the first probe returned.
        let payload = """
        {"error": {"code": 400,
                   "message": "Invalid JSON request body: Missing key\\n  at [\\"contents\\"]",
                   "status": "INVALID_ARGUMENT"}}
        """

        let message = MenuImportGeminiProtocol.errorMessage(from: Data(payload.utf8))

        #expect(message?.hasPrefix("INVALID_ARGUMENT: ") == true)
        #expect(message?.contains("contents") == true)
    }

    @Test
    func aBodyWithoutAnErrorObjectYieldsNoMessage() {
        #expect(MenuImportGeminiProtocol.errorMessage(from: Data("{\"candidates\":[]}".utf8)) == nil)
        #expect(MenuImportGeminiProtocol.errorMessage(from: Data("nicht json".utf8)) == nil)
    }
}
