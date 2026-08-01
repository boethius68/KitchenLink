import SwiftUI

/// KL-ROLE-002: „Freigabe holen" — die eine Geste, für die es die PIN gibt.
///
/// Der Bildschirm gehört keinem Bereich: Kasse und Rechnung brauchen dieselbe
/// Handbewegung. Er sagt zuerst, **wofür** freigegeben wird und dass es bei
/// dieser einen Aktion bleibt — sonst sähe es wie eine Anmeldung aus, und
/// genau das ist es nicht: das Gerät bleibt bei der Servicekraft angemeldet.
struct KitchenLinkV2ManagerPinSheet: View {
    @StateObject private var model: KitchenLinkManagerPinAuthorizationModel
    @Environment(\.dismiss) private var dismiss

    /// Bewusst nicht `async`: die Aktion gehört dem Bildschirm darunter und
    /// darf nicht mit diesem Blatt verschwinden.
    private let onAuthorized: (KitchenLinkManagerOverride) -> Void

    init(
        permission: KitchenLinkVenuePermission,
        note: String? = nil,
        context: [String: String] = [:],
        onAuthorized: @escaping (KitchenLinkManagerOverride) -> Void
    ) {
        _model = StateObject(
            wrappedValue: KitchenLinkManagerPinAuthorizationModel.make(
                permission: permission, note: note, context: context
            )
        )
        self.onAuthorized = onAuthorized
    }

    var body: some View {
        NavigationStack {
            KitchenLinkV2Surface {
                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                        explainerCard
                        pinCard
                        if KitchenLinkDesignPreviewConfiguration.shouldSeedDemoTables() {
                            demoHint
                        }
                    }
                    .frame(maxWidth: 680)
                    .padding(KitchenLinkV2Spacing.large)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Freigabe")
            .navigationBarTitleDisplayMode(.inline)
            .tint(KitchenLinkV2Palette.Content.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }

    private var explainerCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text(model.permission.label)
                    .font(KitchenLinkV2Typography.section)
                    .accessibilityIdentifier("pin.title")
                Text("Eine Führungskraft gibt hier einmal frei — für diese "
                     + "Aktion, jetzt. Danach ist die Freigabe verbraucht. Du "
                     + "bleibst an diesem Gerät angemeldet, es wird niemand "
                     + "ab- und wieder angemeldet.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Wer freigibt, steht danach im Protokoll.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
        }
    }

    private var pinCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("PIN DER FÜHRUNGSKRAFT")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                SecureField("PIN", text: $model.pin, prompt: Text(verbatim: "••••"))
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .kitchenLinkV2TabularNumbers()
                    .disabled(model.isLocked)
                    .onChange(of: model.pin) { _, value in
                        // Mehr als acht Ziffern nimmt die Datenbank ohnehin
                        // nicht an; hier fällt es sofort auf.
                        let digits = String(value.filter(\.isNumber)
                            .prefix(KitchenLinkManagerPinRules.maximumLength))
                        if digits != value { model.pin = digits }
                    }
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(
                            cornerRadius: KitchenLinkV2Radius.control, style: .continuous
                        )
                    )
                    .accessibilityIdentifier("pin.field")

                if let message = model.message {
                    Text(message)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("pin.message")
                }

                Button(model.isWorking ? "Wird geprüft …" : "Freigeben") {
                    Task {
                        if let override = await model.authorize() {
                            onAuthorized(override)
                            dismiss()
                        }
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(!model.canSubmit)
                .accessibilityIdentifier("pin.submit")
            }
        }
    }

    private var demoHint: some View {
        Text("Sandbox: die Demo-Schichtleitung "
             + "(\(KitchenLinkDemoManagerPinTransport.demoAuthorizerEmail)) hat die PIN "
             + "\(KitchenLinkDemoManagerPinTransport.demoAuthorizerPin).")
            .font(KitchenLinkV2Typography.meta)
            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Was ein gesperrter Handgriff anzeigt: die Erklärung aus KL-ROLE-001 und —
/// neu — der Weg daran vorbei, wenn ihn jemand öffnen kann.
///
/// Der Knopf erscheint **nur**, wenn in dieser Venue überhaupt jemand eine PIN
/// hinterlegt hat. Sonst führte er in ein Blatt, das niemand ausfüllen kann.
struct KitchenLinkV2PermissionGate: View {
    let note: String
    let permission: KitchenLinkVenuePermission
    let canBeAuthorized: Bool
    let identifier: String
    let onRequestAuthorization: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.small) {
                Image(systemName: "lock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .accessibilityHidden(true)
                Text(note)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityIdentifier(identifier)

            if canBeAuthorized {
                Button("Freigabe holen") { onRequestAuthorization() }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                    .accessibilityIdentifier("\(identifier).authorize")
            } else {
                Text("Für eine Freigabe vor Ort muss eine Führungskraft im "
                     + "Bereich Team eine PIN hinterlegen.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("\(identifier).noAuthorizer")
            }
        }
    }
}
