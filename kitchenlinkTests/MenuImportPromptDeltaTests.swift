import Foundation
import Testing
@testable import kitchenlink

/// Covers the two tools that let the `1.0.4` regression be narrowed down
/// without buying one paid ten-page run per hypothesis: switchable prompt
/// deltas and a mapping failure that names its own cause.
@Suite(.serialized)
struct MenuImportPromptDeltaTests {
    private func withDeltas(_ value: String?, _ body: () throws -> Void) rethrows {
        let key = "KITCHENLINK_PROMPT_DELTAS"
        let previous = ProcessInfo.processInfo.environment[key]
        if let value {
            setenv(key, value, 1)
        } else {
            unsetenv(key)
        }
        defer {
            if let previous {
                setenv(key, previous, 1)
            } else {
                unsetenv(key)
            }
        }
        try body()
    }

    @Test("Ohne Angabe sind alle drei Deltas aktiv")
    func defaultsToEveryDelta() throws {
        try withDeltas(nil) {
            #expect(
                MenuImportExtractionPrompt.activeDeltas
                    == Set(MenuImportExtractionPrompt.Delta.allCases)
            )
            #expect(
                MenuImportExtractionPrompt.resolvedVersion
                    == MenuImportExtractionPrompt.version
            )
        }
    }

    /// The reconstructed base must actually drop all three instructions —
    /// otherwise a `none` run would silently measure `1.0.4` again.
    @Test("none entfernt genau die drei Delta-Anweisungen")
    func baseDropsEveryDeltaInstruction() throws {
        try withDeltas("none") {
            let prompt = MenuImportExtractionPrompt.systemPrompt
            #expect(MenuImportExtractionPrompt.activeDeltas.isEmpty)
            #expect(!prompt.contains("The \"code\" field must be exactly one of"))
            #expect(!prompt.contains("never ends in a declaration code run"))
            #expect(!prompt.contains("Set currency_code on every offer"))
            // The contract shape and the base rules must survive.
            #expect(prompt.contains("contract_version"))
            #expect(prompt.contains("Rules:"))
            #expect(prompt.contains("Cite only OCR line IDs supplied by the user"))
            #expect(prompt.contains("Return all array fields"))
            #expect(MenuImportExtractionPrompt.resolvedVersion.hasSuffix("+base"))
        }
    }

    @Test("Ein einzelnes Delta lässt die beiden anderen weg")
    func singleDeltaIsIsolated() throws {
        try withDeltas("currency_code") {
            let prompt = MenuImportExtractionPrompt.systemPrompt
            #expect(MenuImportExtractionPrompt.activeDeltas == [.currencyCode])
            #expect(prompt.contains("Set currency_code on every offer"))
            #expect(!prompt.contains("The \"code\" field must be exactly one of"))
            #expect(!prompt.contains("Never write a review reason as a bare string"))
            #expect(!prompt.contains("never ends in a declaration code run"))
            #expect(
                MenuImportExtractionPrompt.resolvedVersion.hasSuffix("+currency_code")
            )
        }
    }

    /// Every distinct delta selection must produce a distinct fingerprint, or a
    /// run archive cannot prove which prompt produced its numbers.
    /// Measured regression: the first wording of this delta read as the value
    /// shape, so the model emitted `review_reasons: ["missing_visible_price"]`
    /// and one page failed contract mapping with a `typeMismatch` at
    /// `sections[0].entries[0].reviewReasons[0]`. The vocabulary must stay
    /// scoped to the `code` field and must state the object shape.
    @Test("Vokabular ist auf das code-Feld begrenzt und nennt die Objektform")
    func reviewCodeVocabularyScopesItselfToTheCodeField() throws {
        try withDeltas("review_codes") {
            let prompt = MenuImportExtractionPrompt.systemPrompt
            #expect(prompt.contains("Never write a review reason as a bare string"))
            #expect(prompt.contains("The \"code\" field must be exactly one of"))
            #expect(prompt.contains("is not itself"))
            #expect(prompt.contains("missing_visible_price"))
        }
    }

    @Test("Jede Delta-Auswahl hat einen eigenen Fingerprint")
    func fingerprintTracksDeltaSelection() throws {
        var fingerprints: Set<String> = []
        for selection in ["none", "review_codes", "trailing_codes", "currency_code", "all"] {
            try withDeltas(selection) {
                fingerprints.insert(MenuImportExtractionPrompt.fingerprint)
            }
        }
        #expect(fingerprints.count == 5)
    }

    /// A typo must not quietly measure the base prompt while the archive claims
    /// otherwise; the resolved version has to disagree with plain `1.0.4`.
    @Test("Unbekannter Delta-Name wird ignoriert, nicht als none gedeutet")
    func unknownDeltaNameIsIgnored() throws {
        try withDeltas("currency_code,tippfehler") {
            #expect(MenuImportExtractionPrompt.activeDeltas == [.currencyCode])
            #expect(
                MenuImportExtractionPrompt.resolvedVersion
                    != MenuImportExtractionPrompt.version
            )
        }
    }
}

