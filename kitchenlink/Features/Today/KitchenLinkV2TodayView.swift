import SwiftUI

/// V2 `Heute`: an event-oriented work list over the existing sandbox order
/// domain. Exactly one persistent lemon primary action per visible context;
/// everything repeated or informative stays grape-based.
struct KitchenLinkV2TodayView: View {
    @EnvironmentObject private var store: KitchenLinkStore
    @EnvironmentObject private var relay: OrderRelayService
    @State private var isPerformingAction = false
    @State private var demoStatusMessage: String?

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let events = KitchenLinkV2TodayEventBuilder.events(
                    from: relay.receivedOrders,
                    now: timeline.date
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                        header(eventCount: events.count)
                        connectionRow
                        eventList(events)

                        if let demoStatusMessage {
                            Text(demoStatusMessage)
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                .fixedSize(horizontal: false, vertical: true)
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
                    actionBar(events: events)
                }
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
        .navigationTitle("Heute")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if KitchenLinkDesignPreviewConfiguration.shouldSeedDemoService(),
               relay.receivedOrders.isEmpty {
                await KitchenLinkV2DemoOperationsSeeder.seed(store: store, relay: relay)
            }
        }
    }

    private func header(eventCount: Int) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Heute")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .accessibilityIdentifier("today.title")

            Spacer()

            Text("\(eventCount) offen")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .kitchenLinkV2TabularNumbers()
        }
    }

    private var connectionRow: some View {
        let isReceiving = relay.mode == .owner && relay.isConnected
        let status = KitchenLinkV2Status(
            operation: .connection,
            urgency: .neutral,
            verb: isReceiving ? "Empfang aktiv" : "kein Empfang"
        )

        return HStack(spacing: KitchenLinkV2Spacing.medium) {
            if isReceiving {
                // The struck ring is reserved for a broken connection (6a);
                // active reception shows a plain filled dot instead.
                Circle()
                    .fill(status.urgency.symbolColor)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            } else {
                KitchenLinkV2OperationGlyph(
                    operation: status.operation,
                    color: status.urgency.symbolColor
                )
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(status.verb)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(isReceiving
                     ? relay.connectionText
                     : "Lokale Bestellungen bleiben erhalten.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
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
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isReceiving
            ? "Verbindung: Empfang aktiv. \(relay.connectionText)"
            : "\(status.accessibilityLabel). \(relay.connectionText)")
        .accessibilityIdentifier("today.connection")
    }

    @ViewBuilder
    private func eventList(_ events: [KitchenLinkV2TodayEvent]) -> some View {
        if events.isEmpty {
            Text("Keine offenen Ereignisse. Lade das Demo-Szenario oder nimm eine Bestellung entgegen.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("today.emptyState")
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("JETZT ERLEDIGEN")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.35)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .padding(.bottom, KitchenLinkV2Spacing.small)

                ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                    eventRow(event)
                    if index < events.count - 1 {
                        Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                    }
                }
            }
        }
    }

    private func eventRow(_ event: KitchenLinkV2TodayEvent) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            KitchenLinkV2OperationGlyph(
                operation: event.status.operation,
                color: event.status.urgency.symbolColor
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(event.detail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(event.status.urgency == .neutral
                        ? KitchenLinkV2Palette.Content.secondary
                        : event.status.urgency.textColor)
            }

            Spacer(minLength: KitchenLinkV2Spacing.small)

            Text(event.trailing.text)
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(trailingColor(for: event))
                .kitchenLinkV2TabularNumbers()
        }
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .frame(minHeight: 44)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.status.accessibilityLabel). \(event.title). \(event.trailing.text)")
        .accessibilityIdentifier("today.event.\(event.id)")
    }

    private func trailingColor(for event: KitchenLinkV2TodayEvent) -> Color {
        if case .overdue = event.trailing {
            return event.status.urgency.textColor
        }
        return KitchenLinkV2Palette.Content.primary
    }

    private func actionBar(events: [KitchenLinkV2TodayEvent]) -> some View {
        let nextEvent = KitchenLinkV2TodayEventBuilder.nextAction(in: events)

        return VStack(spacing: KitchenLinkV2Spacing.small) {
            Button {
                performPrimaryAction(for: nextEvent)
            } label: {
                Text(primaryActionTitle(for: nextEvent))
            }
            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
            .disabled(isPerformingAction || (relay.mode == .owner && nextEvent == nil))
            .accessibilityIdentifier("today.primaryAction")

            Button {
                loadDemoScenario()
            } label: {
                Label("Demo-Szenario laden", systemImage: "wand.and.stars")
            }
            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
            .disabled(isPerformingAction)
            .accessibilityIdentifier("today.simulateDemo")
            .accessibilityHint("Ersetzt die lokalen Sandbox-Bestellungen durch ein Demo-Szenario.")
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.top, KitchenLinkV2Spacing.medium)
        .padding(.bottom, KitchenLinkV2Spacing.small)
        .background(.thinMaterial)
    }

    private func primaryActionTitle(for event: KitchenLinkV2TodayEvent?) -> String {
        guard relay.mode == .owner else {
            return "Service starten"
        }
        guard let event, let actionTitle = event.nextActionTitle else {
            return "Alles erledigt"
        }
        guard let order = order(for: event) else {
            return actionTitle
        }
        return "\(KitchenLinkV2TodayEventBuilder.placeTitle(for: order)) · \(actionTitle)"
    }

    private func performPrimaryAction(for event: KitchenLinkV2TodayEvent?) {
        guard relay.mode == .owner else {
            relay.startHostingAsOwner()
            return
        }
        guard let event,
              let order = order(for: event),
              let nextStatus = order.status.primaryNextStatus else {
            return
        }

        isPerformingAction = true
        Task {
            _ = await relay.updateStatus(for: order, to: nextStatus)
            isPerformingAction = false
        }
    }

    private func loadDemoScenario() {
        isPerformingAction = true
        demoStatusMessage = "Demo-Szenario wird geladen..."
        Task {
            let createdCount = await KitchenLinkV2DemoOperationsSeeder.seed(
                store: store,
                relay: relay
            )
            demoStatusMessage = "\(createdCount) Demo-Bestellungen ersetzen die lokalen Sandbox-Daten."
            isPerformingAction = false
        }
    }

    private func order(for event: KitchenLinkV2TodayEvent) -> LiveOrderMessage? {
        relay.receivedOrders.first { $0.id == event.id }
    }
}
