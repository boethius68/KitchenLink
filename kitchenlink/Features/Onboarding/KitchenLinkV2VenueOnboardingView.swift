import SwiftUI

/// KL-ONBOARD-001: „Restaurant starten" — Konto und eigenes Lokal.
///
/// Der Bildschirm beantwortet drei Fragen in dieser Reihenfolge: Für welches
/// Restaurant arbeitet dieses iPhone gerade? Wie lege ich meines an? Und wie
/// komme ich zurück ins Demo-Lokal, wenn ich nur vorführen will.
struct KitchenLinkV2VenueOnboardingView: View {
    @StateObject private var model = KitchenLinkVenueOnboardingModel.make()
    @State private var email = ""
    @State private var password = ""
    @State private var isRegistering = false

    var body: some View {
        KitchenLinkV2Surface {
            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.large) {
                    activeVenueCard

                    switch model.phase {
                    case .signedOut:
                        accountCard
                    case .working:
                        KitchenLinkV2Card {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                ProgressView()
                                Text("Einen Moment …")
                                    .font(KitchenLinkV2Typography.secondaryLine)
                                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            }
                        }
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
                        accountCard
                    case .ready:
                        createCard
                        if !model.venues.isEmpty {
                            venueListCard
                        }
                    }

                    if let notice = model.notice {
                        Text(notice)
                            .font(KitchenLinkV2Typography.secondaryLine)
                            .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("onboarding.notice")
                    }
                }
                .frame(maxWidth: 680)
                .padding(KitchenLinkV2Spacing.large)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Restaurant")
        .navigationBarTitleDisplayMode(.inline)
        .tint(KitchenLinkV2Palette.Content.primary)
        .task { await model.load() }
    }

    private var activeVenueCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
                Text("DIESES IPHONE BEDIENT")
                    .font(KitchenLinkV2Typography.meta)
                    .tracking(1.25)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                Text(model.venues.first { $0.slug == model.activeSlug }?.name
                     ?? (model.isDemoVenue ? "Demo-Lokal" : model.activeSlug))
                    .font(KitchenLinkV2Typography.section)
                    .accessibilityIdentifier("onboarding.activeVenue")
                Text("\(KitchenLinkMenuPublishModel.guestWebHost)/\(model.activeSlug)/menu")
                    .font(KitchenLinkV2Typography.meta)
                    .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                    .textSelection(.enabled)

                if model.isDemoVenue {
                    Text("Das ist die mitgelieferte Sandbox-Karte. Leg dein eigenes "
                         + "Restaurant an, dann arbeiten Scan, Tische, Bestellungen "
                         + "und Rechnung darauf.")
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var accountCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text(isRegistering ? "Konto anlegen" : "Anmelden")
                    .font(KitchenLinkV2Typography.primaryLine)

                TextField("E-Mail", text: $email, prompt: Text("betreiber@restaurant.de"))
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    )
                    .accessibilityIdentifier("onboarding.email")

                SecureField("Passwort", text: $password)
                    .textContentType(isRegistering ? .newPassword : .password)
                    .padding(KitchenLinkV2Spacing.medium)
                    .background(
                        KitchenLinkV2Palette.Surface.recessed,
                        in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    )
                    .accessibilityIdentifier("onboarding.password")

                Button(isRegistering ? "Konto anlegen" : "Anmelden") {
                    Task {
                        if isRegistering {
                            await model.signUp(email: email, password: password)
                        } else {
                            await model.signIn(email: email, password: password)
                        }
                        password = ""
                    }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(email.isEmpty || password.isEmpty)
                .accessibilityIdentifier("onboarding.submitAccount")

                Button(isRegistering
                       ? "Ich habe schon ein Konto"
                       : "Noch kein Konto? Eines anlegen") {
                    isRegistering.toggle()
                }
                .font(KitchenLinkV2Typography.secondaryLine)
                .accessibilityIdentifier("onboarding.toggleRegister")
            }
        }
    }

    private var createCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                Text("Eigenes Restaurant anlegen")
                    .font(KitchenLinkV2Typography.primaryLine)
                Text("Der Name steht später über der Gastkarte. Die Adresse dazu "
                     + "ergibt sich daraus — du musst keine URL erfinden.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                TextField(
                    "Name des Restaurants",
                    text: $model.restaurantName,
                    prompt: Text("z. B. Trattoria Bella Vista")
                )
                .padding(KitchenLinkV2Spacing.medium)
                .background(
                    KitchenLinkV2Palette.Surface.recessed,
                    in: RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                )
                .accessibilityIdentifier("onboarding.restaurantName")

                if let preview = model.guestURLPreview {
                    Text(preview)
                        .font(KitchenLinkV2Typography.meta)
                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                        .accessibilityIdentifier("onboarding.urlPreview")
                }

                Button("Restaurant anlegen") {
                    Task { await model.createRestaurant() }
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(!model.canCreate)
                .accessibilityIdentifier("onboarding.createVenue")
            }
        }
    }

    private var venueListCard: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.small) {
            Text("MEINE RESTAURANTS")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.25)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            KitchenLinkV2Card(padding: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(model.venues.enumerated()), id: \.element.id) { index, venue in
                        if index > 0 {
                            Divider().overlay(KitchenLinkV2Palette.Border.subtle)
                        }
                        Button {
                            model.activate(venue)
                        } label: {
                            HStack(spacing: KitchenLinkV2Spacing.medium) {
                                Image(systemName: venue.slug == model.activeSlug
                                      ? "checkmark.circle.fill"
                                      : "circle")
                                    .foregroundStyle(venue.slug == model.activeSlug
                                        ? KitchenLinkV2Palette.Urgency.freshSymbol
                                        : KitchenLinkV2Palette.Content.muted)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(venue.name)
                                        .font(KitchenLinkV2Typography.primaryLine)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                                    Text(venue.slug)
                                        .font(KitchenLinkV2Typography.meta)
                                        .foregroundStyle(KitchenLinkV2Palette.Content.muted)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, KitchenLinkV2Spacing.large)
                            .frame(minHeight: KitchenLinkV2GuestMenuMetrics.minimumTapTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("onboarding.venue.\(venue.slug)")
                    }
                }
            }

            if !model.isDemoVenue {
                Button("Demo-Lokal verwenden") { model.useDemoVenue() }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                    .accessibilityIdentifier("onboarding.useDemo")
            }
        }
    }
}
