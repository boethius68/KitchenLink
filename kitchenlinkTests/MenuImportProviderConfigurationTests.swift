import Foundation
import Testing
@testable import kitchenlink

/// Before this change `resolvedLLMBaseURL` hard-coded OpenAI for every stored
/// key, so a paid access at any other OpenAI-compatible gateway was not
/// configurable from the shipped app at all — only through environment
/// variables, which an operator never has.
///
/// These tests deliberately stay off the Keychain: the key path fails in a
/// headless simulator without signing, and the regression being guarded here is
/// the gateway/model resolution, which lives in `UserDefaults`.
///
/// The suite is serialized because every case reads and writes the same process
/// -wide `UserDefaults`; running them in parallel makes them observe each
/// other's writes.
@Suite(.serialized)
struct MenuImportProviderConfigurationTests {

    /// Restores whatever the simulator had before, so the suite leaves no
    /// configuration behind for later tests or app runs.
    private func withRestoredConfiguration(_ body: () throws -> Void) rethrows {
        let previousGateway = MenuImportService.storedLLMGatewayURL()
        let previousModel = MenuImportService.storedLLMModel()
        defer {
            MenuImportService.saveLLMGatewayURL(previousGateway)
            MenuImportService.saveLLMModel(previousModel)
        }
        try body()
    }

    @Test
    func withoutStoredConfigurationTheFreeKeylessDefaultIsUsed() {
        withRestoredConfiguration {
            MenuImportService.saveLLMGatewayURL("")
            MenuImportService.saveLLMModel("")

            #expect(MenuImportService.resolvedLLMBaseURL == MenuImportService.llmFreeGatewayURL)
            #expect(MenuImportService.resolvedLLMModel == MenuImportService.llmFreeModel)
        }
    }

    @Test
    func aStoredGatewayAndModelAreActuallyUsed() {
        withRestoredConfiguration {
            #expect(MenuImportService.saveLLMGatewayURL("https://opencode.ai/zen/v1"))
            MenuImportService.saveLLMModel("deepseek-v4-flash")

            #expect(MenuImportService.resolvedLLMBaseURL == "https://opencode.ai/zen/v1")
            #expect(MenuImportService.resolvedLLMModel == "deepseek-v4-flash")
        }
    }

    @Test
    func gatewayAndModelCanBeSetIndependently() {
        withRestoredConfiguration {
            #expect(MenuImportService.saveLLMGatewayURL("https://gateway.example.com/v1"))
            MenuImportService.saveLLMModel("")

            #expect(MenuImportService.resolvedLLMBaseURL == "https://gateway.example.com/v1")
            // No model configured falls back to the default for the current
            // access mode rather than sending an empty model name.
            #expect(!MenuImportService.resolvedLLMModel.isEmpty)
        }
    }

    @Test
    func clearingTheGatewayRestoresTheDefault() {
        withRestoredConfiguration {
            #expect(MenuImportService.saveLLMGatewayURL("https://opencode.ai/zen/v1"))
            #expect(MenuImportService.saveLLMGatewayURL(""))

            #expect(MenuImportService.storedLLMGatewayURL().isEmpty)
            #expect(MenuImportService.resolvedLLMBaseURL == MenuImportService.llmFreeGatewayURL)
        }
    }

    @Test
    func aMalformedGatewayIsRejectedAndNothingIsStored() {
        withRestoredConfiguration {
            #expect(MenuImportService.saveLLMGatewayURL(""))

            for invalid in ["nicht-eine-url", "ftp://gateway.example.com/v1", "https://", "/v1"] {
                #expect(
                    !MenuImportService.saveLLMGatewayURL(invalid),
                    "\(invalid) should have been rejected"
                )
                #expect(MenuImportService.storedLLMGatewayURL().isEmpty)
            }
        }
    }

    @Test
    func aRejectedGatewayLeavesAPreviouslyStoredOneIntact() {
        withRestoredConfiguration {
            #expect(MenuImportService.saveLLMGatewayURL("https://opencode.ai/zen/v1"))
            #expect(!MenuImportService.saveLLMGatewayURL("nicht-eine-url"))

            #expect(MenuImportService.storedLLMGatewayURL() == "https://opencode.ai/zen/v1")
        }
    }

    @Test
    func plainHTTPIsAcceptedForLocalGateways() {
        // A locally hosted gateway (Ollama, LM Studio, a review proxy) is plain
        // HTTP on the operator's own machine.
        withRestoredConfiguration {
            #expect(MenuImportService.saveLLMGatewayURL("http://127.0.0.1:11434/v1"))
            #expect(MenuImportService.resolvedLLMBaseURL == "http://127.0.0.1:11434/v1")
        }
    }

    @Test
    func storedValuesAreTrimmedOfIncidentalWhitespace() {
        withRestoredConfiguration {
            MenuImportService.saveLLMModel("  deepseek-v4-flash  ")

            #expect(MenuImportService.storedLLMModel() == "deepseek-v4-flash")
        }
    }
}
