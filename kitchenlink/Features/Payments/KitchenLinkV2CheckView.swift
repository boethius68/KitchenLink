import SwiftUI

/// KL-PAY-001: Rechnung kassieren.
///
/// Zuerst die Tische mit offener Rechnung, dann die Rechnung selbst. Der
/// Bildschirm ist für das Kassieren am Tisch gebaut: die Positionen sind
/// antippbar (das ist „getrennt zahlen"), der Betrag steht immer unten, und
/// das Trinkgeld liegt neben der Zahlart statt in einem eigenen Schritt.
struct KitchenLinkV2CheckOverviewView: View {
    @StateObject private var tables = KitchenLinkTablesModel()

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    intro

                    switch tables.phase {
                    case .idle, .loading:
                        KitchenLinkV2Card {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                ProgressView()
                                Text("Tische werden geladen …")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }
                        }
                    case .needsSignIn:
                        KitchenLinkTablesSignInCard { email, password in
                            await tables.signIn(email: email, password: password)
                        }
                    case .failed(let message):
                        KitchenLinkV2Card {
                            Text(message)
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        }
                    case .ready:
                        ForEach(tables.groupedTables, id: \.area) { group in
                            areaSection(group.area, tables: group.tables.filter(\.active))
                        }
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Rechnung")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await tables.load() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
            Text("Tisch wählen und kassieren.")
                .font(KitchenLinkV2Typography.section)
            Text("Gemeinsam, getrennt nach Positionen oder als Teilbetrag — "
                 + "mehrere Zahlungen je Tisch sind möglich.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func areaSection(_ area: String, tables areaTables: [KitchenLinkVenueTable]) -> some View {
        if !areaTables.isEmpty {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text(area.uppercased())
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                KitchenLinkV2Card(padding: 0) {
                    VStack(spacing: 0) {
                        ForEach(Array(areaTables.enumerated()), id: \.element.id) { index, table in
                            if index > 0 {
                                Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                            }
                            NavigationLink {
                                KitchenLinkV2CheckView(table: table)
                            } label: {
                                HStack(spacing: KitchenLinkV2Spacing.medium) {
                                    Text(table.headline)
                                        .font(KitchenLinkV2Typography.primaryLine)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                        .accessibilityHidden(true)
                                }
                                .padding(.horizontal, KitchenLinkV2Spacing.large)
                                .frame(
                                    minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget,
                                    alignment: .leading
                                )
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("check.table.\(table.label)")
                        }
                    }
                }
            }
        }
    }
}

struct KitchenLinkV2CheckView: View {
    @StateObject private var model: KitchenLinkCheckModel
    @State private var isRefundConfirmationVisible = false
    /// KL-ROLE-002: der Storno, für den gerade eine Freigabe geholt wird.
    /// `String` (die Zahlungs-ID) ist hier die ganze Absicht: die Freigabe
    /// gehört zu **dieser** Zahlung, nicht zu „Storno" im Allgemeinen.
    @State private var refundNeedingAuthorization: PendingRefund?

    private struct PendingRefund: Identifiable {
        let paymentID: String
        var id: String { paymentID }
    }

