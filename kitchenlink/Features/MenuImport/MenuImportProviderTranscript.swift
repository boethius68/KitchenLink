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

    /// Ordner für eine bestimmte Karte innerhalb des Ablageverzeichnisses.
    ///
    /// Nötig, weil der Seitenindex allein nicht eindeutig ist: zwei Karten
    /// haben beide eine Seite 2, und ein flaches Verzeichnis würde sie
    /// verwechseln — die Aufzeichnung der einen Karte landete stillschweigend in
    /// der anderen. Beim ersten Versuch ist genau das passiert.
    ///
    /// Die Zuordnung ist absichtlich nachsichtig: gewinnt der Unterordner, dessen
    /// Name im Herkunftsdetail der Karte vorkommt (längster Treffer). So genügt
    /// `alexxanders-chemnitz/`, ohne dass jemand das interne
    /// `review-llm-alexxanders-chemnitz` kennen muss.
    static func scopedDirectory(in directory: URL, scope: String?) -> URL? {
        guard let scope = scope?.lowercased(), !scope.isEmpty else { return nil }
        let entries = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey]
        )) ?? []
        let candidates = entries.filter { url in
            var isDirectory: ObjCBool = false
            let exists = FileManager.default.fileExists(
                atPath: url.path,
                isDirectory: &isDirectory
            )
            guard exists, isDirectory.boolValue else { return false }
            return scope.contains(url.lastPathComponent.lowercased())
        }
        return candidates.max { $0.lastPathComponent.count < $1.lastPathComponent.count }
    }

    /// Liest eine aufgezeichnete Antwort für diese Seite.
    ///
    /// Gibt den Rohtext zurück statt der dekodierten Struktur, damit der
    /// Abspielpfad **denselben** Dekodier- und Diagnosepfad durchläuft wie ein
    /// Live-Aufruf. Eine Aufzeichnung, die der Vertrag nicht annimmt, muss
    /// genauso auffallen wie eine Live-Antwort, die er nicht annimmt.
    static func replayText(pageIndex: Int, scope: String?) -> String? {
        guard let directory = replayDirectory else { return nil }
        let name = fileName(pageIndex: pageIndex)
        let candidates = [
            scopedDirectory(in: directory, scope: scope)?.appendingPathComponent(name),
            directory.appendingPathComponent(name)
        ].compactMap { $0 }
        for url in candidates {
            guard let data = try? Data(contentsOf: url) else { continue }
            let text = String(decoding: data, as: UTF8.self)
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return text
            }
        }
        return nil
    }

    /// Legt eine Live-Antwort für spätere Läufe ab. Fehler beim Schreiben sind
    /// bewusst still: eine Aufzeichnung darf einen Import nicht scheitern
    /// lassen.
    static func record(pageIndex: Int, scope: String?, jsonText: String) {
        guard let directory = recordDirectory else { return }
        // Beim Schreiben wird der Kartenordner angelegt, nicht gesucht: sonst
        // überschreiben zwei Karten gegenseitig ihre Seite 2.
        let target = scope.map { value -> URL in
            let folder = value
                .lowercased()
                .replacingOccurrences(of: "/", with: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return folder.isEmpty
                ? directory
                : directory.appendingPathComponent(folder, isDirectory: true)
        } ?? directory
        try? FileManager.default.createDirectory(
            at: target,
            withIntermediateDirectories: true
        )
        try? Data(jsonText.utf8).write(
            to: target.appendingPathComponent(fileName(pageIndex: pageIndex))
        )
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
