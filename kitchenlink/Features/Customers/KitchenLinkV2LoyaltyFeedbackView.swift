import SwiftUI

/// KL-LOYALTY-001: Betreiberansicht für Treueprogramm, Gutscheine & Gäste-Feedback (Blueprint §13 & Meilenstein 5).
public struct KitchenLinkV2LoyaltyFeedbackView: View {
    @State private var provider: KitchenLinkLoyaltyProviding = KitchenLinkLoyaltyDemoProvider()

    public enum SectionTab: String, CaseIterable, Identifiable {
        case feedback = "Gäste-Feedback"
        case vouchers = "Gutscheine & Rabatte"
        case customers = "Stammgäste & Treue"

        public var id: String { rawValue }
    }

    @State private var selectedTab: SectionTab = .feedback
    @State private var feedbacks: [KitchenLinkOrderFeedback] = []
    @State private var vouchers: [KitchenLinkVoucher] = []
    @State private var customers: [KitchenLinkCustomerProfile] = []
    @State private var showNewVoucherSheet: Bool = false
    @State private var isLoading: Bool = false

    public init(provider: KitchenLinkLoyaltyProviding? = nil) {
        if let custom = provider {
            _provider = State(initialValue: custom)
        }
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                tabSegmentedPicker

                switch selectedTab {
                case .feedback:
                    feedbackSection
                case .vouchers:
                    vouchersSection
                case .customers:
                    customersSection
                }
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Kunden & Loyalty")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if selectedTab == .vouchers {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewVoucherSheet = true
                    } label: {
                        Label("Gutschein erstellen", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                    }
                }
            }
        }
        .task {
            await reloadData()
        }
        .sheet(isPresented: $showNewVoucherSheet) {
            KitchenLinkNewVoucherSheet(provider: provider) {
                Task { await reloadData() }
            }
        }
    }

    // MARK: - Tabs

    private var tabSegmentedPicker: some View {
        HStack(spacing: KitchenLinkV2Spacing.xSmall) {
            ForEach(SectionTab.allCases) { tab in
                let isSelected = selectedTab == tab
                Button {
                    selectedTab = tab
                } label: {
                    Text(tab.rawValue)
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

    // MARK: - Feedback Section

    private var feedbackSection: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            // Durchschnitt
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("DURCHSCHNITTSBEWERTUNG")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.0)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    let avg = feedbacks.isEmpty ? 5.0 : Double(feedbacks.reduce(0) { $0 + $1.rating }) / Double(feedbacks.count)
                    HStack(spacing: 6) {
                        Text(String(format: "%.1f", avg))
                            .font(KitchenLinkV2Typography.display)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Text("★ ★ ★ ★ ★")
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("BEWERTUNGEN")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.0)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Text("\(feedbacks.count) gesamt")
                        .font(KitchenLinkV2Typography.section)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }
            }
            .padding(KitchenLinkV2Spacing.medium)
            .background(
                KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )

            // Liste
            ForEach(feedbacks) { fb in
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                    HStack {
                        Text(fb.orderNumber)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)

                        Text(fb.starsString)
                            .font(.system(size: 14))
                            .foregroundStyle(.orange)

                        Spacer()

                        Text(KitchenLinkReservationDateHelper.formatTime(fb.createdAt))
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }

                    if let comment = fb.comment, !comment.isEmpty {
                        Text("„\(comment)“")
                            .font(KitchenLinkV2Typography.primaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                            .padding(.top, 2)
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
        }
    }

    // MARK: - Vouchers Section

    private var vouchersSection: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            ForEach(vouchers) { v in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(v.code)
                                .font(.system(size: 16, weight: .bold, design: .monospaced))
                                .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                            Text(v.discountDescription)
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(KitchenLinkV2Palette.Action.persistentPrimary.opacity(0.3), in: Capsule())
                        }

                        Text(v.formattedMinOrder)
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(v.timesUsed)x")
                            .font(KitchenLinkV2Typography.section)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Text("eingelöst")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
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
        }
    }

    // MARK: - Customers Section

    private var customersSection: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            ForEach(customers) { c in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(c.name)
                                .font(KitchenLinkV2Typography.section)
                                .foregroundStyle(KitchenLinkV2Palette.Content.primary)

                            HStack(spacing: 3) {
                                Image(systemName: c.tier.badgeIcon)
                                    .font(.system(size: 10))
                                Text(c.tier.title)
                                    .font(.system(size: 11, weight: .bold))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(KitchenLinkV2Palette.Brand.grape.opacity(0.12), in: Capsule())
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                        }

                        Text("\(c.totalOrdersCount) Bestellungen · \(c.formattedSpent) Umsatz")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(c.loyaltyPoints)")
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                        Text("Punkte")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
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
        }
    }

    private func reloadData() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let f = provider.loadFeedbacks()
            async let v = provider.loadVouchers()
            async let c = provider.loadCustomers()
            (feedbacks, vouchers, customers) = try await (f, v, c)
        } catch {
            // error
        }
    }
}

// MARK: - Neuer Gutschein Sheet

struct KitchenLinkNewVoucherSheet: View {
    let provider: KitchenLinkLoyaltyProviding
    let onComplete: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var code: String = ""
    @State private var discountType: String = "percentage"
    @State private var discountValueText: String = "10"
    @State private var minOrderText: String = "15"

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Gutscheincode (z. B. SOMMER15)", text: $code)
                        .textInputAutocapitalization(.characters)

                    Picker("Rabattart", selection: $discountType) {
                        Text("Prozentual (%)").tag("percentage")
                        Text("Festbetrag (€)").tag("fixed_amount")
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        TextField("Rabattwert", text: $discountValueText)
                            .keyboardType(.numberPad)
                        Text(discountType == "percentage" ? "%" : "€")
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }

                    HStack {
                        TextField("Mindestbestellwert", text: $minOrderText)
                            .keyboardType(.numberPad)
                        Text("€")
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                } header: {
                    Text("Konditionen")
                }
            }
            .navigationTitle("Gutschein anlegen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Erstellen") {
                        save()
                    }
                    .font(KitchenLinkV2Typography.primaryButton)
                    .disabled(code.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func save() {
        let val = Int(discountValueText) ?? 10
        let minVal = (Int(minOrderText) ?? 0) * 100
        let storedVal = discountType == "percentage" ? val : val * 100

        Task {
            _ = try? await provider.createVoucher(
                code: code,
                discountType: discountType,
                discountValue: storedVal,
                minOrderCents: minVal
            )
            onComplete()
            dismiss()
        }
    }
}
