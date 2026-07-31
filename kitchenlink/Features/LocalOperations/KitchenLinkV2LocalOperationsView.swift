import CoreImage
import CoreImage.CIFilterBuiltins
import KitchenLinkLocalGuestCore
import SwiftUI

/// Vereinheitlichter Service-Bereich: Online-Bestellungen aus der
/// Supabase-Sandbox (KL-CLOUD-001) und lokale Hub-Bestellungen erscheinen in
/// derselben Küchen-/Kellner-Liste. Es gibt keine Vorauswahl „lokal oder
/// online" mehr — der lokale Foreground-Hub läuft immer mit und übernimmt
/// automatisch, wenn die Internetverbindung fehlt; der Presence-Heartbeat
/// macht den Ausfall für das Gast-Web sichtbar.
///
/// Der äußere Wrapper liefert der NavigationStack zuerst ein leichtes Ziel
/// und mountet Laufzeitmodelle und lokale Netzwerkarbeit erst im nächsten
/// Runloop-Umlauf (KL-OFFLINE-008): die Navigation bleibt dadurch flüssig.
struct KitchenLinkV2LocalOperationsView: View {
    @State private var showsService = false

    var body: some View {
        Group {
            if showsService {
                KitchenLinkV2LocalOperationsContentView()
            } else {
                startupView
            }
        }
        .navigationTitle("Service")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Brand.grape)
        .task {
            guard !showsService else { return }

            // Return the lightweight destination to NavigationStack first.
            // Runtime models and local-network work mount on the next turn.
            await Task.yield()
            guard !Task.isCancelled else { return }
            showsService = true
        }
    }

    private var startupView: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            VStack(spacing: KitchenLinkV2Spacing.medium) {
                ProgressView()
                Text("Service wird vorbereitet …")
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text("Bestellungen, Hub und Gastseite starten gleich hier.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(KitchenLinkV2Spacing.large)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("localOperations.startup")
        }
    }
}

private struct KitchenLinkV2LocalOperationsContentView: View {
    /// KL-STATION-001: Küche und Bar sind eigene Stationen (Blueprint §7) —
    /// jede sieht nur ihre Positionen und gibt nur ihre frei.
    enum Mode: String, CaseIterable, Identifiable {
        case kitchen = "Küche"
        case bar = "Bar"
        case waiter = "Kellner"

        var id: String { rawValue }

