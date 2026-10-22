import SwiftUI

/// KL-DELIVERY-001: Betreiberansicht für Lieferbetrieb, Touren & Fahrer (Blueprint §12 & Meilenstein 3).
public struct KitchenLinkV2DeliveryView: View {
    @State private var provider: KitchenLinkDeliveryProviding = KitchenLinkDeliveryDemoProvider()

    public enum DeliveryTab: String, CaseIterable, Identifiable {
        case pending = "Bereit / Zuweisung"
        case active = "Unterwegs"
        case finished = "Abgeschlossen"

        public var id: String { rawValue }
    }

    @State private var selectedTab: DeliveryTab = .pending
    @State private var orders: [KitchenLinkDeliveryOrder] = []
    @State private var drivers: [KitchenLinkDeliveryDriver] = []
    @State private var areas: [KitchenLinkDeliveryArea] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Sheets
    @State private var selectedOrderForDriver: KitchenLinkDeliveryOrder? = nil
    @State private var selectedOrderForFailure: KitchenLinkDeliveryOrder? = nil
    @State private var showAreasSheet: Bool = false

    @Environment(\.openURL) private var openURL

    public init(provider: KitchenLinkDeliveryProviding? = nil) {
        if let customProvider = provider {
            _provider = State(initialValue: customProvider)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                tabSegmentedPicker
                summaryBar
                ordersList
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Lieferung & Touren")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: KitchenLinkV2Spacing.small) {
                    Button {
                        showAreasSheet = true
                    } label: {
                        Label("Liefergebiete", systemImage: "map")
                            .font(.system(size: 15, weight: .semibold))
                    }

                    Button {
                        Task { await reloadData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
        .task {
            await reloadData()
        }
        .sheet(item: $selectedOrderForDriver) { order in
            KitchenLinkAssignDriverSheet(
                order: order,
                drivers: drivers,
                onAssign: { driver in
                    Task {
                        try? await provider.assignDriver(
                            orderID: order.id,
                            driverID: driver.id,
                            driverName: driver.name
                        )
                        await reloadData()
                        selectedOrderForDriver = nil
                    }
                }
            )
        }
        .sheet(item: $selectedOrderForFailure) { order in
            KitchenLinkDeliveryFailureSheet(
                order: order,
                onConfirmFailure: { reason in
                    Task {
                        try? await provider.updateStatus(
                            orderID: order.id,
                            status: .failed,
                            failureReason: reason
                        )
                        await reloadData()
                        selectedOrderForFailure = nil
                    }
                }
            )
        }
        .sheet(isPresented: $showAreasSheet) {
            KitchenLinkDeliveryAreasSheet(areas: areas)
        }
    }

    // MARK: - Subviews

    private var tabSegmentedPicker: some View {
        HStack(spacing: KitchenLinkV2Spacing.xSmall) {
            ForEach(DeliveryTab.allCases) { tab in
                tabButton(for: tab)
            }
        }
    }

    private func tabButton(for tab: DeliveryTab) -> some View {
        let count = countForTab(tab)
        let isSelected = selectedTab == tab
        return Button {
            selectedTab = tab
        } label: {
            HStack(spacing: 6) {
                Text(tab.rawValue)
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            isSelected
                                ? Color.white.opacity(0.25)
                                : KitchenLinkV2Palette.Surface.recessed,
                            in: Capsule()
                        )
                }
            }
            .font(KitchenLinkV2Typography.primaryButton)
            .foregroundStyle(
                isSelected
                    ? Color.white
                    : KitchenLinkV2Palette.Content.secondary
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: 38)
            .background(
                isSelected
                    ? KitchenLinkV2Palette.Brand.grape
                    : KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    private var summaryBar: some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 2) {
                Text("FAHRER AKTIV")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.0)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                let activeDrivers = drivers.filter { $0.activeDeliveriesCount > 0 }.count
                Text("\(activeDrivers) von \(drivers.count)")
                    .font(KitchenLinkV2Typography.section)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("LIEFERUMSATZ HEUTE")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.0)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                let totalCents = orders.reduce(0) { $0 + $1.totalCents }
                let euros = Double(totalCents) / 100.0
                Text(String(format: "%.2f €", locale: Locale(identifier: "de_DE"), euros))
                    .font(KitchenLinkV2Typography.section)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            }
        }
        .padding(KitchenLinkV2Spacing.medium)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    private var ordersList: some View {
        let filtered = filteredOrders
        return VStack(spacing: KitchenLinkV2Spacing.medium) {
            if filtered.isEmpty {
                emptyState
            } else {
                ForEach(filtered) { order in
                    deliveryOrderCard(order)
                }
            }
        }
    }

