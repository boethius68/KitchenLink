import SwiftUI

/// Product-native preview for an imported menu. This replaces the former jump
/// into the monolithic legacy sandbox and keeps the useful parts of that view:
/// food/drink/total counters, the complete allergen/additive icon language,
/// variants and a small cart simulation.
struct MenuImportGuestPreviewView: View {
    let sections: [MenuSectionData]
    let title: String

    @Environment(\.dismiss) private var dismiss
    @State private var filter: MenuImportPreviewFilter = .all
    @State private var cartLines: [MenuImportCartLine] = []
    @State private var showsSelection = false
    @State private var configurationItem: MenuItemData?

    private var allItems: [MenuItemData] {
        sections.flatMap(\.items)
    }

    private var filteredSections: [MenuSectionData] {
        sections.compactMap { section in
            var copy = section
            copy.items = section.items.filter(filter.includes)
            return copy.items.isEmpty ? nil : copy
        }
    }

    private var totalSelectedCount: Int {
        cartLines.reduce(0) { $0 + $1.quantity }
    }

    private var totalSelectedPrice: Int {
        cartLines.reduce(0) { $0 + $1.lineTotalCents }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KitchenLinkV2Palette.Surface.base
                    .ignoresSafeArea()
                MenuImportPreviewBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                        header
                        countSelector

                        ForEach(filteredSections) { section in
                            sectionCard(section)
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, KitchenLinkV2Spacing.large)
                    .padding(.vertical, KitchenLinkV2Spacing.xLarge)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    if totalSelectedCount > 0 {
                        selectionBar
                    }
                }
            }
            .navigationTitle("Menü testen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .sheet(isPresented: $showsSelection) {
                MenuImportSelectionSheet(
                    items: allItems,
                    cartLines: $cartLines
                )
            }
            .sheet(item: $configurationItem) { item in
                MenuImportConfigurationSheet(item: item) { selectedOptions in
                    add(item, selectedOptions: selectedOptions)
                }
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("GÄSTE-VORSCHAU")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.35)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            Text(title)
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .fixedSize(horizontal: false, vertical: true)

            Text("So sehen Gäste die importierte Karte und stellen ihre Bestellung zusammen.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var countSelector: some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            ForEach(MenuImportPreviewFilter.allCases) { option in
                MenuImportCountButton(
                    title: option.title,
                    systemImage: option.systemImage,
                    count: allItems.filter(option.includes).count,
                    isSelected: filter == option
                ) {
                    filter = option
                }
            }
        }
        .accessibilityIdentifier("menuPreview.countSelector")
    }

    private func sectionCard(_ section: MenuSectionData) -> some View {
        KitchenLinkV2Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Label(section.title, systemImage: section.kind.icon)
                        .font(KitchenLinkV2Typography.section)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                    if !section.subtitle.isEmpty {
                        Text(section.subtitle)
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                }
                .padding(KitchenLinkV2Spacing.large)

                ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                    }
                    itemRow(item, legend: section.allergenLegend)
                        .padding(.horizontal, KitchenLinkV2Spacing.large)
                        .padding(.vertical, KitchenLinkV2Spacing.medium)
                }
            }
        }
    }

    private func itemRow(_ item: MenuItemData, legend: [String: String]?) -> some View {
        let hasDeclarations = !(item.resolvedAllergenCodes?.isEmpty ?? true)
        let itemQuantity = quantity(for: item.id)
        let usesInlineAdd = itemQuantity == 0

        return VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.medium) {
                Text(item.displayName)
                    .font(KitchenLinkV2Typography.menuItemTitle)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .accessibilityIdentifier("menuPreview.itemName.\(item.id)")

                Spacer(minLength: KitchenLinkV2Spacing.small)

                HStack(alignment: .top, spacing: KitchenLinkV2Spacing.xSmall) {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(PriceFormatter.string(cents: item.priceCents))
                            .font(KitchenLinkV2Typography.menuItemPrice)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                            .lineLimit(1)
                            .kitchenLinkV2TabularNumbers()
                            .accessibilityIdentifier("menuPreview.itemPrice.\(item.id)")
                        if item.priceBasis == "per_person" {
                            Text("pro Person")
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        }
                    }

                    if usesInlineAdd {
                        MenuImportCompactQuantityControl(
                            quantity: 0,
                            accessibilityContext: item.displayName,
                            addAccessibilityLabel: item.variants.isEmpty ? "Hinzufügen" : "Auswahl öffnen",
                            addAccessibilityIdentifier: item.variants.isEmpty
                                ? "menuPreview.add.\(item.id)"
                                : "menuPreview.configure.\(item.id)",
                            identifierPrefix: "menuPreview.quantity.\(item.id)",
                            onDecrease: {},
                            onIncrease: {
                                if item.variants.isEmpty {
                                    add(item, selectedOptions: [])
                                } else {
                                    configurationItem = item
                                }
                            }
                        )
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
            }

            // Kennzeichnungen sitzen im Fluss der Beschreibung, nicht in einem
            // eigenen Streifen. Ist keine Beschreibung vorhanden, schliessen die
            // Symbole als kurze Sekundaerzeile an den Namen an.
            let description = descriptionText(for: item)
            if hasDeclarations, let codes = item.resolvedAllergenCodes, !codes.isEmpty {
                AllergenBadgesRow(
                    rawCodes: codes,
                    legendByCode: legend,
                    displayMode: .compact,
                    leadingDescription: description,
                    compactRowIdentifier: "foodDeclaration.row.\(item.id)"
                )
            } else if let description {
                Text(description)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if itemQuantity > 0 {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    if item.variants.isEmpty {
                        MenuImportCompactQuantityControl(
                            quantity: itemQuantity,
                            accessibilityContext: item.displayName,
                            identifierPrefix: "menuPreview.quantity.\(item.id)",
                            onDecrease: { decrease(item.id) },
                            onIncrease: { add(item, selectedOptions: []) }
                        )
                    } else {
                        MenuImportConfigurationControl(
                            itemID: item.id,
                            itemName: item.displayName,
                            quantity: itemQuantity,
                            onDecrease: { decrease(item.id) },
                            onConfigure: { configurationItem = item }
                        )
                    }
                }
            }
        }
    }

    private func descriptionText(for item: MenuItemData) -> String? {
        guard !item.description.isEmpty, item.description != "Automatisch importiert" else {
            return nil
        }
        return item.description
    }

    private var selectionBar: some View {
        Button {
            showsSelection = true
        } label: {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Label("Auswahl ansehen", systemImage: "basket.fill")
                Spacer()
                Text("\(totalSelectedCount) · \(PriceFormatter.string(cents: totalSelectedPrice))")
                    .kitchenLinkV2TabularNumbers()
            }
        }
        .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.vertical, KitchenLinkV2Spacing.small)
        .background(.thinMaterial)
        .accessibilityIdentifier("menuPreview.selection")
    }

    private func quantity(for itemID: String) -> Int {
        cartLines
            .filter { $0.itemID == itemID }
            .reduce(0) { $0 + $1.quantity }
    }

    private func decrease(_ itemID: String) {
        guard let index = cartLines.lastIndex(where: { $0.itemID == itemID }) else { return }
        if cartLines[index].quantity > 1 {
            cartLines[index].quantity -= 1
        } else {
            cartLines.remove(at: index)
        }
    }

    private func add(_ item: MenuItemData, selectedOptions: [MenuItemVariant]) {
        let optionIDs = selectedOptions.map(\.id).sorted()
        let lineID = MenuImportCartLine.id(itemID: item.id, optionIDs: optionIDs)
        if let index = cartLines.firstIndex(where: { $0.id == lineID }) {
            cartLines[index].quantity = min(99, cartLines[index].quantity + 1)
            return
        }

        cartLines.append(
            MenuImportCartLine(
                itemID: item.id,
                optionIDs: optionIDs,
                optionNames: selectedOptions.map(\.name),
                unitPriceCents: MenuImportConfigurationPricing.unitPrice(
                    item: item,
                    selectedOptions: selectedOptions
                ),
                quantity: 1
            )
        )
    }
}

