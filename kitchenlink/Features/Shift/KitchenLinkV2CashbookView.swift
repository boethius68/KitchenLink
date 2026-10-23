import SwiftUI

/// KL-CASHBOOK-001 & KL-TSE-001: Kassenbuch, Betriebsausgaben & TSE-Simulation (Blueprint §15).
///
/// Lückenlose GoBD- und KassenSichV-Erfassung für Bargeldbewegungen,
/// Belege, Steueraufteilung (7% / 19%) und kryptografische TSE-Signaturen.
public struct KitchenLinkV2CashbookView: View {
    @State private var provider: KitchenLinkCashbookProviding = KitchenLinkCashbookDemoProvider()

    public enum CashbookTab: String, CaseIterable, Identifiable {
        case cashbook = "Kassenbuch"
        case tse = "TSE-Sicherheit"

        public var id: String { rawValue }
    }

    public enum EntryFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case expenses = "Ausgaben"
        case income = "Einnahmen"

        public var id: String { rawValue }
    }

    @State private var selectedTab: CashbookTab = .cashbook
    @State private var selectedFilter: EntryFilter = .all
    @State private var entries: [KitchenLinkCashbookEntry] = []
    @State private var tseTransactions: [KitchenLinkTSETransaction] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil

    // Sheets
    @State private var showExpenseSheet: Bool = false
    @State private var showDepositSheet: Bool = false
    @State private var selectedTSETransaction: KitchenLinkTSETransaction? = nil

    public init(provider: KitchenLinkCashbookProviding? = nil) {
        if let customProvider = provider {
            _provider = State(initialValue: customProvider)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                tabSegmentedPicker

                switch selectedTab {
                case .cashbook:
                    cashbookContent
                case .tse:
                    tseContent
                }
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Kassenbuch & TSE")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: KitchenLinkV2Spacing.small) {
                    Menu {
                        ShareLink(
                            item: KitchenLinkFiscalExporter.exportDATEVBuchungsstapel(entries: entries),
                            preview: SharePreview("DATEV_Buchungsstapel.csv")
                        ) {
                            Label("DATEV Buchungsstapel", systemImage: "doc.text")
                        }

                        ShareLink(
                            item: KitchenLinkFiscalExporter.exportDSFinVK(entries: entries, tseTransactions: tseTransactions),
                            preview: SharePreview("DSFinV-K_Pruefprotokoll.txt")
                        ) {
                            Label("DSFinV-K Kassenprüfung", systemImage: "lock.shield")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityIdentifier("cashbook.fiscal_export_menu")

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
        .sheet(isPresented: $showExpenseSheet) {
            KitchenLinkNewExpenseSheet { amountCents, taxRate, receipt, desc in
                Task {
                    try? await provider.recordExpense(
                        amountCents: amountCents,
                        taxRate: taxRate,
                        receiptNumber: receipt,
                        description: desc
                    )
                    await reloadData()
                }
            }
        }
        .sheet(isPresented: $showDepositSheet) {
            KitchenLinkNewDepositSheet { amountCents, desc in
                Task {
                    try? await provider.recordDeposit(
                        amountCents: amountCents,
                        description: desc
                    )
                    await reloadData()
                }
            }
        }
        .sheet(item: $selectedTSETransaction) { tx in
            KitchenLinkTSEInspectorSheet(transaction: tx)
        }
    }

    // MARK: - Subviews

    private var tabSegmentedPicker: some View {
        Picker("Bereich", selection: $selectedTab) {
            ForEach(CashbookTab.allCases) { tab in
                Text(tab.rawValue).tag(tab)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Cashbook Content

    private var currentBalanceCents: Int {
        // Entries are sorted descending by entryNumber; first item is the most recent
        entries.first?.balanceAfterCents ?? 0
    }

    private var filteredEntries: [KitchenLinkCashbookEntry] {
        switch selectedFilter {
        case .all:
            return entries
        case .expenses:
            return entries.filter { !$0.isIncome }
        case .income:
            return entries.filter { $0.isIncome }
        }
    }

    private var cashbookContent: some View {
        VStack(spacing: KitchenLinkV2Spacing.large) {
            balanceOverviewCard

            actionButtonsRow

            filterPicker

            if isLoading && entries.isEmpty {
                ProgressView("Kassenbuch wird geladen …")
                    .padding(.vertical, KitchenLinkV2Spacing.large)
            } else if filteredEntries.isEmpty {
                emptyEntriesView
            } else {
                entriesList
            }
        }
    }

    private var balanceOverviewCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Text("AKTUELLES KASSENGUTHABEN")
                    .font(KLTheme.Typography.tabularMono(.caption, weight: .bold))
                    .tracking(1.25)
                    .foregroundStyle(Color.klMuted)
                Spacer()
                Text("GoBD-konform")
                    .font(KLTheme.Typography.tabularMono(.caption2, weight: .semibold))
                    .foregroundStyle(Color.klSage)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.klSage.opacity(0.12))
                    .clipShape(Capsule())
            }

            Text(String(format: "%.2f €", locale: Locale(identifier: "de_DE"), Double(currentBalanceCents) / 100.0))
                .font(.system(.largeTitle, design: .monospaced).weight(.bold).monospacedDigit())
                .foregroundStyle(Color.klCharcoal)

            Divider()
                .padding(.vertical, 4)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Buchungen gesamt")
                        .font(KLTheme.Typography.operational(.caption, weight: .medium))
                        .foregroundStyle(Color.klMuted)
                    Text("\(entries.count)")
                        .font(KLTheme.Typography.tabularMono(.body, weight: .bold))
                        .foregroundStyle(Color.klCharcoal)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Ausgaben erfasst")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Text("\(entries.filter { !$0.isIncome }.count)")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
                }
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

    private var actionButtonsRow: some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            Button {
                showExpenseSheet = true
            } label: {
                Label("Ausgabe buchen", systemImage: "cart.badge.minus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())

            Button {
                showDepositSheet = true
            } label: {
                Label("Einlage buchen", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
        }
    }

    private var filterPicker: some View {
        Picker("Filter", selection: $selectedFilter) {
            ForEach(EntryFilter.allCases) { filter in
                Text(filter.rawValue).tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }

    private var emptyEntriesView: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            Image(systemName: "book.closed")
                .font(.system(size: 36))
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            Text("Keine Buchungen in dieser Ansicht.")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, KitchenLinkV2Spacing.large)
    }

    private var entriesList: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            ForEach(filteredEntries) { entry in
                cashbookEntryCard(entry)
            }
        }
    }

    private func cashbookEntryCard(_ entry: KitchenLinkCashbookEntry) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack(alignment: .top) {
                Image(systemName: entry.entryType.icon)
                    .foregroundStyle(entry.isIncome ? Color.klEmerald : Color.klTerracotta)
                    .font(.system(size: 18))
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.entryType.title)
                            .font(KitchenLinkV2Typography.primaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Spacer()
                        Text(entry.formattedAmount)
                            .font(KLTheme.Typography.tabularPrice(size: 16))
                            .foregroundStyle(entry.isIncome ? Color.klEmerald : Color.klTerracotta)
                    }

                    Text(entry.description)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Text("#\(entry.entryNumber)")
                            .font(KLTheme.Typography.tabularMono(size: 12))
                            .foregroundStyle(Color.klMuted)

                        if let receipt = entry.receiptNumber {
                            Text("•  Beleg: \(receipt)")
                                .font(KLTheme.Typography.tabularMono(size: 12))
                                .foregroundStyle(Color.klMuted)
                        }

                        if let tax = entry.formattedTax {
                            Text("•  \(tax)")
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(Color.klSage)
                        }

                        Spacer()

                        Text("Stand: \(entry.formattedBalance)")
                            .font(KLTheme.Typography.tabularMono(size: 12))
                            .foregroundStyle(Color.klMuted)
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(KitchenLinkV2Spacing.medium)
        .background(
            Color.klSurface,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(Color.klBorder, lineWidth: 1)
        }
    }

    // MARK: - TSE Content

    private var tseContent: some View {
        VStack(spacing: KitchenLinkV2Spacing.large) {
            tseStatusCard

            HStack {
                Text("TSE-SIGNATUR-TRANSAKTIONEN")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(Color.klMuted)
                Spacer()
                Button {
                    Task {
                        try? await provider.signTSETransaction(amountCents: 1550, processType: "Kassenbeleg-V1")
                        await reloadData()
                    }
                } label: {
                    Label("Test-Signatur", systemImage: "signature")
                        .font(KitchenLinkV2Typography.meta)
                }
            }

            if tseTransactions.isEmpty {
                VStack(spacing: KitchenLinkV2Spacing.medium) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.klMuted)
                    Text("Noch keine TSE-Transaktionen signiert.")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
                .padding(.vertical, KitchenLinkV2Spacing.large)
            } else {
                VStack(spacing: KitchenLinkV2Spacing.medium) {
                    ForEach(tseTransactions) { tx in
                        tseTransactionCard(tx)
                    }
                }
            }
        }
    }

    private var tseStatusCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Label("TSE-Sicherheitsmodul", systemImage: "lock.shield.fill")
                    .font(KitchenLinkV2Typography.section)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Spacer()
                Text("Simuliert (KassenSichV)")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(Color.klSage)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color.klSage.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.label, style: .continuous)
                    )
            }

            Text("Seriennummer: TSE-KL-DEMO-001 • Algorithmus: ECDSA-SHA256 • DSFinV-K V2.3")
                .font(KLTheme.Typography.tabularMono(size: 12))
                .foregroundStyle(Color.klMuted)

            Text("Jeder Belegabschluss erzeugt eine unveränderliche kryptografische Signatur mit lückenlos fortlaufendem Zähler.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .padding(KitchenLinkV2Spacing.large)
        .background(
            Color.klSurface,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(Color.klBorder, lineWidth: 1)
        }
    }

    private func tseTransactionCard(_ tx: KitchenLinkTSETransaction) -> some View {
        Button {
            selectedTSETransaction = tx
        } label: {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                HStack {
                    Text("Transaktion #\(tx.transactionNumber)")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        .monospacedDigit()
                    Spacer()
                    Text("Zähler: \(tx.signatureCounter)")
                        .font(KLTheme.Typography.tabularMono(size: 12))
                        .foregroundStyle(Color.klMuted)
                }

                HStack {
                    Text(tx.processType)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Spacer()
                    Text(KitchenLinkReservationDateHelper.formatTime(tx.finishedAt) + " Uhr")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(Color.klMuted)
                        .monospacedDigit()
                }

                Text("Signatur: \(tx.signatureValue)")
                    .font(KLTheme.Typography.tabularMono(size: 11))
                    .foregroundStyle(Color.klMuted)
                    .lineLimit(1)
            }
            .padding(KitchenLinkV2Spacing.medium)
            .background(
                Color.klSurface,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    .stroke(Color.klBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            entries = try await provider.loadCashbook()
            tseTransactions = try await provider.loadTSETransactions()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Sheets

public struct KitchenLinkNewExpenseSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var amountString: String = ""
    @State private var selectedTax: Decimal = 19.0
    @State private var receiptNumber: String = ""
    @State private var descriptionText: String = ""

    let onSave: (Int, Decimal?, String?, String) -> Void

    private let taxRates: [Decimal] = [19.0, 7.0, 0.0]

    public var body: some View {
        NavigationStack {
            Form {
                Section("Betrag & Steuer") {
                    HStack {
                        Text("Betrag in €")
                        Spacer()
                        TextField("z.B. 18.50", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    Picker("Mehrwertsteuer", selection: $selectedTax) {
                        Text("19% (Regelsatz)").tag(Decimal(19.0))
                        Text("7% (Lebensmittel/Bücher)").tag(Decimal(7.0))
                        Text("0% (Steuerfrei)").tag(Decimal(0.0))
                    }
                }

                Section("Beleginformationen") {
                    TextField("Belegnummer (z. B. BELEG-2026-04)", text: $receiptNumber)
                    TextField("Verwendungszweck (z. B. Büromaterial, Markt)", text: $descriptionText)
                }
            }
            .navigationTitle("Ausgabe erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buchen") {
                        let parsedAmount = Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let cents = Int(round(parsedAmount * 100))
                        guard cents > 0 else { return }

                        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Betriebsausgabe bar"
                            : descriptionText
                        let rec = receiptNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? nil
                            : receiptNumber

                        onSave(cents, selectedTax, rec, desc)
                        dismiss()
                    }
                    .disabled(Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0.0 <= 0)
                }
            }
        }
    }
}

public struct KitchenLinkNewDepositSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var amountString: String = ""
    @State private var descriptionText: String = "Bargeldeinlage / Wechselgeld"

    let onSave: (Int, String) -> Void

    public var body: some View {
        NavigationStack {
            Form {
                Section("Einlage") {
                    HStack {
                        Text("Betrag in €")
                        Spacer()
                        TextField("z.B. 100.00", text: $amountString)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }

                    TextField("Verwendungszweck", text: $descriptionText)
                }
            }
            .navigationTitle("Geldeinlage erfassen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Buchen") {
                        let parsedAmount = Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0.0
                        let cents = Int(round(parsedAmount * 100))
                        guard cents > 0 else { return }

                        let desc = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? "Bargeldeinlage"
                            : descriptionText

                        onSave(cents, desc)
                        dismiss()
                    }
                    .disabled(Double(amountString.replacingOccurrences(of: ",", with: ".")) ?? 0.0 <= 0)
                }
            }
        }
    }
}

public struct KitchenLinkTSEInspectorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let transaction: KitchenLinkTSETransaction

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                        Text("KASSENSICHV-BELEGDRUCK")
                            .font(KitchenLinkV2Typography.meta)
                            .tracking(1.25)
                            .foregroundStyle(Color.klMuted)

                        Text(transaction.receiptFooterText)
                            .font(KLTheme.Typography.tabularMono(size: 13))
                            .padding(KitchenLinkV2Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.klSubtle,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                    }

                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                        Text("DSFINV-K QR-STRING")
                            .font(KitchenLinkV2Typography.meta)
                            .tracking(1.25)
                            .foregroundStyle(Color.klMuted)

                        Text(transaction.qrCodeData)
                            .font(KLTheme.Typography.tabularMono(size: 11))
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .padding(KitchenLinkV2Spacing.medium)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Color.klSubtle,
                                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                            )
                    }

                    ShareLink(item: transaction.receiptFooterText + "\n\nQR-Daten:\n" + transaction.qrCodeData) {
                        Label("Belegdaten teilen", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                }
                .padding(KitchenLinkV2Spacing.large)
            }
            .navigationTitle("TSE-Belegprüfer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
        }
    }
}
