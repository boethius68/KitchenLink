import SwiftUI

/// KL-MENU-005: Bestätigungs- und Veröffentlichungs-Sheet für die
/// Scan-zu-Publish-Brücke. Zeigt, was online geht, meldet bei Bedarf mit
/// vertrauten Zugangsdaten an (keine technischen Verbindungsfelder,
/// Usability-Leitplanke) und bestätigt anschließend mit der Live-URL.
struct MenuPublishSheet: View {
    @StateObject private var model: KitchenLinkMenuPublishModel
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""

    /// Produktiver Einstieg aus dem Draft-Review.
    init(sections: [MenuSectionData]) {
        _model = StateObject(wrappedValue: KitchenLinkMenuPublishModel(sections: sections))
    }

    private var isPublishing: Bool {
        if case .publishing = model.phase { return true }
        return false
    }

    var body: some View {
        NavigationStack {
            ZStack {
                KitchenLinkV2Palette.Surface.base
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                        switch model.phase {
                        case .published(let receipt):
                            successBlock(receipt)
                        default:
                            summaryBlock
                            if !model.hasSession {
                                signInBlock
                            } else {
                                signedInHint
                            }
                            if case .failed(let message) = model.phase {
                                errorBlock(message)
                            }
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .safeAreaInset(edge: .bottom) {
                    actionBar
                }
            }
            .navigationTitle("Online veröffentlichen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isPublished ? "Fertig" : "Schließen") {
                        dismiss()
                    }
                    .accessibilityIdentifier("menuPublish.close")
                }
            }
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private var isPublished: Bool {
        if case .published = model.phase { return true }
        return false
    }

    // MARK: - Summary

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("Geprüfte Karte veröffentlichen")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)

            Text("\(model.itemCount) Artikel in \(model.categoryCount) Kategorien gehen online.")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .kitchenLinkV2TabularNumbers()
                .accessibilityIdentifier("menuPublish.summary")

            Text("Gäste sehen die Karte danach unter \(model.guestMenuURLText). Dies ersetzt die aktuelle Online-Karte dieser Venue vollständig.")
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var signedInHint: some View {
        Label("Als Betreiber angemeldet.", systemImage: "checkmark.seal")
            .font(KitchenLinkV2Typography.meta)
            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            .accessibilityIdentifier("menuPublish.signedIn")
    }

    // MARK: - Sign-in

    private var signInBlock: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("Betreiber-Konto")
                .font(KitchenLinkV2Typography.section)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)

            TextField("E-Mail", text: $email, prompt: Text("betreiber@restaurant.de"))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .textContentType(.username)
                .font(KitchenLinkV2Typography.primaryLine)
                .padding(.horizontal, KitchenLinkV2Spacing.medium)
                .frame(minHeight: 48)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
                }
                .accessibilityLabel("E-Mail")
                .accessibilityIdentifier("menuPublish.email")

            SecureField("Passwort", text: $password)
                .textContentType(.password)
                .font(KitchenLinkV2Typography.primaryLine)
                .padding(.horizontal, KitchenLinkV2Spacing.medium)
                .frame(minHeight: 48)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                        .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
                }
                .accessibilityIdentifier("menuPublish.password")

            Text("Einmal mit dem Betreiber-Konto anmelden. Das Passwort wird nicht gespeichert.")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Error

    private func errorBlock(_ message: String) -> some View {
        Text(message)
            .font(KitchenLinkV2Typography.secondaryLine)
            .foregroundStyle(KitchenLinkV2Palette.Urgency.criticalText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("menuPublish.error")
    }

    // MARK: - Success

    private func successBlock(_ receipt: KitchenLinkMenuPublishReceipt) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Label("Karte ist online", systemImage: "checkmark.circle.fill")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .accessibilityIdentifier("menuPublish.success")

            Text("\(receipt.itemCount) Artikel in \(receipt.categoryCount) Kategorien veröffentlicht.")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .kitchenLinkV2TabularNumbers()

            Text(model.guestMenuURLText)
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Brand.grape)
                .textSelection(.enabled)
                .accessibilityIdentifier("menuPublish.liveURL")

            Text("Die neue Karte ist über das Gast-Web in der Regel innerhalb einer Minute sichtbar (zwischengespeicherte Auslieferung).")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(KitchenLinkV2Spacing.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
    }

    // MARK: - Action bar

    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: KitchenLinkV2Spacing.small) {
            switch model.phase {
            case .published:
                Button("Fertig") { dismiss() }
                    .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                    .accessibilityIdentifier("menuPublish.done")
            default:
                Button {
                    Task { await triggerPublish() }
                } label: {
                    if isPublishing {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Text(model.hasSession ? "Jetzt veröffentlichen" : "Anmelden & veröffentlichen")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(isPublishing || publishDisabled)
                .accessibilityIdentifier("menuPublish.publish")
            }
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .padding(.top, KitchenLinkV2Spacing.medium)
        .padding(.bottom, KitchenLinkV2Spacing.small)
        .background(.thinMaterial)
    }

    private var publishDisabled: Bool {
        if model.hasSession { return false }
        return email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty
    }

    private func triggerPublish() async {
        if model.hasSession {
            await model.publishUsingStoredSession()
        } else {
            await model.signInAndPublish(email: email, password: password)
        }
    }
}
