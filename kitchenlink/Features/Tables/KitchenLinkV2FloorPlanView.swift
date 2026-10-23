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
                        .font(KLTheme.Typography.operational(.subheadline, weight: isSelected ? .bold : .medium))
                        .padding(.horizontal, KitchenLinkV2Spacing.medium)
                        .padding(.vertical, 6)
                        .background(
                            isSelected ? Color.klTerracotta : Color.klSurface,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            isSelected ? Color.white : Color.klCharcoal
                        )
                        .overlay {
                            Capsule()
                                .stroke(Color.klBorder, lineWidth: 1)
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

            legendItem(color: Color.klEmerald, label: "Frei", count: freeCount)
            Divider().frame(height: 18)
            legendItem(color: Color.klTerracotta, label: "Belegt", count: occupiedCount)
            Divider().frame(height: 18)
            legendItem(color: Color.klAmber, label: "Reserviert", count: reservedCount)
        }
        .padding(.vertical, KitchenLinkV2Spacing.small)
        .padding(.horizontal, KitchenLinkV2Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(
            Color.klSurface,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                .stroke(Color.klBorder, lineWidth: 1)
        }
    }

    private func legendItem(color: Color, label: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text("\(label): \(count)")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(Color.klCharcoal)
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
                            .font(KLTheme.Typography.editorialTitle(.title3, weight: .semibold))
                            .foregroundStyle(Color.klCharcoal)

                        Text("\(table.seats) Plätze · \(table.areaOrDefault)")
                            .font(KLTheme.Typography.operational(.caption, weight: .medium))
                            .foregroundStyle(Color.klMuted)
                    }

                    Spacer()

                    tableShapeIcon(table.shape)
                }

                Divider()
                    .overlay(Color.klBorder)

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
        .foregroundStyle(Color.klMuted)
    }

    @ViewBuilder
    private func occupancyView(_ occupancy: KitchenLinkFloorPlanOccupancy) -> some View {
        switch occupancy {
        case .free:
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.klEmerald)
                    .frame(width: 6, height: 6)
                Text("Frei / Bereit")
                    .font(KLTheme.Typography.operational(.caption, weight: .semibold))
                    .foregroundStyle(Color.klEmerald)
            }
        case .occupied(_, let startedAt, let orderCount, let totalCents):
            let minutes = max(0, Int(Date().timeIntervalSince(startedAt) / 60))
            let euro = String(format: "%.2f €", Double(totalCents) / 100.0)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.klTerracotta)
                        .frame(width: 6, height: 6)
                    Text("Belegt · seit \(minutes) Min.")
                        .font(KLTheme.Typography.operational(.caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.klTerracotta)
                }
                Text("\(orderCount) Positionen · \(euro)")
                    .font(KLTheme.Typography.tabularMono(.caption, weight: .semibold))
                    .foregroundStyle(Color.klMuted)
            }
        case .reserved(let time, let guestName, let partySize):
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.klAmber)
                        .frame(width: 6, height: 6)
                    Text("Reserviert um \(time)")
                        .font(KLTheme.Typography.operational(.caption, weight: .bold).monospacedDigit())
                        .foregroundStyle(Color.klAmber)
                }
                Text("\(guestName) (\(partySize) P.)")
                    .font(KLTheme.Typography.operational(.caption, weight: .medium))
                    .foregroundStyle(Color.klMuted)
                    .lineLimit(1)
            }
        case .inactive:
            Text("Stillgelegt")
                .font(KLTheme.Typography.operational(.caption, weight: .regular))
                .foregroundStyle(Color.klMuted)
        }
    }

    private func tableBackgroundColor(_ occupancy: KitchenLinkFloorPlanOccupancy) -> Color {
        switch occupancy {
        case .free:
            return Color.klSurface
        case .occupied:
            return Color.klTerracotta.opacity(0.08)
        case .reserved:
            return Color.klAmber.opacity(0.08)
        case .inactive:
            return Color.klSubtle
        }
    }

    private func tableBorderColor(_ occupancy: KitchenLinkFloorPlanOccupancy) -> Color {
        switch occupancy {
        case .free:
            return Color.klBorder
        case .occupied:
            return Color.klTerracotta.opacity(0.4)
        case .reserved:
            return Color.klAmber.opacity(0.4)
        case .inactive:
            return Color.klBorder
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