enum MenuImportPreviewFilter: String, CaseIterable, Identifiable {
    case drink
    case food
    case all

    var id: String { rawValue }

    var title: String {
        switch self {
        case .drink: return "Getränke"
        case .food: return "Speisen"
        case .all: return "Gesamt"
        }
    }

    var systemImage: String {
        switch self {
        case .drink: return "cup.and.saucer.fill"
        case .food: return "fork.knife"
        case .all: return "square.grid.2x2.fill"
        }
    }

    func includes(_ item: MenuItemData) -> Bool {
        switch self {
        case .drink: return item.kind == .drink
        case .food: return item.kind == .food
        case .all: return true
        }
    }
}

private struct MenuImportCountButton: View {
    let title: String
    let systemImage: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: KitchenLinkV2Spacing.xSmall) {
                Image(systemName: systemImage)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(count)")
                    .font(KitchenLinkV2Typography.section)
                    .kitchenLinkV2TabularNumbers()
                Text(title)
                    .font(KitchenLinkV2Typography.meta)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? Color.white : KitchenLinkV2Palette.Content.primary)
            .frame(maxWidth: .infinity, minHeight: 76)
            .background(
                isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    .stroke(
                        isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Border.subtle,
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title): \(count)")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct MenuImportQuantityButton: View {
    let systemImage: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let accessibilityIdentifier: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Color.clear

                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
            }
            .frame(
                width: KitchenLinkV2GuestMenuMetrics.minimumTapTarget,
                height: KitchenLinkV2GuestMenuMetrics.minimumTapTarget
            )
            .contentShape(Rectangle())
        }
        .frame(
            width: KitchenLinkV2GuestMenuMetrics.minimumTapTarget,
            height: KitchenLinkV2GuestMenuMetrics.minimumTapTarget
        )
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