        var station: KitchenLinkStation? {
            switch self {
            case .kitchen: return .kitchen
            case .bar: return .bar
            case .waiter: return nil
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appStore: KitchenLinkStore
    @StateObject private var model = KitchenLinkLocalOperationsModel()
    @StateObject private var venueHub = KitchenLinkVenueHubModel()
    @StateObject private var cloud = KitchenLinkCloudOperationsModel()
    @StateObject private var hubDiscovery = KitchenLinkVenueHubDiscoveryModel()
    @StateObject private var qrCode = KitchenLinkLocalGuestQRCodeModel()
    @State private var mode: Mode = .kitchen
    @State private var successFeedback = 0
    @State private var showsExternalHub = false
    @State private var usesExternalHub = false
    @State private var cloudEmailField = ""
    @State private var cloudPasswordField = ""
    @State private var isCloudSigningIn = false
    /// Vom Kellner auf diesem Gerät aufgenommene Bestellungen (KL-TABLE-002).
    @State private var waiterOrders: [LiveOrderMessage] = []
    /// Kanäle mit Bestätigungspflicht (KL-ORDER-001). Leer = alles läuft
    /// automatisch durch, das ist der Standardfall aus Blueprint §6.3.
    @State private var confirmationChannels: [ServiceMode] = []
    private let stationTransport: any KitchenLinkStationTransport =
        URLSessionKitchenLinkCloudTransport()

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    header
                    modePicker
                    // Beim ersten Öffnen steht die einmalige Anmeldung oben;
                    // danach kommen die Bestellungen direkt nach dem Modus —
                    // Verbindungs- und Hub-Details rutschen unter die Arbeit.
                    if cloud.connectionState == .signedOut {
                        cloudCard
                    }
                    takeOrderLink
                    checkLink
                    confirmationSection
                    orderSection
                    if cloud.connectionState != .signedOut {
                        cloudCard
                    }
                    venueHubCard
                    externalHubCard
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.vertical, KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .sensoryFeedback(.success, trigger: successFeedback)
        .task {
            cloud.onDrainOutbox = { [weak appStore] config, session in
                guard let repo = appStore?.repository as? EventLogOrderRepository else { return nil }
                return try? await repo.drainCloudOutbox(config: config, session: session)
            }
            cloud.connectIfPossible()
            hubDiscovery.start()
            reloadWaiterOrders()
            await loadConfirmationChannels()
            await startVenueHub()
        }
        .task(id: venueHub.endpoint?.guestURL) {
            await qrCode.render(for: venueHub.endpoint?.guestURL)
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                cloud.connectIfPossible()
                hubDiscovery.start()
                reloadWaiterOrders()
                if usesExternalHub {
                    model.connect()
                } else {
                    Task { await startVenueHub() }
                }
            case .background:
                hubDiscovery.stop()
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
            hubDiscovery.stop()
            venueHub.stop()
            model.disconnect()
            cloud.stop(clearPresence: true)
        }
    }

    /// Online- und lokale Bestellungen in einer Liste, älteste zuerst.
    /// Hub-Projektion **und** die auf diesem Gerät aufgenommenen Bestellungen
    /// (KL-TABLE-002). Beide sind lokal autoritativ; sie liegen nur in
    /// verschiedenen Ereignisprotokollen.
    private var localOrders: [LiveOrderMessage] {
        model.orders + waiterOrders
    }

    private var visibleOrders: [LiveOrderMessage] {
        guard let station = mode.station else {
            return KitchenLinkServiceOrderMerge.waiterOrders(
                local: localOrders,
                online: cloud.orders
            )
        }
        let inProduction = KitchenLinkServiceOrderMerge.kitchenOrders(
            local: localOrders,
            online: cloud.orders
        )
        // Erst die Annahmeregel (§6.3): was auf Bestätigung wartet, geht die
        // Station nichts an. Dann die Station selbst — eine Bestellung ohne
        // offene Position dieser Station steht hier nicht.
        return KitchenLinkOrderAcceptance
            .stationVisible(orders: inProduction, confirmationChannels: confirmationChannels)
            .filter { order in
                order.items.contains { $0.station == station && !$0.isReady }
            }
    }

    /// Bestellungen, die der Betrieb erst bestätigen muss.
    private var ordersAwaitingConfirmation: [LiveOrderMessage] {
        guard !confirmationChannels.isEmpty else { return [] }
        return KitchenLinkOrderAcceptance.awaitingConfirmation(
            orders: KitchenLinkServiceOrderMerge.kitchenOrders(
                local: localOrders,
                online: cloud.orders
            ),
            confirmationChannels: confirmationChannels
        )
    }

    /// Positionen, die diese Station an einer Bestellung zu tun hat.
    private func stationLines(_ order: LiveOrderMessage) -> [LiveOrderLine] {
        guard let station = mode.station else { return order.items }
        return order.items.filter { $0.station == station }
    }

    /// Stationen, die an dieser Bestellung noch arbeiten — ohne die eigene.
    private func otherOpenStations(_ order: LiveOrderMessage) -> [KitchenLinkStation] {
        let own = mode.station
        let open = Set(order.items.filter { !$0.isReady }.map(\.station))
        return KitchenLinkStation.allCases.filter { open.contains($0) && $0 != own }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                Text(mode.rawValue)
                    .font(KitchenLinkV2Typography.display)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(headerDetail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }

            Spacer()

            connectionBadge
        }
    }

