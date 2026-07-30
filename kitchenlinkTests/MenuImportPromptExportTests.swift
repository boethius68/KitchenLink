import UIKit
import XCTest
@testable import kitchenlink

/// Schreibt die Prompt-Pakete der Gate-Seiten auf die Platte, damit eine
/// Antwort aus einer beliebigen Quelle eingesammelt werden kann — auch aus einem
/// Chatfenster, wenn kein API-Zugang zur Verfügung steht.
///
/// Zusammen mit `KITCHENLINK_LLM_REPLAY_DIR` schliesst das die Lücke, die diese
/// Pipeline teuer gemacht hat: eine einmal erhaltene gute Antwort war nach dem
/// Lauf verloren und musste für jede Assembler-Änderung neu bezahlt werden.
final class MenuImportPromptExportTests: XCTestCase {

    /// Nur über `scripts/export-extraction-prompts.sh` aktiv, damit ein
    /// normaler Testlauf nichts in fremde Verzeichnisse schreibt.
    func testExportExtractionPrompts() async throws {
        guard let outputPath = ProcessInfo.processInfo
            .environment["KITCHENLINK_PROMPT_OUTPUT"],
              !outputPath.isEmpty
        else {
            throw XCTSkip("Über scripts/export-extraction-prompts.sh aufrufen.")
        }
        let outputRoot = URL(fileURLWithPath: outputPath, isDirectory: true)

        // Dieselben Seiten wie das Qualitätsgate, mit denselben Indizes — sonst
        // passt die Auswertung der zurückkopierten Antworten nicht.
        let gatePages: [String: [Int]] = [
            "kitchenlink-pruefkueche": [0, 1, 2],
            "scheune-berlin": [0],
            "lichtburg-berlin": [4, 5, 6],
            "alexxanders-chemnitz": [0, 2, 3]
        ]

        // Ein stiller Ausfall der Layoutstufe sieht im Paket wie "nicht
        // konfiguriert" aus. Der Grund gehört deshalb in die Ausgabe.
        print("Layoutstufe konfiguriert: \(MenuImportLayoutPass.isConfigured)")
        print("Layout-Basis: \(MenuImportLayoutPass.configuredBaseURL ?? "(keine)")")
        print("Layout-Modell: \(MenuImportLayoutPass.configuredModel ?? "(keines)")")

        var written = 0
        for fixture in DemoMenuFixtures.reviewFixtures {
            guard let pages = gatePages[fixture.id] else { continue }
            let images = DemoMenuFixtures.images(for: fixture)
            let fixtureRoot = outputRoot.appendingPathComponent(fixture.id, isDirectory: true)
            try FileManager.default.createDirectory(
                at: fixtureRoot,
                withIntermediateDirectories: true
            )

            // Der Export läuft über die ganze Karte, weil `page_index` und die
            // Beleg-IDs seitenübergreifend stabil sein müssen.
            let packages = try await MenuImportService.exportExtractionPrompts(from: images)

            for pageIndex in pages {
                guard let package = packages.first(where: { $0.pageIndex == pageIndex })
                else {
                    XCTFail("Kein Prompt-Paket für \(fixture.id) Seite \(pageIndex)")
                    continue
                }
                let text = """
                ===== SYSTEM =====
                \(package.systemPrompt)

                ===== USER =====
                \(package.userPrompt)

                ===== ANWEISUNG AN DIE PERSON, DIE DAS EINFÜGT =====
                Das zugehörige Seitenbild liegt daneben als page-\(pageIndex).png und
                gehört mit in die Anfrage. Die Antwort muss reines JSON sein, ohne
                Codeblock-Zäune und ohne Vor- oder Nachtext. Zurücklegen als
                page-\(pageIndex).json im Zielverzeichnis, dann auswerten mit
                KITCHENLINK_LLM_REPLAY_DIR=<zielverzeichnis>.
                """
                try Data(text.utf8).write(
                    to: fixtureRoot.appendingPathComponent("page-\(pageIndex).txt")
                )
                if images.indices.contains(pageIndex),
                   let png = images[pageIndex].pngData() {
                    try png.write(
                        to: fixtureRoot.appendingPathComponent("page-\(pageIndex).png")
                    )
                }
                written += 1
            }
            if let diagnostics = MenuImportService.lastLayoutPassDiagnostics {
                print("Layoutstufe \(fixture.id): \(diagnostics)")
            }
        }

        XCTAssertEqual(written, 10, "Das Gate umfasst zehn Seiten.")
    }
}