struct MenuImportCompactQuantityControl: View {
    let quantity: Int
    var accessibilityContext: String? = nil
    var addAccessibilityLabel: String = "Hinzufügen"
    var addAccessibilityIdentifier: String? = nil
    var canIncrease: Bool = true
    var identifierPrefix: String = "menuPreview.quantity"
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        if quantity == 0 {
            Button(action: onIncrease) {
                ZStack {
                    Color.clear

                    Circle()
                        .fill(KitchenLinkV2Palette.Surface.recessed)
                        .overlay {
                            Circle()
                                .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
                        }
                        .frame(width: 34, height: 34)

                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                }
                .frame(
                    width: KitchenLinkV2GuestMenuMetrics.minimumTapTarget,
                    height: KitchenLinkV2GuestMenuMetrics.minimumTapTarget
                )
                .contentShape(Rectangle())
            }
            .frame(
                width: KitchenLinkV2GuestMenuMetrics.minimumTapTarget,
                height: KitchenLinkV2GuestMenuMetrics.minimumTapTarget
            )
            .buttonStyle(.plain)
            .disabled(!canIncrease)
            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(addAccessibilityLabel)
            .accessibilityHint(accessibilityHint)
            .accessibilityIdentifier(
                addAccessibilityIdentifier ?? "\(identifierPrefix).add"
            )
        } else {
            HStack(spacing: 0) {
                quantityButton(
                    systemImage: "minus",
                    label: "Entfernen",
                    identifierSuffix: "decrease",
                    action: onDecrease
                )
                Text("\(quantity)")
                    .font(KitchenLinkV2Typography.primaryLine)
                    .frame(minWidth: 32)
                    .kitchenLinkV2TabularNumbers()
                    .accessibilityIdentifier("\(identifierPrefix).value")
                quantityButton(
                    systemImage: "plus",
                    label: "Hinzufügen",
                    identifierSuffix: "increase",
                    isDisabled: !canIncrease,
                    action: onIncrease
                )
            }
            .background(
                KitchenLinkV2Palette.Surface.recessed,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                    .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
            }
            .accessibilityElement(children: .contain)
        }
    }

    private func quantityButton(
        systemImage: String,
        label: String,
        identifierSuffix: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        MenuImportQuantityButton(
            systemImage: systemImage,
            accessibilityLabel: label,
            accessibilityHint: accessibilityHint,
            accessibilityIdentifier: "\(identifierPrefix).\(identifierSuffix)",
            isDisabled: isDisabled,
            action: action
        )
    }

    private var accessibilityHint: String {
        guard let accessibilityContext, !accessibilityContext.isEmpty else { return "" }
        return "Ändert die Menge für \(accessibilityContext)"
    }
}

