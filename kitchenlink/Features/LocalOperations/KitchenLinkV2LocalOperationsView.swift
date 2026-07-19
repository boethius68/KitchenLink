import CoreImage
import CoreImage.CIFilterBuiltins
import KitchenLinkLocalGuestCore
import SwiftUI
import UIKit

struct KitchenLinkV2LocalOperationsView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case kitchen = "Küche"
        case waiter = "Kellner"

        var id: String { rawValue }
    }

    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = KitchenLinkLocalOperationsModel()
    @StateObject private var venueHub = KitchenLinkVenueHubModel()
    @StateObject private var hubDiscovery = KitchenLinkVenueHubDiscoveryModel()
    @State private var mode: Mode = .kitchen
    @State private var successFeedback = 0
    @State private var showsExternalHub = false
    @State private var usesExternalHub = false

    var body: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    header
                    modePicker
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
        .navigationTitle("Lokaler Service")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Brand.grape)
        .sensoryFeedback(.success, trigger: successFeedback)
        .task {
            hubDiscovery.start()
            await startVenueHub()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                hubDiscovery.start()
                if usesExternalHub {
                    model.connect()
                } else {
                    Task { await startVenueHub() }
                }
            case .background:
                hubDiscovery.stop()
                venueHub.stop()
                model.disconnect()
            case .inactive:
                break
            @unknown default:
                break
            }
        }
        .onDisappear {
            hubDiscovery.stop()
            venueHub.stop()
            model.disconnect()
        }
    }

    private var visibleOrders: [LiveOrderMessage] {
        switch mode {
        case .kitchen:
            return model.orders.filter { $0.status == .preparing }
        case .waiter:
            return model.orders.filter { $0.status == .ready }
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                Text(mode.rawValue)
                    .font(KitchenLinkV2Typography.display)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(mode == .kitchen
                     ? "Neue lokale Bestellungen zubereiten."
                     : "Fertige Bestellungen am Pass übernehmen.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }

            Spacer()

            HStack(spacing: KitchenLinkV2Spacing.xSmall) {
                Circle()
                    .fill(model.isConnected
                          ? KitchenLinkV2Palette.Urgency.freshSymbol
                          : KitchenLinkV2Palette.Urgency.neutralSymbol)
                    .frame(width: 8, height: 8)
                Text(model.isConnected ? "LIVE" : "OFFLINE")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(model.isConnected ? "Live verbunden" : "Nicht verbunden")
            .accessibilityIdentifier("localOperations.connectionBadge")
        }
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

    private var venueHubCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.medium) {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xSmall) {
                    Text("DIESES IPHONE IST DER VENUE-HUB")
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
                "Sandbox: Diese Ansicht muss geöffnet bleiben. Beide Geräte brauchen dasselbe WLAN; das iPhone am besten am Strom lassen.",
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
        if !model.isConnected { return "Lokaler Hub nicht verbunden." }
        return mode == .kitchen ? "Keine neue Bestellung." : "Nichts zur Abholung bereit."
    }

    private var emptyDetail: String {
        if !model.isConnected { return "Hub-Adresse und gemeinsames WLAN prüfen." }
        return mode == .kitchen
            ? "Die nächste lokale Gastbestellung erscheint automatisch."
            : "Sobald die Küche eine Bestellung als zubereitet markiert, erscheint sie hier."
    }

    private func orderCard(_ order: LiveOrderMessage) -> some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.sourceDevice.replacingOccurrences(of: "Lokales Gast-WLAN · ", with: "Bestellung "))
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

            Button(actionTitle) {
                advance(order)
            }
            .buttonStyle(mode == .kitchen
                         ? AnyKitchenLinkV2ButtonStyle(KitchenLinkV2KitchenBumpButtonStyle())
                         : AnyKitchenLinkV2ButtonStyle(KitchenLinkV2PrimaryButtonStyle()))
            .disabled(model.isUpdatingOrder)
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
            if await model.update(order: order, to: target) {
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
