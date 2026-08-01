import SwiftUI

/// KL-STAFFING-001: die Sollbesetzung pflegen.
///
/// Der Bedarf ist ein **Wochenmuster**, kein Einzelwert je Tag — so ist er im
/// Betrieb gedacht: „freitags und samstags abends drei im Service". Deshalb
/// steht hier ein Wochentag und kein Datum.
struct KitchenLinkV2StaffingRequirementsSheet: View {
    let requirements: [KitchenLinkStaffingRequirement]
    /// Gibt `nil` bei Erfolg zurück, sonst den Grund.
    let onAdd: (Int, String, String, Int, String?) async -> String?
    let onDelete: (KitchenLinkStaffingRequirement) async -> Void
    let onClose: () -> Void

    @State private var weekday = 5
    @State private var startsAt = Calendar(identifier: .gregorian)
        .date(bySettingHour: 17, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var endsAt = Calendar(identifier: .gregorian)
        .date(bySettingHour: 23, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var target = 2
    @State private var station: String?
    @State private var isWorking = false
    @State private var failure: String?

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        explainer

                        if !requirements.isEmpty {
                            existingSection
                        }

                        addCard
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Sollbesetzung")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { onClose() }
                        .accessibilityIdentifier("staffing.done")
                }
            }
        }
    }

    private var explainer: some View {
        Text("Der Bedarf gilt jede Woche. Fehlt an einem Tag jemand, steht die "
             + "Zahl im Wochenplan daneben — veröffentlichen lässt sich die "
             + "Woche trotzdem.")
            .font(KitchenLinkV2Typography.secondaryLine)
            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var existingSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("BEDARF")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(requirements.enumerated()), id: \.element.id) { index, item in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        HStack(spacing: KitchenLinkV2Spacing.medium) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(item.weekdayName) · \(item.windowLabel)")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .kitchenLinkV2TabularNumbers()
                                Text([
                                    item.targetHeadcount == 1
                                        ? "eine Person" : "\(item.targetHeadcount) Personen",
                                    item.stationLabel
                                ].compactMap { $0 }.joined(separator: " · "))
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            }
                            Spacer(minLength: 0)
                            Button("Entfernen") {
                                Task { await onDelete(item) }
                            }
                            .font(KitchenLinkV2Typography.meta)
                            .accessibilityIdentifier("staffing.delete.\(item.id)")
                        }
                        .padding(.horizontal, KitchenLinkV2Spacing.large)
                        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
                    }
                }
            }
        }
    }

    private var addCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("Bedarf hinzufügen")
                    .font(KitchenLinkV2Typography.primaryLine)

                Menu {
                    ForEach(1...7, id: \.self) { day in
                        Button(KitchenLinkStaffingRequirement.weekdayNames[day] ?? "") {
                            weekday = day
                        }
                    }
                } label: {
                    row("Wochentag",
                        KitchenLinkStaffingRequirement.weekdayNames[weekday] ?? "")
                }
                .accessibilityIdentifier("staffing.weekday")

                DatePicker("Von", selection: $startsAt, displayedComponents: [.hourAndMinute])
                    .environment(\.locale, Locale(identifier: "de_DE"))
                    .accessibilityIdentifier("staffing.from")

                DatePicker("Bis", selection: $endsAt, displayedComponents: [.hourAndMinute])
                    .environment(\.locale, Locale(identifier: "de_DE"))
                    .accessibilityIdentifier("staffing.to")

                Stepper(
                    target == 1 ? "Eine Person" : "\(target) Personen",
                    value: $target, in: 1...20
                )
                .accessibilityIdentifier("staffing.headcount")

                Menu {
                    Button("Alle") { station = nil }
                    ForEach(KitchenLinkShiftStation.allCases, id: \.self) { value in
                        Button(value.label) { station = value.rawValue }
                    }
                } label: {
                    row("Station", station.flatMap {
                        KitchenLinkShiftStation(rawValue: $0)?.label
                    } ?? "Alle")
                }
                .accessibilityIdentifier("staffing.station")

                if let failure {
                    Text(failure)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("staffing.failure")
                }

                Button(isWorking ? "Wird gespeichert …" : "Hinzufügen") {
                    isWorking = true
                    failure = nil
                    Task {
                        failure = await onAdd(
                            weekday,
                            timeFormatter.string(from: startsAt),
                            timeFormatter.string(from: endsAt),
                            target,
                            station
                        )
                        isWorking = false
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(isWorking)
                .accessibilityIdentifier("staffing.add")
            }
        }
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            Spacer()
            Text(value).foregroundStyle(KitchenLinkV2Palette.Content.primary)
            Image(systemName: "chevron.up.chevron.down")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
        }
        .font(KitchenLinkV2Typography.secondaryLine)
        .padding(KitchenLinkV2Spacing.medium)
        .background(
            KitchenLinkV2Palette.Surface.recessed,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
        )
    }
}
