import SwiftUI

/// Sheet zur Soll-/Ist-Auswertung und Überstunden-Übersicht für Führungskräfte (§ 9.3).
struct KitchenLinkV2WorkforceEvaluationSheet: View {
    let evaluation: KitchenLinkTeamWorkforceEvaluation
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        overviewCard
                        teamListSection
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Soll-/Ist-Auswertung")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schließen", action: onClose)
                        .accessibilityIdentifier("evaluation.close")
                }
            }
        }
    }

    private var overviewCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("TEAM-ÜBERSICHT")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                HStack(spacing: KitchenLinkV2Spacing.medium) {
                    metricColumn(
                        label: "Soll-Planung",
                        value: KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: evaluation.totalTargetSeconds)
                    )
                    Divider()
                    metricColumn(
                        label: "Ist-Zeiten",
                        value: KitchenLinkWorkforceEvaluationFormatter.formatHoursMinutes(seconds: evaluation.totalActualNetSeconds)
                    )
                    Divider()
                    metricColumn(
                        label: "Überstunden-Saldo",
                        value: KitchenLinkWorkforceEvaluationFormatter.formatDelta(seconds: evaluation.totalDeltaSeconds),
                        isEmphasized: true,
                        isPositive: evaluation.totalDeltaSeconds >= 0
                    )
                }

                if evaluation.breakViolationsCount > 0 {
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingSymbol)
                        Text("\(evaluation.breakViolationsCount) Pausenunterschreitung(en) nach § 4 ArbZG")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    }
                    .padding(.top, KitchenLinkV2Spacing.small)
                } else {
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.freshSymbol)
                        Text("Alle erfassten Pausen entsprechen § 4 ArbZG")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.freshText)
                    }
                    .padding(.top, KitchenLinkV2Spacing.small)
                }
            }
        }
    }

    private func metricColumn(
        label: String,
        value: String,
        isEmphasized: Bool = false,
        isPositive: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            Text(value)
                .font(KitchenLinkV2Typography.compactSection)
                .foregroundStyle(
                    isEmphasized
                        ? (isPositive ? KitchenLinkV2Palette.Urgency.freshText : KitchenLinkV2Palette.Urgency.waitingText)
                        : KitchenLinkV2Palette.Content.primary
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var teamListSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("MITARBEITER-ZEITKONTEN")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            if evaluation.evaluations.isEmpty {
                KitchenLinkV2Card {
                    Text("Keine geplanten Schichten oder Zeiteinträge im gewählten Zeitraum.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
            } else {
                ForEach(evaluation.evaluations) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: KitchenLinkEmployeeWorkforceEvaluation) -> some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.displayName)
                            .font(KitchenLinkV2Typography.primaryLine)
                        if let role = member.roleName {
                            Text(role)
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        }
                    }
                    Spacer(minLength: 0)
                    Text(member.formattedDelta)
                        .font(KitchenLinkV2Typography.compactSection)
                        .foregroundStyle(
                            member.isOvertime
                                ? KitchenLinkV2Palette.Urgency.freshText
                                : (member.isUndertime ? KitchenLinkV2Palette.Urgency.waitingText : KitchenLinkV2Palette.Content.secondary)
                        )
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(KitchenLinkV2Palette.Surface.recessed)
                        )
                }

                Divider()

                HStack {
                    Text("Soll: \(member.formattedTarget)")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    Spacer(minLength: 0)
                    Text("Ist: \(member.formattedActual)")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }

                if let notice = member.breakCompliance.notice {
                    Text(notice)
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                }
            }
        }
    }
}
