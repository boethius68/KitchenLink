import Foundation

struct MenuImportOCRLine: Codable, Equatable, Sendable {
    let text: String
    let pageIndex: Int
    let minX: Double
    let minY: Double
    let midY: Double
    let width: Double
    let height: Double
    let method: MenuImportEvidenceMethod
    let confidence: Double

    init(
        text: String,
        pageIndex: Int,
        minX: Double,
        minY: Double? = nil,
        midY: Double,
        width: Double,
        height: Double,
        method: MenuImportEvidenceMethod = .ocr,
        confidence: Double = 0.75
    ) {
        let minimumExtent = 0.000_001
        let clampedX = min(max(minX, 0), 1 - minimumExtent)
        let resolvedMinY = minY ?? (midY - height / 2)
        let clampedY = min(max(resolvedMinY, 0), 1 - minimumExtent)

        self.text = text
        self.pageIndex = pageIndex
        self.minX = clampedX
        self.minY = clampedY
        self.width = max(minimumExtent, min(width, 1 - clampedX))
        self.height = max(minimumExtent, min(height, 1 - clampedY))
        self.midY = min(max(midY, clampedY), clampedY + self.height)
        self.method = method
        self.confidence = min(max(confidence, 0), 1)
    }

    func evidence(
        method overrideMethod: MenuImportEvidenceMethod? = nil,
        methodDetail: String? = nil,
        reviewState: MenuImportReviewState = .unreviewed,
        isLocated: Bool = true
    ) -> MenuImportEvidence {
        MenuImportEvidence(
            rawText: text,
            pageIndex: pageIndex,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: minX,
                y: minY,
                width: width,
                height: height
            ),
            method: overrideMethod ?? method,
            methodDetail: methodDetail,
            confidence: confidence,
            reviewState: reviewState,
            isLocated: isLocated
        )
    }
}

struct MenuImportUnpricedCandidate: Codable, Equatable, Sendable {
    let sectionID: String?
    let sectionTitle: String?
    let title: String
    let kind: String
    let description: String?
    let allergenCodes: String?
    let titleLine: MenuImportOCRLine
    let descriptionLines: [MenuImportOCRLine]
}

struct MenuImportDraftAdapter {
    func makeDraft(
        sourceDocument: MenuImportSourceDocument,
        legacySections: [MenuSectionData],
        ocrLines: [MenuImportOCRLine],
        unpricedCandidates: [MenuImportUnpricedCandidate]
    ) -> MenuImportDraft {
        let matcher = EvidenceMatcher(lines: ocrLines)
        let legend = mergedLegend(from: legacySections)
        var sectionIndexByLegacyID: [String: Int] = [:]
        var sections: [MenuImportSection] = []

        for (sectionIndex, legacySection) in legacySections.enumerated() {
            let titleLine = matcher.bestTextLine(for: legacySection.title)
            let title = makeText(
                legacySection.title,
                line: titleLine,
                fallbackLines: ocrLines,
                confidence: legacySection.importConfidence,
                detail: "section-title-rule"
            )
            let entries = legacySection.items.enumerated().map { itemIndex, item in
                makeEntry(
                    item,
                    sectionIndex: sectionIndex,
                    itemIndex: itemIndex,
                    matcher: matcher,
                    fallbackLines: ocrLines,
                    legend: legend
                )
            }
            let reviewState: MenuImportReviewState = titleLine == nil || legacySection.importConfidence < 0.7
                ? .needsReview
                : .unreviewed

            sectionIndexByLegacyID[legacySection.id] = sections.count
            sections.append(
                MenuImportSection(
                    id: "draft-section-\(sectionIndex)",
                    title: title,
                    order: sections.count,
                    entries: entries,
                    reviewState: reviewState
                )
            )
        }

        for (candidateIndex, candidate) in unpricedCandidates.enumerated() {
            let targetSectionIndex = resolveSectionIndex(
                for: candidate,
                candidateIndex: candidateIndex,
                sections: &sections,
                sectionIndexByLegacyID: sectionIndexByLegacyID,
                matcher: matcher,
                fallbackLines: ocrLines
            )
            let normalizedCandidate = Self.normalized(candidate.title)
            let alreadyRepresented = sections.lazy.flatMap(\.entries).contains {
                Self.normalized($0.name.value) == normalizedCandidate &&
                    $0.name.evidence.pageIndex == candidate.titleLine.pageIndex
            }
            guard !alreadyRepresented else { continue }

            let descriptionText = makeCandidateDescription(candidate)
            let declarations = makeDeclarations(
                codes: candidate.allergenCodes,
                legend: legend,
                idPrefix: "draft-unpriced-\(candidateIndex)",
                fallbackEvidence: candidate.titleLine.evidence(reviewState: .needsReview)
            )
            let entry = MenuImportEntry(
                id: "draft-unpriced-entry-\(candidateIndex)",
                kind: candidate.kind,
                name: MenuImportText(
                    value: candidate.title,
                    languageTag: "de",
                    evidence: candidate.titleLine.evidence(
                        methodDetail: "local-rule-unpriced-candidate",
                        reviewState: .needsReview
                    )
                ),
                description: descriptionText,
                order: sections[targetSectionIndex].entries.count,
                offers: [],
                declarations: declarations,
                reviewState: .needsReview
            )
            sections[targetSectionIndex].entries.append(entry)
            sections[targetSectionIndex].reviewState = .needsReview
        }

        for index in sections.indices {
            sections[index].order = index
            for entryIndex in sections[index].entries.indices {
                sections[index].entries[entryIndex].order = entryIndex
            }
        }

        return MenuImportDraft(
            id: "draft-\(sourceDocument.id)",
            sourceDocument: sourceDocument,
            sections: sections,
            declarations: makeDocumentDeclarations(
                legend: legend,
                matcher: matcher,
                fallbackLines: ocrLines
            ),
            reviewState: .needsReview
        )
    }