private struct MenuImportConfigurationControl: View {
    let itemID: String
    let itemName: String
    let quantity: Int
    let onDecrease: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            MenuImportQuantityButton(
                systemImage: "minus",
                accessibilityLabel: "Entfernen",
                accessibilityHint: "Verringert die Menge für \(itemName)",
                accessibilityIdentifier: "menuPreview.configure.\(itemID).decrease",
                action: onDecrease
            )

            Text("\(quantity)")
                .font(KitchenLinkV2Typography.primaryLine)
                .frame(minWidth: 28)
                .kitchenLinkV2TabularNumbers()
                .accessibilityIdentifier("menuPreview.configure.\(itemID).value")

            MenuImportQuantityButton(
                systemImage: "plus",
                accessibilityLabel: "Weitere Auswahl hinzufügen",
                accessibilityHint: "Auswahl für \(itemName) öffnen",
                accessibilityIdentifier: "menuPreview.configure.\(itemID).increase",
                action: onConfigure
            )
        }
        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
        .background(
            KitchenLinkV2Palette.Surface.recessed,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
        }
    }
}

private struct MenuImportCartLine: Identifiable, Equatable {
    let id: String
    let itemID: String
    let optionIDs: [String]
    let optionNames: [String]
    let unitPriceCents: Int
    var quantity: Int

    init(
        itemID: String,
        optionIDs: [String],
        optionNames: [String],
        unitPriceCents: Int,
        quantity: Int
    ) {
        self.id = Self.id(itemID: itemID, optionIDs: optionIDs)
        self.itemID = itemID
        self.optionIDs = optionIDs
        self.optionNames = optionNames
        self.unitPriceCents = unitPriceCents
        self.quantity = quantity
    }

    var lineTotalCents: Int {
        unitPriceCents * quantity
    }

    static func id(itemID: String, optionIDs: [String]) -> String {
        ([itemID] + optionIDs.sorted()).joined(separator: "::")
    }
}

private struct MenuImportOptionGroupModel: Identifiable {
    let id: String
    let title: String?
    let minimumSelections: Int
    let maximumSelections: Int
    let selectionMode: String
    let freeSelectionCount: Int
    let allowsRepeats: Bool
    var options: [MenuItemVariant]

    var isSingleSelection: Bool { selectionMode == "single" || maximumSelections == 1 }
}

private enum MenuImportOptionGrouping {
    static func groups(for item: MenuItemData) -> [MenuImportOptionGroupModel] {
        var groups: [MenuImportOptionGroupModel] = []

        for option in item.variants {
            let key = option.groupID ?? (option.kind == .extra ? "legacy-extra" : "legacy-choice")
            if let index = groups.firstIndex(where: { $0.id == key }) {
                groups[index].options.append(option)
                continue
            }

            let groupOptionCount = item.variants.filter { candidate in
                let candidateKey = candidate.groupID
                    ?? (candidate.kind == .extra ? "legacy-extra" : "legacy-choice")
                return candidateKey == key
            }.count
            let selectionMode = normalizedSelectionMode(option.selectionMode, kind: option.kind)
            let fallbackMaximum = selectionMode == "single" ? 1 : max(1, groupOptionCount)
            let maximum = max(1, option.maximumSelections ?? fallbackMaximum)
            groups.append(
                MenuImportOptionGroupModel(
                    id: key,
                    title: guestFacingTitle(option.groupTitle),
                    minimumSelections: max(0, option.minimumSelections ?? 0),
                    maximumSelections: maximum,
                    selectionMode: selectionMode,
                    freeSelectionCount: max(0, option.freeSelectionCount ?? 0),
                    allowsRepeats: option.allowsRepeats ?? false,
                    options: [option]
                )
            )
        }

        return groups
    }

    private static func normalizedSelectionMode(
        _ rawMode: String?,
        kind: MenuItemOptionKind
    ) -> String {
        switch rawMode?.lowercased() {
        case "single": return "single"
        case "multiple": return "multiple"
        case "quantity": return "quantity"
        default: return kind == .extra ? "multiple" : "single"
        }
    }

