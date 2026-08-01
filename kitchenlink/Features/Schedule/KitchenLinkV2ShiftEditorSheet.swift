import SwiftUI

/// KL-PLAN-001: eine Schicht anlegen oder ändern.
///
/// Der Bogen sagt die zwei Dinge, die im Betrieb überraschen würden: dass ein
/// neuer Eintrag ein **Entwurf** ist (also noch niemand davon weiß), und dass
/// das Verschieben einer bereits angenommenen Schicht die Zusage aufhebt.
struct KitchenLinkV2ShiftEditorSheet: View {
    let draft: KitchenLinkScheduleDraft
    let team: [KitchenLinkTeamMember]
    /// Gibt `nil` bei Erfolg zurück, sonst den Grund der Absage. Der Bogen muss
    /// ihn **selbst** zeigen: der Hinweis des Bildschirms liegt dahinter, und
    /// wer hier speichert, sähe sonst nur, dass nichts passiert.
    let onSave: (String, Date, Date, String?, String?, String?) async -> String?
    let onCancel: () -> Void

    @State private var userID: String = ""
    @State private var startsAt: Date
    @State private var endsAt: Date
    @State private var area: String
    @State private var station: String?
    @State private var note: String
    @State private var isWorking = false
    @State private var failure: String?

    init(
        draft: KitchenLinkScheduleDraft,
        team: [KitchenLinkTeamMember],
        onSave: @escaping (String, Date, Date, String?, String?, String?) async -> String?,
        onCancel: @escaping () -> Void
    ) {
        self.draft = draft
        self.team = team
        self.onSave = onSave
        self.onCancel = onCancel
        _userID = State(initialValue: draft.userID ?? team.first?.userID ?? "")
        _startsAt = State(initialValue: draft.startsAt)
        _endsAt = State(initialValue: draft.endsAt)
        _area = State(initialValue: draft.area)
        _station = State(initialValue: draft.station)
        _note = State(initialValue: draft.note)
    }

    private var selectedName: String {
        team.first { $0.userID == userID }?.displayName ?? "Wählen"
    }

    private var canSave: Bool {
        !isWorking && !userID.isEmpty && endsAt > startsAt
    }

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                                Menu {
                                    ForEach(team) { member in
                                        Button(member.displayName) { userID = member.userID }
                                    }
                                } label: {
                                    labelledRow("Wer", selectedName)
                                }
                                .accessibilityIdentifier("shiftEditor.person")

                                DatePicker(
                                    "Beginn", selection: $startsAt,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .environment(\.locale, Locale(identifier: "de_DE"))
                                .accessibilityIdentifier("shiftEditor.start")

                                DatePicker(
                                    "Ende", selection: $endsAt,
                                    in: startsAt...,
                                    displayedComponents: [.date, .hourAndMinute]
                                )
                                .environment(\.locale, Locale(identifier: "de_DE"))
                                .accessibilityIdentifier("shiftEditor.end")

                                TextField(
                                    "Bereich", text: $area,
                                    prompt: Text(verbatim: "z. B. Gastraum")
                                )
                                .padding(KitchenLinkV2Spacing.medium)
                                .background(
                                    KitchenLinkV2Palette.Surface.recessed,
                                    in: RoundedRectangle(
                                        cornerRadius: KitchenLinkV2Radius.control,
                                        style: .continuous
                                    )
                                )
                                .accessibilityIdentifier("shiftEditor.area")

                                Menu {
                                    Button("Keine") { station = nil }
                                    ForEach(KitchenLinkShiftStation.allCases, id: \.self) { value in
                                        Button(value.label) { station = value.rawValue }
                                    }
                                } label: {
                                    labelledRow(
                                        "Station",
                                        station.flatMap {
                                            KitchenLinkShiftStation(rawValue: $0)?.label
                                        } ?? "Keine"
                                    )
                                }
                                .accessibilityIdentifier("shiftEditor.station")

                                TextField(
                                    "Notiz", text: $note,
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
                                .accessibilityIdentifier("shiftEditor.note")
                            }
                        }

                        Text(draft.shiftID == nil
                             ? "Neue Schichten sind zunächst Entwürfe — sichtbar nur für "
                                + "die Planung. Erst das Veröffentlichen sagt dem Personal "
                                + "Bescheid."
                             : "Wird eine bereits angenommene Schicht verschoben, muss sie "
                                + "erneut bestätigt werden. Sonst stünde \u{201E}angenommen\u{201C} "
                                + "an einer Zeit, die niemand gesehen hat.")
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
                            .accessibilityIdentifier("shiftEditor.failure")
                        }

                        Button(isWorking ? "Wird gespeichert …" : "Speichern") {
                            isWorking = true
                            failure = nil
                            Task {
                                failure = await onSave(
                                    userID, startsAt, endsAt,
                                    area.isEmpty ? nil : area,
                                    station,
                                    note.isEmpty ? nil : note
                                )
                                isWorking = false
                            }
                        }
                        .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                        .disabled(!canSave)
                        .accessibilityIdentifier("shiftEditor.save")
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(draft.shiftID == nil ? "Schicht anlegen" : "Schicht ändern")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { onCancel() }
                }
            }
        }
    }

    private func labelledRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
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
