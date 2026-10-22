import SwiftUI

/// KL-RES-001 & KL-RES-002: Reservierungsübersicht, Tischzuweisung & Warteliste (Blueprint §10).
public struct KitchenLinkV2ReservationsView: View {
    @State private var provider: KitchenLinkReservationsProviding = KitchenLinkReservationsDemoProvider()
    @State private var waitlistProvider: KitchenLinkWaitlistProviding = KitchenLinkWaitlistDemoProvider()

    public enum SectionMode: String, CaseIterable, Identifiable {
        case reservations = "Reservierungen"
        case waitlist = "Warteliste"

        public var id: String { rawValue }
    }

    @State private var sectionMode: SectionMode = .reservations

    // Reservierungs-Status
    @State private var reservations: [KitchenLinkReservation] = []
    @State private var selectedDate: String = KitchenLinkReservationDateHelper.todayDateString()
    @State private var selectedFilter: ReservationFilter = .all
    @State private var showNewReservationSheet: Bool = false
    @State private var selectedReservationForSeating: KitchenLinkReservation? = nil

    // Wartelisten-Status
    @State private var waitlistEntries: [KitchenLinkWaitlistEntry] = []
    @State private var showNewWaitlistSheet: Bool = false
    @State private var selectedWaitlistForSeating: KitchenLinkWaitlistEntry? = nil

    // Gemeinsame Tischzuweisung
    @State private var assigningTableNumber: String = ""
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    public enum ReservationFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case confirmed = "Bestätigt"
        case seated = "Platziert"
        case terminal = "Erledigt"

