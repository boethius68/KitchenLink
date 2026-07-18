import SwiftUI

/// V2 `Bestand`: read-only Bestandsansicht über die echte
/// `InventoryProjection` der KL-INVENTORY-001-Domain. Kein zweites
/// Bestandsmodell — jede sichtbare Zahl kommt frisch aus dem Ledger.
///
/// Statusregel (`DESIGN_SYSTEM.md` §5/§6): Schwere → Dringlichkeit
/// (`ok`→neutral, `warning`→waiting, `critical`→critical). Zitrone
/// ausschließlich in der einzelnen Demo-Aktion, nie in einer Statusfarbe.
/// Bis ein `.stock`-Form-Muster vom Nutzer freigegeben ist, verzichtet die
/// Zeile bewusst auf einen Operations-Glyph und führt die Dringlichkeit
/// ausschließlich über Farbe und Klartext (`§6`: „bis ein eigenes Muster
/// definiert ist, bleiben Form und Klartext gemeinsam sichtbar").
struct InventoryOperatorView: View {
    @StateObject private var model = InventoryOperatorModel()

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                    header
                    sectionList

                    if let status = model.statusMessage {
                        Text(status)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let error = model.lastError {
                        Text(error)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("inventory.error")
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.top, KitchenLinkV2Spacing.medium)
                .padding(.bottom, 140)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
        .navigationTitle("Bestand")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if KitchenLinkDesignPreviewConfiguration.shouldSeedDemoInventory(),
               model.groups.isEmpty {
                let count = InventoryOperatorDemoSeeder.seed(into: model)
                if count > 0 {
                    model.statusMessage = "\(count) Bestandszeilen aus dem Demo-Szenario."
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Bestand")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .accessibilityIdentifier("inventory.title")

            Spacer()

            Text(headerSummary)
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(headerSummaryColor)
                .kitchenLinkV2TabularNumbers()
                .accessibilityIdentifier("inventory.summary")
        }
    }

    private var headerSummary: String {
        if model.groups.isEmpty {
            return "leer"
        }
        if model.criticalCount > 0 {
            return "\(model.criticalCount) kritisch · \(model.totalRowCount) Positionen"
        }
        return "\(model.totalRowCount) Positionen"
    }

    private var headerSummaryColor: Color {
        model.criticalCount > 0
            ? KitchenLinkV2Palette.Urgency.criticalText
            : KitchenLinkV2Palette.Content.muted
    }

    @ViewBuilder
    private var sectionList: some View {
        if model.groups.isEmpty {
            Text("Kein Bestand geladen. Lade das Demo-Szenario, um die Sandbox-Fixture zu sehen.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("inventory.emptyState")
        } else {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                ForEach(model.groups) { group in
                    locationSection(group)
                }
            }
        }
    }

    private func locationSection(_ group: KitchenLinkV2InventoryLocationGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: KitchenLinkV2Spacing.small) {
                Text(group.locationName.uppercased())
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.35)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Spacer()
                Text("\(group.rows.count)")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .kitchenLinkV2TabularNumbers()
            }
            .padding(.bottom, KitchenLinkV2Spacing.small)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(group.rows.enumerated()), id: \.element.id) { index, row in
                    stockRow(row)
                    if index < group.rows.count - 1 {
                        Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                    }
                }
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Lagerort \(group.locationName), \(group.rows.count) Positionen")
    }

    private func stockRow(_ row: KitchenLinkV2InventoryStockRow) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.ingredientName)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(row.explanation)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(row.urgency == .neutral
                        ? KitchenLinkV2Palette.Content.secondary
                        : row.urgency.textColor)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineLimit(2)
            }

            Spacer(minLength: KitchenLinkV2Spacing.small)

            VStack(alignment: .trailing, spacing: 1) {
                Text(row.available.displayString())
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(row.urgency == .neutral
                        ? KitchenLinkV2Palette.Content.primary
                        : row.urgency.textColor)
                    .kitchenLinkV2TabularNumbers()
                Text(row.verb)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(row.urgency.textColor)
            }
        }
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(row.ingredientName). \(row.verb). verfügbar \(row.available.displayString()). \(row.explanation)")
        .accessibilityIdentifier("inventory.row.\(row.id)")
    }

    private var actionBar: some View {
        VStack(spacing: KitchenLinkV2Spacing.small) {
            Button {
                loadDemo()
            } label: {
                Label("Demo-Szenario laden", systemImage: "wand.and.stars")
            }
            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
            .accessibilityIdentifier("inventory.loadDemo")
            .accessibilityHint("Ersetzt die Ansicht durch die Sandbox-Fixture (12 Zutaten, 2 Lagerorte).")
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.top, KitchenLinkV2Spacing.medium)
        .padding(.bottom, KitchenLinkV2Spacing.small)
        .background(.thinMaterial)
    }

    private func loadDemo() {
        model.statusMessage = "Demo-Szenario wird geladen..."
        let count = InventoryOperatorDemoSeeder.seed(into: model)
        if count > 0 {
            model.statusMessage = "\(count) Bestandszeilen aus dem Demo-Szenario."
        }
    }
}