    private static func guestFacingTitle(_ rawTitle: String?) -> String? {
        guard let title = rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty else { return nil }
        let genericWords: Set<String> = [
            "variante", "varianten", "option", "optionen",
            "extra", "extras", "portion", "portionen"
        ]
        let words = title
            .lowercased()
            .components(separatedBy: CharacterSet.letters.inverted)
            .filter { !$0.isEmpty }
        return !words.isEmpty && words.allSatisfy(genericWords.contains) ? nil : title
    }
}

enum MenuImportConfigurationPricing {
    static func unitPrice(item: MenuItemData, selectedOptions: [MenuItemVariant]) -> Int {
        let fixedPrice = item.variants.first { candidate in
            candidate.priceKind == .fixed && selectedOptions.contains(where: { $0.id == candidate.id })
        }?.priceCents
        let deltas = MenuImportOptionGrouping.groups(for: item).reduce(0) { total, group in
            let groupOptionIDs = Set(group.options.map(\.id))
            let selectedInGroup = selectedOptions.filter { groupOptionIDs.contains($0.id) }
            let deltaPrices = selectedInGroup
                .filter { $0.priceKind == .delta }
                .map(\.priceCents)
                .sorted()
            let includedCount = selectedInGroup.filter {
                $0.priceKind == .included || $0.priceKind == .free
            }.count
            let waivedDeltaCount = group.selectionMode == "single"
                ? 0
                : max(0, group.freeSelectionCount - includedCount)
            return total + deltaPrices
                .dropFirst(min(waivedDeltaCount, deltaPrices.count))
                .reduce(0, +)
        }
        return max(0, (fixedPrice ?? item.priceCents) + deltas)
    }
}

