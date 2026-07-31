import SwiftUI

/// KL-ROLE-001: „Team" — wer arbeitet hier, und was darf er.
///
/// Der Bildschirm sagt zuerst, was die Rollen überhaupt regeln, weil das
/// Missverständnis sonst vorprogrammiert ist: sie regeln **nicht** den Alltag.
/// Bestellen, Status ändern und kassieren darf jedes Personal — sonst könnte
/// die Küche nicht arbeiten. Gesperrt sind fünf Handgriffe an der Kasse.
struct KitchenLinkV2TeamView: View {
    @StateObject private var model = KitchenLinkTeamModel.make()
    @State private var memberToRemove: KitchenLinkTeamMember?

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    switch model.phase {
                    case .loading:
                        KitchenLinkV2Card {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                ProgressView()
                                Text("Team wird geladen …")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }
                        }
                    case .needsSignIn:
                        KitchenLinkTablesSignInCard { email, password in
                            await model.signIn(email: email, password: password)
                        }
                    case .notAllowed(let message):
                        notAllowedCard(message)
                        roleReference
                    case .failed(let message):
                        KitchenLinkV2Card {
                            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                                Text(message)
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                                    .fixedSize(horizontal: false, vertical: true)
                                Button("Erneut versuchen") { Task { await model.load() } }
                                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                            }
                        }
                    case .ready, .working:
                        explainer
                        teamSection
                        inviteCard
                        roleReference
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("team.notice")
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Team")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await model.load() }
        .confirmationDialog(
            memberToRemove.map { "\($0.displayName) entfernen?" } ?? "",
            isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Entfernen", role: .destructive) {
                if let member = memberToRemove {
                    Task { await model.remove(member) }
                }
                memberToRemove = nil
            }
            Button("Abbrechen", role: .cancel) { memberToRemove = nil }
        } message: {
            Text("Der Zugang verliert den Zugriff auf dieses Restaurant. "
                 + "Das Konto selbst bleibt bestehen.")
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
            Text("Wer arbeitet hier?")
                .font(KitchenLinkV2Typography.section)
            Text("Bestellen, Status ändern und kassieren darf jedes Personal — "
                 + "sonst könnte die Küche nicht arbeiten. Die Rolle entscheidet "
                 + "über fünf sensible Handgriffe an der Kasse.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func notAllowedCard(_ message: String) -> some View {
        KitchenLinkV2Card {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.medium) {
                Image(systemName: "lock")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                    Text(model.myRole.roleName ?? "Kein Zugriff")
                        .font(KitchenLinkV2Typography.primaryLine)
                    Text(message)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityIdentifier("team.notAllowed")
        }
    }

    private var teamSection: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("PERSONAL")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.members.enumerated()), id: \.element.id) { index, member in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        memberRow(member)
                    }
                }
            }
        }
    }

    private func memberRow(_ member: KitchenLinkTeamMember) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: KitchenLinkV2Spacing.xSmall) {
                    Text(member.displayName)
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    if member.isMe {
                        Text("DU")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            .padding(.horizontal, KitchenLinkV2Spacing.xSmall)
                            .background(
                                KitchenLinkV2Palette.Surface.recessed,
                                in: RoundedRectangle(
                                    cornerRadius: KitchenLinkV2Radius.label, style: .continuous
                                )
                            )
                    }
                }
                Text(model.role(for: member.roleKey)?.permissionSummary ?? member.roleName)
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            // Die eigene Rolle ist kein Menü: sie lässt sich ohnehin nicht
            // ändern (sonst sperrt sich der letzte Inhaber selbst aus).
            if member.isMe {
                Text(member.roleName)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            } else {
                Menu {
                    ForEach(model.roles) { role in
                        Button {
                            Task { await model.setRole(for: member, to: role.key) }
                        } label: {
                            if role.key == member.roleKey {
                                Label(role.name, systemImage: "checkmark")
                            } else {
                                Text(role.name)
                            }
                        }
                    }
                    Divider()
                    Button("Aus dem Team entfernen", role: .destructive) {
                        memberToRemove = member
                    }
                } label: {
                    HStack(spacing: 2) {
                        Text(member.roleName)
                            .font(KitchenLinkV2Typography.secondaryLine)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }
                .accessibilityIdentifier("team.role.\(member.userID)")
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
    }

    private var inviteCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("Jemanden hinzufügen")
                    .font(KitchenLinkV2Typography.primaryLine)
                Text("Die Person registriert sich selbst in der App; danach "
                     + "ordnest du ihre E-Mail hier zu. KitchenLink legt keine "
                     + "fremden Konten an.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField("E-Mail", text: $model.inviteEmail,
                          prompt: Text(verbatim: "kollege@restaurant.de"))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control, style: .continuous
                        )
                    )
                    .accessibilityIdentifier("team.inviteEmail")

                Menu {
                    ForEach(model.roles) { role in
                        Button(role.name) { model.inviteRoleKey = role.key }
                    }
                } label: {
                    HStack {
                        Text("Rolle")
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        Spacer()
                        Text(model.role(for: model.inviteRoleKey)?.name ?? model.inviteRoleKey)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control, style: .continuous
                        )
                    )
                }
                .accessibilityIdentifier("team.inviteRole")

                Button("Zum Team hinzufügen") { Task { await model.invite() } }
                    .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                    .disabled(!model.canInvite)
                    .accessibilityIdentifier("team.invite")
            }
        }
    }

    private var roleReference: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("WAS DIE ROLLEN DÜRFEN")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.roles.enumerated()), id: \.element.id) { index, role in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text(role.name)
                                .font(KitchenLinkV2Typography.secondaryLine)
                                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                            Text(role.permissionSummary)
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, KitchenLinkV2Spacing.large)
                        .padding(.vertical, KitchenLinkV2Spacing.small)
                    }
                }
            }
        }
    }
}
