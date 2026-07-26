import CryptoKit
import Foundation
import UIKit
import XCTest
@testable import kitchenlink

/// KL-SCAN-002: Batch-Export für die Import-Review-Umgebung.
///
/// Läuft nur, wenn `scripts/run-import-review.sh` eine
/// `ImportReviewRequest.json` in das App-Bundle gelegt hat (gleicher
/// Gate-Mechanismus wie der Scanner-Benchmark). Der Test jagt alle
/// Demo-Fixtures — und optional beliebige eigene Speisekarten aus einem
/// konfigurierten Ordner — durch die echte lokale OCR-/Parser-Pipeline und
/// schreibt Seitenbilder plus einen vollständigen Struktur-Schnappschuss
/// (`report.json`) in das Ausgabeverzeichnis. `import-review-report.html`
/// rendert daraus den Seite-an-Seite-Report für die menschliche Prüfung.
///
/// Der Harness selbst exportiert bewusst nur den beobachteten Stand. Das
/// versionierte Phase-1-Gate bewertet `report.json` anschließend
/// deterministisch gegen die vollständige Ground Truth.
final class MenuImportReviewHarnessTests: XCTestCase {

    // MARK: - Konfiguration (vom Runner-Skript ins Bundle gelegt)

    private struct ReviewRequest: Codable {
        let outputPath: String
        let extraMenusPath: String?
        /// Optionaler, ausdrücklich begrenzter Modell-Pilot. Jeder Wert hat
        /// die Form `fixture-id:pageIndex` mit nullbasiertem Seitenindex.
        /// Nur diese Seiten werden verarbeitet und gegebenenfalls übertragen.
        let selectedPages: [String]?
        /// Runde-2-Vergleich: zusätzlich den vorhandenen KI-Pfad
        /// (Seitenbilder + OCR an das Vision-LLM) laufen lassen. Erfordert
        /// einen konfigurierten API-Key (das Runner-Skript reicht ihn als
        /// TEST_RUNNER_-Umgebungsvariable durch).
        let runLLM: Bool?
    }

    // MARK: - Report-Schema (Vertrag mit import-review-report.html)

    private struct Report: Codable {
        let schemaVersion: String
        let generatedAt: Date
        let parserMode: String
        let selectedPages: [String]?
        let menus: [MenuSnapshot]
    }

    private struct MenuSnapshot: Codable {
        let id: String
        let title: String
        let source: String // "fixture" | "pdf" | "images"
        let pageCount: Int
        let pageFiles: [String]
        let ocrLineCount: Int
        let diagnostics: String
        let ocrLines: [OCRLineSnapshot]
        let legacySections: [LegacySection]
        /// Canonical, lossless contract used by the automated quality gate.
        let draft: MenuImportDraft
        let draftSections: [DraftSection]
        let draftValidationErrors: [String]
        // Optionaler zweiter Durchlauf über den KI-Pfad (Runde-2-Vergleich).
        let llmLegacySections: [LegacySection]?
        let llmDraft: MenuImportDraft?
        let llmDraftSections: [DraftSection]?
        let llmDraftValidationErrors: [String]?
        let llmDiagnostics: String?
        let llmError: String?
    }

    private struct OCRLineSnapshot: Codable {
        let text: String
        let pageIndex: Int
        let minX: Double
        let minY: Double
        let width: Double
        let height: Double
        let confidence: Double
    }

    private struct LegacySection: Codable {
        let title: String
        let kind: String
        let confidence: Double
        let items: [LegacyItem]
    }

    private struct LegacyItem: Codable {
        let name: String
        /// Name nach Abtrennung nachgestellter Allergen-Codes. Weicht er von
        /// `name` ab, sind Codes in den Namen gerutscht — der Report markiert das.
        let displayName: String
        let priceCents: Int
        let description: String
        let allergenCodes: String?
        let variants: [LegacyVariant]
    }

    private struct LegacyVariant: Codable {
        let name: String
        let priceCents: Int
        let kind: String
    }

    private struct DraftSection: Codable {
        let id: String
        let title: String
        let titleEvidence: EvidenceSnapshot
        let entries: [DraftEntry]
    }

    private struct DraftEntry: Codable {
        let id: String
        let kind: String
        let name: String
        let nameEvidence: EvidenceSnapshot
        let description: String?
        let itemNumber: String?
        let reviewState: String
        let offers: [OfferSnapshot]
        let declarations: [DeclarationSnapshot]
        let optionGroups: [OptionGroupSnapshot]
        let quantities: [String]
    }

