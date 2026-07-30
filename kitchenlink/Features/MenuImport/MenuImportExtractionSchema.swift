import Foundation

/// JSON-Schema des Anbietervertrags für **erzwungenes Dekodieren**.
///
/// ## Warum
///
/// Gemessen am 30. Juli 2026: `qwen3.5:9b-32k` lokal hat eine echte Seite
/// dreimal in je 900 s nicht fertiggestellt — rund 17 000 Ausgabe-Token für
/// eine Seite, die 3 000 bis 8 000 braucht. Das ist keine Langsamkeit, sondern
/// eine Wiederholungsschleife, der klassische Ausfall kleiner Modelle bei
/// langem, starrem JSON. Mehr Zeit hilft dagegen nicht.
///
/// Nimmt das Gateway ein Schema (`response_format`), kann das Modell physisch
/// nichts Schemafremdes erzeugen. Die Schleife ist damit ausgeschlossen — und
/// die Vokabulare, die der Prompt bisher nur in Prosa erbittet, werden zur
/// harten Zusage. Der `review_reasons`-Regress vom 27. Juli (das Modell schrieb
/// Codes als nackte Strings statt als Objekte) wäre damit unmöglich gewesen.
///
/// ## Zwei bewusste Abweichungen vom Vertrag
///
/// 1. **Verschachtelung ist begrenzt.** `subsections` rekursiv per `$ref` ist
///    gültiges JSON-Schema, aber die Grammatikübersetzung in llama.cpp kommt mit
///    Rekursion schlecht zurecht. Die Tiefe wird daher ausgeschrieben
///    (Standard: zwei Ebenen). Speisekarten verschachteln praktisch nicht
///    tiefer; wird es doch, verliert man eine Ebene und nicht die Seite.
/// 2. **Nichts ist `required`.** Der Vertrag toleriert fehlende Felder absichtlich
///    (`DefaultEmptyArray`, `DefaultUnknown`), weil ein ausgelassenes Feld sonst
///    eine ganze Karte kostet. Das Schema hält sich daran und schreibt nur vor,
///    *wie* ein vorhandenes Feld aussehen darf.
enum MenuImportExtractionSchema {

    /// Geschlossene Vokabulare. Offene Klassifikatoren des Vertrags (`kind`,
    /// `basis`, `scope`, `claim`, `unit`, `mode`) bleiben freie Strings — sie
    /// sind absichtlich offen, damit die Entdeckung nicht zur Produktontologie
    /// wird.
    static let priceKinds = MenuImportPriceKind.allCases.map(\.rawValue)
    static let severities = ["info", "warning", "error"]
    static let reviewCodes = [
        "missing_visible_price",
        "source_declaration_meaning_unknown",
        "selection_rule_unknown",
        "complex_bundle_choice",
        "chef_composed_bundle",
        "headline_price_unmapped_to_portion_choice",
        "relationship_scope_ambiguous",
        "translation_pairing_unproven",
        "evidence_missing"
    ]

    /// Vollständiges Schema einer Seite, in der Drahtform (snake_case), wie der
    /// Dekoder sie mit `.convertFromSnakeCase` erwartet.
    static func pageSchema(subsectionDepth: Int = 2) -> MenuImportJSONValue {
        object([
            "contract_version": .object(["type": "string"]),
            "page_index": .object(["type": "integer"]),
            "page_kind": .object(["type": "string"]),
            "languages": array(.object(["type": "string"])),
            "sections": array(section(depth: subsectionDepth)),
            "declarations": array(declaration),
            "review_reasons": array(reviewReason)
        ])
    }

    // MARK: - Bausteine

    private static var stringOrNull: MenuImportJSONValue {
        .object(["type": .array(["string", "null"])])
    }

    private static var integerOrNull: MenuImportJSONValue {
        .object(["type": .array(["integer", "null"])])
    }

    private static var evidenceLineIds: MenuImportJSONValue {
        array(.object(["type": "string"]))
    }

    private static var localizedText: MenuImportJSONValue {
        object([
            "value": .object(["type": "string"]),
            "language_tag": stringOrNull,
            "evidence_line_ids": evidenceLineIds
        ])
    }

    private static var text: MenuImportJSONValue {
        object([
            "value": .object(["type": "string"]),
            "language_tag": stringOrNull,
            "evidence_line_ids": evidenceLineIds,
            "alternatives": array(localizedText)
        ])
    }

    private static var textOrNull: MenuImportJSONValue {
        nullable(text)
    }

    private static var reviewReason: MenuImportJSONValue {
        object([
            "code": .object(["type": "string", "enum": .array(reviewCodes.map(MenuImportJSONValue.string))]),
            "path": .object(["type": "string"]),
            "message": .object(["type": "string"]),
            "severity": .object(["type": "string", "enum": .array(severities.map(MenuImportJSONValue.string))]),
            "evidence_line_ids": evidenceLineIds
        ])
    }

