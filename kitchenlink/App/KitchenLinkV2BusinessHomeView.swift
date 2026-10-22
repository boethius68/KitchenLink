import SwiftUI

struct KitchenLinkV2BusinessHomeView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                KitchenLinkV2Palette.Surface.base
                    .ignoresSafeArea()

                KitchenLinkV2HomeBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                        header
                        introduction
                        scanStage
                        operationsAccess
                    }
                    .frame(maxWidth: 680)
                    .padding(.horizontal, KitchenLinkV2Spacing.large)
                    .padding(.top, KitchenLinkV2Spacing.medium)
                    .padding(.bottom, KitchenLinkV2Spacing.xxLarge)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private var header: some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            VStack(alignment: .leading, spacing: 1) {
                Image("KitchenLinkLockupV2")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 180, height: 36, alignment: .leading)
                    .accessibilityLabel("KitchenLink")

                if !dynamicTypeSize.isAccessibilitySize {
                    Text("FÜR BETREIBER")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.35)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .padding(.leading, 50)
                }
            }

            Spacer()

            if dynamicTypeSize.isAccessibilitySize {
                Image(systemName: "shippingbox")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .frame(width: 44, height: 44)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    )
                    .accessibilityLabel("Sandbox für Betreiber")
            } else {
                Text("SANDBOX")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .padding(.horizontal, KitchenLinkV2Spacing.medium)
                    .frame(minHeight: 32)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.label, style: .continuous)
                    )
            }
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("Speisekarte scannen.\nRestaurant starten.")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("business.welcomeTitle")

            Text("Aus Fotos wird ein prüfbares digitales Menü. Ohne Konto und direkt auf diesem iPhone.")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var scanStage: some View {
        VStack(spacing: KitchenLinkV2Spacing.large) {
            V2MenuScanIllustration()

            VStack(spacing: KitchenLinkV2Spacing.medium) {
                NavigationLink {
                    MenuImportEntryView(autoStartScanner: true)
                } label: {
                    Label("Speisekarte scannen", systemImage: "viewfinder")
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .accessibilityIdentifier("business.scanMenu")

                NavigationLink {
                    MenuImportEntryView(autoStartScanner: false)
                } label: {
                    Label("Fotos auswählen", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("business.choosePhotos")

                NavigationLink {
                    MenuManualEditorView()
                } label: {
                    Label("Karte von Hand bearbeiten", systemImage: "square.and.pencil")
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .accessibilityIdentifier("business.editMenuManually")
            }

            HStack(spacing: KitchenLinkV2Spacing.small) {
                Label("Lokal testbar", systemImage: "iphone")
                Spacer(minLength: KitchenLinkV2Spacing.small)
                Label("Vorher prüfen", systemImage: "checkmark.circle")
            }
            .font(KitchenLinkV2Typography.meta)
            .foregroundStyle(KitchenLinkV2Palette.Content.muted)
        }
        .padding(KitchenLinkV2Spacing.large)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.sheet, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.sheet, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    private var operationsAccess: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                KitchenLinkV2LocalOperationsView()
            } label: {
                operationsRow(
                    title: "Service",
                    subtitle: "Online- und lokale Bestellungen · Küche und Kellner",
                    systemImage: "wifi"
                )
            }
            .accessibilityIdentifier("business.openLocalOperations")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2ShiftView()
            } label: {
                operationsRow(
                    title: "Kasse",
                    subtitle: "Betriebsschicht, Bargeld und Tagesabschluss",
                    systemImage: "eurosign.circle"
                )
            }
            .accessibilityIdentifier("business.openShift")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2TodayView()
            } label: {
                operationsRow(
                    title: "Heute",
                    subtitle: "Ereignisse und nächste Handlungen",
                    systemImage: "list.bullet.rectangle"
                )
            }
            .accessibilityIdentifier("business.openToday")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2KitchenView()
            } label: {
                operationsRow(
                    title: "Küche",
                    subtitle: "Gleichzeitige Tickets · für iPad ausgelegt",
                    systemImage: "flame"
                )
            }
            .accessibilityIdentifier("business.openKitchen")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2VenueOnboardingView()
            } label: {
                operationsRow(
                    title: "Restaurant",
                    subtitle: "Konto, eigenes Lokal und Gast-Adresse",
                    systemImage: "storefront"
                )
            }
            .accessibilityIdentifier("business.openVenue")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2TeamView()
            } label: {
                operationsRow(
                    title: "Team",
                    subtitle: "Personal, Rollen und Rechte",
                    systemImage: "person.2"
                )
            }
            .accessibilityIdentifier("business.openTeam")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2ScheduleView()
            } label: {
                operationsRow(
                    title: "Dienstplan",
                    subtitle: "Wer kommt wann · annehmen und ablehnen",
                    systemImage: "calendar"
                )
            }
            .accessibilityIdentifier("business.openSchedule")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2TimeClockView()
            } label: {
                operationsRow(
                    title: "Zeiterfassung",
                    subtitle: "Ein- und ausstempeln · Pausen",
                    systemImage: "clock"
                )
            }
            .accessibilityIdentifier("business.openTimeClock")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2TablesView()
            } label: {
                operationsRow(
                    title: "Tische",
                    subtitle: "Bereiche, Tische und ihre QR-Codes",
                    systemImage: "qrcode"
                )
            }
            .accessibilityIdentifier("business.openTables")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                KitchenLinkV2ReservationsView()
            } label: {
                operationsRow(
                    title: "Reservierungen",
                    subtitle: "Tagesübersicht · Tischzuweisung · Telefonannahme",
                    systemImage: "calendar"
                )
            }
            .accessibilityIdentifier("business.openReservations")

            Divider()
                .overlay(KitchenLinkV2Palette.Border.subtle)

            NavigationLink {
                InventoryOperatorView()
            } label: {
                operationsRow(
                    title: "Bestand",
                    subtitle: "Verfügbarer Bestand je Lagerort · Sandbox",
                    systemImage: "archivebox"
                )
            }
            .accessibilityIdentifier("business.openInventory")
        }
        .padding(.horizontal, KitchenLinkV2Spacing.large)
        .background(
            KitchenLinkV2Palette.Surface.raised,
            in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
        }
    }

    private func operationsRow(
        title: String,
        subtitle: String,
        systemImage: String
    ) -> some View {
        HStack(spacing: KitchenLinkV2Spacing.medium) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(KitchenLinkV2Typography.primaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                Text(subtitle)
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                .accessibilityHidden(true)
        }
        .padding(.vertical, KitchenLinkV2Spacing.medium)
        .frame(minHeight: 52)
        .contentShape(Rectangle())
    }

}