    private func deliveryOrderCard(_ order: KitchenLinkDeliveryOrder) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(order.orderNumber)
                            .font(.system(size: 15, weight: .bold, design: .monospaced))
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)

                        statusBadge(order.status)
                    }

                    Text(order.recipientName)
                        .font(KitchenLinkV2Typography.section)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(order.formattedTotal)
                        .font(KitchenLinkV2Typography.section)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                    paymentBadge(order.paymentMethod, totalCents: order.totalCents)
                }
            }

            // Adresse
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14))
                    .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(order.address.street) \(order.address.houseNumber)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                    Text("\(order.address.postalCode) \(order.address.city)")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

                    if let floorNote = order.address.floorOrNote, !floorNote.isEmpty {
                        Text(floorNote)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .padding(.top, 1)
                    }
                }

                Spacer()

                if let mapURL = order.address.appleMapsURL {
                    Button {
                        openURL(mapURL)
                    } label: {
                        Label("Karte", systemImage: "arrow.triangle.turn.up.right.circle.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                KitchenLinkV2Palette.Surface.recessed,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Speisen & Notiz
            VStack(alignment: .leading, spacing: 4) {
                Text(order.itemsSummary)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .lineLimit(2)

                if let note = order.customerNote, !note.isEmpty {
                    Text("„\(note)“")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .padding(.top, 2)
                }
            }
            .padding(KitchenLinkV2Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                KitchenLinkV2Palette.Surface.recessed,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
            )

            // Fahrer & Status Info
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                if let driver = order.driverName {
                    Label(driver, systemImage: "person.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                } else {
                    Label("Kein Fahrer zugewiesen", systemImage: "person.slash")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }

                Spacer()

                if order.status == .outForDelivery, let minutes = order.transitDurationMinutes {
                    Label("Seit \(minutes) Min. unterwegs", systemImage: "clock")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                } else if order.status == .failed, let reason = order.failureReason {
                    Label(reason, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.red)
                }
            }

            // Aktionen je Status
            cardActions(order)
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
    private func cardActions(_ order: KitchenLinkDeliveryOrder) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            switch order.status {
            case .pending:
                Button {
                    selectedOrderForDriver = order
                } label: {
                    Label("Fahrer zuweisen", systemImage: "person.badge.plus")
                        .font(KitchenLinkV2Typography.primaryButton)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            KitchenLinkV2Palette.Action.persistentPrimary,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

            case .assigned:
                Button {
                    selectedOrderForDriver = order
                } label: {
                    Text("Fahrer wechseln")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .frame(minHeight: 40)
                        .padding(.horizontal, 12)
                        .background(
                            KitchenLinkV2Palette.Surface.recessed,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        try? await provider.updateStatus(orderID: order.id, status: .outForDelivery, failureReason: nil)
                        await reloadData()
                    }
                } label: {
                    Label("Tour starten", systemImage: "bicycle")
                        .font(KitchenLinkV2Typography.primaryButton)
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            KitchenLinkV2Palette.Action.persistentPrimary,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

            case .outForDelivery:
                Button {
                    selectedOrderForFailure = order
                } label: {
                    Text("Problem")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(.red)
                        .frame(minHeight: 40)
                        .padding(.horizontal, 12)
                        .background(
                            Color.red.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        try? await provider.updateStatus(orderID: order.id, status: .delivered, failureReason: nil)
                        await reloadData()
                    }
                } label: {
                    Label("Zugestellt ✓", systemImage: "checkmark")
                        .font(KitchenLinkV2Typography.primaryButton)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 40)
                        .background(
                            KitchenLinkV2Palette.Brand.grape,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                }
                .buttonStyle(.plain)

            case .delivered:
                HStack {
                    Label("Erfolgreich zugestellt", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                    Spacer()
                    if let delivered = order.deliveredAt {
                        Text(KitchenLinkReservationDateHelper.formatTime(delivered))
                            .font(.system(size: 13))
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                }
                .padding(.top, 4)

            case .failed:
                HStack {
                    Label("Zustellung abgebrochen", systemImage: "xmark.octagon.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.red)
                    Spacer()
                }
                .padding(.top, 4)
            }
        }
    }

    private func statusBadge(_ status: KitchenLinkDeliveryStatus) -> some View {
        HStack(spacing: 4) {
            Image(systemName: status.systemIcon)
                .font(.system(size: 10))
            Text(status.title)
                .font(.system(size: 11, weight: .bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            badgeBackground(status),
            in: Capsule()
        )
        .foregroundStyle(badgeForeground(status))
    }

    private func badgeBackground(_ status: KitchenLinkDeliveryStatus) -> Color {
        switch status {
        case .pending: return KitchenLinkV2Palette.Surface.recessed
        case .assigned: return KitchenLinkV2Palette.Brand.grape.opacity(0.12)
        case .outForDelivery: return KitchenLinkV2Palette.Action.persistentPrimary.opacity(0.25)
        case .delivered: return KitchenLinkV2Palette.Brand.grape.opacity(0.15)
        case .failed: return Color.red.opacity(0.12)
        }
    }

    private func badgeForeground(_ status: KitchenLinkDeliveryStatus) -> Color {
        switch status {
        case .pending: return KitchenLinkV2Palette.Content.secondary
        case .assigned: return KitchenLinkV2Palette.Brand.grape
        case .outForDelivery: return Color.black
        case .delivered: return KitchenLinkV2Palette.Brand.grape
        case .failed: return Color.red
        }
    }

    private func paymentBadge(_ payment: KitchenLinkDeliveryPaymentMethod, totalCents: Int) -> some View {
        Group {
            if payment.isCollectOnDelivery {
                Text(payment.title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: Capsule())
            } else {
                Text(payment.title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            Image(systemName: "bicycle")
                .font(.system(size: 36))
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            Text("Keine Bestellungen in dieser Ansicht")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Helpers

    private var filteredOrders: [KitchenLinkDeliveryOrder] {
        switch selectedTab {
        case .pending:
            return orders.filter { $0.status == .pending || $0.status == .assigned }
        case .active:
            return orders.filter { $0.status == .outForDelivery }
        case .finished:
            return orders.filter { $0.status == .delivered || $0.status == .failed }
        }
    }

    private func countForTab(_ tab: DeliveryTab) -> Int {
        switch tab {
        case .pending:
            return orders.filter { $0.status == .pending || $0.status == .assigned }.count
        case .active:
            return orders.filter { $0.status == .outForDelivery }.count
        case .finished:
            return orders.filter { $0.status == .delivered || $0.status == .failed }.count
        }
    }

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let loadedOrders = provider.loadDeliveries()
            async let loadedDrivers = provider.loadAvailableDrivers()
            async let loadedAreas = provider.loadDeliveryAreas()
            (orders, drivers, areas) = try await (loadedOrders, loadedDrivers, loadedAreas)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Fahrer-Zuweisung Sheet

struct KitchenLinkAssignDriverSheet: View {
    let order: KitchenLinkDeliveryOrder
    let drivers: [KitchenLinkDeliveryDriver]
    let onAssign: (KitchenLinkDeliveryDriver) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.orderNumber)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                        Text(order.address.singleLine)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Lieferziel")
                }

                Section {
                    ForEach(drivers) { driver in
                        Button {
                            onAssign(driver)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(driver.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                                    if let phone = driver.phone {
                                        Text(phone)
                                            .font(.system(size: 13))
                                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                    }
                                }

                                Spacer()

                                if driver.activeDeliveriesCount > 0 {
                                    Text("\(driver.activeDeliveriesCount) unterwegs")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(KitchenLinkV2Palette.Brand.grape.opacity(0.12), in: Capsule())
                                } else {
                                    Text("Verfügbar")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Verfügbare Fahrer")
                }
            }
            .navigationTitle("Fahrer zuweisen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Problem melden Sheet

struct KitchenLinkDeliveryFailureSheet: View {
    let order: KitchenLinkDeliveryOrder
    let onConfirmFailure: (String) -> Void

    @State private var selectedReason: String = "Kunde nicht angetroffen"
    @State private var customNote: String = ""
    @Environment(\.dismiss) private var dismiss

    private let standardReasons = [
        "Kunde nicht angetroffen",
        "Adresse unauffindbar",
        "Kunde hat Annahme verweigert",
        "Storniert durch Gast",
        "Panne / Verkehrsunfall"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(order.orderNumber) · \(order.recipientName)")
                            .font(.system(size: 15, weight: .semibold))
                        Text(order.address.singleLine)
                            .font(.system(size: 13))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }
                } header: {
                    Text("Bestellung")
                }

                Section {
                    ForEach(standardReasons, id: \.self) { reason in
                        HStack {
                            Text(reason)
                                .font(.system(size: 15))
                            Spacer()
                            if selectedReason == reason {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedReason = reason
                        }
                    }

                    TextField("Zusätzliche Notiz (optional)", text: $customNote)
                        .font(.system(size: 14))
                } header: {
                    Text("Grund für fehlgeschlagene Zustellung")
                }
            }
            .navigationTitle("Problem melden")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Als Fehlgeschlagen erfassen") {
                        let finalReason = customNote.trimmingCharacters(in: .whitespaces).isEmpty
                            ? selectedReason
                            : "\(selectedReason): \(customNote.trimmingCharacters(in: .whitespaces))"
                        onConfirmFailure(finalReason)
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }
}

// MARK: - Liefergebiete Sheet

struct KitchenLinkDeliveryAreasSheet: View {
    let areas: [KitchenLinkDeliveryArea]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(areas) { area in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(area.postalCode)
                                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                                    Text(area.city)
                                        .font(.system(size: 15, weight: .medium))
                                }
                                Text("Mindestbestellwert: \(area.formattedMinOrder)")
                                    .font(.system(size: 13))
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 2) {
                                Text(area.formattedFee)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                                Text("Liefergebühr")
                                    .font(.system(size: 11))
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                } header: {
                    Text("Aktive Postleitzahlen & Konditionen")
                } footer: {
                    Text("In der Sandbox-Beta sind Liefergebiete zur Validierung von Mindestbestellwerten vorkonfiguriert.")
                }
            }
            .navigationTitle("Liefergebiete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