        public var id: String { rawValue }
    }

    public init(
        provider: KitchenLinkReservationsProviding? = nil,
        waitlistProvider: KitchenLinkWaitlistProviding? = nil
    ) {
        if let customProvider = provider {
            _provider = State(initialValue: customProvider)
        }
        if let customWaitlist = waitlistProvider {
            _waitlistProvider = State(initialValue: customWaitlist)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                modeSegmentedPicker

                if sectionMode == .reservations {
                    dateSelector
                    summaryBar
                    filterChips
                    reservationList
                } else {
                    waitlistSummaryBar
                    waitlistList
                }
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle(sectionMode == .reservations ? "Reservierungen" : "Warteliste")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if sectionMode == .reservations {
                        showNewReservationSheet = true
                    } else {
                        showNewWaitlistSheet = true
                    }
                } label: {
                    Label("Neu", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .task(id: selectedDate) {
            await reloadData()
        }
        .task(id: sectionMode) {
            await reloadData()
        }
        .sheet(isPresented: $showNewReservationSheet) {
            KitchenLinkNewReservationSheet(
                provider: provider,
                initialDate: selectedDate
            ) {
                Task { await reloadData() }
            }
        }
        .sheet(isPresented: $showNewWaitlistSheet) {
            KitchenLinkNewWaitlistSheet(
                provider: waitlistProvider
            ) {
                Task { await reloadData() }
            }
        }
        .alert(
            "Tisch zuweisen & Gäste platzieren",
            isPresented: Binding(
                get: { selectedReservationForSeating != nil || selectedWaitlistForSeating != nil },
                set: { if !$0 {
                    selectedReservationForSeating = nil
                    selectedWaitlistForSeating = nil
                }}
            )
        ) {
            TextField("Tischnummer (z. B. 4)", text: $assigningTableNumber)
                .keyboardType(.numberPad)
            Button("Platzieren") {
                let table = assigningTableNumber.trimmingCharacters(in: .whitespaces)
                let tableID = table.isEmpty ? nil : table

                if let res = selectedReservationForSeating {
                    Task {
                        try? await provider.updateStatus(
                            reservationID: res.id,
                            status: .seated,
                            tableID: tableID
                        )
                        await reloadData()
                        selectedReservationForSeating = nil
                        assigningTableNumber = ""
                    }
                } else if let wait = selectedWaitlistForSeating {
                    Task {
                        try? await waitlistProvider.updateStatus(
                            entryID: wait.id,
                            status: .seated,
                            tableID: tableID
                        )
                        await reloadData()
                        selectedWaitlistForSeating = nil
                        assigningTableNumber = ""
                    }
                }
            }
            Button("Abbrechen", role: .cancel) {
                selectedReservationForSeating = nil
                selectedWaitlistForSeating = nil
                assigningTableNumber = ""
            }
        } message: {
            if let res = selectedReservationForSeating {
                Text("Gäste \(res.guestName) (\(res.partySize) Personen) auf welchen Tisch platzieren?")
            } else if let wait = selectedWaitlistForSeating {
                Text("Walk-in \(wait.guestName) (\(wait.partySize) Personen) auf welchen Tisch platzieren?")
            }
        }
    }

    private var modeSegmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(SectionMode.allCases) { mode in
                let isSelected = sectionMode == mode
                Button {
                    sectionMode = mode
                } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            isSelected ? KitchenLinkV2Palette.Brand.grape : Color.clear,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control - 2, style: .continuous)
                        )
                        .foregroundStyle(
                            isSelected ? Color.white : KitchenLinkV2Palette.Content.primary
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            KitchenLinkV2Palette.Surface.recessed,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
        )
    }

    // =========================================================================
    // RESERVIERUNGEN BEREICH
    // =========================================================================

    private var dateSelector: some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            let today = KitchenLinkReservationDateHelper.todayDateString()
            let tomorrow = KitchenLinkReservationDateHelper.tomorrowDateString()

            dateTabButton(title: "Heute", date: today)
            dateTabButton(title: "Morgen", date: tomorrow)

            Spacer()

            Text(KitchenLinkReservationDateHelper.formattedGermanDate(selectedDate))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .padding(.vertical, 4)
    }

    private func dateTabButton(title: String, date: String) -> some View {
        let isSelected = selectedDate == date
        return Button {
            selectedDate = date
        } label: {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, KitchenLinkV2Spacing.medium)
                .padding(.vertical, KitchenLinkV2Spacing.small)
                .background(
                    isSelected
                        ? KitchenLinkV2Palette.Brand.grape
                        : KitchenLinkV2Palette.Surface.raised,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                )
                .foregroundStyle(
                    isSelected
                        ? Color.white
                        : KitchenLinkV2Palette.Content.primary
                )
        }
        .buttonStyle(.plain)
    }

    private var summaryBar: some View {
        HStack(spacing: KitchenLinkV2Spacing.large) {
            let totalGuests = filteredReservations.reduce(0) { $0 + $1.partySize }
            let openCount = filteredReservations.filter { $0.status == .confirmed }.count
            let seatedCount = filteredReservations.filter { $0.status == .seated }.count

            summaryItem(label: "Gäste gesamt", value: "\(totalGuests)")
            Divider().frame(height: 24)
            summaryItem(label: "Bestätigt", value: "\(openCount)")
            Divider().frame(height: 24)
            summaryItem(label: "Platziert", value: "\(seatedCount)")
        }
        .padding(KitchenLinkV2Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    private func summaryItem(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
            Text(label)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var filterChips: some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            ForEach(ReservationFilter.allCases, id: \.rawValue) { filter in
                let isSelected = selectedFilter == filter
                Button {
                    selectedFilter = filter
                } label: {
                    Text(filter.rawValue)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .padding(.horizontal, KitchenLinkV2Spacing.medium)
                        .padding(.vertical, 6)
                        .background(
                            isSelected
                                ? KitchenLinkV2Palette.Brand.grape
                                : KitchenLinkV2Palette.Surface.raised,
                            in: Capsule()
                        )
                        .foregroundStyle(
                            isSelected
                                ? Color.white
                                : KitchenLinkV2Palette.Content.primary
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

    private var filteredReservations: [KitchenLinkReservation] {
        reservations.filter { res in
            switch selectedFilter {
            case .all:
                return true
            case .confirmed:
                return res.status == .confirmed
            case .seated:
                return res.status == .seated
            case .terminal:
                return res.status.isTerminal
            }
        }
    }

    private var reservationList: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            if filteredReservations.isEmpty {
                VStack(spacing: KitchenLinkV2Spacing.small) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 36))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Text("Keine Reservierungen")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Für diesen Tag liegen keine Einträge in der gewählten Ansicht vor.")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, KitchenLinkV2Spacing.xxLarge)
            } else {
                ForEach(filteredReservations) { res in
                    reservationCard(res)
                }
            }
        }
    }

    private func reservationCard(_ res: KitchenLinkReservation) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Text(res.reservationTime)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                        Text("· \(res.partySize) \(res.partySize == 1 ? "Gast" : "Gäste")")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }

                    Text(res.guestName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }

                Spacer()

                statusBadge(res.status)
            }

            HStack(spacing: KitchenLinkV2Spacing.small) {
                Label(res.area, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

                if let table = res.tableLabel {
                    Text("·")
                    Label(table, systemImage: "table.furniture")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                }

                Spacer()

                Text(res.referenceCode)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }

            if let special = res.specialRequests, !special.isEmpty {
                HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingSymbol)
                    Text(special)
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                }
                .padding(KitchenLinkV2Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                )
            }

            // Aktionen je nach Status
            HStack(spacing: KitchenLinkV2Spacing.small) {
                if res.status == .confirmed {
                    Button {
                        selectedReservationForSeating = res
                    } label: {
                        Text("Gäste platzieren")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                KitchenLinkV2Palette.Action.persistentPrimary,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            try? await provider.updateStatus(
                                reservationID: res.id,
                                status: .noShow,
                                tableID: nil
                            )
                            await reloadData()
                        }
                    } label: {
                        Text("No-Show")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                KitchenLinkV2Palette.Surface.recessed,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }
                    .buttonStyle(.plain)
                } else if res.status == .seated {
                    Button {
                        Task {
                            try? await provider.updateStatus(
                                reservationID: res.id,
                                status: .completed,
                                tableID: res.tableID
                            )
                            await reloadData()
                        }
                    } label: {
                        Text("Besuch abschließen")
                            .font(.system(size: 13, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                KitchenLinkV2Palette.Surface.recessed,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    }
                    .buttonStyle(.plain)
                }
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

    private func statusBadge(_ status: KitchenLinkReservationStatus) -> some View {
        let (color, textColor) = badgeColors(for: status)
        return Text(status.title)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
            .foregroundStyle(textColor)
    }

    private func badgeColors(for status: KitchenLinkReservationStatus) -> (Color, Color) {
        switch status {
        case .confirmed:
            return (KitchenLinkV2Palette.Surface.recessed, KitchenLinkV2Palette.Content.primary)
        case .seated:
            return (KitchenLinkV2Palette.Action.persistentPrimary.opacity(0.35), KitchenLinkV2Palette.Brand.grape)
        case .completed:
            return (KitchenLinkV2Palette.Urgency.freshSymbol.opacity(0.15), KitchenLinkV2Palette.Urgency.freshText)
        case .cancelled, .noShow:
            return (KitchenLinkV2Palette.Urgency.criticalSymbol.opacity(0.15), KitchenLinkV2Palette.Urgency.criticalText)
        }
    }

    // =========================================================================
    // WARTELISTE BEREICH (KL-RES-002)
    // =========================================================================

    private var waitlistSummaryBar: some View {
        HStack(spacing: KitchenLinkV2Spacing.large) {
            let totalWaitingGuests = waitlistEntries.reduce(0) { $0 + $1.partySize }
            let notifiedCount = waitlistEntries.filter { $0.status == .notified }.count
            let overdueCount = waitlistEntries.filter { $0.isOverdue() }.count

            summaryItem(label: "Wartende Gäste", value: "\(totalWaitingGuests)")
            Divider().frame(height: 24)
            summaryItem(label: "Benachrichtigt", value: "\(notifiedCount)")
            Divider().frame(height: 24)
            summaryItem(label: "Überfällig", value: "\(overdueCount)")
        }
        .padding(KitchenLinkV2Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    private var waitlistList: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            if waitlistEntries.isEmpty {
                VStack(spacing: KitchenLinkV2Spacing.small) {
                    Image(systemName: "person.2.badge.gearshape")
                        .font(.system(size: 36))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Text("Warteliste ist leer")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Zurzeit warten keine spontanen Gäste auf einen Tisch.")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, KitchenLinkV2Spacing.xxLarge)
            } else {
                ForEach(waitlistEntries) { entry in
                    waitlistCard(entry)
                }
            }
        }
    }

    private func waitlistCard(_ entry: KitchenLinkWaitlistEntry) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Text("\(entry.partySize) \(entry.partySize == 1 ? "Gast" : "Gäste")")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                        Text("· Wartezeit ca. \(entry.estimatedWaitMinutes) Min.")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }

                    Text(entry.guestName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }

                Spacer()

                waitlistStatusBadge(entry)
            }

            HStack(spacing: KitchenLinkV2Spacing.small) {
                Label(entry.area, systemImage: "mappin.and.ellipse")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

                if let phone = entry.guestPhone, !phone.isEmpty {
                    Text("·")
                    Label(phone, systemImage: "phone")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }

                Spacer()

                let elapsed = entry.elapsedMinutes()
                Text("wartet seit \(elapsed) Min.")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(
                        entry.isOverdue()
                            ? KitchenLinkV2Palette.Urgency.criticalText
                            : KitchenLinkV2Palette.Content.secondary
                    )
            }

            if let notes = entry.notes, !notes.isEmpty {
                HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                    Image(systemName: "note.text")
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Text(notes)
                        .font(.system(size: 13))
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }
                .padding(KitchenLinkV2Spacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.compact, style: .continuous)
                )
            }

            // Aktionen
            HStack(spacing: KitchenLinkV2Spacing.small) {
                Button {
                    selectedWaitlistForSeating = entry
                } label: {
                    Text("Tisch zuweisen & platzieren")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            KitchenLinkV2Palette.Action.persistentPrimary,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                        .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                }
                .buttonStyle(.plain)

                if entry.status == .waiting {
                    Button {
                        Task {
                            try? await waitlistProvider.updateStatus(
                                entryID: entry.id,
                                status: .notified,
                                tableID: nil
                            )
                            await reloadData()
                        }
                    } label: {
                        Text("Benachrichtigen")
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                KitchenLinkV2Palette.Surface.recessed,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task {
                        try? await waitlistProvider.updateStatus(
                            entryID: entry.id,
                            status: .cancelled,
                            tableID: nil
                        )
                        await reloadData()
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            KitchenLinkV2Palette.Surface.recessed,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        )
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
                .buttonStyle(.plain)
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

    private func waitlistStatusBadge(_ entry: KitchenLinkWaitlistEntry) -> some View {
        let title = entry.status.title
        let isNotified = entry.status == .notified
        let isOverdue = entry.isOverdue()

        let bgColor: Color = isNotified
            ? KitchenLinkV2Palette.Action.persistentPrimary.opacity(0.35)
            : (isOverdue ? KitchenLinkV2Palette.Urgency.criticalSymbol.opacity(0.15) : KitchenLinkV2Palette.Surface.recessed)
        let fgColor: Color = isNotified
            ? KitchenLinkV2Palette.Brand.grape
            : (isOverdue ? KitchenLinkV2Palette.Urgency.criticalText : KitchenLinkV2Palette.Content.primary)

        return Text(title)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor, in: Capsule())
            .foregroundStyle(fgColor)
    }

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if sectionMode == .reservations {
                reservations = try await provider.loadReservations(date: selectedDate)
            } else {
                waitlistEntries = try await waitlistProvider.loadWaitlist()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Sheet zur Erfassung telefonischer Reservierungen durch Mitarbeiter (Blueprint §10).
public struct KitchenLinkNewReservationSheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: KitchenLinkReservationsProviding
    let initialDate: String
    let onSaved: () -> Void

    @State private var guestName: String = ""
    @State private var guestEmail: String = ""
    @State private var guestPhone: String = ""
    @State private var partySize: Int = 2
    @State private var reservationDate: String
    @State private var reservationTime: String = "19:00"
    @State private var area: String = "Gastraum"
    @State private var specialRequests: String = ""
    @State private var isSaving: Bool = false
    @State private var formError: String? = nil

    public init(
        provider: KitchenLinkReservationsProviding,
        initialDate: String,
        onSaved: @escaping () -> Void
    ) {
        self.provider = provider
        self.initialDate = initialDate
        self.onSaved = onSaved
        _reservationDate = State(initialValue: initialDate)
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Gast") {
                    TextField("Name des Gastes *", text: $guestName)
                    TextField("Telefonnummer (Rückruf)", text: $guestPhone)
                        .keyboardType(.phonePad)
                    TextField("E-Mail-Adresse", text: $guestEmail)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                }

                Section("Reservierungsdetails") {
                    Stepper("Personen: \(partySize)", value: $partySize, in: 1...30)

                    Picker("Bereich", selection: $area) {
                        Text("Gastraum").tag("Gastraum")
                        Text("Terrasse").tag("Terrasse")
                    }

                    TextField("Uhrzeit (z. B. 19:30)", text: $reservationTime)
                }

                Section("Besondere Wünsche & Notizen") {
                    TextField("z. B. Kinderstuhl, Allergien, Geburtstag...", text: $specialRequests, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let err = formError {
                    Section {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
                    }
                }
            }
            .navigationTitle("Telefonische Reservierung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        saveReservation()
                    }
                    .disabled(guestName.trimmingCharacters(in: .whitespaces).count < 2 || isSaving)
                }
            }
        }
    }

    private func saveReservation() {
        isSaving = true
        formError = nil
        Task {
            do {
                _ = try await provider.createPhoneReservation(
                    guestName: guestName,
                    guestEmail: guestEmail.isEmpty ? "telefon@kitchenlink.internal" : guestEmail,
                    guestPhone: guestPhone.isEmpty ? nil : guestPhone,
                    partySize: partySize,
                    date: reservationDate,
                    time: reservationTime,
                    area: area,
                    specialRequests: specialRequests.isEmpty ? nil : specialRequests
                )
                onSaved()
                dismiss()
            } catch {
                formError = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// Sheet zur Erfassung spontan eintreffender Walk-ins auf der Warteliste (Blueprint §10).
public struct KitchenLinkNewWaitlistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let provider: KitchenLinkWaitlistProviding
    let onSaved: () -> Void

    @State private var guestName: String = ""
    @State private var guestPhone: String = ""
    @State private var partySize: Int = 2
    @State private var area: String = "Gastraum"
    @State private var estimatedWaitMinutes: Int = 15
    @State private var notes: String = ""
    @State private var isSaving: Bool = false
    @State private var formError: String? = nil

    public init(
        provider: KitchenLinkWaitlistProviding,
        onSaved: @escaping () -> Void
    ) {
        self.provider = provider
        self.onSaved = onSaved
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("Gäste") {
                    TextField("Name des Gastes *", text: $guestName)
                    TextField("Mobilnummer (für Benachrichtigung)", text: $guestPhone)
                        .keyboardType(.phonePad)
                    Stepper("Personen: \(partySize)", value: $partySize, in: 1...30)
                }

                Section("Wartezeit & Bereich") {
                    Stepper("Geschätzte Wartezeit: \(estimatedWaitMinutes) Min.", value: $estimatedWaitMinutes, in: 5...120, step: 5)

                    Picker("Bereichspräferenz", selection: $area) {
                        Text("Gastraum (Innen)").tag("Gastraum")
                        Text("Terrasse").tag("Terrasse")
                        Text("Egal / Erster freier Tisch").tag("Egal")
                    }
                }

                Section("Notizen") {
                    TextField("z. B. wartet an der Bar, Kinderstuhl...", text: $notes)
                }

                if let err = formError {
                    Section {
                        Text(err)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
                    }
                }
            }
            .navigationTitle("Auf Warteliste setzen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Eintragen") {
                        saveEntry()
                    }
                    .disabled(guestName.trimmingCharacters(in: .whitespaces).count < 2 || isSaving)
                }
            }
        }
    }

    private func saveEntry() {
        isSaving = true
        formError = nil
        Task {
            do {
                _ = try await provider.addWalkIn(
                    guestName: guestName,
                    partySize: partySize,
                    phone: guestPhone.isEmpty ? nil : guestPhone,
                    area: area,
                    estimatedWaitMinutes: estimatedWaitMinutes,
                    notes: notes.isEmpty ? nil : notes
                )
                onSaved()
                dismiss()
            } catch {
                formError = error.localizedDescription
                isSaving = false
            }
        }
    }
}
