import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

/// Vereinheitlichter Service-Bereich (KL-CLOUD-001): Online-Bestellungen aus
/// der Supabase-Sandbox und lokale Hub-Bestellungen erscheinen in derselben
/// Küchen-/Kellner-Liste. Es gibt keine Vorauswahl „lokal oder online" mehr —
/// der lokale Foreground-Hub läuft immer mit und übernimmt automatisch, wenn
/// die Internetverbindung fehlt; der Presence-Heartbeat macht den Ausfall für
/// das Gast-Web sichtbar.
struct KitchenLinkV2LocalOperationsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case kitchen = "Küche"
        case waiter = "Kellner"

        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = KitchenLinkLocalOperationsModel()
    @StateObject private var venueHub = KitchenLinkVenueHubModel()
    @StateObject private var cloud = KitchenLinkCloudOperationsModel()
    @State private var mode: Mode = .kitchen
    @State private var successFeedback = 0
    @State private var showsExternalHub = false
    @State private var usesExternalHub = false
    @State private var showsCloudSetup = false
    @State private var cloudURLField = ""
    @State private var cloudAnonKeyField = ""
    @State private var cloudVenueField = KitchenLinkCloudCredentialStore.defaultVenueSlug
    @State private var cloudEmailField = ""
    @State private var cloudPasswordField = ""
    @State private var isCloudSigningIn = false

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    header
                    modePicker
                    cloudCard
                    venueHubCard
                    externalHubCard
                    orderSection
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.vertical, KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Brand.grape)
        .sensoryFeedback(.success, trigger: successFeedback)
        .task {
            cloud.connectIfPossible()
            await startVenueHub()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                cloud.connectIfPossible()
                if usesExternalHub {
                    model.connect()
                } else {
                    Task { await startVenueHub() }
                }
            case .background:
                venueHub.stop()
                model.disconnect()
                cloud.stop(clearPresence: true)
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onChange(of: venueHub.endpoint) { _, newEndpoint in
            cloud.setLocalGuestURL(newEndpoint?.guestURL)
        }
        .onDisappear {
            venueHub.stop()
            model.disconnect()
            cloud.stop(clearPresence: true)
        }
    }

    /// Online- und lokale Bestellungen in einer Liste, älteste zuerst.
    private var visibleOrders: [LiveOrderMessage] {
        switch mode {
        case .kitchen:
            return KitchenLinkServiceOrderMerge.kitchenOrders(
                local: model.orders,
                online: cloud.orders
            )
        case .waiter:
            return KitchenLinkServiceOrderMerge.waiterOrders(
                local: model.orders,
                online: cloud.orders
            )
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                Text(mode.rawValue)
                    .font(KitchenLinkV2Typography.display)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(mode == .kitchen
                     ? "Neue Bestellungen zubereiten – online und lokal."
                     : "Fertige Bestellungen am Pass übernehmen.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }

            Spacer()

            connectionBadge
        }
    }

    private var connectionBadge: some View {
        HStack(spacing: KitchenLinkV2Spacing.xSmall) {
            Circle()
                .fill(badgeColor)
                .frame(width: 8, height: 8)
            Text(badgeTitle)
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(badgeAccessibilityLabel)
        .accessibilityIdentifier("localOperations.connectionBadge")
    }

    private var badgeTitle: String {
        if cloud.isConnected { return "ONLINE" }
        if model.isConnected { return "LOKAL" }
        return "OFFLINE"
    }

    private var badgeColor: Color {
        if cloud.isConnected { return KitchenLinkV2Palette.Urgency.freshSymbol }
        if model.isConnected { return KitchenLinkV2Palette.Urgency.waitingSymbol }
        return KitchenLinkV2Palette.Urgency.neutralSymbol
    }

    private var badgeAccessibilityLabel: String {
        if cloud.isConnected { return "Online-Service verbunden" }
        if model.isConnected { return "Nur lokaler Service verbunden" }
        return "Nicht verbunden"
    }

    private var modePicker: some View {
        Picker("Arbeitsmodus", selection: $mode) {
            ForEach(Mode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("localOperations.mode")
    }

    // MARK: Online-Service

    @ViewBuilder
    private var cloudCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.medium) {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                    Text("ONLINE-BESTELLUNGEN (GAST-WEB)")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.1)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Text(cloud.stateDetail)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(cloudStateColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("localOperations.cloudState")
                }

                Spacer(minLength: 0)

                if cloud.connectionState == .connecting || isCloudSigningIn {
                    ProgressView()
                }
            }

            if let actionError = cloud.lastActionError {
                Label(actionError, systemImage: "exclamationmark.triangle")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            switch cloud.connectionState {
            case .signedOut:
                cloudSetupControls
            case .connected, .unreachable:
                Button("Online-Service abmelden") {
                    cloud.signOut()
                }
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .frame(minHeight: 44)
                .accessibilityIdentifier("localOperations.cloudSignOut")
            case .connecting:
                EmptyView()
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
        .accessibilityIdentifier("localOperations.cloudCard")
    }

    private var cloudStateColor: Color {
        switch cloud.connectionState {
        case .connected:
            return KitchenLinkV2Palette.Content.secondary
        case .connecting, .signedOut:
            return KitchenLinkV2Palette.Content.secondary
        case .unreachable:
            return KitchenLinkV2Palette.Urgency.waitingText
        }
    }

    private var cloudSetupControls: some View {
        DisclosureGroup("Einmalig verbinden", isExpanded: $showsCloudSetup) {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                cloudField("Supabase-URL", text: $cloudURLField, placeholder: "https://xxxx.supabase.co")
                cloudField("Anon-Key", text: $cloudAnonKeyField, placeholder: "eyJ…")
                cloudField("Venue-Slug", text: $cloudVenueField, placeholder: "alte-muehle")
                cloudField("E-Mail", text: $cloudEmailField, placeholder: "operator@example.com")

                SecureField("Passwort", text: $cloudPasswordField)
                    .textInputAutocapitalization(.never)
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
                    .accessibilityIdentifier("localOperations.cloudPassword")

                Button {
                    Task { await signInToCloud() }
                } label: {
                    if isCloudSigningIn {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Verbinden")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(isCloudSigningIn)
                .accessibilityIdentifier("localOperations.cloudSignIn")

                Text("Sandbox: Zugangsdaten des Betreiber-Kontos aus dem Supabase-Projekt (SANDBOX_SETUP.md). Das Passwort wird nicht gespeichert.")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, KitchenLinkV2Spacing.medium)
        }
        .font(KitchenLinkV2Typography.primaryLine)
        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
        .accessibilityIdentifier("localOperations.cloudSetup")
    }

    private func cloudField(
        _ label: String,
        text: Binding<String>,
        placeholder: String
    ) -> some View {
        TextField(label, text: text, prompt: Text(placeholder))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
            .accessibilityLabel(label)
    }

    @MainActor
    private func signInToCloud() async {
        isCloudSigningIn = true
        defer { isCloudSigningIn = false }
        let success = await cloud.signIn(
            supabaseURLString: cloudURLField,
            anonKey: cloudAnonKeyField,
            venueSlug: cloudVenueField,
            email: cloudEmailField,
            password: cloudPasswordField
        )
        if success {
            cloudPasswordField = ""
            showsCloudSetup = false
            cloud.setLocalGuestURL(venueHub.endpoint?.guestURL)
        }
    }

    // MARK: Lokaler Hub

    private var venueHubCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.medium) {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                    Text("LOKALER FALLBACK AUF DIESEM IPHONE")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.1)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Text(venueHub.statusDetail)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(hubStatusColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                ProgressView()
                    .opacity(venueHub.state == .starting ? 1 : 0)
            }

            if let guestURL = venueHub.endpoint?.guestURL {
                HStack(alignment: .center, spacing: KitchenLinkV2Spacing.large) {
                    if let image = qrCode(for: guestURL) {
                        image
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 116, height: 116)
                            .padding(KitchenLinkV2Spacing.small)
                            .background(.white, in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control))
                            .accessibilityLabel("QR-Code zur lokalen Gastbestellung")
                    }

                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                        Text("Gastseite im selben WLAN")
                            .font(KitchenLinkV2Typography.primaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        Text(guestURL.absoluteString)
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .textSelection(.enabled)

                        ShareLink(item: guestURL) {
                            Label("Link teilen", systemImage: "square.and.arrow.up")
                        }
                        .font(KitchenLinkV2Typography.meta)
                        .accessibilityIdentifier("localOperations.shareGuestURL")
                    }
                }
                .accessibilityIdentifier("localOperations.guestEndpoint")
            } else if venueHub.state == .waitingForWiFi {
                Label(
                    "WLAN wird gesucht. Küche, Kellner und bereits gespeicherte Bestellungen bleiben auf diesem iPhone verfügbar.",
                    systemImage: "wifi.slash"
                )
                .font(KitchenLinkV2Typography.secondaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("localOperations.waitingForWiFi")
            } else if venueHub.state != .starting {
                Button("iPhone-Hub starten") {
                    usesExternalHub = false
                    Task { await startVenueHub() }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .accessibilityIdentifier("localOperations.startVenueHub")
            }

            Label(
                "Sandbox: Diese Ansicht muss geöffnet bleiben. Fällt das Internet aus, verweist das Gast-Web Gäste automatisch auf diese lokale Adresse; beide Geräte brauchen dann dasselbe WLAN.",
                systemImage: "exclamationmark.triangle"
            )
            .font(KitchenLinkV2Typography.meta)
            .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
            .fixedSize(horizontal: false, vertical: true)
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
        .accessibilityIdentifier("localOperations.venueHub")
    }

    private var externalHubCard: some View {
        DisclosureGroup("Mac-Hub als Fallback", isExpanded: $showsExternalHub) {
            externalHubControls
                .padding(.top, KitchenLinkV2Spacing.medium)
        }
        .font(KitchenLinkV2Typography.primaryLine)
        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
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

    private var externalHubControls: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            TextField("http://192.168.1.20:8080", text: $model.hubAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
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
                .accessibilityLabel("Adresse des lokalen Hubs")
                .accessibilityIdentifier("localOperations.hubAddress")

            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Text(model.connectionDetail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(model.isConnected
                                     ? KitchenLinkV2Palette.Content.secondary
                                     : KitchenLinkV2Palette.Urgency.waitingText)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button("Mac-Hub verbinden") {
                    usesExternalHub = true
                    venueHub.stop()
                    model.connect()
                }
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .frame(minHeight: 44)
                .accessibilityIdentifier("localOperations.connect")
            }
        }
    }

    // MARK: Bestellliste

    @ViewBuilder
    private var orderSection: some View {
        if visibleOrders.isEmpty {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text(emptyTitle)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(emptyDetail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(KitchenLinkV2Spacing.large)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )
            .accessibilityIdentifier("localOperations.empty")
        } else {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text(mode == .kitchen ? "IN ZUBEREITUNG" : "BEREIT AM PASS")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)

                ForEach(visibleOrders) { order in
                    orderCard(order)
                }
            }
        }
    }

    private var emptyTitle: String {
        if !cloud.isConnected && !model.isConnected {
            return "Kein Service verbunden."
        }
        return mode == .kitchen ? "Keine neue Bestellung." : "Nichts zur Abholung bereit."
    }

    private var emptyDetail: String {
        if !cloud.isConnected && !model.isConnected {
            return "Online-Service verbinden oder den lokalen Hub starten."
        }
        if mode == .kitchen {
            return cloud.isConnected
                ? "Online- und lokale Gastbestellungen erscheinen hier automatisch."
                : "Lokale Gastbestellungen erscheinen hier automatisch. Der Online-Service ist gerade nicht verbunden."
        }
        return "Sobald die Küche eine Bestellung als zubereitet markiert, erscheint sie hier."
    }

    private func orderCard(_ order: LiveOrderMessage) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.sourceDevice.replacingOccurrences(of: "Lokales Gast-WLAN · ", with: "Lokal · "))
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text(order.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }

                Spacer()

                Text(KitchenLinkV2AmountText.euro(cents: order.totalCents))
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .kitchenLinkV2TabularNumbers()
            }

            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                ForEach(order.items) { line in
                    Text("\(line.quantity)× \(line.name)")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                }
            }

            if !order.customerNote.isEmpty {
                Text(order.customerNote)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button(actionTitle) {
                advance(order)
            }
            .buttonStyle(mode == .kitchen
                         ? AnyKitchenLinkV2ButtonStyle(KitchenLinkV2KitchenBumpButtonStyle())
                         : AnyKitchenLinkV2ButtonStyle(KitchenLinkV2PrimaryButtonStyle()))
            .disabled(model.isUpdatingOrder || cloud.isUpdatingOrder)
            .accessibilityIdentifier("localOperations.advance.\(order.id)")
        }
        .padding(KitchenLinkV2Spacing.large)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay(alignment: .top) {
            UnevenRoundedRectangle(
                topLeadingRadius: KitchenLinkV2Radius.card,
                topTrailingRadius: KitchenLinkV2Radius.card
            )
            .fill(mode == .kitchen
                  ? KitchenLinkV2Palette.Urgency.neutralSymbol
                  : KitchenLinkV2Palette.Urgency.freshSymbol)
            .frame(height: 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("localOperations.order.\(order.id)")
    }

    private var actionTitle: String {
        mode == .kitchen ? "Bestellung zubereitet" : "Bestellung serviert"
    }

    private func advance(_ order: LiveOrderMessage) {
        let target: OrderLifecycleStatus = mode == .kitchen ? .ready : .served
        Task {
            let success: Bool
            if cloud.containsOrder(id: order.id) {
                success = await cloud.update(order: order, to: target)
            } else {
                success = await model.update(order: order, to: target)
            }
            if success {
                successFeedback += 1
            }
        }
    }

    private var hubStatusColor: Color {
        if venueHub.state == .waitingForWiFi {
            return KitchenLinkV2Palette.Urgency.waitingText
        }
        if case .failed = venueHub.state {
            return KitchenLinkV2Palette.Urgency.waitingText
        }
        return KitchenLinkV2Palette.Content.secondary
    }

    @MainActor
    private func startVenueHub() async {
        guard scenePhase == .active,
              venueHub.state != .starting,
              !venueHub.isRunning else { return }
        guard let endpoint = await venueHub.start() else { return }
        model.connect(to: endpoint.operatorURL)
        cloud.setLocalGuestURL(endpoint.guestURL)
    }

    private func qrCode(for url: URL) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        let context = CIContext()
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return Image(uiImage: UIImage(cgImage: cgImage))
    }
}

/// Type erasure lets the same card use the established kitchen bump style and
/// the normal service primary style without duplicating either visual contract.
private struct AnyKitchenLinkV2ButtonStyle: ButtonStyle {
    private let makeBodyClosure: (Configuration) -> AnyView

    init<S: ButtonStyle>(_ style: S) {
        makeBodyClosure = { configuration in
            AnyView(style.makeBody(configuration: configuration))
        }
    }

    func makeBody(configuration: Configuration) -> some View {
        makeBodyClosure(configuration)
    }
}