private struct MenuImportConfigurationSheet: View {
    let item: MenuItemData
    let onAdd: ([MenuItemVariant]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedOptionIDs: [String] = []

    private var groups: [MenuImportOptionGroupModel] {
        MenuImportOptionGrouping.groups(for: item)
    }

    private var selectedOptions: [MenuItemVariant] {
        let optionsByID = Dictionary(uniqueKeysWithValues: item.variants.map { ($0.id, $0) })
        return selectedOptionIDs.compactMap { optionsByID[$0] }
    }

    private var canAdd: Bool {
        let fixedSelectionCount = selectedOptions.filter { $0.priceKind == .fixed }.count
        return fixedSelectionCount <= 1 && groups.allSatisfy { group in
            let groupOptionIDs = Set(group.options.map(\.id))
            let selectedInGroup = selectedOptionIDs.filter { groupOptionIDs.contains($0) }
            let hasInvalidRepeat = !group.allowsRepeats
                && Set(selectedInGroup).count != selectedInGroup.count
            return !hasInvalidRepeat
                && selectedInGroup.count >= group.minimumSelections
                && selectedInGroup.count <= group.maximumSelections
        }
    }

    private var unitPriceCents: Int {
        MenuImportConfigurationPricing.unitPrice(item: item, selectedOptions: selectedOptions)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    if !item.description.isEmpty, item.description != "Automatisch importiert" {
                        Text(item.description)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }

                    ForEach(groups) { group in
                        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                            if let title = group.title {
                                Text(title)
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                    .textCase(.uppercase)
                            }

                            if group.selectionMode != "single", group.freeSelectionCount > 0 {
                                Text(
                                    group.freeSelectionCount == 1
                                        ? "1 Auswahl inklusive, danach Aufpreis"
                                        : "\(group.freeSelectionCount) Auswahlen inklusive, danach Aufpreis"
                                )
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }

                            ForEach(group.options) { option in
                                optionButton(option, in: group)
                            }

                            if group.minimumSelections > 0,
                               selectedCount(in: group) < group.minimumSelections {
                                Text("Bitte noch auswählen")
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                            }
                        }
                    }
                }
                .padding(KitchenLinkV2Spacing.large)
            }
            .navigationTitle(item.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(selectedOptions)
                    dismiss()
                } label: {
                    HStack {
                        Text("Hinzufügen")
                        Spacer()
                        Text(PriceFormatter.string(cents: unitPriceCents))
                            .kitchenLinkV2TabularNumbers()
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(!canAdd)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.vertical, KitchenLinkV2Spacing.small)
                .background(.thinMaterial)
                .accessibilityIdentifier("menuPreview.configuration.add")
            }
        }
        .presentationDetents([.medium, .large])
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    @ViewBuilder
    private func optionButton(
        _ option: MenuItemVariant,
        in group: MenuImportOptionGroupModel
    ) -> some View {
        if group.allowsRepeats, !group.isSingleSelection, option.priceKind != .fixed {
            repeatableOptionRow(option, in: group)
        } else {
            let isSelected = selectedOptionIDs.contains(option.id)
            Button {
                toggle(option, in: group)
            } label: {
                HStack(spacing: KitchenLinkV2Spacing.medium) {
                    Image(systemName: selectionIcon(isSelected: isSelected, single: group.isSingleSelection))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Content.muted)
                        .accessibilityHidden(true)

                    Text(option.name)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: KitchenLinkV2Spacing.small)

                    Text(optionPrice(option, in: group))
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .kitchenLinkV2TabularNumbers()
                }
                .frame(minHeight: 44)
                .padding(.horizontal, KitchenLinkV2Spacing.medium)
                .background(
                    isSelected
                        ? KitchenLinkV2Palette.Brand.grape.opacity(0.08)
                        : KitchenLinkV2Palette.Surface.raised,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                        .stroke(
                            isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Border.subtle,
                            lineWidth: 1
                        )
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(option.name), \(optionPrice(option, in: group))")
            .accessibilityValue(isSelected ? "Ausgewählt" : "Nicht ausgewählt")
            .accessibilityAddTraits(isSelected ? .isSelected : [])
            .accessibilityIdentifier("menuPreview.configuration.option.\(option.id)")
        }
    }

    private func repeatableOptionRow(
        _ option: MenuItemVariant,
        in group: MenuImportOptionGroupModel
    ) -> some View {
        let count = selectedOptionIDs.filter { $0 == option.id }.count
        return HStack(spacing: KitchenLinkV2Spacing.medium) {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Text(option.name)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: KitchenLinkV2Spacing.small)

                Text(optionPrice(option, in: group))
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .kitchenLinkV2TabularNumbers()
            }

            MenuImportCompactQuantityControl(
                quantity: count,
                accessibilityContext: option.name,
                canIncrease: selectedCount(in: group) < group.maximumSelections,
                identifierPrefix: "menuPreview.configuration.quantity.\(option.id)",
                onDecrease: { changeRepeatCount(for: option, in: group, delta: -1) },
                onIncrease: { changeRepeatCount(for: option, in: group, delta: 1) }
            )
        }
        .frame(minHeight: 44)
        .padding(.leading, KitchenLinkV2Spacing.medium)
        .background(
            count > 0
                ? KitchenLinkV2Palette.Brand.grape.opacity(0.08)
                : KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                .stroke(
                    count > 0 ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Border.subtle,
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("menuPreview.configuration.option.\(option.id)")
    }

    private func toggle(_ option: MenuItemVariant, in group: MenuImportOptionGroupModel) {
        if selectedOptionIDs.contains(option.id) {
            if !group.isSingleSelection || group.minimumSelections == 0 {
                selectedOptionIDs.removeAll { $0 == option.id }
            }
            return
        }

        if option.priceKind == .fixed {
            let otherFixedIDs = Set(
                item.variants
                    .filter { $0.id != option.id && $0.priceKind == .fixed }
                    .map(\.id)
            )
            selectedOptionIDs.removeAll { otherFixedIDs.contains($0) }
        }

        if group.isSingleSelection {
            let siblingIDs = Set(group.options.map(\.id))
            selectedOptionIDs.removeAll { siblingIDs.contains($0) }
            selectedOptionIDs.append(option.id)
        } else if selectedCount(in: group) < group.maximumSelections {
            selectedOptionIDs.append(option.id)
        }
    }

    private func changeRepeatCount(
        for option: MenuItemVariant,
        in group: MenuImportOptionGroupModel,
        delta: Int
    ) {
        if delta < 0 {
            guard let index = selectedOptionIDs.lastIndex(of: option.id) else { return }
            selectedOptionIDs.remove(at: index)
        } else if selectedCount(in: group) < group.maximumSelections {
            selectedOptionIDs.append(option.id)
        }
    }

    private func selectedCount(in group: MenuImportOptionGroupModel) -> Int {
        let groupOptionIDs = Set(group.options.map(\.id))
        return selectedOptionIDs.filter { groupOptionIDs.contains($0) }.count
    }

    private func selectionIcon(isSelected: Bool, single: Bool) -> String {
        if single {
            return isSelected ? "largecircle.fill.circle" : "circle"
        }
        return isSelected ? "checkmark.square.fill" : "square"
    }

    private func optionPrice(
        _ option: MenuItemVariant,
        in group: MenuImportOptionGroupModel
    ) -> String {
        switch option.priceKind {
        case .fixed:
            return PriceFormatter.string(cents: option.priceCents)
        case .delta:
            let prefix = group.selectionMode != "single" && group.freeSelectionCount > 0
                ? "danach +"
                : "+"
            return prefix + PriceFormatter.string(cents: option.priceCents)
        case .included, .free:
            return "inklusive"
        }
    }
}

