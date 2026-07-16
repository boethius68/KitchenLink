import SwiftUI

/// One kitchen ticket derived from the existing sandbox order domain.
struct KitchenLinkV2KitchenTicket: Identifiable, Equatable {
    let id: String
    let tableTitle: String
    let status: KitchenLinkV2Status
    let itemLines: [String]
    let overflowCount: Int
    let note: String?
    let trailingText: String
    let isOverdue: Bool
    let orderStatus: OrderLifecycleStatus
    let createdAt: Date

    var advanceActionTitle: String? {
        orderStatus.primaryActionTitle
    }

    static func tickets(
        from orders: [LiveOrderMessage],
        now: Date = Date()
    ) -> [KitchenLinkV2KitchenTicket] {
        orders
            .compactMap { ticket(from: $0, now: now) }
            .sorted { $0.createdAt < $1.createdAt }
    }

    static func ticket(
        from order: LiveOrderMessage,
        now: Date = Date()
    ) -> KitchenLinkV2KitchenTicket? {
        let age = now.timeIntervalSince(order.createdAt)
        let isLate = age > KitchenLinkV2TodayEventBuilder.kitchenWaitThreshold

        let status: KitchenLinkV2Status
        var trailingText = KitchenLinkV2TimeText.elapsed(age)
        var isOverdue = false

        switch order.status {
        case .pending:
            status = KitchenLinkV2Status(operation: .order, urgency: .fresh, verb: "neu")
        case .accepted:
            status = isLate
                ? KitchenLinkV2Status(operation: .order, urgency: .waiting, verb: "verspätet")
                : KitchenLinkV2Status(operation: .order, urgency: .neutral, verb: "angenommen")
            isOverdue = isLate
        case .preparing:
            status = isLate
                ? KitchenLinkV2Status(operation: .order, urgency: .waiting, verb: "verspätet")
                : KitchenLinkV2Status(operation: .order, urgency: .neutral, verb: "in Arbeit")
            isOverdue = isLate
        case .ready:
            status = KitchenLinkV2Status(operation: .order, urgency: .fresh, verb: "bereit")
        case .served:
            // Served tickets stay visible as a neutral open-payment task:
            // clear the table, no alarm.
            status = KitchenLinkV2Status(operation: .payment, urgency: .neutral, verb: "Zahlung offen")
            trailingText = KitchenLinkV2AmountText.euro(cents: order.totalCents)
        case .canceled:
            return nil
        }

        if isOverdue {
            trailingText = "+" + KitchenLinkV2TimeText.elapsed(
                age - KitchenLinkV2TodayEventBuilder.kitchenWaitThreshold
            )
        }

        let allLines = order.items.map { "\($0.quantity)× \($0.name)" }
        let visibleLines = Array(allLines.prefix(3))
        let trimmedNote = order.customerNote.trimmingCharacters(in: .whitespacesAndNewlines)

        return KitchenLinkV2KitchenTicket(
            id: order.id,
            tableTitle: KitchenLinkV2TodayEventBuilder.placeTitle(for: order),
            status: status,
            itemLines: visibleLines,
            overflowCount: max(0, allLines.count - visibleLines.count),
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            trailingText: trailingText,
            isOverdue: isOverdue,
            orderStatus: order.status,
            createdAt: order.createdAt
        )
    }
}

/// V2 `Küche`: deep surface, simultaneous tickets, no lemon anywhere.
/// The kitchen context is dark by design (`DESIGN_SYSTEM.md` section 9), so the
/// adaptive tokens are resolved in their dark roles regardless of system mode.
struct KitchenLinkV2KitchenView: View {
    @EnvironmentObject private var store: KitchenLinkStore
    @EnvironmentObject private var relay: OrderRelayService
    @State private var isPerformingAction = false

    private let gridColumns = [
        GridItem(.adaptive(minimum: 290, maximum: 460), spacing: KitchenLinkV2Spacing.medium)
    ]

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.kitchenBase
                .ignoresSafeArea()

            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let tickets = KitchenLinkV2KitchenTicket.tickets(
                    from: relay.receivedOrders,
                    now: timeline.date
                )

                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        header(ticketCount: tickets.count, now: timeline.date)

