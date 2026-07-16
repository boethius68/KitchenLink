#!/usr/bin/env swift

import Foundation

struct GoldBaseline: Decodable {
    let fixtures: [GoldFixture]
}

struct GoldFixture: Decodable {
    let id: String
    let expectedSectionAnchors: [SectionAnchor]
    let expectedItemAnchors: [ItemAnchor]
}

struct SectionAnchor: Decodable {
    let page: Int
    let exactTitle: String
}

struct ItemAnchor: Decodable {
    let page: Int
    let exactName: String
    let expectedPriceCents: Int?
}

struct ActualReport: Decodable {
    let generatedAt: Date
    let parserMode: String
    let fixtures: [ActualFixture]
}

struct ActualFixture: Decodable {
    let fixtureID: String
    let pageCount: Int
    let ocrLineCount: Int
    let sections: [ActualSection]
    let ocrLines: [OCRLine]
    let draftSections: [ActualDraftSection]
}

struct ActualSection: Decodable {
    let title: String
    let items: [ActualItem]
}

struct ActualItem: Decodable {
    let name: String
    let priceCents: Int
}

struct ActualDraftSection: Decodable {
    let title: String
    let entries: [ActualDraftItem]
}

struct ActualDraftItem: Decodable {
    let name: String
    let pageIndex: Int
    let offers: [ActualDraftOffer]
}

struct ActualDraftOffer: Decodable {
    let amountCents: Int?
    let deltaCents: Int?
    let pageIndex: Int
}

struct OCRLine: Decodable {
    let text: String
    let pageIndex: Int
}

struct ThresholdFile: Decodable {
    let fixtures: [FixtureThreshold]
}

struct FixtureThreshold: Decodable {
    let id: String
    let minimumSectionRecall: Double
    let minimumItemNameRecall: Double
    let minimumItemPriceRecall: Double
}

struct EvaluationReport: Encodable {
    let evaluatedAt: Date
    let sourceGeneratedAt: Date
    let parserMode: String
    let passed: Bool
    let fixtures: [FixtureEvaluation]
}

struct FixtureEvaluation: Encodable {
    let fixtureID: String
    let passed: Bool
    let sectionRecall: Double
    let itemNameRecall: Double
    let itemPriceRecall: Double
    let ocrItemRecall: Double
    let draftItemNameRecall: Double
    let draftItemPriceRecall: Double
    let sectionMatches: Int
    let sectionAnchorCount: Int
    let itemNameMatches: Int
    let itemPriceMatches: Int
    let itemAnchorCount: Int
    let ocrItemMatches: Int
    let draftItemNameMatches: Int
    let draftItemPriceMatches: Int
    let parserMisses: [AnchorFailure]
    let ocrMisses: [AnchorFailure]
    let priceMismatches: [AnchorFailure]
    let draftParserMisses: [AnchorFailure]
    let draftPriceMismatches: [AnchorFailure]
    let draftRecoveredWithoutPrice: [AnchorFailure]
    let draftUnpricedItems: [String]
    let missingSections: [String]
    let suspiciousItems: [String]
    let thresholds: FixtureThresholdSummary
}

struct AnchorFailure: Encodable {
    let page: Int
    let expected: String
    let expectedPriceCents: Int?
    let matchedActual: String?
    let actualPriceCents: Int?
}

struct FixtureThresholdSummary: Encodable {
    let minimumSectionRecall: Double
    let minimumItemNameRecall: Double
    let minimumItemPriceRecall: Double
}

enum EvaluationError: Error, CustomStringConvertible {
    case usage
    case missingFixture(String)

    var description: String {
        switch self {
        case .usage:
            return "Usage: evaluate-scanner-benchmark.swift <gold.json> <actual.json> <thresholds.json>"
        case let .missingFixture(id):
            return "Actual benchmark report is missing fixture: \(id)"
        }
    }
}

func decode<T: Decodable>(_ type: T.Type, from path: String) throws -> T {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return try decoder.decode(type, from: data)
}

func normalized(_ value: String) -> String {
    let folded = value
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
        .lowercased()

    let scalars = folded.unicodeScalars.map { scalar -> String in
        CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : " "
    }
    return scalars
        .joined()
        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        .trimmingCharacters(in: .whitespacesAndNewlines)
}

func matchScore(expected: String, actual: String) -> Double {
    let expectedNormalized = normalized(expected)
    let actualNormalized = normalized(actual)
    guard !expectedNormalized.isEmpty, !actualNormalized.isEmpty else { return 0 }
    if expectedNormalized == actualNormalized { return 1 }
    if expectedNormalized.contains(actualNormalized) || actualNormalized.contains(expectedNormalized) {
        let shorter = min(expectedNormalized.count, actualNormalized.count)
        if shorter >= 5 {
            return 0.95
        }
    }

    let expectedTokens = Set(expectedNormalized.split(separator: " ").map(String.init))
    let actualTokens = Set(actualNormalized.split(separator: " ").map(String.init))
    guard !expectedTokens.isEmpty else { return 0 }
    let overlap = expectedTokens.intersection(actualTokens).count
    return Double(overlap) / Double(expectedTokens.count)
}