    private func makeEntry(
        _ item: MenuItemData,
        sectionIndex: Int,
        itemIndex: Int,
        matcher: EvidenceMatcher,
        fallbackLines: [MenuImportOCRLine],
        legend: [String: String]
    ) -> MenuImportEntry {
        let idPrefix = "draft-entry-\(sectionIndex)-\(itemIndex)"
        let nameLine = matcher.bestTextLine(for: item.name)
        let name = makeText(
            item.name,
            line: nameLine,
            fallbackLines: fallbackLines,
            confidence: nil,
            detail: "legacy-item-name"
        )
        let description = makeDescription(
            item.description,
            preferredPage: nameLine?.pageIndex,
            matcher: matcher,
            fallbackLine: nameLine,
            fallbackLines: fallbackLines
        )
        let offer = makeOffer(
            cents: item.priceCents,
            id: "\(idPrefix)-offer",
            kind: .fixed,
            matcher: matcher,
            near: nameLine,
            fallbackLines: fallbackLines
        )
        let optionGroups = makeOptionGroups(
            item.variants,
            idPrefix: idPrefix,
            matcher: matcher,
            near: nameLine,
            fallbackLines: fallbackLines
        )
        let declarations = makeDeclarations(
            codes: item.resolvedAllergenCodes,
            legend: legend,
            idPrefix: idPrefix,
            fallbackEvidence: name.evidence
        )
        let needsReview = nameLine == nil || offer.evidence.method == .layoutRule

        return MenuImportEntry(
            id: idPrefix,
            kind: item.kind.rawValue,
            name: name,
            description: description,
            order: itemIndex,
            offers: [offer],
            optionGroups: optionGroups,
            declarations: declarations,
            reviewState: needsReview ? .needsReview : .unreviewed
        )
    }

    private func makeOptionGroups(
        _ variants: [MenuItemVariant],
        idPrefix: String,
        matcher: EvidenceMatcher,
        near itemLine: MenuImportOCRLine?,
        fallbackLines: [MenuImportOCRLine]
    ) -> [MenuImportOptionGroup] {
        let orderedKinds: [MenuItemOptionKind] = [.variant, .portion, .extra]
        var groups: [MenuImportOptionGroup] = []

        for kind in orderedKinds {
            let matchingVariants = variants.filter { $0.kind == kind }
            guard !matchingVariants.isEmpty else { continue }
            let groupIndex = groups.count
            let groupPrefix = "\(idPrefix)-group-\(groupIndex)"
            let firstLine = matcher.bestTextLine(
                for: matchingVariants[0].name,
                preferredPage: itemLine?.pageIndex
            )
            let groupTitle: String
            switch kind {
            case .variant: groupTitle = "Varianten"
            case .portion: groupTitle = "Portionen"
            case .extra: groupTitle = "Extras"
            }
            let title = makeText(
                groupTitle,
                line: firstLine,
                fallbackLines: fallbackLines,
                confidence: 0.65,
                detail: "legacy-option-kind",
                isLocated: false
            )
            let choices = matchingVariants.enumerated().map { choiceIndex, variant in
                let choiceLine = matcher.bestTextLine(
                    for: variant.name,
                    preferredPage: itemLine?.pageIndex
                )
                let choicePrefix = "\(groupPrefix)-choice-\(choiceIndex)"
                let priceKind: MenuImportPriceKind = kind == .extra ? .delta : .fixed
                let offer = makeOffer(
                    cents: variant.priceCents,
                    id: "\(choicePrefix)-offer",
                    kind: priceKind,
                    matcher: matcher,
                    near: choiceLine ?? itemLine,
                    fallbackLines: fallbackLines
                )
                return MenuImportChoice(
                    id: choicePrefix,
                    name: makeText(
                        variant.name,
                        line: choiceLine,
                        fallbackLines: fallbackLines,
                        confidence: nil,
                        detail: "legacy-option-name"
                    ),
                    kind: kind.rawValue,
                    order: choiceIndex,
                    offers: [offer],
                    reviewState: .needsReview
                )
            }

            groups.append(
                MenuImportOptionGroup(
                    id: groupPrefix,
                    title: title,
                    order: groupIndex,
                    selectionRule: MenuImportSelectionRule(mode: "unknown"),
                    choices: choices,
                    reviewState: .needsReview
                )
            )
        }
        return groups
    }