                        if tickets.isEmpty {
                            emptyState
                        } else {
                            LazyVGrid(
                                columns: gridColumns,
                                alignment: .leading,
                                spacing: KitchenLinkV2Spacing.medium
                            ) {
                                ForEach(tickets) { ticket in
                                    ticketCard(ticket)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, KitchenLinkV2Spacing.large)
                    .padding(.vertical, KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .scrollIndicators(.hidden)
            }
        }
        .environment(\.colorScheme, .dark)
        .tint(KitchenLinkV2Palette.Content.primary)
        .navigationTitle("Küche")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if KitchenLinkDesignPreviewConfiguration.shouldSeedDemoService(),
               relay.receivedOrders.isEmpty {
                await KitchenLinkV2DemoOperationsSeeder.seed(store: store, relay: relay)
            }
        }
    }

    private func header(ticketCount: Int, now: Date) -> some View {
        let isReceiving = relay.mode == .owner && relay.isConnected

        return HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
            Text("Küche · Pass")
                .font(KitchenLinkV2Typography.kitchenTitle)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)

            HStack(spacing: KitchenLinkV2Spacing.small) {
                if isReceiving {
                    Circle()
                        .fill(KitchenLinkV2Palette.Content.primary)
                        .frame(width: 7, height: 7)
                } else {
                    KitchenLinkV2OperationGlyph(
                        operation: .connection,
                        color: KitchenLinkV2Palette.Urgency.neutralSymbol,
                        size: 13
                    )
                }

                Text(isReceiving ? "LIVE" : "kein Empfang")
                    .font(KitchenLinkV2Typography.kitchenStatus)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isReceiving
                ? "Empfang aktiv"
                : "Verbindung, durchgestrichener Ring: kein Empfang. Lokale Tickets bleiben erhalten.")
            .accessibilityIdentifier("kitchen.connection")

            Spacer()

            Text("\(now.formatted(date: .omitted, time: .shortened)) · \(ticketCount) offen")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .kitchenLinkV2TabularNumbers()
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("Keine Tickets am Pass.")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .accessibilityIdentifier("kitchen.emptyState")

            Button {
                loadDemoScenario()
            } label: {
                Label("Demo-Szenario laden", systemImage: "wand.and.stars")
            }
            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
            .disabled(isPerformingAction)
            .frame(maxWidth: 420)
            .accessibilityIdentifier("kitchen.simulateDemo")
        }
    }

    private func ticketCard(_ ticket: KitchenLinkV2KitchenTicket) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack(alignment: .firstTextBaseline) {
                Text(ticket.tableTitle)
                    .font(KitchenLinkV2Typography.kitchenTitle)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .lineLimit(2)

                Spacer(minLength: KitchenLinkV2Spacing.small)

                HStack(spacing: 6) {
                    KitchenLinkV2OperationGlyph(
                        operation: ticket.status.operation,
                        color: ticket.status.urgency.symbolColor,
                        size: 12
                    )
                    Text(ticket.status.verb)
                        .font(KitchenLinkV2Typography.kitchenStatus)
                        .foregroundStyle(ticket.status.urgency.textColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                ForEach(ticket.itemLines, id: \.self) { line in
                    Text(line)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if ticket.overflowCount > 0 {
                    Text("+\(ticket.overflowCount) weitere")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }
            }

            if let note = ticket.note {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    KitchenLinkV2OperationGlyph(
                        operation: .change,
                        color: KitchenLinkV2Palette.Urgency.waitingSymbol,
                        size: 11
                    )
                    Text(note)
                        .font(KitchenLinkV2Typography.kitchenStatus)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack {
                Text(ticket.trailingText)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(ticket.isOverdue
                        ? KitchenLinkV2Palette.Urgency.waitingText
                        : KitchenLinkV2Palette.Content.primary)
                    .kitchenLinkV2TabularNumbers()

                Spacer()

                if let actionTitle = ticket.advanceActionTitle {
                    Button(actionTitle) {
                        advance(ticket)
                    }
                    .font(KitchenLinkV2Typography.kitchenStatus)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .frame(minHeight: 44)
                    .padding(.horizontal, KitchenLinkV2Spacing.medium)
                    .background {
                        RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.compact,
                            style: .continuous
                        )
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1.5)
                    }
                    .disabled(isPerformingAction)
                    .accessibilityIdentifier("kitchen.advance.\(ticket.id)")
                }
            }
        }
        .padding(KitchenLinkV2Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .fill(KitchenLinkV2Palette.Surface.recessed)
        }
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: KitchenLinkV2Radius.card,
                topTrailingRadius: KitchenLinkV2Radius.card
            )
            .fill(ticket.status.urgency.symbolColor)
            .frame(height: 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(ticket.tableTitle). \(ticket.status.accessibilityLabel). \(ticket.trailingText)"
        )
        .accessibilityIdentifier("kitchen.ticket.\(ticket.id)")
    }

    private func advance(_ ticket: KitchenLinkV2KitchenTicket) {
        guard let order = relay.receivedOrders.first(where: { $0.id == ticket.id }),
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
        Task {
            _ = await KitchenLinkV2DemoOperationsSeeder.seed(store: store, relay: relay)
            isPerformingAction = false
        }
    }
}