func bestItemMatch(for expected: String, in items: [ActualItem]) -> ActualItem? {
    items
        .map { ($0, matchScore(expected: expected, actual: $0.name)) }
        .filter { $0.1 >= 0.75 }
        .max { $0.1 < $1.1 }?
        .0
}

func bestDraftItemMatch(
    for expected: String,
    expectedPageIndex: Int,
    expectedPriceCents: Int?,
    in items: [ActualDraftItem]
) -> ActualDraftItem? {
    items
        .map { item in
            var score = matchScore(expected: expected, actual: item.name)
            if item.pageIndex == expectedPageIndex {
                score += 0.04
            }
            if let expectedPriceCents,
               item.offers.contains(where: {
                   $0.amountCents == expectedPriceCents && $0.pageIndex == expectedPageIndex
               }) {
                score += 0.05
            }
            return (item, score)
        }
        .filter { $0.1 >= 0.75 }
        .max { $0.1 < $1.1 }?
        .0
}

func recall(_ matches: Int, _ total: Int) -> Double {
    total == 0 ? 1 : Double(matches) / Double(total)
}

func isSuspiciousItemName(_ name: String) -> Bool {
    let value = normalized(name)
    let prefixes = ["als ", "auf wunsch ", "pro person", "per person"]
    return name.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") ||
        prefixes.contains { value.hasPrefix($0) }
}