    private func makeOffer(
        cents: Int,
        id: String,
        kind: MenuImportPriceKind,
        matcher: EvidenceMatcher,
        near line: MenuImportOCRLine?,
        fallbackLines: [MenuImportOCRLine]
    ) -> MenuImportOffer {
        if let match = matcher.bestPriceLine(cents: cents, near: line) {
            return MenuImportOffer(
                id: id,
                priceKind: kind,
                amountCents: kind == .fixed ? cents : nil,
                deltaCents: kind == .delta ? cents : nil,
                currencyCode: "EUR",
                rawPrice: match.rawPrice,
                basis: "per_item",
                evidence: match.line.evidence(methodDetail: "local-rule-price")
            )
        }

        let formatted = Self.formattedPrice(cents)
        let fallback = fallbackEvidence(
            text: formatted,
            preferredLine: line,
            fallbackLines: fallbackLines,
            confidence: 0.35,
            detail: "legacy-price-without-matched-ocr-line",
            preferredLineShowsValue: false
        )
        return MenuImportOffer(
            id: id,
            priceKind: kind,
            amountCents: kind == .fixed ? cents : nil,
            deltaCents: kind == .delta ? cents : nil,
            currencyCode: "EUR",
            rawPrice: formatted,
            basis: "per_item",
            evidence: fallback
        )
    }

    private func makeDescription(
        _ value: String,
        preferredPage: Int?,
        matcher: EvidenceMatcher,
        fallbackLine: MenuImportOCRLine?,
        fallbackLines: [MenuImportOCRLine]
    ) -> MenuImportText? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != "Automatisch importiert",
              trimmed != "Ohne Beschreibung" else {
            return nil
        }

