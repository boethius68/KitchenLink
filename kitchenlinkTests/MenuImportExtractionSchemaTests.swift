import Foundation
import Testing
@testable import kitchenlink

/// Das Schema ist handgeschrieben und muss zum Vertrag passen. Diese Tests
/// halten die Verbindung: eine Antwort, die der Vertrag akzeptiert, muss vom
/// Schema erlaubt sein, und die geschlossenen Vokabulare müssen mit den
/// Swift-Aufzählungen übereinstimmen. Läuft beides auseinander, verbietet das
/// Schema plötzlich gültige Antworten — der Ausfall wäre schwer zu finden.
struct MenuImportExtractionSchemaTests {

    private func encoded(_ value: MenuImportJSONValue) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
    }

    @Test("Schema beschreibt die Drahtform der Seite in snake_case")
    func describesThePageInWireForm() throws {
        let root = try encoded(MenuImportExtractionSchema.pageSchema())
        #expect(root["type"] as? String == "object")
        let properties = try #require(root["properties"] as? [String: Any])
        // Der Dekoder nutzt .convertFromSnakeCase; das Schema muss die
        // Drahtnamen beschreiben, nicht die Swift-Namen.
        for key in [
            "contract_version", "page_index", "page_kind",
            "languages", "sections", "declarations", "review_reasons"
        ] {
            #expect(properties[key] != nil, "Feld \(key) fehlt im Schema")
        }
        #expect(properties["pageIndex"] == nil)
        #expect(properties["reviewReasons"] == nil)
    }

    @Test("Kein Feld ist verpflichtend")
    func keepsEveryFieldOptional() throws {
        // Der Vertrag toleriert fehlende Felder absichtlich, weil ein
        // ausgelassenes Feld sonst eine ganze Karte kostet.
        func assertNoRequired(_ node: Any, path: String) {
            guard let object = node as? [String: Any] else { return }
            #expect(object["required"] == nil, "required aufgetaucht bei \(path)")
            if let properties = object["properties"] as? [String: Any] {
                for (key, value) in properties {
                    assertNoRequired(value, path: "\(path).\(key)")
                }
            }
            if let items = object["items"] {
                assertNoRequired(items, path: "\(path)[]")
            }
            if let anyOf = object["anyOf"] as? [Any] {
                for (index, value) in anyOf.enumerated() {
                    assertNoRequired(value, path: "\(path)|\(index)")
                }
            }
        }
        assertNoRequired(try encoded(MenuImportExtractionSchema.pageSchema()), path: "root")
    }

    @Test("Geschlossene Vokabulare stimmen mit dem Vertrag überein")
    func closedVocabulariesMatchTheContract() throws {
        // Preisarten kommen direkt aus der Aufzählung, damit ein neuer Fall
        // nicht stillschweigend verboten wird.
        #expect(
            Set(MenuImportExtractionSchema.priceKinds)
                == Set(MenuImportPriceKind.allCases.map(\.rawValue))
        )
        #expect(Set(MenuImportExtractionSchema.severities) == ["info", "warning", "error"])

        // Jeder Prüfcode des Schemas muss im Prompt-Vokabular stehen, sonst
        // verlangt das Schema etwas, das der Prompt nie erklärt hat.
        let prompt = MenuImportExtractionPrompt.systemPrompt
        for code in MenuImportExtractionSchema.reviewCodes {
            #expect(prompt.contains(code), "Prüfcode \(code) fehlt im Prompt")
        }
    }

    @Test("Eine vertragsgültige Antwort verletzt das Schema nicht")
    func acceptsAContractValidResponse() throws {
        // Dieselbe Nutzlast wie im Vertragstest, nur hier gegen das Schema
        // geprüft: erlaubte Typen, erlaubte Vokabeln, keine Fremdfelder.
        let payload = """
        {
          "contract_version": "1.0.0",
          "page_index": 0,
          "page_kind": "menu",
          "languages": ["de"],
          "sections": [{
            "title": {"value": "Vorspeisen", "evidence_line_ids": ["p1-l1"]},
            "order": 0,
            "entries": [{
              "kind": "food",
              "name": {"value": "Salat", "evidence_line_ids": ["p1-l2"]},
              "order": 0,
              "offers": [{
                "price_kind": "fixed",
                "amount_cents": 890,
                "currency_code": "EUR",
                "raw_price": "8,90",
                "basis": "per_item",
                "evidence_line_ids": ["p1-l2"]
              }],
              "review_reasons": [{
                "code": "missing_visible_price",
                "path": "offers",
                "message": "Kein Preis sichtbar.",
                "severity": "warning",
                "evidence_line_ids": ["p1-l2"]
              }]
            }]
          }]
        }
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        // Der Vertrag akzeptiert sie …
        let extraction = try decoder.decode(
            MenuImportPageExtraction.self,
            from: Data(payload.utf8)
        )
        #expect(extraction.sections.first?.entries.first?.offers.first?.priceKind == "fixed")

        // … und jedes darin benutzte Feld ist im Schema beschrieben.
        let root = try encoded(MenuImportExtractionSchema.pageSchema())
        let sections = try #require(
            (root["properties"] as? [String: Any])?["sections"] as? [String: Any]
        )
        let sectionItems = try #require(sections["items"] as? [String: Any])
        let sectionProperties = try #require(sectionItems["properties"] as? [String: Any])
        for key in ["title", "order", "entries", "subsections", "declarations", "review_reasons"] {
            #expect(sectionProperties[key] != nil, "Sektionsfeld \(key) fehlt")
        }
        let entryItems = try #require(
            (sectionProperties["entries"] as? [String: Any])?["items"] as? [String: Any]
        )
        let entryProperties = try #require(entryItems["properties"] as? [String: Any])
        for key in [
            "kind", "name", "description", "item_number", "order", "offers",
            "quantities", "option_groups", "bundle_components", "declarations",
            "review_reasons"
        ] {
            #expect(entryProperties[key] != nil, "Eintragsfeld \(key) fehlt")
        }
    }

    @Test("Verschachtelung ist begrenzt statt rekursiv")
    func boundsTheSubsectionDepth() throws {
        // Rekursion per $ref ist gültiges Schema, aber die Grammatikübersetzung
        // in llama.cpp kommt damit schlecht zurecht.
        let data = try JSONEncoder().encode(MenuImportExtractionSchema.pageSchema())
        let text = String(decoding: data, as: UTF8.self)
        #expect(!text.contains("$ref"))
        #expect(!text.contains("$defs"))

        func depth(_ node: Any) -> Int {
            guard let object = node as? [String: Any] else { return 0 }
            if let properties = object["properties"] as? [String: Any],
               let subsections = properties["subsections"] as? [String: Any],
               let items = subsections["items"] {
                return 1 + depth(items)
            }
            if let items = object["items"] { return depth(items) }
            return 0
        }
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let sections = try #require(
            (root["properties"] as? [String: Any])?["sections"] as? [String: Any]
        )
        #expect(depth(try #require(sections["items"])) == 3)
    }
}
