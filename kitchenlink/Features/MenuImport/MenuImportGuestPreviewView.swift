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
    @State private var quantities: [String: Int] = [:]
    @State private var showsSelection = false

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
        quantities.values.reduce(0, +)
    }

    private var totalSelectedPrice: Int {
        allItems.reduce(0) { result, item in
            result + item.priceCents * quantities[item.id, default: 0]
        }
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
                    quantities: $quantities
                )
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

            Text("Allergene, Zusatzstoffe, Varianten und Mengen lassen sich hier direkt im neuen Produktstand prüfen.")
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
                        .padding(KitchenLinkV2Spacing.large)
                }
            }
        }
    }

    private func itemRow(_ item: MenuItemData, legend: [String: String]?) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
                Text(item.displayName)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: KitchenLinkV2Spacing.small)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(PriceFormatter.string(cents: item.priceCents))
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        .kitchenLinkV2TabularNumbers()
                    if item.priceBasis == "per_person" {
                        Text("pro Person")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                }
            }

            if !item.description.isEmpty, item.description != "Automatisch importiert" {
                Text(item.description)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let codes = item.resolvedAllergenCodes, !codes.isEmpty {
                AllergenBadgesRow(rawCodes: codes, legendByCode: legend)
            }

            MenuItemOptionsListView(options: item.variants)

            HStack {
                Spacer()
                MenuImportCompactQuantityControl(
                    quantity: quantities[item.id, default: 0],
                    onDecrease: { decrease(item.id) },
                    onIncrease: { increase(item.id) }
                )
            }
        }
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

    private func increase(_ itemID: String) {
        quantities[itemID] = min(99, quantities[itemID, default: 0] + 1)
    }

    private func decrease(_ itemID: String) {
        let next = quantities[itemID, default: 0] - 1
        if next > 0 {
            quantities[itemID] = next
        } else {
            quantities[itemID] = nil
        }
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

struct MenuImportCompactQuantityControl: View {
    let quantity: Int
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        if quantity == 0 {
            Button(action: onIncrease) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            .background(
                KitchenLinkV2Palette.Surface.recessed,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                    .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
            }
            .accessibilityLabel("Hinzufügen")
        } else {
            HStack(spacing: 0) {
                quantityButton(systemImage: "minus", label: "Entfernen", action: onDecrease)
                Text("\(quantity)")
                    .font(KitchenLinkV2Typography.primaryLine)
                    .frame(minWidth: 32)
                    .kitchenLinkV2TabularNumbers()
                quantityButton(systemImage: "plus", label: "Hinzufügen", action: onIncrease)
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
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
        .accessibilityLabel(label)
    }
}

private struct MenuImportSelectionSheet: View {
    let items: [MenuItemData]
    @Binding var quantities: [String: Int]
    @Environment(\.dismiss) private var dismiss

    private var selectedItems: [MenuItemData] {
        items.filter { quantities[$0.id, default: 0] > 0 }
    }

    private var totalPrice: Int {
        selectedItems.reduce(0) { result, item in
            result + item.priceCents * quantities[item.id, default: 0]
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(selectedItems) { item in
                        HStack(spacing: KitchenLinkV2Spacing.medium) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.displayName)
                                    .font(KitchenLinkV2Typography.primaryLine)
                                HStack(spacing: 4) {
                                    Text(PriceFormatter.string(cents: item.priceCents))
                                    if item.priceBasis == "per_person" {
                                        Text("pro Person")
                                    }
                                }
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }
                            Spacer()
                            MenuImportCompactQuantityControl(
                                quantity: quantities[item.id, default: 0],
                                onDecrease: { decrease(item.id) },
                                onIncrease: { increase(item.id) }
                            )
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

    private func increase(_ itemID: String) {
        quantities[itemID] = min(99, quantities[itemID, default: 0] + 1)
    }

    private func decrease(_ itemID: String) {
        let next = quantities[itemID, default: 0] - 1
        if next > 0 {
            quantities[itemID] = next
        } else {
            quantities[itemID] = nil
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