    init(table: KitchenLinkVenueTable) {
        _model = StateObject(wrappedValue: KitchenLinkCheckModel.make(for: table))
    }

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    switch model.phase {
                    case .idle, .loading:
                        KitchenLinkV2Card {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                ProgressView()
                                Text("Rechnung wird geladen …")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }
                        }
                    case .needsSignIn:
                        KitchenLinkTablesSignInCard { email, password in
                            await model.signIn(email: email, password: password)
                        }
                    case .failed(let message):
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                                Text("Rechnung konnte nicht geladen werden")
                                    .font(KitchenLinkV2Typography.primaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                                Text(message)
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                Button("Erneut versuchen") { Task { await model.load() } }
                                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                            }
                        }
                    case .ready, .paying:
                        if model.check.tableSessionID == nil {
                            emptyCard
                        } else {
                            itemsCard
                            methodCard
                            tipCard
                        }
                    }

                    if let receipt = model.lastReceipt {
                        receiptCard(receipt)
                    }
                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                            .accessibilityIdentifier("check.notice")
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                if model.check.tableSessionID != nil {
                    payBar
                }
            }
        }
        .navigationTitle(model.table.headline)
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await model.load() }
        .sheet(item: $refundNeedingAuthorization) { pending in
            KitchenLinkV2ManagerPinSheet(
                permission: .paymentsRefund,
                note: "Storno am Tisch \(model.table.headline)",
                context: ["payment_id": pending.paymentID, "table": model.table.label]
            ) { override in
                Task {
                    await model.refund(
                        paymentID: pending.paymentID,
                        reason: "Storno am Tisch",
                        overrideToken: override.token
                    )
                }
            }
        }
    }

    private var emptyCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("Keine offene Rechnung")
                    .font(KitchenLinkV2Typography.primaryLine)
                Text("An diesem Tisch ist gerade nichts zu kassieren.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
        }
        .accessibilityIdentifier("check.empty")
    }

    private var itemsCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Text("POSITIONEN")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Spacer()
                if model.check.hasOpenItems {
                    Button(model.selectedItemIDs.isEmpty ? "Alle wählen" : "Auswahl aufheben") {
                        if model.selectedItemIDs.isEmpty {
                            model.selectAllOpenItems()
                        } else {
                            model.clearSelection()
                        }
                    }
                    .font(KitchenLinkV2Typography.meta)
                    .accessibilityIdentifier("check.toggleSelection")
                }
            }

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.check.items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        itemRow(item)
                    }
                }
            }

            Text("Positionen antippen heißt getrennt zahlen. Ohne Auswahl wird "
                 + "der gesamte offene Betrag kassiert.")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
        }
    }

    private func itemRow(_ item: KitchenLinkCheckItem) -> some View {
        let isSelected = model.selectedItemIDs.contains(item.id)
        return Button {
            model.toggle(item)
        } label: {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Image(systemName: item.paid
                      ? "checkmark.seal.fill"
                      : (isSelected ? "checkmark.circle.fill" : "circle"))
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(item.paid
                        ? KitchenLinkV2Palette.Urgency.freshSymbol
                        : (isSelected
                           ? KitchenLinkV2Palette.Content.primary
                           : KitchenLinkV2Palette.Content.muted))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.quantityPrefix + item.name)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(item.paid
                            ? KitchenLinkV2Palette.Content.muted
                            : KitchenLinkV2Palette.Content.primary)
                    if item.paid {
                        Text("bezahlt")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
                    }
                }

                Spacer(minLength: 0)

                Text(KitchenLinkV2AmountText.euro(cents: item.lineTotalCents))
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(item.paid
                        ? KitchenLinkV2Palette.Content.muted
                        : KitchenLinkV2Palette.Content.primary)
                    .kitchenLinkV2TabularNumbers()
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
            .padding(.vertical, KitchenLinkV2Spacing.small)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.paid)
        .accessibilityIdentifier("check.item.\(item.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var methodCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("ZAHLART")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Picker("Zahlart", selection: $model.method) {
                    ForEach(KitchenLinkPaymentMethod.allCases) { method in
                        Text(method.title).tag(method)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("check.method")

                Text("Sandbox: es wird nichts abgebucht. Karte und Tap to Pay "
                     + "laufen über den simulierten Zahlungsanbieter.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var tipCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                HStack {
                    Text("TRINKGELD")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.25)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Spacer()
                    Text(KitchenLinkV2AmountText.euro(cents: model.tipCents))
                        .font(KitchenLinkV2Typography.primaryLine)
                        .kitchenLinkV2TabularNumbers()
                }

                HStack(spacing: KitchenLinkV2Spacing.small) {
                    ForEach([0, 5, 10, 15], id: \.self) { percent in
                        Button {
                            model.tipCents = percent == 0
                                ? 0
                                : Int((Double(model.selectionCents) * Double(percent) / 100).rounded())
                        } label: {
                            Text(percent == 0 ? "kein" : "\(percent) %")
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
                                .background(
                                    KitchenLinkV2Palette.Surface.recessed,
                                    in: RoundedRectangle(
                                        cornerRadius: KitchenLinkV2Radius.control,
                                        style: .continuous
                                    )
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("check.tip.\(percent)")
                    }
                }
            }
        }
    }

    private func receiptCard(_ receipt: KitchenLinkPaymentReceipt) -> some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text(receipt.sessionClosed ? "Rechnung beglichen" : "Zahlung gebucht")
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
                Text("\(KitchenLinkV2AmountText.euro(cents: receipt.amountCents))"
                     + (receipt.tipCents > 0
                        ? " + \(KitchenLinkV2AmountText.euro(cents: receipt.tipCents)) Trinkgeld"
                        : ""))
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                if !receipt.sessionClosed {
                    Text("Offen: \(KitchenLinkV2AmountText.euro(cents: receipt.openCents))")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
                Text("Sandbox-Beleg \(receipt.providerReference)")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                switch model.refundGate {
                case .allowed:
                    Button("Zahlung stornieren") { isRefundConfirmationVisible = true }
                        .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                        .accessibilityIdentifier("check.refund")
                case .needsAuthorization, .blocked:
                    // Genau der Fall aus Blueprint §9.1: die Servicekraft steht
                    // am Tisch, der Manager sitzt nicht daneben.
                    KitchenLinkV2PermissionGate(
                        note: model.refundGate.note ?? "",
                        permission: .paymentsRefund,
                        canBeAuthorized: model.refundGate.allowsAuthorization,
                        identifier: "check.refundDenied"
                    ) {
                        refundNeedingAuthorization = PendingRefund(paymentID: receipt.paymentID)
                    }
                }
            }
        }
        .accessibilityIdentifier("check.receipt")
        .confirmationDialog(
            "Zahlung stornieren?",
            isPresented: $isRefundConfirmationVisible,
            titleVisibility: .visible
        ) {
            Button("Stornieren", role: .destructive) {
                Task { await model.refund(paymentID: receipt.paymentID, reason: "Storno am Tisch") }
            }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Die Positionen werden wieder offen und können erneut kassiert werden.")
        }
    }

    private var payBar: some View {
        VStack(spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Text(model.isPartialPayment ? "Auswahl" : "Offen")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                Spacer()
                Text(KitchenLinkV2AmountText.euro(cents: model.selectionCents))
                    .font(KitchenLinkV2Typography.primaryLine)
                    .kitchenLinkV2TabularNumbers()
            }

            Button {
                Task { await model.pay() }
            } label: {
                HStack {
                    Text(model.phase == .paying ? "Wird gebucht …" : "Kassieren")
                    Spacer()
                    Text(KitchenLinkV2AmountText.euro(cents: model.payableCents))
                        .kitchenLinkV2TabularNumbers()
                }
            }
            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
            .disabled(!model.canPay)
            .accessibilityIdentifier("check.pay")
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .background(.bar)
    }
}