    private static var declaration: MenuImportJSONValue {
        object([
            "kind": .object(["type": "string"]),
            "raw_text": .object(["type": "string"]),
            "alternatives": array(localizedText),
            "local_code": stringOrNull,
            "canonical_id": stringOrNull,
            "claim": .object(["type": "string"]),
            "scope": .object(["type": "string"]),
            "evidence_line_ids": evidenceLineIds
        ])
    }

    private static var offer: MenuImportJSONValue {
        object([
            "label": textOrNull,
            "price_kind": .object(["type": "string", "enum": .array(priceKinds.map(MenuImportJSONValue.string))]),
            "amount_cents": integerOrNull,
            "delta_cents": integerOrNull,
            "minimum_amount_cents": integerOrNull,
            "maximum_amount_cents": integerOrNull,
            "currency_code": stringOrNull,
            "raw_price": stringOrNull,
            "basis": .object(["type": "string"]),
            "applies_to_quantity_order": integerOrNull,
            "evidence_line_ids": evidenceLineIds
        ])
    }

    private static var quantity: MenuImportJSONValue {
        object([
            "raw_text": .object(["type": "string"]),
            "value": .object(["type": .array(["number", "null"])]),
            "unit": .object(["type": "string"]),
            "kind": .object(["type": "string"]),
            "evidence_line_ids": evidenceLineIds
        ])
    }

    private static var selectionRule: MenuImportJSONValue {
        object([
            "minimum": integerOrNull,
            "maximum": integerOrNull,
            "free_selection_count": integerOrNull,
            "mode": .object(["type": "string"]),
            "allows_repeats": .object(["type": .array(["boolean", "null"])])
        ])
    }

    private static var choice: MenuImportJSONValue {
        object([
            "name": text,
            "description": textOrNull,
            "kind": .object(["type": "string"]),
            "order": .object(["type": "integer"]),
            "offers": array(offer),
            "quantity": nullable(quantity),
            "declarations": array(declaration),
            "review_reasons": array(reviewReason)
        ])
    }

    private static var optionGroup: MenuImportJSONValue {
        object([
            "title": text,
            "order": .object(["type": "integer"]),
            "selection_rule": selectionRule,
            "choices": array(choice),
            "review_reasons": array(reviewReason)
        ])
    }

    private static var bundleComponent: MenuImportJSONValue {
        object([
            "title": text,
            "description": textOrNull,
            "kind": .object(["type": "string"]),
            "order": .object(["type": "integer"]),
            "quantity": nullable(quantity),
            "option_group": nullable(optionGroup),
            "offers": array(offer),
            "declarations": array(declaration),
            "review_reasons": array(reviewReason)
        ])
    }

    private static var entry: MenuImportJSONValue {
        object([
            "kind": .object(["type": "string"]),
            "name": text,
            "description": textOrNull,
            "item_number": stringOrNull,
            "order": .object(["type": "integer"]),
            "offers": array(offer),
            "quantities": array(quantity),
            "option_groups": array(optionGroup),
            "bundle_components": array(bundleComponent),
            "declarations": array(declaration),
            "review_reasons": array(reviewReason)
        ])
    }

    /// Ausgeschriebene Verschachtelung statt `$ref` — siehe Abweichung 1.
    private static func section(depth: Int) -> MenuImportJSONValue {
        var properties: [String: MenuImportJSONValue] = [
            "title": text,
            "order": .object(["type": "integer"]),
            "entries": array(entry),
            "declarations": array(declaration),
            "review_reasons": array(reviewReason)
        ]
        properties["subsections"] = depth > 0
            ? array(section(depth: depth - 1))
            : array(.object(["type": "object", "additionalProperties": .bool(true)]))
        return object(properties)
    }

    // MARK: - Hilfen

    private static func object(_ properties: [String: MenuImportJSONValue]) -> MenuImportJSONValue {
        .object([
            "type": "object",
            "properties": .object(properties),
            // Kein `required`: siehe Abweichung 2. `additionalProperties: false`
            // hält das Modell davon ab, sich Felder auszudenken, die der
            // Dekoder ohnehin verwerfen würde.
            "additionalProperties": .bool(false)
        ])
    }

    private static func array(_ items: MenuImportJSONValue) -> MenuImportJSONValue {
        .object(["type": "array", "items": items])
    }

    /// Ein verschachteltes Objekt, das auch `null` sein darf. Als `anyOf`
    /// formuliert, weil `"type": ["object","null"]` zusammen mit `properties`
    /// von manchen Grammatikübersetzern nicht angenommen wird.
    private static func nullable(_ schema: MenuImportJSONValue) -> MenuImportJSONValue {
        .object(["anyOf": .array([schema, .object(["type": "null"])])])
    }
}