    private struct EvidenceSnapshot: Codable {
        let rawText: String
        let pageIndex: Int
        let x: Double
        let y: Double
        let width: Double
        let height: Double
        let located: Bool
        let confidence: Double
        let method: String
    }

    private struct OfferSnapshot: Codable {
        let priceKind: String
        let amountCents: Int?
        let deltaCents: Int?
        let rawPrice: String?
        let basis: String
        let evidence: EvidenceSnapshot
    }

    private struct DeclarationSnapshot: Codable {
        let kind: String
        let localCode: String?
        let rawText: String
    }

    private struct OptionGroupSnapshot: Codable {
        let title: String
        let selectionRule: String
        let choices: [ChoiceSnapshot]
    }

    private struct ChoiceSnapshot: Codable {
        let name: String
        let kind: String
        let offers: [OfferSnapshot]
    }

    // MARK: - Test

    func testExportImportReviewReport() async throws {
        guard let requestURL = Bundle.main.url(
            forResource: "ImportReviewRequest",
            withExtension: "json"
        ) else {
            throw XCTSkip("Run through scripts/run-import-review.sh to enable the review export.")
        }
        let request = try JSONDecoder().decode(
            ReviewRequest.self,
            from: Data(contentsOf: requestURL)
        )

        let outputURL = URL(fileURLWithPath: request.outputPath, isDirectory: true)
        let pagesURL = outputURL.appendingPathComponent("pages", isDirectory: true)
        try FileManager.default.createDirectory(at: pagesURL, withIntermediateDirectories: true)

        let previousLLMSetting = MenuImportService.isLLMEnabled()
        MenuImportService.setLLMEnabled(false)
        defer { MenuImportService.setLLMEnabled(previousLLMSetting) }

        var menus: [MenuSnapshot] = []
        let runLLM = request.runLLM == true

        // 1. Eingebaute Fixtures (dieselbe Quelle wie der Benchmark). Ein
        // ausdrücklich gesetzter Seitenfilter ist ein kleiner Modell-Pilot
        // und verhindert, dass der normale 17-Seiten-Umfang versehentlich an
        // einen externen Anbieter übertragen wird.
        if let selectedPages = request.selectedPages, !selectedPages.isEmpty {
            var selectedImages: [UIImage] = []
            for selection in selectedPages {
                let components = selection.split(separator: ":", maxSplits: 1)
                guard components.count == 2,
                      let pageIndex = Int(components[1]),
                      let fixture = DemoMenuFixtures.reviewFixtures.first(
                          where: { $0.id == String(components[0]) }
                      )
                else {
                    XCTFail("Ungültige Seitenauswahl: \(selection)")
                    continue
                }
                let fixtureImages = DemoMenuFixtures.images(for: fixture)
                guard fixtureImages.indices.contains(pageIndex) else {
                    XCTFail("Seite \(pageIndex) fehlt in Fixture \(fixture.id)")
                    continue
                }
                selectedImages.append(fixtureImages[pageIndex])
            }
            XCTAssertEqual(
                selectedImages.count,
                selectedPages.count,
                "Nicht alle ausgewählten Pilotseiten konnten geladen werden."
            )
            if !selectedImages.isEmpty {
                let snapshot = try await process(
                    menuID: "pilot-selection",
                    title: "Begrenzter Modell-Pilot",
                    source: "fixture-selection",
                    images: selectedImages,
                    pagesURL: pagesURL,
                    runLLM: runLLM
                )
                menus.append(snapshot)
            }
        } else {
            for fixture in DemoMenuFixtures.reviewFixtures {
                let images = DemoMenuFixtures.images(for: fixture)
                XCTAssertEqual(images.count, fixture.pageCount, "Fixture \(fixture.id) unvollständig")
                let snapshot = try await process(
                    menuID: fixture.id,
                    title: fixture.title,
                    source: "fixture",
                    images: images,
                    pagesURL: pagesURL,
                    runLLM: runLLM
                )
                menus.append(snapshot)
            }
        }

        // 2. Optionale eigene Karten aus dem konfigurierten Ordner.
        if let extraPath = request.extraMenusPath, !extraPath.isEmpty {
            for extra in try loadExtraMenus(from: extraPath) {
                let snapshot = try await process(
                    menuID: extra.id,
                    title: extra.title,
                    source: extra.source,
                    images: extra.images,
                    pagesURL: pagesURL,
                    runLLM: runLLM
                )
                menus.append(snapshot)
            }
        }

        let report = Report(
            schemaVersion: "kitchenlink-import-review-report/1.0.0",
            generatedAt: Date(),
            parserMode: "apple-vision-plus-local-rules",
            selectedPages: request.selectedPages,
            menus: menus
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let reportData = try encoder.encode(report)
        try reportData.write(
            to: outputURL.appendingPathComponent("report.json"),
            options: .atomic
        )

        print("KITCHENLINK_IMPORT_REVIEW_OUTPUT: \(outputURL.path)")
    }

    // MARK: - Pipeline-Lauf pro Karte

    private func process(
        menuID: String,
        title: String,
        source: String,
        images: [UIImage],
        pagesURL: URL,
        runLLM: Bool
    ) async throws -> MenuSnapshot {
        // Seitenbilder exportieren (PNG, Orientierung normalisiert).
        var pageFiles: [String] = []
        for (index, image) in images.enumerated() {
            let fileName = "\(menuID)-p\(index + 1).png"
            let fileURL = pagesURL.appendingPathComponent(fileName)
            guard let data = normalizedPNGData(from: image) else {
                XCTFail("Seite \(index + 1) von \(menuID) ließ sich nicht als PNG exportieren.")
                continue
            }
            try data.write(to: fileURL, options: .atomic)
            pageFiles.append(fileName)
        }

        var sourceHasher = SHA256()
        var sourcePages: [MenuImportSourcePage] = []
        for (pageIndex, fileName) in pageFiles.enumerated() {
            let fileURL = pagesURL.appendingPathComponent(fileName)
            let pageData = try Data(contentsOf: fileURL)
            let digest = SHA256.hash(data: pageData)
            sourceHasher.update(data: Data(digest))
            let image = images[pageIndex]
            sourcePages.append(
                MenuImportSourcePage(
                    pageIndex: pageIndex,
                    fingerprint: "sha256:" + digest.map {
                        String(format: "%02x", $0)
                    }.joined(),
                    pixelWidth: max(
                        1,
                        Int((image.size.width * image.scale).rounded())
                    ),
                    pixelHeight: max(
                        1,
                        Int((image.size.height * image.scale).rounded())
                    ),
                    originalAssetReference: fileURL.path
                )
            )
        }
        let sourceDocument = MenuImportSourceDocument(
            id: "review-source-\(menuID)",
            sourceType: .demoFixture,
            sourceTypeDetail: menuID,
            pageCount: images.count,
            fingerprint: "sha256:" + sourceHasher.finalize().map {
                String(format: "%02x", $0)
            }.joined(),
            displayName: title,
            pages: sourcePages
        )
        let importResult = try await MenuImportService.benchmarkLocalImport(
            from: images,
            sourceDocument: sourceDocument
        )
        let validation = importResult.draft.validate()

        // Optionaler zweiter Durchlauf über den vorhandenen KI-Pfad
        // (Seitenbilder + OCR-Zeilen an das Vision-LLM). Fehler werden ehrlich
        // in den Report geschrieben statt den Lauf abzubrechen — der lokale
        // Teil des Vergleichs bleibt dann trotzdem nutzbar.
        var llmLegacySections: [LegacySection]?
        var llmDraft: MenuImportDraft?
        var llmDraftSections: [DraftSection]?
        var llmDraftValidationErrors: [String]?
        var llmDiagnostics: String?
        var llmError: String?
        if runLLM {
            if MenuImportService.hasConfiguredLLMAPIKey() {
                // Vorherigen Zustand sichern und wiederherstellen — NICHT hart auf
                // false setzen, sonst bleibt der geteilte UserDefaults-Schalter
                // deaktiviert und ein späterer App-Start (oder anderer Test) sieht
                // fälschlich „KI aus".
                let previousLLMEnabled = MenuImportService.isLLMEnabled()
                MenuImportService.setLLMEnabled(true)
                defer { MenuImportService.setLLMEnabled(previousLLMEnabled) }
                do {
                    let llmResult = try await MenuImportService.importMenu(
                        from: images,
                        sourceType: .demoFixture,
                        sourceTypeDetail: "review-llm-\(menuID)",
                        displayName: title
                    )
                    llmLegacySections = llmResult.sections.map(legacySection(from:))
                    llmDraft = llmResult.draft
                    llmDraftSections = llmResult.draft.sections.map(draftSection(from:))
                    llmDraftValidationErrors = llmResult.draft.validate().errors.map {
                        String(describing: $0)
                    }
                    llmDiagnostics = "Modell \(MenuImportService.resolvedLLMModel) @ "
                        + "\(MenuImportService.resolvedLLMBaseURL) — "
                        + MenuImportService.lastImportDiagnostics()
                } catch {
                    // Die Diagnose trägt die Server-Begründung (z. B. den
                    // 401-Antworttext); der blanke Fehlerfall wäre nur "invalidAPIKey".
                    llmError = "\(String(describing: error)) — "
                        + MenuImportService.lastImportDiagnostics()
                }
            } else {
                llmError = "Kein API-Key konfiguriert "
                    + "(KITCHENLINK_OPENAI_API_KEY oder KITCHENLINK_OPENCODE_API_KEY)."
            }
        }

        return MenuSnapshot(
            id: menuID,
            title: title,
            source: source,
            pageCount: images.count,
            pageFiles: pageFiles,
            ocrLineCount: importResult.ocrLines.count,
            diagnostics: MenuImportService.lastImportDiagnostics(),
            ocrLines: importResult.ocrLines.map { line in
                OCRLineSnapshot(
                    text: line.text,
                    pageIndex: line.pageIndex,
                    minX: line.minX,
                    minY: line.minY,
                    width: line.width,
                    height: line.height,
                    confidence: line.confidence
                )
            },
            legacySections: importResult.sections.map(legacySection(from:)),
            draft: importResult.draft,
            draftSections: importResult.draft.sections.map(draftSection(from:)),
            draftValidationErrors: validation.errors.map { String(describing: $0) },
            llmLegacySections: llmLegacySections,
            llmDraft: llmDraft,
            llmDraftSections: llmDraftSections,
            llmDraftValidationErrors: llmDraftValidationErrors,
            llmDiagnostics: llmDiagnostics,
            llmError: llmError
        )
    }

    private func legacySection(from section: MenuSectionData) -> LegacySection {
        LegacySection(
            title: section.title,
            kind: section.kind.rawValue,
            confidence: section.importConfidence,
            items: section.items.map { item in
                LegacyItem(
                    name: item.name,
                    displayName: item.displayName,
                    priceCents: item.priceCents,
                    description: item.description,
                    allergenCodes: item.resolvedAllergenCodes,
                    variants: item.variants.map { variant in
                        LegacyVariant(
                            name: variant.name,
                            priceCents: variant.priceCents,
                            kind: variant.kind.rawValue
                        )
                    }
                )
            }
        )
    }

    private func draftSection(from section: MenuImportSection) -> DraftSection {
        DraftSection(
            id: section.id,
            title: section.title.value,
            titleEvidence: evidence(section.title.evidence),
            entries: section.entries.map { entry in
                DraftEntry(
                    id: entry.id,
                    kind: entry.kind,
                    name: entry.name.value,
                    nameEvidence: evidence(entry.name.evidence),
                    description: entry.description?.value,
                    itemNumber: entry.itemNumber,
                    reviewState: entry.reviewState.rawValue,
                    offers: entry.offers.map(offer(from:)),
                    declarations: entry.declarations.map { declaration in
                        DeclarationSnapshot(
                            kind: declaration.kind,
                            localCode: declaration.localCode,
                            rawText: declaration.rawText
                        )
                    },
                    optionGroups: entry.optionGroups.map { group in
                        OptionGroupSnapshot(
                            title: group.title.value,
                            selectionRule: String(describing: group.selectionRule),
                            choices: group.choices.map { choice in
                                ChoiceSnapshot(
                                    name: choice.name.value,
                                    kind: choice.kind,
                                    offers: choice.offers.map(offer(from:))
                                )
                            }
                        )
                    },
                    quantities: entry.quantities.map(\.rawText)
                )
            }
        )
    }

    private func offer(from offer: MenuImportOffer) -> OfferSnapshot {
        OfferSnapshot(
            priceKind: offer.priceKind.rawValue,
            amountCents: offer.amountCents,
            deltaCents: offer.deltaCents,
            rawPrice: offer.rawPrice,
            basis: offer.basis,
            evidence: evidence(offer.evidence)
        )
    }

    private func evidence(_ source: MenuImportEvidence) -> EvidenceSnapshot {
        EvidenceSnapshot(
            rawText: source.rawText,
            pageIndex: source.pageIndex,
            x: source.boundingBox.x,
            y: source.boundingBox.y,
            width: source.boundingBox.width,
            height: source.boundingBox.height,
            located: source.isLocated,
            confidence: source.confidence,
            method: source.method.rawValue
        )
    }

    // MARK: - Eigene Karten (PDF oder Bilderordner)

    private struct ExtraMenu {
        let id: String
        let title: String
        let source: String
        let images: [UIImage]
    }

    /// Konvention: Im Ordner liegt pro Karte entweder eine PDF-Datei
    /// (`meine-karte.pdf` -> Seiten = PDF-Seiten) oder ein Unterordner mit
    /// Bildern (PNG/JPG, Seitenreihenfolge = Dateinamen-Sortierung).
    private func loadExtraMenus(from path: String) throws -> [ExtraMenu] {
        let rootURL = URL(fileURLWithPath: path, isDirectory: true)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: rootURL.path) else {
            XCTFail("Ordner für eigene Karten nicht gefunden: \(path)")
            return []
        }

        var menus: [ExtraMenu] = []
        let contents = try fileManager.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent < $1.lastPathComponent }

