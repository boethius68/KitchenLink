import CoreGraphics
import Foundation
import Testing
@testable import kitchenlink

/// Every page is recognized twice (contrast-enhanced + plain image). The two
/// passes read the same visual line slightly differently, and the previous
/// exact-text deduplication let those near-duplicates through — the rule parser
/// reported 51 invented entries on the 10-page quality gate, and the extraction
/// provider turned single dishes into two.
///
/// The cases below are taken from a real Vision run over the Prüfküche fixture.
struct MenuImportOCRDeduplicationTests {

    private typealias Line = MenuImportService.OCRLineToken

    private func line(
        _ text: String,
        x: CGFloat,
        y: CGFloat,
        width: CGFloat = 0.30,
        height: CGFloat = 0.020,
        confidence: Double = 0.75,
        method: MenuImportEvidenceMethod = .enhancedOCR,
        page: Int = 0
    ) -> Line {
        Line(
            text: text,
            boundingBox: CGRect(x: x, y: y, width: width, height: height),
            pageIndex: page,
            method: method,
            confidence: confidence
        )
    }

    // MARK: - Collapsing our own double pass

    @Test
    func collapsesBracketConfusionOfTheSameVisualLine() {
        // Observed pair: the code group reads `[A,C,G,J]` once and `IA,C,G,J]`
        // once, at the same position.
        let lines = [
            line("Wiener Schnitzel [A,C,G,J]", x: 0.515, y: 0.180, confidence: 0.82),
            line("Wiener Schnitzel IA,C,G,J]", x: 0.515, y: 0.180, confidence: 0.61, method: .ocr)
        ]

        let collapsed = MenuImportService.collapseDuplicateOCRLines(lines)

        #expect(collapsed.count == 1)
        #expect(collapsed.first?.text == "Wiener Schnitzel [A,C,G,J]")
    }

    @Test
    func collapsesTrailingCodeConfusionIntoOneDish() {
        // Observed pair: `Bunter Marktsalat NJ` / `Bunter Marktsalat WI` — one
        // dish, two readings of the same garbled code group. This pair became
        // two separate dishes in both the rule parser and the model output.
        let lines = [
            line("Bunter Marktsalat NJ", x: 0.055, y: 0.260, confidence: 0.70),
            line("Bunter Marktsalat WI", x: 0.049, y: 0.262, confidence: 0.70, method: .ocr)
        ]

        let collapsed = MenuImportService.collapseDuplicateOCRLines(lines)

        #expect(collapsed.count == 1)
    }

    @Test
    func keepsTheCompleteReadingWhenConfidenceIsEqual() {
        // Observed pair: the plain pass dropped the leading `K` and the trailing
        // `t` of `Kartoffelsalat`.
        let truncated = "<albsschnitzel, Preiselbeeren und Kartoffelsala"
        let complete = "Kalbsschnitzel, Preiselbeeren und Kartoffelsalat"
        let lines = [
            line(truncated, x: 0.522, y: 0.196, confidence: 0.72, method: .ocr),
            line(complete, x: 0.517, y: 0.195, confidence: 0.72)
        ]

        let collapsed = MenuImportService.collapseDuplicateOCRLines(lines)

        #expect(collapsed.count == 1)
        #expect(collapsed.first?.text == complete)
    }

    @Test
    func balancedDelimitersBeatHigherConfidence() {
        // Measured on the gate: Vision is often *confident* about a garbled code
        // group. Keeping that reading cost two dishes entirely, because the
        // parser could no longer split codes from the name.
        let lines = [
            line("Käsespätzle [A,C,G]", x: 0.05, y: 0.40, confidence: 0.55, method: .ocr),
            line("Käsespätzle IA,C,G]", x: 0.05, y: 0.40, confidence: 0.94)
        ]

        let collapsed = MenuImportService.collapseDuplicateOCRLines(lines)

        #expect(collapsed.count == 1)
        #expect(collapsed.first?.text == "Käsespätzle [A,C,G]")
    }

    @Test
    func higherConfidenceDecidesAmongEquallyBalancedReadings() {
        let lines = [
            line("Küstenfisch [D,G]", x: 0.05, y: 0.40, confidence: 0.55, method: .ocr),
            line("Kustenfisch [D,G]", x: 0.05, y: 0.40, confidence: 0.94)
        ]

        let collapsed = MenuImportService.collapseDuplicateOCRLines(lines)

        #expect(collapsed.count == 1)
        #expect(collapsed.first?.confidence == 0.94)
    }

