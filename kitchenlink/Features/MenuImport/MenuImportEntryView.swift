import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct MenuImportEntryView: View {
    @EnvironmentObject private var store: KitchenLinkStore

    let autoStartScanner: Bool
    let usesV2Design: Bool

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showDocumentScanner = false
    @State private var didHandleAutoStart = false
    @State private var importInProgress = false
    @State private var importStatusMessage: String?
    @State private var importedSections: [MenuSectionData] = []
    @State private var importedDraft: MenuImportDraft?
    @State private var showImportPreview = false
    @State private var menuWasApplied = false
    @State private var showLegacySandbox = false

    private var importedItemCount: Int {
        importedSections.reduce(0) { $0 + $1.items.count }
    }

    init(autoStartScanner: Bool, usesV2Design: Bool = true) {
        self.autoStartScanner = autoStartScanner
        self.usesV2Design = usesV2Design
    }

    var body: some View {
        entryContent
            .accessibilityIdentifier("menuImport.entry")
            .navigationTitle(usesV2Design ? "Speisekarte scannen" : "Speisekarte importieren")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDocumentScanner) {
                MenuDocumentScannerView { images in
                    showDocumentScanner = false
                    startImport(images, sourceType: .camera)
                } onCancel: {
                    showDocumentScanner = false
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showImportPreview) {
                MenuImportReviewView(sections: importedSections) {
                    store.replaceMenu(with: importedSections)
                    menuWasApplied = true
                    importStatusMessage = "Das erkannte Menü ist jetzt in der lokalen Sandbox aktiv."
                    showImportPreview = false
                }
            }
            .fullScreenCover(isPresented: $showLegacySandbox) {
                LegacySandboxSheet()
            }
            .onAppear {
                guard autoStartScanner, !didHandleAutoStart else { return }
                didHandleAutoStart = true
                presentScanner()
            }
            .onChange(of: selectedPhotoItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    await loadSelectedPhotos(items)
                }
            }
    }

    @ViewBuilder
    private var entryContent: some View {
        if usesV2Design {
            v2EntryContent
        } else {
            legacyEntryContent
        }
    }

    private var legacyEntryContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                introCard
                sourceActions

                if importInProgress || importStatusMessage != nil {
                    statusCard
                }

                if !importedSections.isEmpty {
                    resultCard
                }
            }
            .frame(maxWidth: 680)
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .kitchenSurface()
    }

    private var v2EntryContent: some View {
        ZStack {
            KitchenLinkV2Palette.Surface.base
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.xLarge) {
                    v2Introduction
                    v2SourceActions

                    if importInProgress || importStatusMessage != nil {
                        v2StatusCard
                    }

                    if !importedSections.isEmpty {
                        v2ResultCard
                    }
                }
                .frame(maxWidth: 680)
                .padding(.horizontal, KitchenLinkV2Spacing.large)
                .padding(.vertical, KitchenLinkV2Spacing.xLarge)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .tint(KitchenLinkV2Palette.Brand.grape)
    }

    private var v2Introduction: some View {
        VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
            Text("ERSTER SCHRITT")
                .font(KitchenLinkV2Typography.meta)
                .tracking(1.35)
                .foregroundStyle(KitchenLinkV2Palette.Content.muted)

            Text("Zeig uns deine Karte")
                .font(KitchenLinkV2Typography.display)
                .foregroundStyle(KitchenLinkV2Palette.Content.primary)

            Text("Scanne alle Seiten gerade und bei gutem Licht. Du prüfst das erkannte Menü, bevor es deine Sandbox ersetzt.")
                .font(KitchenLinkV2Typography.primaryLine)
                .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                .fixedSize(horizontal: false, vertical: true)

            V2ImportScanFrame()
        }
    }

    @ViewBuilder
    private var v2SourceActions: some View {
        VStack(spacing: KitchenLinkV2Spacing.medium) {
            if importedSections.isEmpty {
                Button {
                    presentScanner()
                } label: {
                    Label("Dokumentkamera öffnen", systemImage: "viewfinder")
                }
                .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                .disabled(importInProgress)
                .accessibilityIdentifier("menuImport.openScanner")
            } else {
                Button {
                    presentScanner()
                } label: {
                    Label("Weitere Seiten scannen", systemImage: "viewfinder")
                }
                .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                .disabled(importInProgress)
                .accessibilityIdentifier("menuImport.openScanner")
            }

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 24,
                matching: .images
            ) {
                Label("Menüfotos auswählen", systemImage: "photo.stack")
            }
            .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
            .disabled(importInProgress)
            .accessibilityIdentifier("menuImport.choosePhotos")

            MenuDemoFixturePicker(isDisabled: importInProgress) { fixture in
                startDemoImport(fixture)
            }
        }
    }

    private var v2StatusCard: some View {
        KitchenLinkV2Card {
            HStack(alignment: .top, spacing: KitchenLinkV2Spacing.medium) {
                if importInProgress {
                    ProgressView()
                        .tint(KitchenLinkV2Palette.Brand.grape)
                        .controlSize(.regular)
                        .accessibilityLabel("Import läuft")
                } else {
                    Image(systemName: "info.circle")
                        .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                        .accessibilityHidden(true)
                }

                if let importStatusMessage {
                    Text(importStatusMessage)
                        .font(KitchenLinkV2Typography.secondaryLine)
                        .foregroundStyle(KitchenLinkV2Palette.Content.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var v2ResultCard: some View {
        KitchenLinkV2Card {
            VStack(alignment: .leading, spacing: KitchenLinkV2Spacing.medium) {
                KitchenLinkV2StatusLabel(
                    status: KitchenLinkV2Status(
                        operation: .change,
                        urgency: .fresh,
                        verb: menuWasApplied ? "Menü lokal übernommen" : "Menü erkannt"
                    )
                )

                Text("\(importedSections.count) Kategorien · \(importedItemCount) Artikel")
                    .font(KitchenLinkV2Typography.section)
                    .kitchenLinkV2TabularNumbers()

                Text(menuWasApplied
                     ? "Der Import ist lokal gespeichert und kann sofort im Bestellablauf getestet werden."
                     : "Prüfe Namen, Preise und Erkennungswarnungen, bevor du die aktuellen Sandbox-Daten ersetzt.")
                    .font(KitchenLinkV2Typography.secondaryLine)
                    .foregroundStyle(KitchenLinkV2Palette.Content.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if menuWasApplied {
                    Button("Import erneut prüfen") {
                        showImportPreview = true
                    }
                    .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
                    .accessibilityIdentifier("menuImport.reviewResult")

                    Button("Mit diesem Menü testen") {
                        showLegacySandbox = true
                    }
                    .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                    .accessibilityIdentifier("menuImport.testMenu")
                } else {
                    Button("Ergebnis prüfen") {
                        showImportPreview = true
                    }
                    .buttonStyle(KitchenLinkV2PrimaryButtonStyle())
                    .accessibilityIdentifier("menuImport.reviewResult")
                }
            }
        }
    }

    private var introCard: some View {
        KitchenCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(KitchenTheme.brand)
                    Spacer()
                    Text("SCHRITT 1")
                        .font(.caption2.weight(.black))
                        .tracking(1.2)
                        .foregroundStyle(KitchenTheme.brandDark)
                }

                Text("Zeig uns deine Karte")
                    .font(.title2.bold())
                Text("Scanne alle Seiten möglichst gerade und bei gutem Licht. Vor dem Speichern kannst du Kategorien, Artikel, Preise und Erkennungswarnungen prüfen.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var sourceActions: some View {
        VStack(spacing: 12) {
            Button {
                presentScanner()
            } label: {
                Label("Dokumentkamera öffnen", systemImage: "camera.viewfinder")
            }
            .buttonStyle(KitchenPrimaryButtonStyle())
            .disabled(importInProgress)

            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 24,
                matching: .images
            ) {
                Label("Menüfotos auswählen", systemImage: "photo.stack")
            }
            .buttonStyle(KitchenSecondaryButtonStyle())
            .disabled(importInProgress)

            MenuDemoFixturePicker(isDisabled: importInProgress) { fixture in
                startDemoImport(fixture)
            }
        }
    }

    private var statusCard: some View {
        KitchenCard {
            VStack(alignment: .leading, spacing: 10) {
                if importInProgress {
                    MenuImportWhooshView()
                }

                if let importStatusMessage {
                    Text(importStatusMessage)
                        .font(.subheadline)
                        .foregroundStyle(importInProgress ? .secondary : .primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var resultCard: some View {
        KitchenCard {
            VStack(alignment: .leading, spacing: 12) {
                Label(
                    "\(importedSections.count) Kategorien, \(importedItemCount) Artikel",
                    systemImage: menuWasApplied ? "checkmark.seal.fill" : "sparkles"
                )
                .font(.headline)
                .foregroundStyle(menuWasApplied ? KitchenTheme.brand : KitchenTheme.accent)

                Text(menuWasApplied
                     ? "Der Import ist lokal gespeichert. Öffne die Sandbox, um das Menü im Bestellablauf zu testen."
                     : "Prüfe das erkannte Menü, bevor es die aktuellen Sandbox-Daten ersetzt.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button(menuWasApplied ? "Import erneut prüfen" : "Ergebnis prüfen") {
                    showImportPreview = true
                }
                .buttonStyle(KitchenSecondaryButtonStyle())

                if menuWasApplied {
                    Button("Mit diesem Menü testen") {
                        showLegacySandbox = true
                    }
                    .buttonStyle(KitchenPrimaryButtonStyle())
                }
            }
        }
    }

    private func presentScanner() {
        guard VNDocumentCameraViewController.isSupported else {
            importStatusMessage = "Die Dokumentkamera ist auf diesem Gerät nicht verfügbar. Bitte Menüfotos aus der Mediathek wählen."
            return
        }
        showDocumentScanner = true
    }

    private func startImport(
        _ images: [UIImage],
        sourceType: MenuImportSourceDocument.SourceType,
        sourceTypeDetail: String? = nil,
        displayName: String? = nil
    ) {
        guard !images.isEmpty else {
            importStatusMessage = "Es wurden keine Seiten übergeben."
            return
        }

        importInProgress = true
        menuWasApplied = false
        importedSections = []
        importedDraft = nil
        let semanticMode = MenuImportService.isLLMEnabled() && MenuImportService.hasConfiguredLLMAPIKey()
        importStatusMessage = semanticMode
            ? "Texterkennung und KI-Analyse starten..."
            : "Lokale Texterkennung startet..."

        Task {
            do {
                let result = try await MenuImportService.importMenu(
                    from: images,
                    sourceType: sourceType,
                    sourceTypeDetail: sourceTypeDetail,
                    displayName: displayName
                ) { completed, total in
                    await MainActor.run {
                        importStatusMessage = semanticMode
                            ? "Seite \(completed) von \(total) erkannt. KI strukturiert das Menü..."
                            : "Seite \(completed) von \(total) lokal erkannt..."
                    }
                }
                importedSections = result.sections
                importedDraft = result.draft
                importStatusMessage = "Import abgeschlossen. \(MenuImportService.lastImportDiagnostics())"
                showImportPreview = true
            } catch MenuImportService.ImportError.noMenuItemsDetected {
                importStatusMessage = "Keine Artikel erkannt. Bitte klarere, gerade aufgenommene Seiten verwenden."
            } catch {
                importStatusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
            importInProgress = false
        }
    }

    private func startDemoImport(_ fixture: DemoMenuFixture) {
        let images = DemoMenuFixtures.images(for: fixture)
        guard !images.isEmpty else {
            importStatusMessage = "Die Beispielkarte konnte nicht geladen werden."
            return
        }

        startImport(
            images,
            sourceType: .demoFixture,
            sourceTypeDetail: fixture.id,
            displayName: fixture.title
        )
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        importInProgress = true
        importStatusMessage = "Menüfotos werden geladen..."

        do {
            var images: [UIImage] = []
            images.reserveCapacity(items.count)

            for item in items {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else {
                    continue
                }
                images.append(image)
            }

            selectedPhotoItems = []
            guard !images.isEmpty else {
                importInProgress = false
                importStatusMessage = "Keines der ausgewählten Bilder konnte geladen werden."
                return
            }

            startImport(images, sourceType: .photoLibrary)
        } catch {
            selectedPhotoItems = []
            importInProgress = false
            importStatusMessage = "Menüfotos konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }
}

private struct MenuDemoFixturePicker: View {
    let isDisabled: Bool
    let onSelect: (DemoMenuFixture) -> Void

    var body: some View {
        Menu {
            ForEach(DemoMenuFixtures.all) { fixture in
                Button {
                    onSelect(fixture)
                } label: {
                    Label(
                        fixture.title + " · " + String(fixture.pageCount) + " Seiten",
                        systemImage: "doc.text"
                    )
                }
            }
        } label: {
            Label("Beispielkarte testen", systemImage: "doc.text.magnifyingglass")
        }
        .buttonStyle(KitchenLinkV2SecondaryButtonStyle())
        .disabled(isDisabled)
        .accessibilityIdentifier("menuImport.demoFixture")
        .accessibilityHint("Wählt eine mitgelieferte Speisekarte für den Scanner-Test aus.")
    }
}

private struct V2ImportScanFrame: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                .fill(KitchenLinkV2Palette.Surface.recessed)

            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                .fill(KitchenLinkV2Palette.Surface.raised)
                .frame(width: 156, height: 196)
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 11) {
                        Capsule()
                            .fill(KitchenLinkV2Palette.Content.primary.opacity(0.7))
                            .frame(width: 74, height: 8)

                        ForEach([0.86, 0.65, 0.92, 0.72, 0.8], id: \.self) { width in
                            Capsule()
                                .fill(KitchenLinkV2Palette.Content.muted.opacity(0.32))
                                .frame(width: 108 * width, height: 5)
                        }
                    }
                    .padding(KitchenLinkV2Spacing.large)
                }

            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 2)
                .padding(KitchenLinkV2Spacing.large)
        }
        .frame(height: 228)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Neutraler Scanrahmen mit einer Speisekarte")
    }
}
