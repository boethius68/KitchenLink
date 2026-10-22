import SwiftUI

/// KL-PURCHASE-001: Betreiberansicht für Lieferantenbestellungen & Wareneingang (Blueprint §11 & Meilenstein 4).
public struct KitchenLinkV2PurchaseOrdersView: View {
    @State private var provider: KitchenLinkPurchaseOrderProviding = KitchenLinkPurchaseOrderDemoProvider()

    public enum FilterTab: String, CaseIterable, Identifiable {
        case active = "Offen / Unterwegs"
        case received = "Ware erhalten"
        case all = "Alle"

        public var id: String { rawValue }
    }

    @State private var selectedTab: FilterTab = .active
    @State private var orders: [KitchenLinkPurchaseOrder] = []
    @State private var showNewOrderSheet: Bool = false
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    public init(provider: KitchenLinkPurchaseOrderProviding? = nil) {
        if let custom = provider {
            _provider = State(initialValue: custom)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                tabSegmentedPicker
                ordersList
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Lieferantenbestellungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewOrderSheet = true
                } label: {
                    Label("Neu", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .task {
            await reloadData()
        }
        .sheet(isPresented: $showNewOrderSheet) {
            KitchenLinkNewPurchaseOrderSheet(provider: provider) {
                Task { await reloadData() }
            }
        }
    }

    // MARK: - Subviews

    private var tabSegmentedPicker: some View {
        HStack(spacing: KitchenLinkV2Spacing.xSmall) {
            ForEach(FilterTab.allCases) { tab in
                let count = countForTab(tab)
                let isSelected = selectedTab == tab
                Button {
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
        }
    }

    private var ordersList: some View {
        let filtered = filteredOrders
        return VStack(spacing: KitchenLinkV2Spacing.medium) {
            if filtered.isEmpty {
                emptyState
            } else {
                ForEach(filtered) { order in
                    orderCard(order)
                }
            }
        }
    }

    private func orderCard(_ order: KitchenLinkPurchaseOrder) -> some View {
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

                    Text(order.supplierName)
                        .font(KitchenLinkV2Typography.section)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                    if let contact = order.supplierContact {
                        Text(contact)
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                }

                Spacer()

                Text(order.formattedTotal)
                    .font(KitchenLinkV2Typography.section)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            }

            // Positionen
            VStack(alignment: .leading, spacing: 4) {
                ForEach(order.lines) { line in
                    HStack {
                        Text(line.ingredientName)
                            .font(KitchenLinkV2Typography.primaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Spacer()
                        Text(line.formattedQuantity)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                    }
                }

                if let notes = order.notes, !notes.isEmpty {
                    Text("„\(notes)“")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .italic()
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .padding(.top, 4)
                }
            }
            .padding(KitchenLinkV2Spacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                KitchenLinkV2Palette.Surface.recessed,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
            )

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
    private func cardActions(_ order: KitchenLinkPurchaseOrder) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            switch order.status {
            case .draft:
                Button {
                    Task {
                        try? await provider.sendPurchaseOrder(orderID: order.id)
                        await reloadData()
                    }
                } label: {
                    Label("Bestellung absenden ✉️", systemImage: "paperplane.fill")
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

            case .sent:
                Button {
                    Task {
                        try? await provider.receivePurchaseOrder(orderID: order.id)
                        await reloadData()
                    }
                } label: {
                    Label("Wareneingang buchen 📦", systemImage: "arrow.down.doc.fill")
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

            case .received:
                HStack {
                    Label("Ware vollständig eingebucht", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                    Spacer()
                }

            case .cancelled:
                HStack {
                    Label("Bestellung storniert", systemImage: "xmark.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Spacer()
                }
            }
        }
    }

    private func statusBadge(_ status: KitchenLinkPurchaseOrderStatus) -> some View {
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

    private func badgeBackground(_ status: KitchenLinkPurchaseOrderStatus) -> Color {
        switch status {
        case .draft: return KitchenLinkV2Palette.Surface.recessed
        case .sent: return KitchenLinkV2Palette.Action.persistentPrimary.opacity(0.25)
        case .received: return KitchenLinkV2Palette.Brand.grape.opacity(0.15)
        case .cancelled: return Color.red.opacity(0.12)
        }
    }

    private func badgeForeground(_ status: KitchenLinkPurchaseOrderStatus) -> Color {
        switch status {
        case .draft: return KitchenLinkV2Palette.Content.secondary
        case .sent: return Color.black
        case .received: return KitchenLinkV2Palette.Brand.grape
        case .cancelled: return Color.red
        }
    }

    private var emptyState: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            Image(systemName: "shippingbox")
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

    private var filteredOrders: [KitchenLinkPurchaseOrder] {
        switch selectedTab {
        case .active:
            return orders.filter { $0.status.isActive }
        case .received:
            return orders.filter { $0.status == .received }
        case .all:
            return orders
        }
    }

    private func countForTab(_ tab: FilterTab) -> Int {
        switch tab {
        case .active:
            return orders.filter { $0.status.isActive }.count
        case .received:
            return orders.filter { $0.status == .received }.count
        case .all:
            return orders.count
        }
    }

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            orders = try await provider.loadPurchaseOrders()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Neue Lieferantenbestellung Sheet

struct KitchenLinkNewPurchaseOrderSheet: View {
    let provider: KitchenLinkPurchaseOrderProviding
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var supplierName: String = "Kochberg Frischegroßhandel"
    @State private var orderNumber: String = "PO-\(Int.random(in: 1000...9999))"
    @State private var itemName: String = ""
    @State private var quantityText: String = ""
    @State private var unit: String = "kg"
    @State private var priceText: String = ""
    @State private var notes: String = ""
    @State private var lines: [KitchenLinkPurchaseOrderLine] = []
    @State private var errorMessage: String? = nil

    private let availableUnits = ["kg", "g", "l", "ml", "count"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Lieferant", text: $supplierName)
                    TextField("Bestellnummer", text: $orderNumber)
                    TextField("Notiz an Lieferanten", text: $notes)
                } header: {
                    Text("Lieferant & Kopfdaten")
                }

                Section {
                    ForEach(lines) { line in
                        HStack {
                            Text(line.ingredientName)
                            Spacer()
                            Text("\(line.quantity) \(line.unit)")
                                .font(.system(size: 14, weight: .semibold))
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Artikel / Zutat (z. B. Mehl)", text: $itemName)
                        HStack {
                            TextField("Menge", text: $quantityText)
                                .keyboardType(.decimalPad)
                            Picker("Einheit", selection: $unit) {
                                ForEach(availableUnits, id: \.self) { u in
                                    Text(u).tag(u)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        Button {
                            addLine()
                        } label: {
                            Label("Position hinzufügen", systemImage: "plus.circle.fill")
                                .font(KitchenLinkV2Typography.primaryButton)
                                .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                        }
                        .disabled(itemName.trimmingCharacters(in: .whitespaces).isEmpty || quantityText.isEmpty)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Bestellpositionen (\(lines.count))")
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Neue Bestellung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Entwurf anlegen") {
                        saveOrder()
                    }
                    .font(KitchenLinkV2Typography.primaryButton)
                    .disabled(lines.isEmpty)
                }
            }
        }
    }

    private func addLine() {
        let clean = quantityText.replacingOccurrences(of: ",", with: ".")
        guard let qty = Decimal(string: clean), qty > 0 else { return }

        let newLine = KitchenLinkPurchaseOrderLine(
            ingredientID: "custom-\(UUID().uuidString.prefix(6))",
            ingredientName: itemName.trimmingCharacters(in: .whitespaces),
            quantity: qty,
            unit: unit,
            pricePerUnitCents: 500
        )
        lines.append(newLine)
        itemName = ""
        quantityText = ""
    }

    private func saveOrder() {
        guard !lines.isEmpty else { return }
        Task {
            do {
                _ = try await provider.createPurchaseOrder(
                    supplierID: "supplier-\(UUID().uuidString.prefix(6))",
                    supplierName: supplierName.trimmingCharacters(in: .whitespaces),
                    orderNumber: orderNumber.trimmingCharacters(in: .whitespaces),
                    lines: lines,
                    expectedDate: Date().addingTimeInterval(48 * 3600),
                    notes: notes.isEmpty ? nil : notes
                )
                onComplete()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
