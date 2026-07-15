import PhotosUI
import SwiftUI
import UIKit
import VisionKit

struct MenuImportEntryView: View {
    @EnvironmentObject private var store: KitchenLinkStore

    let autoStartScanner: Bool

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showDocumentScanner = false
    @State private var didHandleAutoStart = false
    @State private var importInProgress = false
    @State private var importStatusMessage: String?
    @State private var importedSections: [MenuSectionData] = []
    @State private var showImportPreview = false
    @State private var menuWasApplied = false
    @State private var showLegacySandbox = false

    private var importedItemCount: Int {
        importedSections.reduce(0) { $0 + $1.items.count }
    }

    var body: some View {
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
        .accessibilityIdentifier("menuImport.entry")
        .navigationTitle("Speisekarte importieren")
        .navigationBarTitleDisplayMode(.inline)
        .kitchenSurface()
        .sheet(isPresented: $showDocumentScanner) {
            MenuDocumentScannerView { images in
                showDocumentScanner = false
                startImport(images)
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

    private func startImport(_ images: [UIImage]) {
        guard !images.isEmpty else {
            importStatusMessage = "Es wurden keine Seiten übergeben."
            return
        }

        importInProgress = true
        menuWasApplied = false
        importedSections = []
        let semanticMode = MenuImportService.isLLMEnabled() && MenuImportService.hasConfiguredLLMAPIKey()
        importStatusMessage = semanticMode
            ? "Texterkennung und KI-Analyse starten..."
            : "Lokale Texterkennung startet..."

        Task {
            do {
                let sections = try await MenuImportService.importSections(from: images) { completed, total in
                    await MainActor.run {
                        importStatusMessage = semanticMode
                            ? "Seite \(completed) von \(total) erkannt. KI strukturiert das Menü..."
                            : "Seite \(completed) von \(total) lokal erkannt..."
                    }
                }
                importedSections = sections
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

            startImport(images)
        } catch {
            selectedPhotoItems = []
            importInProgress = false
            importStatusMessage = "Menüfotos konnten nicht geladen werden: \(error.localizedDescription)"
        }
    }
}