func evaluate() throws -> EvaluationReport {
    guard CommandLine.arguments.count == 4 else { throw EvaluationError.usage }
    let gold = try decode(GoldBaseline.self, from: CommandLine.arguments[1])
    let actual = try decode(ActualReport.self, from: CommandLine.arguments[2])
    let thresholds = try decode(ThresholdFile.self, from: CommandLine.arguments[3])
    let thresholdByID = Dictionary(uniqueKeysWithValues: thresholds.fixtures.map { ($0.id, $0) })
    let actualByID = Dictionary(uniqueKeysWithValues: actual.fixtures.map { ($0.fixtureID, $0) })

    let fixtureEvaluations = try gold.fixtures.map { goldFixture -> FixtureEvaluation in
        guard let actualFixture = actualByID[goldFixture.id] else {
            throw EvaluationError.missingFixture(goldFixture.id)
        }
        let threshold = thresholdByID[goldFixture.id] ?? FixtureThreshold(
            id: goldFixture.id,
            minimumSectionRecall: 0,
            minimumItemNameRecall: 0,
            minimumItemPriceRecall: 0
        )

        let sectionTitles = actualFixture.sections.map(\.title)
        let missingSections = goldFixture.expectedSectionAnchors.compactMap { anchor -> String? in
            let found = sectionTitles.contains { matchScore(expected: anchor.exactTitle, actual: $0) >= 0.75 }
            return found ? nil : "p\(anchor.page): \(anchor.exactTitle)"
        }
        let sectionMatches = goldFixture.expectedSectionAnchors.count - missingSections.count

        let items = actualFixture.sections.flatMap(\.items)
        let draftItems = actualFixture.draftSections.flatMap(\.entries)
        let pageOCR = Dictionary(grouping: actualFixture.ocrLines, by: \.pageIndex)
            .mapValues { $0.map(\.text).joined(separator: " ") }

        var parserMisses: [AnchorFailure] = []
        var ocrMisses: [AnchorFailure] = []
        var priceMismatches: [AnchorFailure] = []
        var draftParserMisses: [AnchorFailure] = []
        var draftPriceMismatches: [AnchorFailure] = []
        var draftRecoveredWithoutPrice: [AnchorFailure] = []
        var itemNameMatches = 0
        var itemPriceMatches = 0
        var ocrItemMatches = 0
        var draftItemNameMatches = 0
        var draftItemPriceMatches = 0

        for anchor in goldFixture.expectedItemAnchors {
            let ocrText = pageOCR[anchor.page - 1] ?? ""
            let wasReadByOCR = matchScore(expected: anchor.exactName, actual: ocrText) >= 0.75
            if wasReadByOCR { ocrItemMatches += 1 }

            if let item = bestItemMatch(for: anchor.exactName, in: items) {
                itemNameMatches += 1
                if anchor.expectedPriceCents == nil || anchor.expectedPriceCents == item.priceCents {
                    itemPriceMatches += 1
                } else {
                    priceMismatches.append(
                        AnchorFailure(
                            page: anchor.page,
                            expected: anchor.exactName,
                            expectedPriceCents: anchor.expectedPriceCents,
                            matchedActual: item.name,
                            actualPriceCents: item.priceCents
                        )
                    )
                }
            } else {
                let failure = AnchorFailure(
                    page: anchor.page,
                    expected: anchor.exactName,
                    expectedPriceCents: anchor.expectedPriceCents,
                    matchedActual: nil,
                    actualPriceCents: nil
                )
                if wasReadByOCR {
                    parserMisses.append(failure)
                } else {
                    ocrMisses.append(failure)
                }
            }

            if let draftItem = bestDraftItemMatch(
                for: anchor.exactName,
                expectedPageIndex: anchor.page - 1,
                expectedPriceCents: anchor.expectedPriceCents,
                in: draftItems
            ) {
                draftItemNameMatches += 1
                let offerOnExpectedPage = draftItem.offers.first {
                    $0.pageIndex == anchor.page - 1 && $0.amountCents != nil
                }
                let actualPrice = offerOnExpectedPage?.amountCents ?? draftItem.offers.compactMap(\.amountCents).first
                let priceMatches = anchor.expectedPriceCents == nil || draftItem.offers.contains {
                    $0.pageIndex == anchor.page - 1 && $0.amountCents == anchor.expectedPriceCents
                }
                if priceMatches {
                    draftItemPriceMatches += 1
                } else {
                    let failure = AnchorFailure(
                        page: anchor.page,
                        expected: anchor.exactName,
                        expectedPriceCents: anchor.expectedPriceCents,
                        matchedActual: draftItem.name,
                        actualPriceCents: actualPrice
                    )
                    draftPriceMismatches.append(failure)
                    if draftItem.offers.isEmpty {
                        draftRecoveredWithoutPrice.append(failure)
                    }
                }
            } else if wasReadByOCR {
                draftParserMisses.append(
                    AnchorFailure(
                        page: anchor.page,
                        expected: anchor.exactName,
                        expectedPriceCents: anchor.expectedPriceCents,
                        matchedActual: nil,
                        actualPriceCents: nil
                    )
                )
            }
        }

        let sectionRecall = recall(sectionMatches, goldFixture.expectedSectionAnchors.count)
        let itemNameRecall = recall(itemNameMatches, goldFixture.expectedItemAnchors.count)
        let itemPriceRecall = recall(itemPriceMatches, goldFixture.expectedItemAnchors.count)
        let passesThresholds =
            sectionRecall >= threshold.minimumSectionRecall &&
            itemNameRecall >= threshold.minimumItemNameRecall &&
            itemPriceRecall >= threshold.minimumItemPriceRecall

        return FixtureEvaluation(
            fixtureID: goldFixture.id,
            passed: passesThresholds,
            sectionRecall: sectionRecall,
            itemNameRecall: itemNameRecall,
            itemPriceRecall: itemPriceRecall,
            ocrItemRecall: recall(ocrItemMatches, goldFixture.expectedItemAnchors.count),
            draftItemNameRecall: recall(draftItemNameMatches, goldFixture.expectedItemAnchors.count),
            draftItemPriceRecall: recall(draftItemPriceMatches, goldFixture.expectedItemAnchors.count),
            sectionMatches: sectionMatches,
            sectionAnchorCount: goldFixture.expectedSectionAnchors.count,
            itemNameMatches: itemNameMatches,
            itemPriceMatches: itemPriceMatches,
            itemAnchorCount: goldFixture.expectedItemAnchors.count,
            ocrItemMatches: ocrItemMatches,
            draftItemNameMatches: draftItemNameMatches,
            draftItemPriceMatches: draftItemPriceMatches,
            parserMisses: parserMisses,
            ocrMisses: ocrMisses,
            priceMismatches: priceMismatches,
            draftParserMisses: draftParserMisses,
            draftPriceMismatches: draftPriceMismatches,
            draftRecoveredWithoutPrice: draftRecoveredWithoutPrice,
            draftUnpricedItems: draftItems
                .filter { $0.offers.isEmpty }
                .map(\.name)
                .sorted(),
            missingSections: missingSections,
            suspiciousItems: items.map(\.name).filter(isSuspiciousItemName).sorted(),
            thresholds: FixtureThresholdSummary(
                minimumSectionRecall: threshold.minimumSectionRecall,
                minimumItemNameRecall: threshold.minimumItemNameRecall,
                minimumItemPriceRecall: threshold.minimumItemPriceRecall
            )
        )
    }

    return EvaluationReport(
        evaluatedAt: Date(),
        sourceGeneratedAt: actual.generatedAt,
        parserMode: actual.parserMode,
        passed: fixtureEvaluations.allSatisfy(\.passed),
        fixtures: fixtureEvaluations
    )
}

do {
    let report = try evaluate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    encoder.dateEncodingStrategy = .iso8601
    FileHandle.standardOutput.write(try encoder.encode(report))
    FileHandle.standardOutput.write(Data("\n".utf8))
    if !report.passed {
        exit(1)
    }
} catch {
    FileHandle.standardError.write(Data("Scanner benchmark evaluation failed: \(error)\n".utf8))
    exit(2)
}
