import Foundation
import UIKit
import XCTest
@testable import kitchenlink

final class MenuImportBenchmarkTests: XCTestCase {
    private struct Report: Codable {
        let generatedAt: Date
        let parserMode: String
        let fixtures: [FixtureSnapshot]
    }

    private struct FixtureSnapshot: Codable {
        let fixtureID: String
        let pageCount: Int
        let sectionCount: Int
        let itemCount: Int
        let ocrLineCount: Int
        let diagnostics: String
        let ocrLines: [MenuImportService.BenchmarkOCRLine]
        let sections: [SectionSnapshot]
        let draftSectionCount: Int
        let draftEntryCount: Int
        let draftValidationIssues: [MenuImportValidationIssue]
        let draftSections: [DraftSectionSnapshot]
    }

    private struct SectionSnapshot: Codable {
        let title: String
        let confidence: Double
        let items: [ItemSnapshot]
    }

    private struct ItemSnapshot: Codable {
        let name: String
        let priceCents: Int
        let description: String
        let allergenCodes: String?
        let variants: [VariantSnapshot]
    }

    private struct VariantSnapshot: Codable {
        let name: String
        let priceCents: Int
        let kind: String
    }

    private struct DraftSectionSnapshot: Codable {
        let title: String
        let entries: [DraftEntrySnapshot]
    }

    private struct DraftEntrySnapshot: Codable {
        let name: String
        let pageIndex: Int
        let reviewState: String
        let offers: [DraftOfferSnapshot]
    }

    private struct DraftOfferSnapshot: Codable {
        let priceKind: String
        let amountCents: Int?
        let deltaCents: Int?
        let rawPrice: String?
        let pageIndex: Int
        let boundingBox: MenuImportNormalizedBoundingBox
    }

    func testDemoMenusProduceLocalOCRBenchmarkSnapshot() async throws {
        let benchmarkWasRequested =
            ProcessInfo.processInfo.environment["KITCHENLINK_RUN_SCANNER_BENCHMARK"] == "1" ||
            ProcessInfo.processInfo.arguments.contains("--kitchenlink-scanner-benchmark") ||
            Bundle.main.url(forResource: "RunScannerBenchmark", withExtension: "flag") != nil
        try XCTSkipUnless(
            benchmarkWasRequested,
            "Run through scripts/run-scanner-benchmark.sh to enable the OCR benchmark."
        )

        let previousLLMSetting = MenuImportService.isLLMEnabled()
        MenuImportService.setLLMEnabled(false)
        defer { MenuImportService.setLLMEnabled(previousLLMSetting) }

        var fixtureSnapshots: [FixtureSnapshot] = []
        for fixture in DemoMenuFixtures.all {
            let images = DemoMenuFixtures.images(for: fixture)
            XCTAssertEqual(images.count, fixture.pageCount)

            let sourceDocument = MenuImportSourceDocument(
                id: "benchmark-source-\(fixture.id)",
                sourceType: .demoFixture,
                sourceTypeDetail: fixture.id,
                pageCount: images.count,
                fingerprint: "fixture:\(fixture.id):v1",
                displayName: fixture.title
            )
            let importResult = try await MenuImportService.benchmarkLocalImport(
                from: images,
                sourceDocument: sourceDocument
            )
            let sections = importResult.sections
            let itemCount = sections.reduce(0) { $0 + $1.items.count }
            let draft = importResult.draft
            let draftEntries = draft.sections.flatMap(\.entries)
            let draftValidation = draft.validate()
            XCTAssertFalse(sections.isEmpty)
            XCTAssertGreaterThan(itemCount, 0)
            XCTAssertTrue(
                draftValidation.isValid,
                "Draft validation failed for \(fixture.id): \(draftValidation.errors)"
            )
            XCTAssertGreaterThanOrEqual(draftEntries.count, itemCount)

            if fixture.id == "lichtburg-berlin" {
                let expectedRecoveredNames = [
                    "Hähnchenbrustfilet „Pfeffer“",
                    "Gegrillte Garnelen",
                    "Gemischter Eisbecher"
                ]
                for expectedName in expectedRecoveredNames {
                    let recovered = draftEntries.first {
                        normalized($0.name.value) == normalized(expectedName)
                    }
                    XCTAssertNotNil(
                        recovered,
                        "Lossless draft did not retain \(expectedName)."
                    )
                    XCTAssertTrue(
                        recovered?.offers.isEmpty == true,
                        "\(expectedName) must stay unpriced until its own OCR price is available."
                    )
                }
            }

            fixtureSnapshots.append(
                FixtureSnapshot(
                    fixtureID: fixture.id,
                    pageCount: images.count,
                    sectionCount: sections.count,
                    itemCount: itemCount,
                    ocrLineCount: importResult.ocrLines.count,
                    diagnostics: MenuImportService.lastImportDiagnostics(),
                    ocrLines: importResult.ocrLines,
                    sections: sections.map { section in
                        SectionSnapshot(
                            title: section.title,
                            confidence: section.importConfidence,
                            items: section.items.map { item in
                                ItemSnapshot(
                                    name: item.name,
                                    priceCents: item.priceCents,
                                    description: item.description,
                                    allergenCodes: item.allergenCodes,
                                    variants: item.variants.map { variant in
                                        VariantSnapshot(
                                            name: variant.name,
                                            priceCents: variant.priceCents,
                                            kind: variant.kind.rawValue
                                        )
                                    }
                                )
                            }
                        )
                    },
                    draftSectionCount: draft.sections.count,
                    draftEntryCount: draftEntries.count,
                    draftValidationIssues: draftValidation.issues,
                    draftSections: draft.sections.map { section in
                        DraftSectionSnapshot(
                            title: section.title.value,
                            entries: section.entries.map { entry in
                                DraftEntrySnapshot(
                                    name: entry.name.value,
                                    pageIndex: entry.name.evidence.pageIndex,
                                    reviewState: entry.reviewState.rawValue,
                                    offers: entry.offers.map { offer in
                                        DraftOfferSnapshot(
                                            priceKind: offer.priceKind.rawValue,
                                            amountCents: offer.amountCents,
                                            deltaCents: offer.deltaCents,
                                            rawPrice: offer.rawPrice,
                                            pageIndex: offer.evidence.pageIndex,
                                            boundingBox: offer.evidence.boundingBox
                                        )
                                    }
                                )
                            }
                        )
                    }
                )
            )
        }

        let report = Report(
            generatedAt: Date(),
            parserMode: "apple-vision-plus-local-rules",
            fixtures: fixtureSnapshots
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let reportData = try encoder.encode(report)
        let reportJSON = try XCTUnwrap(String(data: reportData, encoding: .utf8))
        let reportURL = try XCTUnwrap(
            FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
        ).appendingPathComponent("kitchenlink-scanner-benchmark.json")
        try reportData.write(to: reportURL, options: .atomic)

        let attachment = XCTAttachment(data: reportData, uniformTypeIdentifier: "public.json")
        attachment.name = "kitchenlink-scanner-benchmark.json"
        attachment.lifetime = .keepAlways
        add(attachment)

        print("KITCHENLINK_SCANNER_BENCHMARK_BEGIN")
        print(reportJSON)
        print("Report: \(reportURL.path)")
        print("KITCHENLINK_SCANNER_BENCHMARK_END")
    }

    private func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
            .joined()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