@Suite
struct MenuImportMappingDiagnosticsTests {
    /// A response that stops mid-object is a length problem; one that is
    /// complete but disagrees with the contract is a schema problem. The two
    /// need opposite fixes, so the check has to tell them apart.
    @Test("Abgeschnittene Antwort wird als unbalanciert erkannt")
    func detectsTruncatedResponse() {
        #expect(
            !MenuLLMDiagnostics.hasBalancedJSONDelimiters(
                #"{"sections": [{"title": {"value": "Vorspeisen""#
            )
        )
        #expect(
            MenuLLMDiagnostics.hasBalancedJSONDelimiters(
                #"{"sections": [{"title": "Vorspeisen"}]}"#
            )
        )
    }

    /// Braces and brackets inside string literals are content, not structure.
    @Test("Klammern in Strings zählen nicht als Struktur")
    func ignoresDelimitersInsideStringLiterals() {
        #expect(
            MenuLLMDiagnostics.hasBalancedJSONDelimiters(
                #"{"raw_text": "Salat [A,G] {gross}"}"#
            )
        )
        #expect(
            MenuLLMDiagnostics.hasBalancedJSONDelimiters(
                #"{"raw_text": "Zitat \" mit [Klammer]"}"#
            )
        )
    }

    /// A measured run lost a whole document to a single omitted empty array
    /// (`Feld fehlt: sections[0].title.alternatives`). Absence must cost
    /// nothing.
    @Test("Fehlende leere Arrays kosten die Seite nicht mehr")
    func absentArraysDecodeAsEmpty() throws {
        let payload = """
        {
          "contract_version": "1.0.0",
          "page_index": 0,
          "page_kind": "menu",
          "sections": [{
            "title": {"value": "Vorspeisen"},
            "order": 0,
            "entries": [{
              "kind": "food",
              "name": {"value": "Bunter Marktsalat"},
              "order": 0
            }]
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let page = try decoder.decode(
            MenuImportPageExtraction.self,
            from: Data(payload.utf8)
        )
        #expect(page.languages.isEmpty)
        #expect(page.declarations.isEmpty)
        #expect(page.sections.first?.title.alternatives.isEmpty == true)
        #expect(page.sections.first?.entries.first?.offers.isEmpty == true)
        // The content that *was* sent must survive untouched.
        #expect(page.sections.first?.entries.first?.name.value == "Bunter Marktsalat")
        #expect(page.recursiveEntryCount == 1)
    }

    /// The opposite direction must stay strict: swallowing a present-but-wrong
    /// value would have hidden the review-code regression instead of reporting
    /// it, which is what made that failure cost a paid run to find.
    @Test("Vorhandenes Feld mit falschem Typ scheitert weiterhin")
    func presentButWrongTypeStillThrows() throws {
        let payload = """
        {
          "contract_version": "1.0.0",
          "page_index": 0,
          "page_kind": "menu",
          "sections": [{
            "title": {"value": "Vorspeisen"},
            "order": 0,
            "entries": [{
              "kind": "food",
              "name": {"value": "Salat"},
              "order": 0,
              "review_reasons": ["missing_visible_price"]
            }]
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var captured: Error?
        do {
            _ = try decoder.decode(
                MenuImportPageExtraction.self,
                from: Data(payload.utf8)
            )
        } catch {
            captured = error
        }
        #expect(captured != nil)
        let message = MenuLLMDiagnostics.describeContractMappingFailure(
            captured,
            jsonText: payload,
            rawText: payload
        )
        #expect(message.contains("Falscher Typ"))
        #expect(message.contains("reviewReasons"))
    }

    /// The whole point of keeping the decode error: the message must name the
    /// missing field instead of only stating that something went wrong.
    @Test("Fehlendes Feld wird mit Coding-Pfad benannt")
    func namesTheMissingField() throws {
        let incomplete = #"{"contract_version": "1.0.0", "page_index": 0}"#
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        var captured: Error?
        do {
            _ = try decoder.decode(
                MenuImportPageExtraction.self,
                from: Data(incomplete.utf8)
            )
        } catch {
            captured = error
        }
        let message = MenuLLMDiagnostics.describeContractMappingFailure(
            captured,
            jsonText: incomplete,
            rawText: incomplete
        )
        #expect(message.contains("Feld fehlt"))
        #expect(message.contains("pageKind") || message.contains("page_kind"))
    }
}