        for entry in contents {
            let isDirectory = (try? entry.resourceValues(
                forKeys: [.isDirectoryKey]
            ).isDirectory) ?? false

            if isDirectory {
                let images = try loadImages(fromDirectory: entry)
                guard !images.isEmpty else { continue }
                let id = sanitizedMenuID(entry.lastPathComponent)
                menus.append(ExtraMenu(
                    id: "extra-\(id)",
                    title: entry.lastPathComponent,
                    source: "images",
                    images: images
                ))
            } else if entry.pathExtension.lowercased() == "pdf" {
                let images = renderPDFPages(at: entry)
                guard !images.isEmpty else {
                    XCTFail("PDF ohne renderbare Seiten: \(entry.lastPathComponent)")
                    continue
                }
                let id = sanitizedMenuID(entry.deletingPathExtension().lastPathComponent)
                menus.append(ExtraMenu(
                    id: "extra-\(id)",
                    title: entry.deletingPathExtension().lastPathComponent,
                    source: "pdf",
                    images: images
                ))
            }
        }
        return menus
    }

    private func loadImages(fromDirectory directory: URL) throws -> [UIImage] {
        let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic"]
        return try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        .compactMap { UIImage(contentsOfFile: $0.path) }
    }

    /// Rendert PDF-Seiten mit ~2000 px Zielbreite — genug für Vision-OCR,
    /// klein genug für einen schnellen Batch-Lauf.
    private func renderPDFPages(at url: URL, targetWidth: CGFloat = 2000) -> [UIImage] {
        guard let document = CGPDFDocument(url as CFURL) else { return [] }
        var images: [UIImage] = []
        for pageNumber in 1...document.numberOfPages {
            guard let page = document.page(at: pageNumber) else { continue }
            let box = page.getBoxRect(.mediaBox)
            guard box.width > 0, box.height > 0 else { continue }
            let scale = targetWidth / box.width
            let size = CGSize(width: targetWidth, height: box.height * scale)

            let format = UIGraphicsImageRendererFormat()
            format.scale = 1
            let image = UIGraphicsImageRenderer(size: size, format: format).image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: size))
                context.cgContext.translateBy(x: 0, y: size.height)
                context.cgContext.scaleBy(x: scale, y: -scale)
                context.cgContext.translateBy(x: -box.origin.x, y: -box.origin.y)
                context.cgContext.drawPDFPage(page)
            }
            images.append(image)
        }
        return images
    }

    private func sanitizedMenuID(_ raw: String) -> String {
        let lowered = raw.lowercased()
        var out = ""
        var pendingDash = false
        for character in lowered {
            if character.isASCII && (character.isLetter || character.isNumber) {
                if pendingDash && !out.isEmpty { out.append("-") }
                out.append(character)
                pendingDash = false
            } else {
                pendingDash = true
            }
        }
        return out.isEmpty ? "karte" : out
    }

    /// Rendert einmal neu, damit EXIF-Orientierung und Scale neutralisiert sind
    /// und die normalisierten Bounding Boxes exakt auf dem PNG liegen.
    private func normalizedPNGData(from image: UIImage) -> Data? {
        let pixelSize = CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
        guard pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let normalized = UIGraphicsImageRenderer(size: pixelSize, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: pixelSize))
        }
        return normalized.pngData()
    }
}