        let line = matcher.bestTextLine(for: trimmed, preferredPage: preferredPage)
        return makeText(
            trimmed,
            line: line ?? fallbackLine,
            fallbackLines: fallbackLines,
            confidence: line == nil ? 0.45 : nil,
            detail: line == nil ? "combined-legacy-description" : "legacy-description",
            isLocated: line != nil
        )
    }

    private func makeCandidateDescription(
        _ candidate: MenuImportUnpricedCandidate
    ) -> MenuImportText? {
        guard let description = candidate.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else {
            return nil
        }

        let pageLines = candidate.descriptionLines.filter {
            $0.pageIndex == candidate.titleLine.pageIndex
        }
        guard let first = pageLines.first else {
            return MenuImportText(
                value: description,
                languageTag: "de",
                evidence: candidate.titleLine.evidence(
                    method: .layoutRule,
                    methodDetail: "unpriced-description-without-own-line",
                    reviewState: .needsReview,
                    isLocated: false
                )
            )
        }

        let minX = pageLines.map(\.minX).min() ?? first.minX
        let minY = pageLines.map(\.minY).min() ?? first.minY
        let maxX = pageLines.map { $0.minX + $0.width }.max() ?? (first.minX + first.width)
        let maxY = pageLines.map { $0.minY + $0.height }.max() ?? (first.minY + first.height)
        let combinedLine = MenuImportOCRLine(
            text: pageLines.map(\.text).joined(separator: " "),
            pageIndex: first.pageIndex,
            minX: minX,
            minY: minY,
            midY: (minY + maxY) / 2,
            width: maxX - minX,
            height: maxY - minY,
            method: .layoutRule,
            confidence: pageLines.map(\.confidence).min() ?? first.confidence
        )
        return MenuImportText(
            value: description,
            languageTag: "de",
            evidence: combinedLine.evidence(
                methodDetail: "combined-unpriced-description",
                reviewState: .needsReview
            )
        )
    }

    private func resolveSectionIndex(
        for candidate: MenuImportUnpricedCandidate,
        candidateIndex: Int,
        sections: inout [MenuImportSection],
        sectionIndexByLegacyID: [String: Int],
        matcher: EvidenceMatcher,
        fallbackLines: [MenuImportOCRLine]
    ) -> Int {
        if let sectionID = candidate.sectionID,
           let sectionIndex = sectionIndexByLegacyID[sectionID],
           sections.indices.contains(sectionIndex) {
            return sectionIndex
        }

        if let sectionTitle = candidate.sectionTitle {
            let key = Self.normalized(sectionTitle)
            if let index = sections.firstIndex(where: { Self.normalized($0.title.value) == key }) {
                return index
            }
        }

        let sectionTitle = candidate.sectionTitle ?? (candidate.kind == MenuItemKind.drink.rawValue
            ? "Getraenke (Import)"
            : "Speisen (Import)")
        let titleLine = matcher.bestTextLine(
            for: sectionTitle,
            preferredPage: candidate.titleLine.pageIndex
        )
        sections.append(
            MenuImportSection(
                id: "draft-unpriced-section-\(candidateIndex)",
                title: makeText(
                    sectionTitle,
                    line: titleLine ?? candidate.titleLine,
                    fallbackLines: fallbackLines,
                    confidence: titleLine == nil ? 0.5 : nil,
                    detail: titleLine == nil ? "section-inferred-from-parser-context" : "section-title-rule",
                    isLocated: titleLine != nil
                ),
                order: sections.count,
                entries: [],
                reviewState: .needsReview
            )
        )
        return sections.indices.last!
    }

    private func makeDocumentDeclarations(
        legend: [String: String],
        matcher: EvidenceMatcher,
        fallbackLines: [MenuImportOCRLine]
    ) -> [MenuImportDeclaration] {
        legend.keys.sorted().enumerated().compactMap { index, code in
            let title = legend[code] ?? code
            let rawText = "\(code) \(title)"
            let line = matcher.bestTextLine(for: rawText) ?? matcher.bestTextLine(for: title)
            guard let line else { return nil }
            return MenuImportDeclaration(
                id: "draft-document-declaration-\(index)",
                kind: "source_declaration",
                rawText: rawText,
                localCode: code,
                canonicalID: nil,
                claim: "unknown",
                scope: "document",
                evidence: fallbackEvidence(
                    text: rawText,
                    preferredLine: line,
                    fallbackLines: fallbackLines,
                    confidence: nil,
                    detail: "legend-entry"
                )
            )
        }
    }

    private func makeDeclarations(
        codes: String?,
        legend: [String: String],
        idPrefix: String,
        fallbackEvidence: MenuImportEvidence
    ) -> [MenuImportDeclaration] {
        Self.allergenTokens(from: codes).enumerated().map { index, code in
            MenuImportDeclaration(
                id: "\(idPrefix)-declaration-\(index)",
                kind: "source_declaration",
                rawText: legend[code].map { "\(code) \($0)" } ?? code,
                localCode: code,
                canonicalID: nil,
                claim: "declared",
                scope: "entry",
                evidence: fallbackEvidence
            )
        }
    }

    private func makeText(
        _ value: String,
        line: MenuImportOCRLine?,
        fallbackLines: [MenuImportOCRLine],
        confidence: Double?,
        detail: String,
        isLocated: Bool = true
    ) -> MenuImportText {
        MenuImportText(
            value: value,
            languageTag: "de",
            evidence: fallbackEvidence(
                text: value,
                preferredLine: line,
                fallbackLines: fallbackLines,
                confidence: confidence,
                detail: detail,
                preferredLineShowsValue: isLocated
            )
        )
    }

    private func fallbackEvidence(
        text: String,
        preferredLine: MenuImportOCRLine?,
        fallbackLines: [MenuImportOCRLine],
        confidence: Double?,
        detail: String,
        preferredLineShowsValue: Bool = true
    ) -> MenuImportEvidence {
        if let preferredLine {
            var evidence = preferredLine.evidence(
                method: confidence == nil ? nil : .layoutRule,
                methodDetail: detail,
                reviewState: confidence == nil ? .unreviewed : .needsReview,
                isLocated: preferredLineShowsValue
            )
            if let confidence {
                evidence.confidence = min(max(confidence, 0), 1)
            }
            return evidence
        }

        if let fallback = fallbackLines.first {
            var evidence = fallback.evidence(
                method: .layoutRule,
                methodDetail: detail,
                reviewState: .needsReview,
                isLocated: false
            )
            evidence.confidence = min(max(confidence ?? 0.35, 0), 1)
            return evidence
        }

        return MenuImportEvidence(
            rawText: text,
            pageIndex: 0,
            boundingBox: MenuImportNormalizedBoundingBox(
                x: 0,
                y: 0,
                width: 0.000_001,
                height: 0.000_001
            ),
            method: .layoutRule,
            methodDetail: detail,
            confidence: min(max(confidence ?? 0, 0), 1),
            reviewState: .needsReview,
            isLocated: false
        )
    }

    private func mergedLegend(from sections: [MenuSectionData]) -> [String: String] {
        var result: [String: String] = [:]
        for section in sections {
            for (code, title) in section.allergenLegend ?? [:] where result[code] == nil {
                result[code] = title
            }
        }
        return result
    }

    private static func allergenTokens(from value: String?) -> [String] {
        guard let value else { return [] }
        var seen: Set<String> = []
        return value
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0).inserted }
    }

    fileprivate static func normalized(_ value: String) -> String {
        let folded = value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
        return folded.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? String($0) : " " }
            .joined()
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func formattedPrice(_ cents: Int) -> String {
        String(format: "%.2f", Double(cents) / 100)
            .replacingOccurrences(of: ".", with: ",")
    }
}