    private var headerDetail: String {
        switch mode {
        case .kitchen:
            return "Speisen zubereiten – online und lokal."
        case .bar:
            return "Getränke zubereiten – online und lokal."
        case .waiter:
            return "Fertige Bestellungen am Pass übernehmen."
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
        return "LOKAL"
    }

    private var badgeColor: Color {
        if cloud.isConnected { return KitchenLinkV2Palette.Urgency.freshSymbol }
        return KitchenLinkV2Palette.Content.muted
    }

    private var badgeAccessibilityLabel: String {
        if cloud.isConnected { return "Online-Service verbunden" }
        return "Lokaler Bestell-Speicher aktiv; Cloud nicht verbunden"
    }

    /// KL-TABLE-002: der Weg für eine mündlich aufgegebene Bestellung. Er steht
    /// bewusst über der Bestellliste und nicht in einem Untermenü: bei
    /// Cloud-Ausfall ist das der einzige Weg, wie eine Bestellung ins System
    /// kommt (DECISIONS.md, Local-First).
    private var takeOrderLink: some View {
        NavigationLink {
            KitchenLinkV2WaiterOrderView(
                model: KitchenLinkWaiterOrderModel(
                    repository: appStore.repository,
                    venue: appStore.venueProfile,
                    sections: appStore.menuSections,
                    syncCloud: { [weak cloud] in
                        await cloud?.syncOutboxNow() ?? false
                    }
                )
            )
            .environmentObject(appStore)
            .onDisappear { reloadWaiterOrders() }
        } label: {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Bestellung aufnehmen")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text("Für einen Tisch, die Theke oder telefonisch")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .accessibilityHidden(true)
            }
            .padding(KitchenLinkV2Spacing.large)
            .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
            .background(
                KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("localOperations.takeOrder")
    }

    /// KL-PAY-001: Kassieren steht neben dem Aufnehmen — beides sind Handgriffe
    /// am Tisch, keine Verwaltung.
    private var checkLink: some View {
        NavigationLink {
            KitchenLinkV2CheckOverviewView()
        } label: {
            HStack(spacing: KitchenLinkV2Spacing.medium) {
                Image(systemName: "eurosign.circle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Rechnung kassieren")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text("Gemeinsam, getrennt oder als Teilbetrag · Sandbox")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .accessibilityHidden(true)
            }
            .padding(KitchenLinkV2Spacing.large)
            .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
            .background(
                KitchenLinkV2Palette.Surface.raised,
                in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("localOperations.openCheck")
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

            outboxSyncStatus

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

    @ViewBuilder private var outboxSyncStatus: some View {
        switch cloud.outboxSyncState {
        case .syncing:
            HStack(spacing: KitchenLinkV2Spacing.small) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Lokale Bestellungen werden synchronisiert …")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
            }
        case .error(let message):
            Label(message, systemImage: "exclamationmark.arrow.trianglehead.counterclockwise")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                .fixedSize(horizontal: false, vertical: true)
        case .idle:
            if let lastSync = cloud.lastOutboxSync {
                let elapsed = Int(-lastSync.timeIntervalSinceNow)
                HStack(spacing: KitchenLinkV2Spacing.small) {
                    Image(systemName: "checkmark.circle")
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    Text("Letzte Synchronisation: vor \(elapsed)s")
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }
            }
        }
    }

    private var cloudStateColor: Color {
        switch cloud.connectionState {
        case .connected:
            return KitchenLinkV2Palette.Content.secondary
        case .connecting, .signedOut:
            return KitchenLinkV2Palette.Content.secondary
        case .unreachable:
            return KitchenLinkV2Palette.Content.muted
        }
    }

    private var cloudSetupControls: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            TextField("E-Mail", text: $cloudEmailField, prompt: Text("betreiber@restaurant.de"))
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
                .accessibilityIdentifier("localOperations.cloudEmail")

            SecureField("Passwort", text: $cloudPasswordField)
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
                .accessibilityIdentifier("localOperations.cloudPassword")

            Button {
                Task { await signInToCloud() }
            } label: {
                if isCloudSigningIn {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Online-Service aktivieren")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
            .disabled(isCloudSigningIn
                      || cloudEmailField.isEmpty
                      || cloudPasswordField.isEmpty)
            .accessibilityIdentifier("localOperations.cloudSignIn")

            Text("Einmal mit dem Betreiber-Konto anmelden. Danach bleibt dieses iPhone verbunden; das Passwort wird nicht gespeichert.")
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityIdentifier("localOperations.cloudSetup")
    }

    @MainActor
    private func signInToCloud() async {
        isCloudSigningIn = true
        defer { isCloudSigningIn = false }
        let success = await cloud.signIn(
            email: cloudEmailField,
            password: cloudPasswordField
        )
        if success {
            cloudPasswordField = ""
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
                    if let renderedQRCode = qrCode.renderedQRCode {
                        Image(decorative: renderedQRCode.cgImage, scale: 1)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 116, height: 116)
                            .padding(KitchenLinkV2Spacing.small)
                            .background(.white, in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control))
                            .accessibilityLabel("QR-Code zur lokalen Gastbestellung")
                    } else {
                        ProgressView()
                            .frame(width: 116, height: 116)
                            .padding(KitchenLinkV2Spacing.small)
                            .background(.white, in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control))
                            .accessibilityLabel("QR-Code wird erstellt")
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
        DisclosureGroup("Anderen Hub verwenden", isExpanded: $showsExternalHub) {
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
            HStack(spacing: KitchenLinkV2Spacing.small) {
                Text(hubDiscovery.statusDetail)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(discoveryStatusColor)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                ProgressView()
                    .opacity(hubDiscovery.isSearching ? 1 : 0)
            }
            .accessibilityIdentifier("localOperations.discoveryStatus")

            ForEach(hubDiscovery.hubs) { hub in
                Button {
                    connect(to: hub)
                } label: {
                    HStack(spacing: KitchenLinkV2Spacing.medium) {
                        Image(systemName: "network")
                            .foregroundStyle(KitchenLinkV2Palette.Brand.grape)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(hub.name)
                                .font(KitchenLinkV2Typography.primaryLine)
                                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                            Text(hub.baseURL.absoluteString)
                                .font(KitchenLinkV2Typography.meta)
                                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(KitchenLinkV2Typography.meta)
                            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    }
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Mit \(hub.name) verbinden")
                .accessibilityIdentifier("localOperations.discoveredHub.\(hub.hubID)")
            }

            Divider()

            Text("MANUELLE ADRESSE")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.1)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

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

                Button("Adresse verbinden") {
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
                Text(mode.station != nil ? "IN ZUBEREITUNG" : "BEREIT AM PASS")
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
            return "Keine Bestellungen."
        }
        switch mode {
        case .kitchen: return "Keine neue Speise."
        case .bar: return "Kein neues Getränk."
        case .waiter: return "Nichts zur Abholung bereit."
        }
    }

    private var emptyDetail: String {
        if !cloud.isConnected && !model.isConnected {
            return "Bestellungen werden lokal auf diesem iPhone gespeichert – auch ohne Verbindung zu Cloud oder Hub."
        }
        if mode.station != nil {
            return cloud.isConnected
                ? "Online- und lokale Bestellungen erscheinen hier automatisch."
                : "Der Online-Service ist nicht verbunden. Lokale Bestellungen erscheinen hier automatisch."
        }
        return "Sobald Küche und Bar ihre Positionen freigegeben haben, erscheint die Bestellung hier."
    }

    private func orderCard(_ order: LiveOrderMessage) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    // Der Tisch führt, sobald es einen gibt (KL-TABLE-002):
                    // die Küche muss wissen, wohin — die Herkunft des Auftrags
                    // ist dafür zweitrangig.
                    Text(orderTitle(order))
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    Text(orderSubtitle(order))
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                }

                Spacer()

                Text(KitchenLinkV2AmountText.euro(cents: order.totalCents))
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                    .kitchenLinkV2TabularNumbers()
            }

            // KL-STATION-001: Eine Station sieht nur, was sie selbst zu tun
            // hat. Der Barkeeper bekommt keine Schnitzelliste.
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                ForEach(stationLines(order)) { line in
                    Text("\(line.quantity)× \(line.name)")
                        .font(KitchenLinkV2Typography.primaryLine)
                        .foregroundStyle(line.isReady
                            ? KitchenLinkV2Palette.Content.muted
                            : KitchenLinkV2Palette.Content.primary)
                }
            }

            // „Service sieht, welche Station noch arbeitet" (Blueprint §7).
            if !otherOpenStations(order).isEmpty {
                Text(otherOpenStations(order).map(\.title).joined(separator: " und ")
                     + " arbeitet noch")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)
                    .accessibilityIdentifier("localOperations.openStations")
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
            // Der Stations-Bump behält seinen hellen, nassen-Händen-tauglichen
            // Stil; der Kellner bekommt die normale Primäraktion.
            .buttonStyle(mode.station != nil
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
            .fill(mode.station != nil
                  ? KitchenLinkV2Palette.Urgency.neutralSymbol
                  : KitchenLinkV2Palette.Urgency.freshSymbol)
            .frame(height: 3)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("localOperations.order.\(order.id)")
    }

    private var actionTitle: String {
        switch mode {
        case .kitchen: return "Speisen fertig"
        case .bar: return "Getränke fertig"
        case .waiter: return "Bestellung serviert"
        }
    }

    /// KL-ORDER-001: Bestellungen, die der Betrieb erst annehmen muss. Sie
    /// stehen über der Stationsliste — solange hier etwas liegt, wartet ein
    /// Gast auf eine Antwort.
    @ViewBuilder
    private var confirmationSection: some View {
        if !ordersAwaitingConfirmation.isEmpty {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("ZU BESTÄTIGEN")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Urgency.waitingText)

                ForEach(ordersAwaitingConfirmation) { order in
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(orderTitle(order))
                                    .font(KitchenLinkV2Typography.primaryLine)
                                Text(orderSubtitle(order))
                                    .font(KitchenLinkV2Typography.meta)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                            }
                            Spacer()
                            Text(KitchenLinkV2AmountText.euro(cents: order.totalCents))
                                .font(KitchenLinkV2Typography.primaryLine)
                                .kitchenLinkV2TabularNumbers()
                        }

                        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                            ForEach(order.items) { line in
                                Text("\(line.quantity)× \(line.name)")
                                    .font(KitchenLinkV2Typography.primaryLine)
                            }
                        }

                        HStack(spacing: KitchenLinkV2Spacing.medium) {
                            Button("Ablehnen") { reject(order) }
                                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                                .accessibilityIdentifier("localOperations.reject")
                            Button("Annehmen") { accept(order) }
                                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                                .accessibilityIdentifier("localOperations.accept")
                        }
                    }
                    .padding(KitchenLinkV2Spacing.large)
                    .background(
                        KitchenLinkV2Palette.Surface.raised,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                            .stroke(KitchenLinkV2Palette.Urgency.waitingSymbol, lineWidth: 1)
                    }
                }
            }
            .accessibilityIdentifier("localOperations.confirmationSection")
        }
    }

    private func accept(_ order: LiveOrderMessage) {
        Task {
            if await cloud.update(order: order, to: .accepted) {
                successFeedback += 1
            }
        }
    }

    private func reject(_ order: LiveOrderMessage) {
        Task {
            guard let session = cloud.currentSession else { return }
            try? await stationTransport.rejectOrder(
                config: cloud.currentConfig,
                session: session,
                venueSlug: cloud.currentConfig.venueSlug,
                orderID: order.id,
                reason: "Vom Betrieb abgelehnt"
            )
            await cloud.refreshOrders()
        }
    }

    private func loadConfirmationChannels() async {
        confirmationChannels = (try? await stationTransport.loadConfirmationChannels(
            config: cloud.currentConfig,
            venueSlug: cloud.currentConfig.venueSlug
        )) ?? []
    }

    private func orderTitle(_ order: LiveOrderMessage) -> String {
        if let label = order.tableLabel, !label.isEmpty {
            return KitchenLinkTableLabel.headline(label)
        }
        return order.sourceDevice.replacingOccurrences(
            of: "Lokales Gast-WLAN · ",
            with: "Lokal · "
        )
    }

    private func orderSubtitle(_ order: LiveOrderMessage) -> String {
        let time = order.createdAt.formatted(date: .omitted, time: .shortened)
        guard let label = order.tableLabel, !label.isEmpty else { return time }
        // Bei einer Tischbestellung rutscht die Herkunft in die zweite Zeile,
        // damit sie nicht ganz verschwindet.
        let source = order.sourceDevice.replacingOccurrences(
            of: "Lokales Gast-WLAN · ",
            with: "Lokal · "
        )
        return "\(time) · \(source)"
    }

    private func advance(_ order: LiveOrderMessage) {
        // In einem Stationsmodus gibt der Tap **nur diese Station** frei; die
        // Bestellung wird erst bereit, wenn keine Station mehr offen ist. Das
        // entscheidet die Datenbank, nicht die App.
        if let station = mode.station, cloud.containsOrder(id: order.id) {
            releaseStation(order, station: station)
            return
        }

        let target: OrderLifecycleStatus = mode.station != nil ? .ready : .served
        Task {
            let success: Bool
            if cloud.containsOrder(id: order.id) {
                success = await cloud.update(order: order, to: target)
            } else if waiterOrders.contains(where: { $0.id == order.id }) {
                // Auf diesem Gerät aufgenommen: der Status gehört in dasselbe
                // Ereignisprotokoll, in dem die Bestellung entstanden ist.
                success = (try? appStore.repository.updateOrderStatus(
                    orderID: order.id,
                    to: target
                )) != nil
                reloadWaiterOrders()
            } else {
                success = await model.update(order: order, to: target)
            }
            if success {
                successFeedback += 1
            }
        }
    }

    private func releaseStation(_ order: LiveOrderMessage, station: KitchenLinkStation) {
        Task {
            guard let session = cloud.currentSession else { return }
            do {
                _ = try await stationTransport.markStationReady(
                    config: cloud.currentConfig,
                    session: session,
                    venueSlug: cloud.currentConfig.venueSlug,
                    orderID: order.id,
                    station: station
                )
                successFeedback += 1
                await cloud.refreshOrders()
            } catch {
                // Der Fehler steht im Verbindungsbereich; die Bestellung bleibt
                // sichtbar, damit niemand glaubt, sie sei durch.
                await cloud.refreshOrders()
            }
        }
    }

    /// Liest die lokal aufgenommenen Bestellungen neu. Bewusst kein Polling:
    /// sie entstehen nur auf diesem Gerät, also genügt ein Nachladen bei
    /// Rückkehr, nach einer Aufnahme und nach einem Statuswechsel.
    private func reloadWaiterOrders() {
        waiterOrders = (try? appStore.repository.loadOrders()) ?? []
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

    private var discoveryStatusColor: Color {
        if case .failed = hubDiscovery.state {
            return KitchenLinkV2Palette.Urgency.waitingText
        }
        return KitchenLinkV2Palette.Content.secondary
    }

    private func connect(to hub: KitchenLinkVenueHubBonjourDescriptor) {
        usesExternalHub = true
        venueHub.stop()
        model.hubAddress = hub.baseURL.absoluteString
        model.connect()
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
}

struct KitchenLinkRenderedQRCode: @unchecked Sendable {
    let cgImage: CGImage
}

@MainActor
final class KitchenLinkLocalGuestQRCodeModel: ObservableObject {
    @Published private(set) var renderedQRCode: KitchenLinkRenderedQRCode?
    @Published private(set) var isRendering = false

    private let renderer: @Sendable (URL) -> KitchenLinkRenderedQRCode?
    private var renderID: UUID?

    init(
        renderer: @escaping @Sendable (URL) -> KitchenLinkRenderedQRCode? =
            KitchenLinkLocalGuestQRCodeModel.renderQRCode
    ) {
        self.renderer = renderer
    }

    func render(for url: URL?) async {
        renderedQRCode = nil
        renderID = nil
        isRendering = false
        guard let url else { return }

        let renderID = UUID()
        self.renderID = renderID
        isRendering = true
        let renderer = self.renderer
        let renderedQRCode = await Task.detached(priority: .userInitiated) {
            renderer(url)
        }.value

        guard self.renderID == renderID else { return }
        self.renderID = nil
        isRendering = false
        guard !Task.isCancelled else { return }
        self.renderedQRCode = renderedQRCode
    }

    nonisolated private static func renderQRCode(for url: URL) -> KitchenLinkRenderedQRCode? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.absoluteString.utf8)
        filter.correctionLevel = "M"
        let context = CIContext()
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
              let cgImage = context.createCGImage(output, from: output.extent) else {
            return nil
        }
        return KitchenLinkRenderedQRCode(cgImage: cgImage)
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
