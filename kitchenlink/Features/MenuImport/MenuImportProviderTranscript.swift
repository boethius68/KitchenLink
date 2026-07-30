import Foundation

/// Aufzeichnen und Abspielen von Anbieterantworten.
///
/// ## Warum das fehlte
///
/// Jede Messung dieser Pipeline brauchte bisher einen Live-Aufruf. Damit hing
/// jede Aussage über Assembler, Gate und Auswerter an einem Anbieter, an dessen
/// Tagesform und am Guthaben — und eine einmal bezahlte, gute Antwort war nach
/// dem Lauf verloren. Rückblickend hat das mehrere Sitzungen Geld und Zeit
/// gekostet: derselbe Prompt musste erneut bezahlt werden, nur um eine
/// Assembler-Änderung zu prüfen.
///
/// Eine aufgezeichnete Antwort trennt die beiden Fragen:
///
/// - *Liefert der Anbieter gute Rohdaten?* Braucht einen Live-Aufruf.
/// - *Macht die Pipeline aus gegebenen Rohdaten das Richtige?* Braucht das nie
///   wieder.
///
/// Aufzeichnungen sind ausserdem der Weg, eine Antwort aus einer fremden Quelle
/// einzuspeisen — etwa aus einem Chatfenster, in das der Prompt von Hand
/// eingegeben wurde.
///
/// ## Ablage
///
/// Eine Datei pro Seite, `page-<index>.json`, mit dem **rohen Vertrags-JSON**
/// des Anbieters (nicht der Chat-Hülle). Fehlt eine Datei, gilt die Seite als
/// nicht erfasst und die Seitenrettung greift wie bei einem echten Fehlschlag.
enum MenuImportProviderTranscript {

    static var replayDirectory: URL? {
        configValue(forKey: "KITCHENLINK_LLM_REPLAY_DIR").map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    static var recordDirectory: URL? {
        configValue(forKey: "KITCHENLINK_LLM_RECORD_DIR").map {
            URL(fileURLWithPath: $0, isDirectory: true)
        }
    }

    static func fileName(pageIndex: Int) -> String {
        "page-\(pageIndex).json"
    }

    /// Liest eine aufgezeichnete Antwort für diese Seite.
    ///
    /// Gibt den Rohtext zurück statt der dekodierten Struktur, damit der
    /// Abspielpfad **denselben** Dekodier- und Diagnosepfad durchläuft wie ein
    /// Live-Aufruf. Eine Aufzeichnung, die der Vertrag nicht annimmt, muss
    /// genauso auffallen wie eine Live-Antwort, die er nicht annimmt.
    static func replayText(pageIndex: Int) -> String? {
        guard let directory = replayDirectory else { return nil }
        let url = directory.appendingPathComponent(fileName(pageIndex: pageIndex))
        guard let data = try? Data(contentsOf: url) else { return nil }
        let text = String(decoding: data, as: UTF8.self)
        return text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : text
    }

    /// Legt eine Live-Antwort für spätere Läufe ab. Fehler beim Schreiben sind
    /// bewusst still: eine Aufzeichnung darf einen Import nicht scheitern
    /// lassen.
    static func record(pageIndex: Int, jsonText: String) {
        guard let directory = recordDirectory else { return }
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(fileName(pageIndex: pageIndex))
        try? Data(jsonText.utf8).write(to: url)
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
