import Foundation
import Testing
@testable import kitchenlink

/// Die Layoutstufe ist Lesehilfe, nicht Voraussetzung. Diese Tests halten die
/// zwei Eigenschaften fest, an denen sich das entscheidet: der Anfragekörper
/// muss beim Gateway ankommen wie gedacht, und der Prompt-Block muss die
/// Belegherkunft eindeutig abgrenzen — sonst erfindet das Vertragsmodell
/// Beleg-IDs, die zu Zeilen des Transkripts passen sollen.
struct MenuImportLayoutPassTests {

    @Test("Anfragekörper trägt Modell, Anweisung und Bild")
    func buildsAnOpenAICompatibleRequestBody() throws {
        let data = try MenuImportLayoutPass.requestBody(
            model: "olmocr-2",
            instruction: "Transkribiere die Seite.",
            imageDataURL: "data:image/jpeg;base64,AAAA"
        )
        let root = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(root["model"] as? String == "olmocr-2")
        #expect(root["stream"] as? Bool == false)
        // Ein Dokumentmodell soll transkribieren, nicht formulieren.
        #expect((root["temperature"] as? NSNumber)?.doubleValue == 0)

        let messages = try #require(root["messages"] as? [[String: Any]])
        let content = try #require(messages.first?["content"] as? [[String: Any]])
        #expect(content.first?["text"] as? String == "Transkribiere die Seite.")
        let image = try #require(content.last?["image_url"] as? [String: Any])
        #expect(image["url"] as? String == "data:image/jpeg;base64,AAAA")
    }

    @Test("Antworttext wird gelesen, leerer Inhalt fällt durch")
    func readsTheTranscriptAndRejectsEmptyContent() throws {
        func text(_ json: String) -> String? {
            MenuImportLayoutPass.text(fromResponse: Data(json.utf8))
        }
        #expect(
            text(#"{"choices":[{"message":{"content":"Lotte\n28 € Zwischengericht"}}]}"#)
                == "Lotte\n28 € Zwischengericht"
        )
        // Reasoning-Modell mit verbrauchtem Ausgabebudget: content ist leer.
        #expect(text(#"{"choices":[{"message":{"content":"   "}}]}"#) == nil)
        #expect(text(#"{"choices":[]}"#) == nil)
        #expect(text("kein json") == nil)
    }

    @Test("Prompt-Block grenzt die Belegherkunft ab")
    func scopesEvidenceToTheOCRLines() throws {
        let block = MenuImportLayoutPass.promptBlock(for: "Lotte\n28 € Zwischengericht")
        #expect(block.contains("Lotte"))
        // Ohne diese Abgrenzung erfindet das Vertragsmodell IDs für Zeilen des
        // Transkripts, die es im OCR-Index nicht gibt.
        #expect(block.localizedCaseInsensitiveContains("no evidence IDs"))
        #expect(block.localizedCaseInsensitiveContains("only the supplied OCR evidence lines"))
    }

    @Test("Ohne Konfiguration bleibt die Stufe aus")
    func staysOffWhenUnconfigured() throws {
        // Im Testlauf sind die Variablen nicht gesetzt; die Stufe darf dann
        // nichts anfordern und den Import unverändert lassen.
        if ProcessInfo.processInfo.environment["KITCHENLINK_LAYOUT_BASE_URL"] == nil {
            #expect(MenuImportLayoutPass.isConfigured == false)
        }
        #expect(MenuImportLayoutPass.timeoutSeconds > 0)
    }
}
