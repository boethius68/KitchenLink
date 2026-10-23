import SwiftUI

/// KL-SANDBOX-001: Betreiberansicht für Sandbox-Steuerung, Szenarien & Fehlersimulation (Blueprint §20 & §21).
public struct KitchenLinkV2SandboxControlView: View {
    @State private var activeScenario: KitchenLinkSandboxScenarioType = .lunchRush
    @State private var faultState = KitchenLinkSandboxFaultState()
    @State private var showResetConfirmation: Bool = false
    @State private var noticeMessage: String? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: KitchenLinkV2Spacing.large) {
                sandboxBannerCard

                scenarioSection

                faultInjectionSection

                backupExportSection

                resetSection
            }
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .padding(.vertical, KitchenLinkV2Spacing.medium)
        }
        .background(KitchenLinkV2Palette.Surface.base.ignoresSafeArea())
        .navigationTitle("Sandbox & Szenarien")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sandbox zurücksetzen?", isPresented: $showResetConfirmation) {
            Button("Abbrechen", role: .cancel) {}
            Button("Zurücksetzen", role: .destructive) {
                performReset()
            }
        } message: {
            Text("Alle simulierten Bestellungen, Kassenbucheinträge und Belege werden auf den Standardzustand von „Gasthaus Alte Mühle“ zurückgesetzt.")
        }
    }

    // MARK: - Subviews

    private var sandboxBannerCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Label("SANDBOX-BETRIEBSMODUS", systemImage: "shippingbox.fill")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Spacer()
                Text("Kein Echtes Geld")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
            }

            Text("In dieser Umgebung können Sie alle Restaurant-Prozesse gefahrlos durchspielen. Alle Zahlungen, Schichten und Belege sind simuliert.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

            if let notice = noticeMessage {
                Text(notice)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
                    .padding(.top, 4)
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

    private var scenarioSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("GEFÜHRTE DEMO-SZENARIEN")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            ForEach(KitchenLinkSandboxScenarioType.allCases) { scenario in
                scenarioCard(scenario)
            }
        }
    }

    private func scenarioCard(_ scenario: KitchenLinkSandboxScenarioType) -> some View {
        let isSelected = activeScenario == scenario

        return VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack {
                Image(systemName: scenario.icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Content.secondary)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(scenario.title)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text(scenario.subtitle)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }

                Spacer()

                if isSelected {
                    Text("Aktiv")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            KitchenLinkV2Palette.Surface.recessed,
                            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.label, style: .continuous)
                        )
                } else {
                    Button("Aktivieren") {
                        activeScenario = scenario
                        noticeMessage = "Szenario „\(scenario.title)“ erfolgreich geladen."
                    }
                    .font(KitchenLinkV2Typography.meta)
                    .buttonStyle(.bordered)
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
                .stroke(isSelected ? KitchenLinkV2Palette.Brand.grape : KitchenLinkV2Palette.Border.subtle, lineWidth: isSelected ? 2 : 1)
        }
    }

    private var faultInjectionSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("FEHLERSIMULATION & LAST")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            VStack(spacing: KitchenLinkV2Spacing.small) {
                Toggle("Zahlungsabbruch / Timeout simulieren", isOn: $faultState.simulatePaymentTimeout)
                    .font(KitchenLinkV2Typography.secondaryLine)

                Divider()

                Toggle("Kassendifferenz bei Zählung (5,00 €)", isOn: $faultState.simulateCashVariance)
                    .font(KitchenLinkV2Typography.secondaryLine)

                Divider()

                Toggle("Zutatenmangel / Bestandsalarm", isOn: $faultState.simulateIngredientDepletion)
                    .font(KitchenLinkV2Typography.secondaryLine)

                Divider()

                Toggle("Offline-Modus (Cloud trennen)", isOn: $faultState.simulateCloudOffline)
                    .font(KitchenLinkV2Typography.secondaryLine)
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

    private var backupExportSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("DATENEXPORT & BACKUP")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("Erzeugen Sie eine vollständige JSON-Sicherung aller Restaurantdaten zur revisionssicheren Aufbewahrung.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)

                ShareLink(
                    item: KitchenLinkBackupExporter.createSnapshotJSON(),
                    preview: SharePreview("KitchenLink_Snapshot.json")
                ) {
                    Label("Vollständiges Backup (JSON) teilen", systemImage: "arrow.down.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
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

    private var resetSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Button(role: .destructive) {
                showResetConfirmation = true
            } label: {
                Label("Sandbox auf Werkseinstellungen zurücksetzen", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(KitchenLinkV2Palette.Urgency.criticalSymbol)
        }
        .padding(.top, KitchenLinkV2Spacing.medium)
    }

    private func performReset() {
        activeScenario = .lunchRush
        faultState = KitchenLinkSandboxFaultState()
        noticeMessage = "Sandbox erfolgreich auf Werkseinstellungen zurückgesetzt."
    }
}