    @Test
    func delimiterBalanceRecognizesTheObservedConfusions() {
        #expect(MenuImportService.hasBalancedDelimiters("Wiener Schnitzel [A,C,G,J]"))
        #expect(!MenuImportService.hasBalancedDelimiters("Wiener Schnitzel IA,C,G,J]"))
        #expect(!MenuImportService.hasBalancedDelimiters("Käsespätzle (A,CG1"))
        #expect(MenuImportService.hasBalancedDelimiters("Portionen: klein (14,90 €) groß (20,90 €)"))
        #expect(MenuImportService.hasBalancedDelimiters("Geröstetes Bauernbrot"))
        // Closing before opening is unbalanced, not merely uneven.
        #expect(!MenuImportService.hasBalancedDelimiters("A,G] Bauernbrot ["))
    }

    @Test
    func collapsesExactDuplicatesWithinASinglePass() {
        let lines = [
            line("Knoblauchgarnelen", x: 0.053, y: 0.222),
            line("Knoblauchgarnelen", x: 0.053, y: 0.222)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 1)
    }

    // MARK: - What must survive

    @Test
    func keepsTwoColumnDishesThatShareABaseline() {
        // The horizontal overlap test is what protects two-column cards: both
        // dishes sit on the same baseline but never share x.
        let lines = [
            line("Geröstetes Bauernbrot", x: 0.053, y: 0.182, width: 0.28),
            line("Geröstetes Bauernbrot", x: 0.515, y: 0.182, width: 0.28)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 2)
    }

    @Test
    func keepsIdenticalPricesInSeparateColumns() {
        let lines = [
            line("12,90 €", x: 0.427, y: 0.222, width: 0.08),
            line("12,90 €", x: 0.891, y: 0.222, width: 0.08)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 2)
    }

    @Test
    func keepsDistinctLinesStackedInTheSameColumn() {
        let lines = [
            line("Knoblauchgarnelen [B,O]", x: 0.053, y: 0.222),
            line("Garnelen aus der Pfanne, Chili und Petersilie", x: 0.053, y: 0.235)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 2)
    }

    @Test
    func keepsSimilarLinesOnDifferentPages() {
        let lines = [
            line("Wiener Schnitzel [A,C,G,J]", x: 0.515, y: 0.180, page: 0),
            line("Wiener Schnitzel IA,C,G,J]", x: 0.515, y: 0.180, page: 1)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 2)
    }

    @Test
    func shortFragmentsRequireAnExactMatch() {
        // `1/3` and `2/3` are page markers, not two readings of one line.
        let lines = [
            line("1/3", x: 0.867, y: 0.089, width: 0.04),
            line("2/3", x: 0.867, y: 0.089, width: 0.04)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 2)
    }

    @Test
    func similarNamesInTheSameBoxAreTreatedAsOneReading() {
        // Documents the deliberate trade-off: `Pizza Salami` / `Pizza Salame`
        // differ by one character in twelve (0.92 similarity), so they collapse
        // when they occupy the SAME box. That is correct — a printed card never
        // stacks two dishes on top of each other, so one box means one line.
        // Two genuinely different dishes always have different boxes, which the
        // stacked and two-column cases above cover.
        let lines = [
            line("Pizza Salami", x: 0.05, y: 0.30),
            line("Pizza Salame", x: 0.05, y: 0.30)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 1)
    }

    @Test
    func similarNamesOnTheirOwnLinesBothSurvive() {
        // The same two names as printed in reality: separate rows.
        let lines = [
            line("Pizza Salami", x: 0.05, y: 0.300),
            line("Pizza Salame", x: 0.05, y: 0.330)
        ]

        #expect(MenuImportService.collapseDuplicateOCRLines(lines).count == 2)
    }

    // MARK: - Similarity metric

    @Test
    func similarityIsOneForEqualStringsAndZeroForEmptyInput() {
        #expect(MenuImportService.ocrTextSimilarity("wiener schnitzel", "wiener schnitzel") == 1)
        #expect(MenuImportService.ocrTextSimilarity("", "wiener") == 0)
    }

    @Test
    func observedConfusionsScoreAboveTheThreshold() {
        let pairs = [
            ("wiener schnitzel a c g j", "wiener schnitzel ia c g j"),
            ("bunter marktsalat nj", "bunter marktsalat wi"),
            ("kalbsschnitzel preiselbeeren und kartoffelsalat",
             "albsschnitzel preiselbeeren und kartoffelsala")
        ]

        for (lhs, rhs) in pairs {
            let similarity = MenuImportService.ocrTextSimilarity(lhs, rhs)
            #expect(
                similarity >= MenuImportService.ocrDuplicateSimilarityThreshold,
                "\(lhs) vs \(rhs) scored \(similarity)"
            )
        }
    }

    @Test
    func unrelatedDishNamesScoreBelowTheThreshold() {
        let similarity = MenuImportService.ocrTextSimilarity(
            "gerostetes bauernbrot",
            "knoblauchgarnelen"
        )

        #expect(similarity < MenuImportService.ocrDuplicateSimilarityThreshold)
    }
}
