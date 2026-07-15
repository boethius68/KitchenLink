import SwiftUI

struct KitchenLinkRootView: View {
    @EnvironmentObject private var store: KitchenLinkStore
    @State private var showLegacySandbox = false
    @State private var designVariant: KitchenLinkDesignVariant

    init() {
        _designVariant = State(
            initialValue: KitchenLinkDesignPreviewConfiguration.initialVariant()
        )
    }

    var body: some View {
        Group {
            if designVariant == .v2 {
                KitchenLinkV2BusinessHomeView(
                    menuSectionCount: store.menuSections.count,
                    onOpenSandbox: { showLegacySandbox = true },
                    onUseLegacyDesign: { designVariant = .legacy }
                )
            } else {
                legacyHome
            }
        }
        .fullScreenCover(isPresented: $showLegacySandbox) {
            LegacySandboxSheet()
        }
    }

    private var legacyHome: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    introduction
                    importActions
                    sandboxCard
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 36)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .toolbar(.hidden, for: .navigationBar)
        }
        .kitchenSurface()
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 54, height: 54)
                .padding(7)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(KitchenTheme.brand.opacity(0.14))
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("KitchenLink")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("BUSINESS")
                    .font(.caption2.weight(.black))
                    .tracking(2.2)
                    .foregroundStyle(KitchenTheme.brand)
            }

            Spacer()

            Text("SANDBOX")
                .font(.caption2.weight(.black))
                .tracking(1.1)
                .foregroundStyle(KitchenTheme.brandDark)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(KitchenTheme.accent.opacity(0.18), in: Capsule())
        }
    }

    private var introduction: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Speisekarte scannen.\nRestaurant starten.")
                .font(.system(size: 42, weight: .black, design: .rounded))
                .minimumScaleFactor(0.78)
                .foregroundStyle(KitchenTheme.brandDark)
                .accessibilityIdentifier("business.welcomeTitle")

            Text("Fotografiere deine bestehende Karte. KitchenLink erkennt Kategorien, Artikel, Preise, Varianten und ausgewiesene Allergene. Erst das Ergebnis prüfen, dann registrieren.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var importActions: some View {
        VStack(spacing: 12) {
            NavigationLink {
                MenuImportEntryView(autoStartScanner: true, usesV2Design: false)
            } label: {
                Label("Speisekarte scannen", systemImage: "doc.viewfinder")
            }
            .buttonStyle(KitchenPrimaryButtonStyle())
            .accessibilityIdentifier("business.scanMenu")

            NavigationLink {
                MenuImportEntryView(autoStartScanner: false, usesV2Design: false)
            } label: {
                Label("Fotos aus Mediathek wählen", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(KitchenSecondaryButtonStyle())
            .accessibilityIdentifier("business.choosePhotos")

            HStack(spacing: 8) {
                Label("Kein Konto nötig", systemImage: "person.crop.circle.badge.checkmark")
                Spacer()
                Label("Lokal testbar", systemImage: "iphone")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 4)
        }
    }

    private var sandboxCard: some View {
        KitchenCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "shippingbox.fill")
                        .font(.title2)
                        .foregroundStyle(KitchenTheme.accent)
                        .frame(width: 38, height: 38)
                        .background(KitchenTheme.accent.opacity(0.13), in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bestehende Produktsandbox")
                            .font(.headline)
                        Text("Bestellen, Küche, Zahlungen und Betreiberfunktionen bleiben während des Neubaus testbar.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("\(store.menuSections.count) Menükategorien geladen")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Sandbox öffnen") {
                        showLegacySandbox = true
                    }
                    .font(.subheadline.weight(.bold))
                    .accessibilityIdentifier("business.openLegacySandbox")
                }

                Divider()

                Button {
                    designVariant = .v2
                } label: {
                    Label("Neue Designvorschau öffnen", systemImage: "sparkles.rectangle.stack")
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(KitchenTheme.brandDark)
                .accessibilityIdentifier("business.useV2Design")
            }
        }
    }
}

struct LegacySandboxSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ContentView()
            .overlay(alignment: .topTrailing) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 42, height: 42)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Sandbox schließen")
                .padding()
            }
    }
}
