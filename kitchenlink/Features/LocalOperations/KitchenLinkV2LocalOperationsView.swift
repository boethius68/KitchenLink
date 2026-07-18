import SwiftUI

struct KitchenLinkV2LocalOperationsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case kitchen = "Küche"
        case waiter = "Kellner"

        var id: String { rawValue }
    }

    @StateObject private var model = KitchenLinkLocalOperationsModel()
    @State private var mode: Mode = .kitchen
    @State private var successFeedback = 0

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    header
                    modePicker
                    connectionCard
                    orderSection
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.vertical, KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Lokaler Service")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Brand.grape)
        .sensoryFeedback(.success, trigger: successFeedback)
        .task {
            model.connect()
        }
        .onDisappear {
            model.disconnect()
        }
    }

    private var visibleOrders: [LiveOrderMessage] {
        switch mode {
        case .kitchen:
            return model.orders.filter { $0.status == .preparing }
        case .waiter:
            return model.orders.filter { $0.status == .ready }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                Text(mode.rawValue)
                    .font(KitchenLinkV2Typography.display)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(mode == .kitchen
                     ? "Neue lokale Bestellungen zubereiten."
                     : "Fertige Bestellungen am Pass übernehmen.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }

            Spacer()

            HStack(spacing: KitchenLinkV2Spacing.xSmall) {
                Circle()
                    .fill(model.isConnected
                          ? KitchenLinkV2Palette.Urgency.freshSymbol
                          : KitchenLinkV2Palette.Urgency.neutralSymbol)
                    .frame(width: 8, height: 8)
                Text(model.isConnected ? "LIVE" : "OFFLINE")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.isConnected ? "Live verbunden" : "Nicht verbunden")
            .accessibilityIdentifier("localOperations.connectionBadge")
        }
    }

    private var modePicker: some View {
        Picker("Arbeitsmodus", selection: $mode) {
            ForEach(Mode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("localOperations.mode")
    }

    private var connectionCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            TextField("http://192.168.1.20:8080", text: $model.hubAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .font(KitchenLinkV2Typography.primaryLine)
                .padding(.horizontal, KitchenLinkV2Spacing.medium)
                .frame(minHeight: 48)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
                }
                .accessibilityLabel("Adresse des lokalen Hubs")
                .accessibilityIdentifier("localOperations.hubAddress")

            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Text(model.connectionDetail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(model.isConnected
                                     ? KitchenLinkV2Palette.Content.secondary
                                     : KitchenLinkV2Palette.Urgency.waitingText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button(model.isConnected ? "Neu verbinden" : "Verbinden") {
                    model.connect()
                }
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .frame(minHeight: 44)
                .accessibilityIdentifier("localOperations.connect")
            }
        }
        .padding(KitchenLinkV2Spacing.large)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var orderSection: some View {
        if visibleOrders.isEmpty {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text(emptyTitle)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(emptyDetail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(KitchenLinkV2Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )
            .accessibilityIdentifier("localOperations.empty")
        } else {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text(mode == .kitchen ? "IN ZUBEREITUNG" : "BEREIT AM PASS")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                ForEach(visibleOrders) { order in
                    orderCard(order)
                }
            }
        }
    }

    private var emptyTitle: String {
        if !model.isConnected { return "Lokaler Hub nicht verbunden." }
        return mode == .kitchen ? "Keine neue Bestellung." : "Nichts zur Abholung bereit."
    }

    private var emptyDetail: String {
        if !model.isConnected { return "Hub-Adresse und gemeinsames WLAN prüfen." }
        return mode == .kitchen
            ? "Die nächste lokale Gastbestellung erscheint automatisch."
            : "Sobald die Küche eine Bestellung als zubereitet markiert, erscheint sie hier."
    }

    private func orderCard(_ order: LiveOrderMessage) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.sourceDevice.replacingOccurrences(of: "Lokales Gast-WLAN · ", with: "Bestellung "))
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text(order.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }

                Spacer()

                Text(KitchenLinkV2AmountText.euro(cents: order.totalCents))
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .kitchenLinkV2TabularNumbers()
            }

            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                ForEach(order.items) { line in
                    Text("\(line.quantity)× \(line.name)")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }
            }

            Button(actionTitle) {
                advance(order)
            }
            .buttonStyle(mode == .kitchen
                         ? AnyKitchenLinkV2ButtonStyle(KitchenLinkV2KitchenBumpButtonStyle())
                         : AnyKitchenLinkV2ButtonStyle(KitchenLinkV2PrimaryButtonStyle()))
            .disabled(model.isUpdatingOrder)
            .accessibilityIdentifier("localOperations.advance.\(order.id)")
        }
        .padding(KitchenLinkV2Spacing.large)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: KitchenLinkV2Radius.card,
                topTrailingRadius: KitchenLinkV2Radius.card
            )
            .fill(mode == .kitchen
                  ? KitchenLinkV2Palette.Urgency.neutralSymbol
                  : KitchenLinkV2Palette.Urgency.freshSymbol)
            .frame(height: 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("localOperations.order.\(order.id)")
    }

    private var actionTitle: String {
        mode == .kitchen ? "Bestellung zubereitet" : "Bestellung serviert"
    }

    private func advance(_ order: LiveOrderMessage) {
        let target: OrderLifecycleStatus = mode == .kitchen ? .ready : .served
        Task {
            if await model.update(order: order, to: target) {
                successFeedback += 1
            }
        }
    }
}

/// Type erasure lets the same card use the established kitchen bump style and
/// the normal service primary style without duplicating either visual contract.
private struct AnyKitchenLinkV2ButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}
