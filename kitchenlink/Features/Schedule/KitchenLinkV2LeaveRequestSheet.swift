import SwiftUI

/// KL-LEAVE-001: eine Abwesenheit beantragen.
///
/// Der Bogen arbeitet in **ganzen Tagen** — so wird eine Abwesenheit im
/// Betrieb gedacht. Intern wird daraus Ortsmitternacht bis Ortsmitternacht des
/// Folgetags, damit sich die Überlappung mit geplanten Schichten exakt prüfen
/// lässt.
struct KitchenLinkV2LeaveRequestSheet: View {
    /// Gibt `nil` bei Erfolg zurück, sonst den Grund — der Bogen zeigt ihn
    /// selbst, weil der Hinweis des Bildschirms dahinter liegt.
    let onSubmit: (Date, Date, KitchenLinkLeaveKind, String?) async -> String?
    let onCancel: () -> Void

    @State private var firstDay = Calendar(identifier: .gregorian)
        .startOfDay(for: Date().addingTimeInterval(86_400))
    @State private var lastDay = Calendar(identifier: .gregorian)
        .startOfDay(for: Date().addingTimeInterval(86_400))
    @State private var kind: KitchenLinkLeaveKind = .vacation
    @State private var reason = ""
    @State private var isWorking = false
    @State private var failure: String?

    private var calendar: Calendar { Calendar(identifier: .gregorian) }

    private var dayCount: Int {
        let days = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
        return max(1, days + 1)
    }

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                                Picker("Art", selection: $kind) {
                                    ForEach(KitchenLinkLeaveKind.allCases, id: \.self) { value in
                                        Text(value.label).tag(value)
                                    }
                                }
                                .pickerStyle(.segmented)
                                .accessibilityIdentifier("leaveRequest.kind")

                                DatePicker(
                                    "Erster Tag", selection: $firstDay,
                                    displayedComponents: [.date]
                                )
                                .environment(\.locale, Locale(identifier: "de_DE"))
                                .accessibilityIdentifier("leaveRequest.first")

                                DatePicker(
                                    "Letzter Tag", selection: $lastDay,
                                    in: firstDay...,
                                    displayedComponents: [.date]
                                )
                                .environment(\.locale, Locale(identifier: "de_DE"))
                                .accessibilityIdentifier("leaveRequest.last")

                                Text(dayCount == 1 ? "Ein Tag" : "\(dayCount) Tage")
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                                TextField(
                                    "Grund", text: $reason,
                                    prompt: Text(verbatim: "optional")
                                )
                                .padding(KitchenLinkV2Spacing.medium)
                                .background(
                                    KitchenLinkV2Palette.Surface.recessed,
                                    in: RoundedRectangle(
                                        cornerRadius: KitchenLinkV2Radius.control,
                                        style: .continuous
                                    )
                                )
                                .accessibilityIdentifier("leaveRequest.reason")
                            }
                        }

                        Text("Der Antrag geht an die Planung. Solange er offen ist, "
                             + "kannst du weiter eingeteilt werden — erst die "
                             + "Genehmigung hält den Zeitraum frei.")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .fixedSize(horizontal: false, vertical: true)

                        if let failure {
                            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.system(size: 13, weight: .semibold))
                                    .accessibilityHidden(true)
                                Text(failure)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                            .accessibilityIdentifier("leaveRequest.failure")
                        }

                        Button(isWorking ? "Wird beantragt …" : "Beantragen") {
                            isWorking = true
                            failure = nil
                            Task {
                                // Ortsmitternacht bis Ortsmitternacht des
                                // Folgetags: der letzte Tag zählt ganz mit.
                                let start = calendar.startOfDay(for: firstDay)
                                let end = calendar.date(
                                    byAdding: .day, value: 1,
                                    to: calendar.startOfDay(for: lastDay)
                                ) ?? start
                                failure = await onSubmit(
                                    start, end, kind, reason.isEmpty ? nil : reason
                                )
                                isWorking = false
                            }
                        }
                        .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                        .disabled(isWorking)
                        .accessibilityIdentifier("leaveRequest.submit")
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Abwesenheit")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { onCancel() }
                }
            }
        }
    }
}
