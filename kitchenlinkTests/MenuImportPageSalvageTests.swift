import Foundation
import Testing
@testable import kitchenlink

/// Bis zur Nutzerentscheidung vom 29. Juli 2026 verwarf EINE gescheiterte Seite
/// die semantische Erfassung der ganzen Karte ("no partial semantic draft
/// accepted"). Gemessen kostete das im kostenlosen Pfad alle vier Testkarten
/// und im bezahlten zwei von vieren — jedes Mal wegen genau einer Seite.
///
/// Jetzt bleibt erhalten, was erfasst wurde; die Lücke füllen die lokalen
/// Regeln. Weil der Entwurf damit gemischter Herkunft ist, prüfen diese Tests
/// vor allem, dass die Herkunft sichtbar bleibt.
struct MenuImportPageSalvageTests {

    private func evidence(page: Int, text: String) -> MenuImportEvidence {
        MenuImportEvidence(
            rawText: text,
            pageIndex: page,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0.1,
                y: 0.5,
                width: 0.3,
                height: 0.04
            ),
            method: .ocr,
            confidence: 0.9,
            isLocated: true
        )
    }

    private func entry(_ name: String, page: Int, order: Int) -> MenuImportEntry {
        MenuImportEntry(
            id: "entry-\(name)",
            kind: "food",
            name: MenuImportText(
                value: name,
                languageTag: "de",
                evidence: evidence(page: page, text: name)
            ),
            order: order
        )
    }

    private func section(
        _ title: String,
        page: Int,
        order: Int,
        entries: [MenuImportEntry]
    ) -> MenuImportSection {
        MenuImportSection(
            id: "section-\(title)",
            title: MenuImportText(
                value: title,
                languageTag: "de",
                evidence: evidence(page: page, text: title)
            ),
            order: order,
            entries: entries
        )
    }

    private func draft(
        id: String,
        sections: [MenuImportSection]
    ) -> MenuImportDraft {
        MenuImportDraft(
            id: id,
            sourceDocument: MenuImportSourceDocument(
                id: "source",
                sourceType: .demoFixture,
                pageCount: 3,
                fingerprint: "sha256:document"
            ),
            sections: sections,
            processing: MenuImportProcessingMetadata(
                pipelineVersion: "test",
                provider: "test",
                pageOutcomes: (0..<3).map {
                    MenuImportPageOutcome(pageIndex: $0, status: .processed, attempts: 1)
                }
            )
        )
    }

    @Test("Gescheiterte Seite wird aus den lokalen Regeln aufgefüllt")
    func fillsTheUnextractedPageFromTheLocalRules() throws {
        let semantic = draft(
            id: "draft-semantic",
            sections: [
                section("Vorspeisen", page: 0, order: 0, entries: [
                    entry("Tomatensuppe", page: 0, order: 0)
                ]),
                section("Desserts", page: 2, order: 1, entries: [
                    entry("Tiramisu", page: 2, order: 0)
                ])
            ]
        )
        let local = draft(
            id: "draft-local",
            sections: [
                section("Alles", page: 0, order: 0, entries: [
                    entry("Tomatensuppe (Regel)", page: 0, order: 0),
                    entry("Schnitzel", page: 1, order: 1),
                    entry("Rumpsteak", page: 1, order: 2),
                    entry("Tiramisu (Regel)", page: 2, order: 3)
                ])
            ]
        )

        let merged = MenuImportService.mergingLocalPages(
            into: semantic,
            localDraft: local,
            pages: [1]
        )

        let names = merged.sections.flatMap { $0.entries.map(\.name.value) }
        #expect(names.contains("Schnitzel"))
        #expect(names.contains("Rumpsteak"))
        // Nur die Lücke wird gefüllt: Seiten mit KI-Erfassung bleiben unberührt.
        #expect(!names.contains("Tomatensuppe (Regel)"))
        #expect(!names.contains("Tiramisu (Regel)"))
        #expect(names.contains("Tomatensuppe"))
        #expect(names.contains("Tiramisu"))
    }

    @Test("Die Herkunft der aufgefüllten Seite bleibt sichtbar")
    func marksTheSalvagedOriginForTheReview() throws {
        let semantic = draft(
            id: "draft-semantic",
            sections: [
                section("Vorspeisen", page: 0, order: 0, entries: [
                    entry("Tomatensuppe", page: 0, order: 0)
                ])
            ]
        )
        let local = draft(
            id: "draft-local",
            sections: [
                section("Alles", page: 0, order: 0, entries: [
                    entry("Schnitzel", page: 1, order: 0)
                ])
            ]
        )

        let merged = MenuImportService.mergingLocalPages(
            into: semantic,
            localDraft: local,
            pages: [1]
        )

        let salvagedSection = try #require(
            merged.sections.first { section in
                section.entries.contains { $0.name.value == "Schnitzel" }
            }
        )
        #expect(salvagedSection.reviewState == .needsReview)
        let finding = try #require(
            (merged.reviewFindings ?? []).first {
                $0.code == "page_filled_from_local_rules"
            }
        )
        #expect(finding.pageIndex == 1)
        #expect(finding.severity == .warning)
    }

    @Test("Aufgefüllte Bereiche stehen in Seitenreihenfolge")
    func keepsTheSalvagedSectionInReadingOrder() throws {
        let semantic = draft(
            id: "draft-semantic",
            sections: [
                section("Vorspeisen", page: 0, order: 0, entries: [
                    entry("Tomatensuppe", page: 0, order: 0)
                ]),
                section("Desserts", page: 2, order: 1, entries: [
                    entry("Tiramisu", page: 2, order: 0)
                ])
            ]
        )
        let local = draft(
            id: "draft-local",
            sections: [
                section("Alles", page: 0, order: 0, entries: [
                    entry("Schnitzel", page: 1, order: 0)
                ])
            ]
        )

        let merged = MenuImportService.mergingLocalPages(
            into: semantic,
            localDraft: local,
            pages: [1]
        )

        let firstEntryNames = merged.sections.compactMap { $0.entries.first?.name.value }
        #expect(firstEntryNames == ["Tomatensuppe", "Schnitzel", "Tiramisu"])
        #expect(merged.sections.map(\.order) == [0, 1, 2])
        #expect(merged.validate().errors.isEmpty)
    }

    @Test("Ohne Lücke bleibt der Entwurf unverändert")
    func leavesACompleteDraftUntouched() throws {
        let semantic = draft(
            id: "draft-semantic",
            sections: [
                section("Vorspeisen", page: 0, order: 0, entries: [
                    entry("Tomatensuppe", page: 0, order: 0)
                ])
            ]
        )
        let local = draft(
            id: "draft-local",
            sections: [
                section("Alles", page: 0, order: 0, entries: [
                    entry("Schnitzel", page: 1, order: 0)
                ])
            ]
        )

        #expect(
            MenuImportService.mergingLocalPages(
                into: semantic,
                localDraft: local,
                pages: []
            ) == semantic
        )
    }
}
