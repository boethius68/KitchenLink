import SwiftUI

/// KL-TABLE-002: Bestellaufnahme am Tisch, für den Kellner.
///
/// Der Bildschirm ist auf die Situation zugeschnitten, für die er gedacht ist:
/// jemand steht am Tisch, der Gast redet, die Cloud ist vielleicht weg. Deshalb
/// Tisch zuerst, dann die Karte mit großen Mengensteuerungen, und eine
/// Bestätigung, die ehrlich sagt, was passiert ist — dauerhaft gespeichert,
/// und ob die Cloud sie schon kennt.
struct KitchenLinkV2WaiterOrderView: View {
    @EnvironmentObject private var appStore: KitchenLinkStore
    @StateObject private var tables = KitchenLinkTablesModel()
    @StateObject private var model: KitchenLinkWaiterOrderModel

    @Environment(\.dismiss) private var dismiss
    @State private var successFeedback = 0

    init(model: KitchenLinkWaiterOrderModel) {
        _model = StateObject(wrappedValue: model)
    }

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    modeCard
                    if model.requiresTable {
                        tableCard
                    }
                    menuCard
                    noteCard
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .bottom) { placeBar }
        }
        .navigationTitle("Bestellung aufnehmen")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .sensoryFeedback(.success, trigger: successFeedback)
        .task { await tables.load() }
    }

    // MARK: Kanal und Tisch

    private var modeCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("KANAL")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Picker("Kanal", selection: $model.serviceMode) {
                    ForEach(appStore.venueProfile.supportedServiceModes) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("waiterOrder.serviceMode")
            }
        }
    }

    private var tableCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("TISCH")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                switch tables.phase {
                case .idle, .loading:
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        ProgressView()
                        Text("Tische werden geladen …")
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }
                case .needsSignIn:
                    Text("Für Tische ist eine Anmeldung nötig. Sie steht unter „Tische“ "
                         + "auf der Startseite; Theke und Abholung gehen auch ohne.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                case .failed(let message):
                    Text(message)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                case .ready:
                    if activeTables.isEmpty {
                        Text("Noch keine aktiven Tische. Unter „Tische“ anlegen.")
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    } else {
                        tableGrid
                    }
                }
            }
        }
    }

    private var activeTables: [KitchenLinkVenueTable] {
        tables.groupedTables.flatMap(\.tables).filter(\.active)
    }

    private var tableGrid: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 92), spacing: KitchenLinkV2Spacing.small)],
            spacing: KitchenLinkV2Spacing.small
        ) {
            ForEach(activeTables) { table in
                Button {
                    model.selectedTable = model.selectedTable?.id == table.id ? nil : table
                } label: {
                    Text(table.headline)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
                        .foregroundStyle(
                            model.selectedTable?.id == table.id
                                ? KitchenLinkV2Palette.Content.onPrimaryAction
                                : KitchenLinkV2Palette.Content.primary
                        )
                        .background(
                            model.selectedTable?.id == table.id
                                ? KitchenLinkV2Palette.Action.persistentPrimary
                                : KitchenLinkV2Palette.Surface.recessed,
                            in: RoundedRectangle(
                                cornerRadius: KitchenLinkV2Radius.control,
                                style: .continuous
                            )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("waiterOrder.table.\(table.label)")
                .accessibilityAddTraits(
                    model.selectedTable?.id == table.id ? .isSelected : []
                )
            }
        }
    }

    // MARK: Karte

    private var menuCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            ForEach(model.orderableSections) { section in
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                    Text(section.title.uppercased())
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.25)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                    KitchenLinkV2Card(padding: 0) {
                        VStack(spacing: 0) {
                            ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                                }
                                itemRow(item)
                            }
                        }
                    }
                }
            }
        }
    }

    private func itemRow(_ item: MenuItemData) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(PriceFormatter.string(cents: item.priceCents))
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .kitchenLinkV2TabularNumbers()
            }

            Spacer(minLength: 0)

            let quantity = model.quantity(for: item)
            if quantity > 0 {
                Button {
                    model.decrement(item)
                } label: {
                    stepperGlyph("minus")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(item.name) verringern")

                Text("\(quantity)")
                    .font(KitchenLinkV2Typography.primaryLine)
                    .kitchenLinkV2TabularNumbers()
                    .frame(minWidth: 24)
            }

            Button {
                model.increment(item)
            } label: {
                stepperGlyph("plus")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(item.name) hinzufügen")
            .accessibilityIdentifier("waiterOrder.add.\(item.id)")
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.vertical, KitchenLinkV2Spacing.small)
    }

    private func stepperGlyph(_ systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            // Volles 44-Punkt-Ziel, auch wenn der gezeichnete Kreis kleiner ist
            // (Import-Konsolidierung, 22. Juli).
            .frame(
                width: KitchenLinkV2GuestMenuMetrics.minimumTapTarget,
                height: KitchenLinkV2GuestMenuMetrics.minimumTapTarget
            )
            .background(
                Circle()
                    .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
                    .frame(width: 32, height: 32)
            )
            .contentShape(Rectangle())
    }

    private var noteCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("HINWEIS FÜR DIE KÜCHE")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                TextField(
                    "Hinweis",
                    text: $model.customerNote,
                    prompt: Text("z. B. ohne Zwiebeln, Allergie Nuss"),
                    axis: .vertical
                )
                .lineLimit(1...3)
                .accessibilityIdentifier("waiterOrder.note")
            }
        }
    }

    // MARK: Abschluss

    /// Die Rückmeldung steht direkt über der Aktion, nicht unter der Karte:
    /// diese Speisekarte hat über hundert Artikel, eine Bestätigung am Ende des
    /// Scrollbereichs würde der Kellner nie sehen (im Simulator genau so
    /// aufgefallen).
    @ViewBuilder
    private var statusNotice: some View {
        switch model.phase {
        case .placed(let orderID, let syncedToCloud):
            VStack(alignment: .leading, spacing: 2) {
                Text("Angenommen · dauerhaft gespeichert · #\(orderID.prefix(8))")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
                Text(syncedToCloud
                     ? "Auch in die Cloud übertragen."
                     : "Noch nicht in der Cloud — wird automatisch nachgeholt.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(
                        syncedToCloud
                            ? KitchenLinkV2Palette.Content.muted
                            : KitchenLinkV2Palette.Urgency.waitingText
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("waiterOrder.placed")
        case .failed(let message):
            VStack(alignment: .leading, spacing: 2) {
                Text("Nicht angenommen: \(message)")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
                Text("Die aufgenommenen Positionen bleiben stehen.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("waiterOrder.failed")
        case .composing, .placing:
            if let reason = model.placementBlockedReason {
                Text(reason)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var placeBar: some View {
        VStack(spacing: KitchenLinkV2Spacing.small) {
            statusNotice
            Button {
                Task {
                    await model.place()
                    if case .placed = model.phase {
                        successFeedback += 1
                    }
                }
            } label: {
                HStack {
                    Text(model.phase == .placing
                         ? "Wird angenommen …"
                         : "\(model.itemCount) Artikel · annehmen")
                    Spacer()
                    Text(PriceFormatter.string(cents: model.totalCents))
                        .kitchenLinkV2TabularNumbers()
                }
            }
            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
            .disabled(!model.canPlace)
            .accessibilityIdentifier("waiterOrder.place")
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .background(.bar)
    }
}