private struct V2MenuScanIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .fill(KitchenLinkV2Palette.Surface.recessed)

            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("TAGESKARTE")
                        .font(KitchenLinkV2Typography.meta)
                        .tracking(1.1)
                    Spacer()
                    Text("12:30")
                        .font(KitchenLinkV2Typography.meta)
                        .kitchenLinkV2TabularNumbers()
                }

                ForEach([0.72, 0.9, 0.58, 0.82], id: \.self) { width in
                    HStack(spacing: KitchenLinkV2Spacing.small) {
                        Capsule()
                            .fill(KitchenLinkV2Palette.Content.muted.opacity(0.34))
                            .frame(width: 190 * width, height: 5)
                        Spacer()
                        Capsule()
                            .fill(KitchenLinkV2Palette.Content.muted.opacity(0.52))
                            .frame(width: 28, height: 5)
                    }
                }
            }
            .padding(.horizontal, KitchenLinkV2Spacing.xLarge)
            .padding(.vertical, KitchenLinkV2Spacing.large)

            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1.5)
                .padding(KitchenLinkV2Spacing.medium)
        }
        .frame(height: 164)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Vorschau einer Speisekarte im neutralen Scanrahmen")
    }
}

private struct KitchenLinkV2HomeBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Circle()
                .fill(KitchenLinkV2Palette.Brand.grape.opacity(0.055))
                .frame(width: proxy.size.width * 0.95)
                .offset(x: -proxy.size.width * 0.48, y: -proxy.size.height * 0.08)

            RoundedRectangle(cornerRadius: 90, style: .continuous)
                .fill(KitchenLinkV2Palette.Brand.grape.opacity(0.035))
                .frame(width: proxy.size.width * 0.78, height: proxy.size.height * 0.34)
                .rotationEffect(.degrees(-11))
                .offset(x: proxy.size.width * 0.52, y: proxy.size.height * 0.66)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
