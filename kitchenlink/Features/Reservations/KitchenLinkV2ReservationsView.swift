import SwiftUI

/// KL-RES-001: Reservierungsübersicht & Tischzuweisung für den Service (Blueprint §10).
public struct KitchenLinkV2ReservationsView: View {
    @State private var provider: KitchenLinkReservationsProviding = KitchenLinkReservationsDemoProvider()
    @State private var reservations: [KitchenLinkReservation] = []
    @State private var selectedDate: String = KitchenLinkReservationDateHelper.todayDateString()
    @State private var selectedFilter: ReservationFilter = .all
    @State private var showNewReservationSheet: Bool = false
    @State private var selectedReservationForSeating: KitchenLinkReservation? = nil
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

    public init(provider: KitchenLinkReservationsProviding? = nil) {
        if let customProvider = provider {
            _provider = State(initialValue: customProvider)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                dateSelector
                summaryBar
                filterChips
                reservationList
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Reservierungen")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewReservationSheet = true
                } label: {
                    Label("Neu", systemImage: "plus")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
        }
        .task(id: selectedDate) {
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
        .alert(
            "Tisch zuweisen & Gäste platzieren",
            isPresented: Binding(
                get: { selectedReservationForSeating != nil },
                set: { if !$0 { selectedReservationForSeating = nil } }
            )
        ) {
            TextField("Tischnummer (z. B. 4)", text: $assigningTableNumber)
                .keyboardType(.numberPad)
            Button("Platzieren") {
                if let res = selectedReservationForSeating {
                    let table = assigningTableNumber.trimmingCharacters(in: .whitespaces)
                    let tableID = table.isEmpty ? nil : table
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
                }
            }
            Button("Abbrechen", role: .cancel) {
                selectedReservationForSeating = nil
                assigningTableNumber = ""
            }
        } message: {
            if let res = selectedReservationForSeating {
                Text("Gäste \(res.guestName) (\(res.partySize) Personen) auf welchen Tisch platzieren?")
            }
        }
    }

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

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            reservations = try await provider.loadReservations(date: selectedDate)
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