private struct MenuImportSelectionSheet: View {
    let items: [MenuItemData]
    @Binding var cartLines: [MenuImportCartLine]
    @Environment(\.dismiss) private var dismiss

    private var itemsByID: [String: MenuItemData] {
        Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
    }

    private var selectedLines: [MenuImportCartLine] {
        cartLines.filter { $0.quantity > 0 }
    }

    private var totalPrice: Int {
        selectedLines.reduce(0) { $0 + $1.lineTotalCents }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(selectedLines) { line in
                        if let item = itemsByID[line.itemID] {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .font(KitchenLinkV2Typography.primaryLine)
                                    if !line.optionNames.isEmpty {
                                        Text(line.optionNames.joined(separator: " · "))
                                            .font(KitchenLinkV2Typography.meta)
                                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                    }
                                    HStack(spacing: 4) {
                                        Text(PriceFormatter.string(cents: line.unitPriceCents))
                                        if item.priceBasis == "per_person" {
                                            Text("pro Person")
                                        }
                                    }
                                        .font(KitchenLinkV2Typography.meta)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                }
                                Spacer()
                                MenuImportCompactQuantityControl(
                                    quantity: line.quantity,
                                    accessibilityContext: item.displayName,
                                    identifierPrefix: "menuPreview.cart.quantity.\(line.id)",
                                    onDecrease: { decrease(line.id) },
                                    onIncrease: { increase(line.id) }
                                )
                            }
                        }
                    }
                } header: {
                    Text("Testauswahl")
                } footer: {
                    Text("Vorschau in der Sandbox – hier wird keine Bestellung gesendet.")
                }

                Section {
                    HStack {
                        Text("Gesamt")
                        Spacer()
                        Text(PriceFormatter.string(cents: totalPrice))
                            .fontWeight(.semibold)
                            .kitchenLinkV2TabularNumbers()
                    }
                }
            }
            .navigationTitle("Auswahl")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private func increase(_ lineID: String) {
        guard let index = cartLines.firstIndex(where: { $0.id == lineID }) else { return }
        cartLines[index].quantity = min(99, cartLines[index].quantity + 1)
    }

    private func decrease(_ lineID: String) {
        guard let index = cartLines.firstIndex(where: { $0.id == lineID }) else { return }
        if cartLines[index].quantity > 1 {
            cartLines[index].quantity -= 1
        } else {
            cartLines.remove(at: index)
        }
    }
}

private struct MenuImportPreviewBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(KitchenLinkV2Palette.Brand.grape.opacity(0.05))
                .frame(width: proxy.size.width * 0.9)
                .offset(x: -proxy.size.width * 0.5, y: -proxy.size.height * 0.05)

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(KitchenLinkV2Palette.Brand.grape.opacity(0.035))
                .frame(width: proxy.size.width * 0.8, height: proxy.size.height * 0.28)
                .rotationEffect(.degrees(-10))
                .offset(x: proxy.size.width * 0.55, y: proxy.size.height * 0.72)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