private struct EvidenceMatcher {
    struct PriceMatch {
        let line: MenuImportOCRLine
        let rawPrice: String
    }

    let lines: [MenuImportOCRLine]

    func bestTextLine(for value: String, preferredPage: Int? = nil) -> MenuImportOCRLine? {
        lines
            .map { line in
                var score = textScore(expected: value, actual: line.text)
                if let preferredPage, line.pageIndex == preferredPage {
                    score += 0.04
                }
                return (line, score)
            }
            .filter { $0.1 >= 0.66 }
            .max { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 < rhs.1 }
                if lhs.0.pageIndex != rhs.0.pageIndex { return lhs.0.pageIndex > rhs.0.pageIndex }
                return lhs.0.midY < rhs.0.midY
            }?
            .0
    }

    func bestPriceLine(cents: Int, near reference: MenuImportOCRLine?) -> PriceMatch? {
        var candidates: [(PriceMatch, Double)] = []
        for line in lines {
            for extracted in extractedPrices(from: line.text) where extracted.cents == cents {
                var score = 1.0
                if let reference {
                    if line == reference { score += 100 }
                    if line.pageIndex == reference.pageIndex {
                        score += 30
                        let rowDistance = abs(line.midY - reference.midY)
                        score += max(0, 40 - rowDistance * 1_000)
                    }
                }
                candidates.append((PriceMatch(line: line, rawPrice: extracted.raw), score))
            }
        }
        return candidates.max { $0.1 < $1.1 }?.0
    }

    private func textScore(expected: String, actual: String) -> Double {
        let expectedValue = MenuImportDraftAdapter.normalized(expected)
        let actualValue = MenuImportDraftAdapter.normalized(actual)
        guard !expectedValue.isEmpty, !actualValue.isEmpty else { return 0 }
        if expectedValue == actualValue { return 1 }
        if actualValue.contains(expectedValue) { return 0.96 }
        if expectedValue.contains(actualValue), actualValue.count >= 5 { return 0.82 }

        let expectedTokens = Set(expectedValue.split(separator: " ").map(String.init))
        let actualTokens = Set(actualValue.split(separator: " ").map(String.init))
        guard !expectedTokens.isEmpty else { return 0 }
        let overlap = expectedTokens.intersection(actualTokens).count
        let recall = Double(overlap) / Double(expectedTokens.count)
        let precision = Double(overlap) / Double(max(actualTokens.count, 1))
        return recall * 0.7 + precision * 0.3
    }

    private func extractedPrices(from value: String) -> [(raw: String, cents: Int)] {
        guard let regex = try? NSRegularExpression(pattern: #"(?<!\d)(\d{1,3})[,.](\d{2})(?!\d)"#) else {
            return []
        }
        let range = NSRange(value.startIndex..., in: value)
        return regex.matches(in: value, range: range).compactMap { match in
            guard let rawRange = Range(match.range(at: 0), in: value),
                  let eurosRange = Range(match.range(at: 1), in: value),
                  let centsRange = Range(match.range(at: 2), in: value),
                  let euros = Int(value[eurosRange]),
                  let cents = Int(value[centsRange]) else {
                return nil
            }
            return (String(value[rawRange]), euros * 100 + cents)
        }
    }
}
