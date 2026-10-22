import SwiftUI

/// KL-TABLE-003: Grafischer Tischplan, Raumstatus & Tisch-Transfer (Blueprint §10).
public struct KitchenLinkV2FloorPlanView: View {
    @State private var provider: KitchenLinkFloorPlanProviding = KitchenLinkFloorPlanDemoProvider()
    @State private var tables: [KitchenLinkFloorPlanTable] = []
    @State private var selectedArea: String = "Alle"
    @State private var selectedTable: KitchenLinkFloorPlanTable? = nil
    @State private var transferSourceTable: KitchenLinkFloorPlanTable? = nil
    @State private var mergeSourceTable: KitchenLinkFloorPlanTable? = nil
    @State private var isLoading: Bool = false
    @State private var statusNotice: String? = nil

    public init(provider: KitchenLinkFloorPlanProviding? = nil) {
        if let customProvider = provider {
            _provider = State(initialValue: customProvider)
        }
    }

    private var availableAreas: [String] {
        var areas = ["Alle"]
        let distinct = Set(tables.map(\.areaOrDefault)).sorted()
        areas.append(contentsOf: distinct)
        return areas
    }

    private var filteredTables: [KitchenLinkFloorPlanTable] {
        if selectedArea == "Alle" {
            return tables
        }
        return tables.filter { $0.areaOrDefault == selectedArea }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                areaPicker
                legendBar
                tableGrid
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Tischplan")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await reloadData()
        }
        .sheet(item: $selectedTable) { table in
            tableActionSheet(table)
        }
        .sheet(item: $transferSourceTable) { source in
            transferSelectionSheet(source)
        }
        .sheet(item: $mergeSourceTable) { source in
            mergeSelectionSheet(source)
        }
    }

    // =========================================================================
    // HEADER & FILTER
    // =========================================================================

    private var areaPicker: some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            ForEach(availableAreas, id: \.self) { area in
                let isSelected = selectedArea == area
                Button {
                    selectedArea = area
                } label: {
                    Text(area)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .padding(.horizontal, KitchenLinkV2Spacing.medium)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Surface.raised,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            isSelected ? Color.white : KitchenLinkV2Palette.Content.primary
                        )
                        .overlay {
                            Capsule()
                                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private var legendBar: some View {
        HStack(spacing: KitchenLinkV2Spacing.large) {
            let freeCount = tables.filter { $0.occupancy.isFree }.count
            let occupiedCount = tables.filter { $0.occupancy.isOccupied }.count
            let reservedCount = tables.filter { $0.occupancy.isReserved }.count

            legendItem(color: KitchenLinkV2Palette.Urgency.freshSymbol, label: "Frei", count: freeCount)
            Divider().frame(height: 18)
            legendItem(color: KitchenLinkV2Palette.Brand.grape, label: "Belegt", count: occupiedCount)
            Divider().frame(height: 18)
            legendItem(color: KitchenLinkV2Palette.Urgency.waitingSymbol, label: "Reserviert", count: reservedCount)
        }
        .padding(.vertical, KitchenLinkV2Spacing.small)
        .padding(.horizontal, KitchenLinkV2Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
        }
    }

    // =========================================================================
    // TISCH-GRID
    // =========================================================================

    private var tableGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: KitchenLinkV2Spacing.medium),
                GridItem(.flexible(), spacing: KitchenLinkV2Spacing.medium)
            ],
            spacing: KitchenLinkV2Spacing.medium
        ) {
            ForEach(filteredTables) { table in
                tableCard(table)
            }
        }
    }

    private func tableCard(_ table: KitchenLinkFloorPlanTable) -> some View {
        Button {
            selectedTable = table
        } label: {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(table.headline)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                        Text("\(table.seats) Plätze · \(table.areaOrDefault)")
                            .font(.system(size: 12))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }

                    Spacer()

                    tableShapeIcon(table.shape)
                }

                Divider()
                    .overlay(KitchenLinkV2Palette.Border.subtle)

                occupancyView(table.occupancy)
            }
            .padding(KitchenLinkV2Spacing.medium)
            .frame(maxWidth: .infinity, minHeight: 110, alignment: .topLeading)
            .background(
                tableBackgroundColor(table.occupancy),
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    .stroke(tableBorderColor(table.occupancy), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    private func tableShapeIcon(_ shape: KitchenLinkTableShape) -> some View {
        Group {
            switch shape {
            case .round:
                Image(systemName: "circle")
            case .square:
                Image(systemName: "square")
            case .rectangle:
                Image(systemName: "rectangle")
            }
        }
        .font(.system(size: 14))
        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
    }

    @ViewBuilder
    private func occupancyView(_ occupancy: KitchenLinkFloorPlanOccupancy) -> some View {
        switch occupancy {
        case .free:
            HStack(spacing: 4) {
                Circle()
                    .fill(KitchenLinkV2Palette.Urgency.freshSymbol)
                    .frame(width: 6, height: 6)
                Text("Frei / Bereit")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
            }
        case .occupied(_, let startedAt, let orderCount, let totalCents):
            let minutes = max(0, Int(Date().timeIntervalSince(startedAt) / 60))
            let euro = String(format: "%.2f €", Double(totalCents) / 100.0)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(KitchenLinkV2Palette.Brand.grape)
                        .frame(width: 6, height: 6)
                    Text("Belegt · seit \(minutes) Min.")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                }
                Text("\(orderCount) Positionen · \(euro)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
        case .reserved(let time, let guestName, let partySize):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(KitchenLinkV2Palette.Urgency.waitingSymbol)
                        .frame(width: 6, height: 6)
                    Text("Reserviert um \(time)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                }
                Text("\(guestName) (\(partySize) P.)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .lineLimit(1)
            }
        case .inactive:
            Text("Stillgelegt")
                .font(.system(size: 12))
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
        }
    }

    private func tableBackgroundColor(_ occupancy: KitchenLinkFloorPlanOccupancy) -> Color {
        switch occupancy {
        case .free:
            return KitchenLinkV2Palette.Surface.raised
        case .occupied:
            return KitchenLinkV2Palette.Brand.grape.opacity(0.06)
        case .reserved:
            return KitchenLinkV2Palette.Urgency.waitingSymbol.opacity(0.08)
        case .inactive:
            return KitchenLinkV2Palette.Surface.recessed
        }
    }

    private func tableBorderColor(_ occupancy: KitchenLinkFloorPlanOccupancy) -> Color {
        switch occupancy {
        case .free:
            return KitchenLinkV2Palette.Border.subtle
        case .occupied:
            return KitchenLinkV2Palette.Brand.grape.opacity(0.3)
        case .reserved:
            return KitchenLinkV2Palette.Urgency.waitingSymbol.opacity(0.4)
        case .inactive:
            return KitchenLinkV2Palette.Border.subtle
        }
    }

    // =========================================================================
    // TISCH-AKTIONEN SHEET
    // =========================================================================

    private func tableActionSheet(_ table: KitchenLinkFloorPlanTable) -> some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(table.headline)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text("\(table.areaOrDefault) · \(table.seats) Plätze · Form: \(table.shape.title)")
                        .font(.system(size: 14))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }

                Divider()

                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                    Text("Aktueller Status:")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    occupancyView(table.occupancy)
                }
                .padding(KitchenLinkV2Spacing.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                )

                Spacer()

                // Aktionen
                VStack(spacing: KitchenLinkV2Spacing.medium) {
                    if table.occupancy.isOccupied {
                        Button {
                            selectedTable = nil
                            transferSourceTable = table
                        } label: {
                            Label("Tisch umsetzen (Transfer)", systemImage: "arrow.right.arrow.left")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    KitchenLinkV2Palette.Brand.grape,
                                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                                )
                                .foregroundStyle(Color.white)
                        }
                        .buttonStyle(.plain)

                        Button {
                            selectedTable = nil
                            mergeSourceTable = table
                        } label: {
                            Label("Tische zusammenlegen", systemImage: "link")
                                .font(.system(size: 14, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    KitchenLinkV2Palette.Surface.recessed,
                                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                                )
                                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        selectedTable = nil
                    } label: {
                        Text("Schließen")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                KitchenLinkV2Palette.Surface.raised,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(KitchenLinkV2Spacing.large)
            .navigationTitle("Tisch-Details")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // =========================================================================
    // UMSETZEN & ZUSAMMENLEGEN SHEETS
    // =========================================================================

    private func transferSelectionSheet(_ source: KitchenLinkFloorPlanTable) -> some View {
        let freeTables = tables.filter { $0.id != source.id && $0.occupancy.isFree }

        return NavigationStack {
            List {
                Section("Gäste von \(source.headline) umsetzen auf:") {
                    if freeTables.isEmpty {
                        Text("Keine freien Tische im Lokal verfügbar.")
                            .font(.system(size: 14))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    } else {
                        ForEach(freeTables) { target in
                            Button {
                                Task {
                                    try? await provider.transferSession(
                                        fromTableID: source.id,
                                        toTableID: target.id
                                    )
                                    await reloadData()
                                    transferSourceTable = nil
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(target.headline)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                                        Text("\(target.areaOrDefault) · \(target.seats) Plätze")
                                            .font(.system(size: 12))
                                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(KitchenLinkV2Palette.Action.persistentPrimary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tisch umsetzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { transferSourceTable = nil }
                }
            }
        }
    }

    private func mergeSelectionSheet(_ source: KitchenLinkFloorPlanTable) -> some View {
        let otherOccupied = tables.filter { $0.id != source.id && $0.occupancy.isOccupied }

        return NavigationStack {
            List {
                Section("Tisch \(source.headline) zusammenlegen mit:") {
                    if otherOccupied.isEmpty {
                        Text("Keine weiteren belegten Tische zum Zusammenlegen verfügbar.")
                            .font(.system(size: 14))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    } else {
                        ForEach(otherOccupied) { target in
                            Button {
                                Task {
                                    try? await provider.mergeTables(
                                        sourceTableID: source.id,
                                        targetTableID: target.id
                                    )
                                    await reloadData()
                                    mergeSourceTable = nil
                                }
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(target.headline)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                                        Text("\(target.areaOrDefault) · \(target.seats) Plätze")
                                            .font(.system(size: 12))
                                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "link.circle.fill")
                                        .font(.system(size: 20))
                                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tische zusammenlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { mergeSourceTable = nil }
                }
            }
        }
    }

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            tables = try await provider.loadFloorPlan()
        } catch {
            statusNotice = error.localizedDescription
        }
    }
}
