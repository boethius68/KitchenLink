import Foundation

/// Optionale erste Stufe der semantischen Erfassung: ein Dokumentmodell löst
/// das **Layout** der Seite auf, bevor das Vertragsmodell sie interpretiert.
///
/// ## Warum es diese Stufe gibt
///
/// Apple Vision liefert Zeilen mit Koordinaten. Das genügt, um Text zu finden
/// (Belegabdeckung 0,988 gemessen) — aber nicht, um räumliche Beziehungen
/// aufzulösen. Genau dort sitzt die verbleibende Fehlermasse: Angebote 0,731,
/// Preisbasis 0,703, Beziehungen 0,425.
///
/// Gemessen am 30. Juli 2026 mit `olmOCR-2-7B` lokal über Ollama (42–49 s pro
/// Seite, 450–710 Ausgabe-Token) an genau den Seiten, die heute scheitern:
///
/// - Zwei Preisspalten neben einem Gericht kommen als
///   `28 € Zwischengericht    36 € Hauptgericht` **unter** dem Gericht heraus,
///   statt als zwei eigenständige Optionen. Das war einer der zehn
///   "erfundenen Preise".
/// - `Hüftsteak (250gr)` behält den gedruckten Namen samt Gewicht.
/// - Eine zweispaltige Beilagenliste wird als Tabelle mit korrekter Paarung
///   ausgegeben; aus einer flachen Zeilenliste wird sie unweigerlich vermischt.
/// - Zweisprachige Karten behalten die Paarung Deutsch/Englisch pro Gericht.
///
/// ## Was diese Stufe NICHT ist
///
/// Sie ersetzt die OCR-Belegzeilen nicht. Die Beleg-IDs und Bounding-Boxen
/// bleiben Apple Visions Aufgabe, weil der Review jeden Eintrag auf der
/// Originalseite zeigen muss. Diese Stufe liefert ausschliesslich zusätzlichen
/// Lesekontext — sie darf nichts hinzufügen, was nicht auf der Seite steht.
enum MenuImportLayoutPass {

    /// Ergebnis eines Layoutdurchgangs für eine Seite.
    struct Result: Sendable {
        let text: String
        let latencyMilliseconds: Int
        let model: String
    }

    /// Standardaufforderung. Bewusst knapp und ohne Interpretationsauftrag:
    /// die Stufe soll lesen und ordnen, nicht deuten.
    static let instruction = """
    Attached is one page of a restaurant menu. Return the complete text of the \
    page in natural reading order. Preserve the layout structure: keep each dish \
    together with the price or prices that belong to it, keep a bilingual pair on \
    the same dish, and render price columns or multi-column lists as a table so \
    it stays clear which price belongs to which dish and which portion. Do not \
    summarize, do not translate, do not omit anything, and do not add anything \
    that is not printed on the page.
    """

    static var isConfigured: Bool {
        configuredBaseURL != nil && configuredModel != nil
    }

    static var configuredBaseURL: String? {
        configValue(forKey: "KITCHENLINK_LAYOUT_BASE_URL")
    }

    static var configuredModel: String? {
        configValue(forKey: "KITCHENLINK_LAYOUT_MODEL")
    }

    static var configuredAPIKey: String? {
        configValue(forKey: "KITCHENLINK_LAYOUT_API_KEY")
    }

    /// Eigenes Zeitlimit: ein Dokumentmodell auf dem Entwicklerrechner braucht
    /// gemessen 42–49 s pro Seite und darf nicht am Limit des Vertragsmodells
    /// hängen.
    static var timeoutSeconds: Double {
        guard let raw = configValue(forKey: "KITCHENLINK_LAYOUT_PAGE_TIMEOUT_SECONDS"),
              let value = Double(raw),
              value > 0
        else { return 300 }
        return min(value, 1800)
    }

    /// Baut den Anfragekörper für ein OpenAI-kompatibles Chat-Gateway.
    ///
    /// Getrennt von der Ausführung, damit der Aufbau ohne Netz testbar ist.
    static func requestBody(
        model: String,
        instruction: String,
        imageDataURL: String
    ) throws -> Data {
        let payload: [String: Any] = [
            "model": model,
            "stream": false,
            // Ein Dokumentmodell soll transkribieren, nicht formulieren.
            "temperature": 0,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "text", "text": instruction],
                    ["type": "image_url", "image_url": ["url": imageDataURL]]
                ]
            ]]
        ]
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// Liest den Textinhalt aus der Antwort eines OpenAI-kompatiblen Gateways.
    static func text(fromResponse data: Data) -> String? {
        guard
            let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let message = choices.first?["message"] as? [String: Any]
        else { return nil }
        // Reasoning-Modelle legen die Antwort in `content`; bleibt es leer, ist
        // das Ausgabebudget im Nachdenken verbraucht (siehe MenuLLMDiagnostics).
        for key in ["content", "reasoning_content", "reasoning"] {
            guard let value = message[key] as? String else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    /// Der Block, der dem Vertragsmodell zusätzlich mitgegeben wird.
    ///
    /// Die Abgrenzung ist ausdrücklich: aufgelöstes Layout als Lesehilfe, aber
    /// Beleg-IDs kommen weiterhin ausschliesslich aus den OCR-Zeilen. Ohne
    /// diesen Satz würde das Modell anfangen, IDs zu erfinden, die zu Zeilen
    /// dieses Transkripts passen sollen.
    static func promptBlock(for text: String) -> String {
        """
        Layout-resolved transcript of this page (from a document model, reading \
        order and column structure already resolved). Use it to decide which \
        price, portion and option belongs to which entry. It carries no evidence \
        IDs: cite only the supplied OCR evidence lines.

        \(text)
        """
    }

    private static func configValue(forKey key: String) -> String? {
        if let environment = ProcessInfo.processInfo.environment[key] {
            let trimmed = environment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        if let bundled = Bundle.main.object(forInfoDictionaryKey: key) as? String {
            let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
