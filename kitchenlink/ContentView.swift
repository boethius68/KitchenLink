import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import PhotosUI
import SwiftUI
import UIKit
@preconcurrency import Vision
import VisionKit

private enum DemoQR {
    static let sampleMenuCode = "kitchenlink://menu/sample"
}

private enum KitchenTheme {
    static let brand = Color(red: 0.10, green: 0.46, blue: 0.43)
    static let brandDark = Color(red: 0.05, green: 0.28, blue: 0.27)
    static let accent = Color(red: 0.87, green: 0.48, blue: 0.29)
    static let warmBackground = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.07, green: 0.13, blue: 0.15, alpha: 1)
            }
            return UIColor(red: 0.96, green: 0.93, blue: 0.88, alpha: 1)
        }
    )
    static let card = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.11, green: 0.19, blue: 0.21, alpha: 0.9)
            }
            return UIColor(red: 0.99, green: 0.98, blue: 0.96, alpha: 0.88)
        }
    )
    static let surfaceRaised = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.16, green: 0.24, blue: 0.27, alpha: 0.95)
            }
            return UIColor(red: 1.0, green: 0.99, blue: 0.97, alpha: 0.96)
        }
    )
    static let stroke = Color(
        uiColor: UIColor { trait in
            if trait.userInterfaceStyle == .dark {
                return UIColor(red: 0.75, green: 0.88, blue: 0.84, alpha: 0.22)
            }
            return UIColor(red: 0.18, green: 0.33, blue: 0.31, alpha: 0.18)
        }
    )
}

private struct KitchenBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    KitchenTheme.warmBackground,
                    KitchenTheme.surfaceRaised.opacity(colorScheme == .dark ? 0.62 : 0.82),
                    KitchenTheme.warmBackground
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(KitchenTheme.brand.opacity(colorScheme == .dark ? 0.24 : 0.14))
                .frame(width: 340, height: 340)
                .blur(radius: 20)
                .offset(x: -130, y: -290)

            Circle()
                .fill(KitchenTheme.accent.opacity(colorScheme == .dark ? 0.18 : 0.12))
                .frame(width: 300, height: 300)
                .blur(radius: 22)
                .offset(x: 160, y: 280)
        }
        .ignoresSafeArea()
    }
}

private struct KitchenSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            KitchenBackground()
            content
        }
        .tint(KitchenTheme.brand)
        .fontDesign(.rounded)
    }
}

private extension View {
    func kitchenSurface() -> some View {
        modifier(KitchenSurfaceModifier())
    }
}

private struct KitchenCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(KitchenTheme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KitchenTheme.stroke, lineWidth: 1)
            )
            .shadow(color: KitchenTheme.brandDark.opacity(0.08), radius: 12, y: 6)
    }
}

private struct KitchenPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [KitchenTheme.brand, KitchenTheme.brandDark],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct KitchenSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(KitchenTheme.surfaceRaised.opacity(configuration.isPressed ? 0.82 : 0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(KitchenTheme.stroke, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

struct ContentView: View {
    @State private var showOperatorArea = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    KitchenCard {
                        HStack(alignment: .center, spacing: 14) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 84, height: 84)
                                .padding(6)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(KitchenTheme.brand.opacity(0.16))
                                )
                                .onLongPressGesture(minimumDuration: 1.4) {
                                    showOperatorArea = true
                                }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("KitchenLink")
                                    .font(.system(size: 30, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)

                                Text("Scan. Order. Serve.")
                                    .font(.subheadline)
                                    .foregroundStyle(KitchenTheme.accent)

                                Text("Schnelle digitale Bestellungen für Restaurants und Bars.")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 2)
                            }
                        }
                    }

                    TestQRCodeCard(code: DemoQR.sampleMenuCode)

                    NavigationLink(destination: QRScannerView()) {
                        Label("QR-Code scannen", systemImage: "qrcode.viewfinder")
                    }
                    .buttonStyle(KitchenPrimaryButtonStyle())

                    NavigationLink(destination: SampleMenuView(scanSource: "Direkter Test ohne Scan")) {
                        Label("Beispiel-Menü starten", systemImage: "list.bullet.rectangle.portrait")
                    }
                    .buttonStyle(KitchenSecondaryButtonStyle())

                    Text("Betreiberzugang: Logo gedrückt halten")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(.horizontal, 18)
                .padding(.top, 14)
                .padding(.bottom, 24)
            }
            .navigationTitle("Start")
            .navigationBarTitleDisplayMode(.inline)
        }
        .kitchenSurface()
        .sheet(isPresented: $showOperatorArea) {
            OperatorEntryView()
        }
    }
}

private struct TestQRCodeCard: View {
    let code: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()

    var body: some View {
        KitchenCard {
            VStack(spacing: 10) {
                HStack {
                    Label("Test-QR-Code", systemImage: "qrcode")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                }

                if let image = generateQRCode(from: code) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 210, height: 210)
                        .padding(10)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(KitchenTheme.brand.opacity(0.2), lineWidth: 1)
                        )
                } else {
                    Text("QR-Code konnte nicht erstellt werden.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Text(code)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func generateQRCode(from string: String) -> UIImage? {
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else {
            return nil
        }

        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

private enum CameraPermissionState {
    case checking
    case granted
    case denied
    case unavailable
}

struct QRScannerView: View {
    @State private var permissionState: CameraPermissionState = .checking
    @State private var scannedCode = ""
    @State private var showMenu = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                KitchenCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QR-Scan")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)

                        Text("Scanne den Tischcode oder nutze den Direkt-Test.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        scannerContent

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Erwarteter Testcode")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary.opacity(0.85))
                            Text(DemoQR.sampleMenuCode)
                                .font(.caption)
                                .multilineTextAlignment(.leading)
                                .foregroundStyle(.secondary)
                        }

                        Button {
                            scannedCode = "Direkter Test im Scanner"
                            showMenu = true
                        } label: {
                            Label("Beispiel-Menü ohne Scan", systemImage: "sparkles")
                        }
                        .buttonStyle(KitchenSecondaryButtonStyle())
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 24)
        }
        .navigationTitle("QR-Code scannen")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            requestCameraPermissionIfNeeded()
        }
        .navigationDestination(isPresented: $showMenu) {
            SampleMenuView(scanSource: scannedCode)
        }
        .alert("Scan fehlgeschlagen", isPresented: isShowingAlert, actions: {
            Button("OK") {
                alertMessage = nil
            }
        }, message: {
            Text(alertMessage ?? "")
        })
        .kitchenSurface()
    }

    private var isShowingAlert: Binding<Bool> {
        Binding(
            get: { alertMessage != nil },
            set: { show in
                if !show {
                    alertMessage = nil
                }
            }
        )
    }

    @ViewBuilder
    private var scannerContent: some View {
        switch permissionState {
        case .checking:
            ProgressView("Kamerazugriff wird geprüft...")
                .frame(maxWidth: .infinity, minHeight: 260)

        case .granted:
            QRScannerRepresentable { code in
                handleScannedCode(code)
            }
            .frame(height: 320)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(KitchenTheme.brand, lineWidth: 2)
            )

        case .denied:
            VStack(spacing: 8) {
                Text("Kein Kamerazugriff")
                    .font(.headline)
                Text("Bitte aktiviere den Zugriff in den iOS-Einstellungen, damit QR-Scans funktionieren.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Einstellungen öffnen") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        return
                    }
                    UIApplication.shared.open(url)
                }
                .buttonStyle(KitchenPrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity, minHeight: 260)
            .padding()
            .background(KitchenTheme.surfaceRaised.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

        case .unavailable:
            VStack(spacing: 8) {
                Text("Keine Kamera verfügbar")
                    .font(.headline)
                Text("Auf diesem Gerät ist kein Kamera-Scan möglich. Nutze den Direkt-Test-Button unten.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
            .padding()
            .background(KitchenTheme.surfaceRaised.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func requestCameraPermissionIfNeeded() {
        guard AVCaptureDevice.default(for: .video) != nil else {
            permissionState = .unavailable
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionState = .granted
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    permissionState = granted ? .granted : .denied
                }
            }
        case .denied, .restricted:
            permissionState = .denied
        @unknown default:
            permissionState = .denied
        }
    }

    private func handleScannedCode(_ rawCode: String) {
        let code = rawCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty, !showMenu else {
            return
        }

        if code == DemoQR.sampleMenuCode {
            scannedCode = code
            showMenu = true
        } else {
            alertMessage = "Dieser QR-Code gehört nicht zur Test-Menükarte."
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerViewController {
        let controller = ScannerViewController()
        controller.onScan = onScan
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {}
}

private final class ScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var didEmitCodeRecently = false

    var onScan: ((String) -> Void)?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureSession()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if !captureSession.isRunning {
            captureSession.startRunning()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func configureSession() {
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            return
        }

        guard let videoInput = try? AVCaptureDeviceInput(device: videoDevice) else {
            return
        }

        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: captureSession)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.layer.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !didEmitCodeRecently,
              let metadataObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              metadataObject.type == .qr,
              let code = metadataObject.stringValue else {
            return
        }

        didEmitCodeRecently = true
        onScan?(code)

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.didEmitCodeRecently = false
        }
    }
}

enum MenuItemKind: String, CaseIterable, Codable {
    case drink
    case food

    var title: String {
        switch self {
        case .drink:
            return "Getränke"
        case .food:
            return "Essen"
        }
    }

    var icon: String {
        switch self {
        case .drink:
            return "cup.and.saucer.fill"
        case .food:
            return "fork.knife"
        }
    }
}

struct MenuItemData: Identifiable, Codable {
    let id: String
    var name: String
    var description: String
    var priceCents: Int
    var kind: MenuItemKind
    var variants: [MenuItemVariant]
    var allergenCodes: String?

    init(
        id: String,
        name: String,
        description: String,
        priceCents: Int,
        kind: MenuItemKind,
        variants: [MenuItemVariant] = [],
        allergenCodes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.priceCents = priceCents
        self.kind = kind
        self.variants = variants
        self.allergenCodes = allergenCodes
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case priceCents
        case kind
        case variants
        case allergenCodes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decode(String.self, forKey: .description)
        priceCents = try container.decode(Int.self, forKey: .priceCents)
        kind = try container.decode(MenuItemKind.self, forKey: .kind)
        variants = try container.decodeIfPresent([MenuItemVariant].self, forKey: .variants) ?? []
        allergenCodes = try container.decodeIfPresent(String.self, forKey: .allergenCodes)
    }

    var displayName: String {
        AllergenCodeParser.splitNameAndAllergenCodes(from: name).name
    }

    var resolvedAllergenCodes: String? {
        if let allergenCodes, !allergenCodes.isEmpty {
            return allergenCodes
        }
        return AllergenCodeParser.splitNameAndAllergenCodes(from: name).allergenCodes
    }
}

enum MenuItemOptionKind: String, CaseIterable, Codable {
    case variant
    case extra
    case portion

    var title: String {
        switch self {
        case .variant:
            return "Variante"
        case .extra:
            return "Extra"
        case .portion:
            return "Portion"
        }
    }

    var icon: String {
        switch self {
        case .variant:
            return "arrow.triangle.swap"
        case .extra:
            return "plus.circle.fill"
        case .portion:
            return "scalemass.fill"
        }
    }
}

struct MenuItemVariant: Identifiable, Codable {
    let id: String
    var name: String
    var priceCents: Int
    var kind: MenuItemOptionKind

    init(id: String, name: String, priceCents: Int, kind: MenuItemOptionKind = .variant) {
        self.id = id
        self.name = name
        self.priceCents = priceCents
        self.kind = kind
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case priceCents
        case kind
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        priceCents = try container.decode(Int.self, forKey: .priceCents)
        kind = try container.decodeIfPresent(MenuItemOptionKind.self, forKey: .kind) ?? .variant
    }
}

struct MenuSectionData: Identifiable, Codable {
    let id: String
    var title: String
    var subtitle: String
    var kind: MenuItemKind
    var items: [MenuItemData]
    var importConfidence: Double
    var allergenLegend: [String: String]?

    init(
        id: String,
        title: String,
        subtitle: String,
        kind: MenuItemKind,
        items: [MenuItemData],
        importConfidence: Double = 1.0,
        allergenLegend: [String: String]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.items = items
        self.importConfidence = importConfidence
        self.allergenLegend = allergenLegend
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subtitle
        case kind
        case items
        case importConfidence
        case allergenLegend
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        subtitle = try container.decode(String.self, forKey: .subtitle)
        kind = try container.decode(MenuItemKind.self, forKey: .kind)
        items = try container.decode([MenuItemData].self, forKey: .items)
        importConfidence = try container.decodeIfPresent(Double.self, forKey: .importConfidence) ?? 1.0
        allergenLegend = try container.decodeIfPresent([String: String].self, forKey: .allergenLegend)
    }
}

private enum AllergenCodeParser {
    static let allowedLetterCodes: Set<String> = [
        "a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n"
    ]

    static func tokens(from rawCodes: String) -> [String] {
        let normalized = normalizeSuperscriptCharacters(in: rawCodes).lowercased()
        let candidate = normalized
            .replacingOccurrences(of: #"[.;:/|]"#, with: ",", options: .regularExpression)
            .replacingOccurrences(of: #"[()\[\]{}]"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9,]"#, with: "", options: .regularExpression)

        let parts = candidate.split(separator: ",").map(String.init).filter { !$0.isEmpty }
        guard !parts.isEmpty else { return [] }

        var tokens: [String] = []
        for part in parts {
            let canonical = canonicalizeToken(part)
            if isAllowedToken(canonical) {
                tokens.append(canonical)
                continue
            }
            let expanded = expandCompactToken(canonical)
            tokens.append(contentsOf: expanded.isEmpty ? [canonical] : expanded)
        }

        var deduped: [String] = []
        var seen: Set<String> = []
        for token in tokens where isAllowedToken(token) {
            guard !seen.contains(token) else { continue }
            seen.insert(token)
            deduped.append(token)
        }
        return deduped
    }

    static func splitNameAndAllergenCodes(from text: String) -> (name: String, allergenCodes: String?) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return ("", nil) }

        let normalized = normalizeSuperscriptCharacters(in: cleaned)

        if let split = extractTrailingBracketCodes(from: normalized) {
            return split
        }

        if let split = extractCodes(
            from: normalized,
            pattern: #"(?i)((?:[a-z][0-9]?|[0-9]{1,2})(?:[\s,.;:/|]+(?:[a-z][0-9]?|[0-9]{1,2})){1,30})\s*$"#,
            allowSingleLetterCode: false
        ) {
            return split
        }

        let hasTrailingSuperscriptCode =
            cleaned.range(of: #"[ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿ]\s*$"#, options: .regularExpression) != nil
        if hasTrailingSuperscriptCode {
            if let split = extractCodes(
                from: normalized,
                pattern: #"(?i)([a-z])\s*$"#,
                allowSingleLetterCode: true
            ) {
                return split
            }
        }

        let hasSingleLowercaseCodeSuffix =
            cleaned.range(of: #"\s+[a-n]\s*$"#, options: .regularExpression) != nil

        if hasSingleLowercaseCodeSuffix {
            if let split = extractCodes(
                from: normalized,
                pattern: #"(?i)\s+([a-z])\s*$"#,
                allowSingleLetterCode: true
            ) {
                return split
            }
        }

        if let compactNumericSplit = extractTrailingCompactNumericCodes(from: normalized) {
            return compactNumericSplit
        }

        let containsSuperscriptGlyph =
            cleaned.range(of: #"[⁰¹²³⁴⁵⁶⁷⁸⁹ᵃᵇᶜᵈᵉᶠᵍʰⁱʲᵏˡᵐⁿ]"#, options: .regularExpression) != nil
        if containsSuperscriptGlyph {
            if let split = extractCodes(
                from: normalized,
                pattern: #"(?i)([a-z0-9]{2,20})\s*$"#,
                allowSingleLetterCode: false
            ) {
                return split
            }
        }

        return (cleaned, nil)
    }

    private static func extractTrailingCompactNumericCodes(from normalizedText: String) -> (name: String, allergenCodes: String?)? {
        guard let regex = try? NSRegularExpression(pattern: #"\s([0-9]{2,4})\s*$"#),
              let match = regex.firstMatch(in: normalizedText, range: NSRange(normalizedText.startIndex..., in: normalizedText)),
              let fullCodeRange = Range(match.range(at: 0), in: normalizedText),
              let codeRange = Range(match.range(at: 1), in: normalizedText) else {
            return nil
        }

        let rawCodes = String(normalizedText[codeRange])
        let parsed = tokens(from: rawCodes)
        guard parsed.count >= 2 else { return nil }
        guard parsed.allSatisfy({ Int($0) != nil || allowedLetterCodes.contains($0) }) else { return nil }

        let namePrefix = String(normalizedText[..<fullCodeRange.lowerBound])
        let name = sanitizeNameCandidate(namePrefix)
        guard !name.isEmpty else { return nil }
        return (name, parsed.joined(separator: ","))
    }

    private static func extractCodes(
        from normalizedText: String,
        pattern: String,
        allowSingleLetterCode: Bool
    ) -> (name: String, allergenCodes: String?)? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: normalizedText, range: NSRange(normalizedText.startIndex..., in: normalizedText)),
              let codesRange = Range(match.range(at: 1), in: normalizedText) else {
            return nil
        }

        let tokens = tokens(from: String(normalizedText[codesRange]))
        guard !tokens.isEmpty else { return nil }

        if allowSingleLetterCode {
            guard tokens.count == 1 else { return nil }
            let only = tokens[0]
            guard allowedLetterCodes.contains(only) || only.range(of: #"^[a-n][0-9]$"#, options: .regularExpression) != nil else {
                return nil
            }
        } else {
            guard tokens.count >= 2 else { return nil }
        }

        let namePrefix = String(normalizedText[..<codesRange.lowerBound])
        let name = namePrefix
            .replacingOccurrences(of: #"[,\.;:/|]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        return (name, tokens.joined(separator: ","))
    }

    private static func extractTrailingBracketCodes(from text: String) -> (name: String, allergenCodes: String?)? {
        let patterns = [
            #"\(([^)]{1,120})\)\s*$"#,
            #"\[([^\]]{1,120})\]\s*$"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let fullRange = Range(match.range(at: 0), in: text),
                  let codesRange = Range(match.range(at: 1), in: text) else {
                continue
            }

            let rawCodes = String(text[codesRange])
            let parsed = tokens(from: rawCodes)
            guard looksLikeCodeBlock(rawCodes, parsedTokens: parsed) else { continue }

            let namePrefix = String(text[..<fullRange.lowerBound])
            let name = sanitizeNameCandidate(namePrefix)
            guard !name.isEmpty else { continue }
            return (name, parsed.joined(separator: ","))
        }
        return nil
    }

    private static func looksLikeCodeBlock(_ raw: String, parsedTokens: [String]) -> Bool {
        guard !parsedTokens.isEmpty else { return false }
        let normalized = raw
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[.;:/|]"#, with: ",", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9,]"#, with: "", options: .regularExpression)
        guard !normalized.isEmpty else { return false }

        let commaCount = normalized.filter { $0 == "," }.count
        if parsedTokens.count >= 2 || commaCount >= 1 {
            return true
        }

        return normalized.count <= 3
    }

    private static func sanitizeNameCandidate(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: #"[,\.;:/|]+$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isAllowedToken(_ token: String) -> Bool {
        if allowedLetterCodes.contains(token) {
            return true
        }
        if token.range(of: #"^[a-n][0-9]$"#, options: .regularExpression) != nil {
            return true
        }
        if let number = Int(token), (1 ... 14).contains(number) {
            return true
        }
        return false
    }

    private static func canonicalizeToken(_ raw: String) -> String {
        var token = raw.lowercased()
        token = token.replacingOccurrences(of: "!", with: "1")
        token = token.replacingOccurrences(of: "|", with: "1")

        guard token.count == 2 else { return token }
        var characters = Array(token)
        if characters[0].isLetter {
            if characters[1] == "l" || characters[1] == "i" {
                characters[1] = "1"
            } else if characters[1] == "s" {
                characters[1] = "5"
            }
        }
        return String(characters)
    }

    private static func expandCompactToken(_ token: String) -> [String] {
        guard token.range(of: #"^[a-z0-9]+$"#, options: .regularExpression) != nil else {
            return []
        }
        if isAllowedToken(token) {
            return [token]
        }

        if token.allSatisfy(\.isNumber) {
            let digits = Array(token)
            if digits.count == 2 {
                if let value = Int(token), (10 ... 14).contains(value) {
                    return [token]
                }
                return digits.compactMap { char in
                    let single = String(char)
                    guard let number = Int(single), (1 ... 9).contains(number) else { return nil }
                    return single
                }
            }
            return digits.compactMap { char in
                let single = String(char)
                guard let number = Int(single), (1 ... 9).contains(number) else { return nil }
                return single
            }
        }

        var result: [String] = []
        var index = token.startIndex
        while index < token.endIndex {
            let char = token[index]
            if char.isLetter {
                let next = token.index(after: index)
                if next < token.endIndex, token[next].isNumber {
                    let pair = String(token[index...next])
                    if isAllowedToken(pair) {
                        result.append(pair)
                        index = token.index(after: next)
                        continue
                    }
                }
                let single = String(char)
                if isAllowedToken(single) {
                    result.append(single)
                    index = next
                    continue
                }
                return []
            }

            if char.isNumber {
                let next = token.index(after: index)
                if next < token.endIndex, token[next].isNumber {
                    let two = String(token[index...next])
                    if let n = Int(two), (10 ... 14).contains(n) {
                        result.append(two)
                        index = token.index(after: next)
                        continue
                    }
                }
                result.append(String(char))
                index = next
                continue
            }

            result.append(String(char))
            index = token.index(after: index)
        }

        return result.allSatisfy { isAllowedToken($0) } ? result : []
    }

    static func normalizeSuperscriptCharacters(in text: String) -> String {
        let replacements: [Character: String] = [
            "⁰": "0", "¹": "1", "²": "2", "³": "3", "⁴": "4", "⁵": "5", "⁶": "6", "⁷": "7", "⁸": "8", "⁹": "9",
            "ᵃ": "a", "ᵇ": "b", "ᶜ": "c", "ᵈ": "d", "ᵉ": "e", "ᶠ": "f", "ᵍ": "g", "ʰ": "h", "ⁱ": "i", "ʲ": "j",
            "ᵏ": "k", "ˡ": "l", "ᵐ": "m", "ⁿ": "n",
            "а": "a", "б": "b", "с": "c", "е": "e", "о": "o", "р": "p", "і": "i"
        ]

        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            if let mapped = replacements[character] {
                result.append(mapped)
            } else {
                result.append(character)
            }
        }
        return result
    }
}

private enum DemoMenuFactory {
    static func buildDefaultSections() -> [MenuSectionData] {
        [
            MenuSectionData(
                id: "s-drinks-soft",
                title: "Soft Drinks",
                subtitle: "Hausgemacht und Klassiker",
                kind: .drink,
                items: [
                    MenuItemData(id: "d-limo", name: "Haus-Limonade", description: "Zitrone, Minze, Soda", priceCents: 450, kind: .drink),
                    MenuItemData(id: "d-cola", name: "Cola Zero 0,33l", description: "Eisgekühlt serviert", priceCents: 360, kind: .drink),
                    MenuItemData(id: "d-ginger", name: "Ginger Ale 0,2l", description: "Mit Limettenscheibe", priceCents: 330, kind: .drink)
                ]
            ),
            MenuSectionData(
                id: "s-drinks-hot",
                title: "Kaffee & Tee",
                subtitle: "Frisch gebrüht",
                kind: .drink,
                items: [
                    MenuItemData(id: "d-espresso", name: "Espresso Doppio", description: "Kräftig geröstet", priceCents: 280, kind: .drink),
                    MenuItemData(id: "d-cappuccino", name: "Cappuccino", description: "Mit feinporigem Milchschaum", priceCents: 390, kind: .drink),
                    MenuItemData(id: "d-tea", name: "Bio Minztee", description: "Frische Minze, Honig optional", priceCents: 340, kind: .drink)
                ]
            ),
            MenuSectionData(
                id: "s-food-starters",
                title: "Vorspeisen",
                subtitle: "Zum Teilen oder solo",
                kind: .food,
                items: [
                    MenuItemData(id: "f-bruschetta", name: "Bruschetta", description: "Tomaten, Basilikum, Knoblauch", priceCents: 690, kind: .food),
                    MenuItemData(id: "f-soup", name: "Tomatensuppe", description: "Mit Crostini", priceCents: 650, kind: .food),
                    MenuItemData(id: "f-salad", name: "Caesar Salad", description: "Romanasalat, Croutons, Parmesan", priceCents: 990, kind: .food)
                ]
            ),
            MenuSectionData(
                id: "s-food-main",
                title: "Hauptgerichte",
                subtitle: "Beliebte Klassiker",
                kind: .food,
                items: [
                    MenuItemData(id: "f-margherita", name: "Pizza Margherita", description: "Tomate, Mozzarella, Basilikum", priceCents: 1090, kind: .food),
                    MenuItemData(id: "f-burger", name: "Cheeseburger", description: "Rind, Cheddar, Haus-Sauce", priceCents: 1250, kind: .food),
                    MenuItemData(id: "f-pasta", name: "Pasta Arrabbiata", description: "Pikante Tomatensauce, Parmesan", priceCents: 1180, kind: .food),
                    MenuItemData(id: "f-schnitzel", name: "Wiener Schnitzel", description: "Pommes oder Kartoffelsalat", priceCents: 1690, kind: .food)
                ]
            )
        ]
    }
}

private enum PriceFormatter {
    static let formatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "EUR"
        formatter.locale = Locale(identifier: "de_DE")
        return formatter
    }()

    static func string(cents: Int) -> String {
        formatter.string(from: NSNumber(value: Double(cents) / 100.0)) ?? "\(cents) ct"
    }
}

private struct AllergenDefinition: Identifiable {
    let code: String
    let title: String
    let icon: String
    let tint: Color

    var id: String { code }
}

private enum AllergenCatalog {
    static let definitionsByCode: [String: AllergenDefinition] = [
        "a": AllergenDefinition(code: "a", title: "Glutenhaltiges Getreide", icon: "leaf", tint: .orange),
        "b": AllergenDefinition(code: "b", title: "Krebstiere", icon: "fish", tint: .cyan),
        "c": AllergenDefinition(code: "c", title: "Eier", icon: "circle.grid.2x2.fill", tint: .yellow),
        "d": AllergenDefinition(code: "d", title: "Fisch", icon: "fish.fill", tint: .blue),
        "e": AllergenDefinition(code: "e", title: "Erdnüsse", icon: "bolt.heart", tint: .brown),
        "f": AllergenDefinition(code: "f", title: "Soja", icon: "circle.hexagongrid.fill", tint: .green),
        "g": AllergenDefinition(code: "g", title: "Milch / Laktose", icon: "drop.fill", tint: .mint),
        "h": AllergenDefinition(code: "h", title: "Schalenfrüchte (Nüsse)", icon: "circle.dashed", tint: .teal),
        "i": AllergenDefinition(code: "i", title: "Sellerie", icon: "leaf.fill", tint: .green),
        "j": AllergenDefinition(code: "j", title: "Senf", icon: "flame.fill", tint: .yellow),
        "k": AllergenDefinition(code: "k", title: "Sesamsamen", icon: "smallcircle.filled.circle.fill", tint: .orange),
        "l": AllergenDefinition(code: "l", title: "Schwefeldioxid / Sulfite", icon: "aqi.medium", tint: .purple),
        "m": AllergenDefinition(code: "m", title: "Lupinen", icon: "sparkles", tint: .indigo),
        "n": AllergenDefinition(code: "n", title: "Weichtiere", icon: "tortoise.fill", tint: .blue),
        "o": AllergenDefinition(code: "o", title: "Knoblauch", icon: "fork.knife", tint: .orange),
        "p": AllergenDefinition(code: "p", title: "Zwiebeln", icon: "circle.grid.cross.fill", tint: .orange),
        "1": AllergenDefinition(code: "1", title: "mit Farbstoff", icon: "paintpalette.fill", tint: .pink),
        "2": AllergenDefinition(code: "2", title: "mit Konservierungsstoff", icon: "archivebox.fill", tint: .gray),
        "3": AllergenDefinition(code: "3", title: "mit Antioxidationsmittel", icon: "shield.lefthalf.filled", tint: .gray),
        "4": AllergenDefinition(code: "4", title: "mit Geschmacksverstärker", icon: "waveform.path.ecg", tint: .red),
        "5": AllergenDefinition(code: "5", title: "geschwefelt", icon: "cloud.fill", tint: .purple),
        "6": AllergenDefinition(code: "6", title: "geschwärzt", icon: "moon.fill", tint: .black),
        "7": AllergenDefinition(code: "7", title: "gewachst", icon: "drop.triangle.fill", tint: .mint),
        "8": AllergenDefinition(code: "8", title: "mit Phosphat", icon: "atom", tint: .blue),
        "9": AllergenDefinition(code: "9", title: "mit Süßungsmittel", icon: "heart.circle.fill", tint: .pink),
        "10": AllergenDefinition(code: "10", title: "enthält eine Phenylalaninquelle", icon: "exclamationmark.triangle.fill", tint: .orange),
        "11": AllergenDefinition(code: "11", title: "koffeinhaltig", icon: "bolt.fill", tint: .brown),
        "12": AllergenDefinition(code: "12", title: "chininhaltig", icon: "cross.case.fill", tint: .blue),
        "13": AllergenDefinition(code: "13", title: "alkoholhaltig", icon: "wineglass.fill", tint: .purple),
        "14": AllergenDefinition(code: "14", title: "taurin-haltig", icon: "hare.fill", tint: .red)
    ]

    static func definitions(for rawCodes: String, customTitles: [String: String]? = nil) -> [AllergenDefinition] {
        var tokens = AllergenCodeParser.tokens(from: rawCodes)
        if let customTitles, !customTitles.isEmpty {
            let allowed = Set(customTitles.keys.map { $0.lowercased() })
            tokens = tokens.filter { allowed.contains($0.lowercased()) }
        }

        var seen: Set<String> = []
        var result: [AllergenDefinition] = []

        for token in tokens {
            guard !seen.contains(token) else { continue }
            seen.insert(token)

            if let customTitle = customTitles?[token], !customTitle.isEmpty {
                result.append(definition(fromLegendTitle: customTitle, code: token))
            } else if let mapped = definitionsByCode[token] {
                result.append(mapped)
            } else {
                result.append(
                    AllergenDefinition(
                        code: token,
                        title: "Code \(token.uppercased())",
                        icon: "questionmark.circle.fill",
                        tint: .gray
                    )
                )
            }
        }
        return result
    }

    private static func definition(fromLegendTitle title: String, code: String) -> AllergenDefinition {
        let normalized = title
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()

        if normalized.contains("fisch") {
            return AllergenDefinition(code: code, title: title, icon: "fish.fill", tint: .blue)
        }
        if normalized.contains("milch") || normalized.contains("laktose") {
            return AllergenDefinition(code: code, title: title, icon: "drop.fill", tint: .mint)
        }
        if normalized.contains("krebstier") || normalized.contains("garnel") || normalized.contains("scampi") {
            return AllergenDefinition(code: code, title: title, icon: "fish", tint: .cyan)
        }
        if normalized.contains("ei") || normalized.contains("eier") {
            return AllergenDefinition(code: code, title: title, icon: "circle.grid.2x2.fill", tint: .yellow)
        }
        if normalized.contains("senf") {
            return AllergenDefinition(code: code, title: title, icon: "flame.fill", tint: .yellow)
        }
        if normalized.contains("sesam") {
            return AllergenDefinition(code: code, title: title, icon: "smallcircle.filled.circle.fill", tint: .orange)
        }
        if normalized.contains("sellerie") {
            return AllergenDefinition(code: code, title: title, icon: "leaf.fill", tint: .green)
        }
        if normalized.contains("knoblauch") || normalized.contains("zwiebel") {
            return AllergenDefinition(code: code, title: title, icon: "fork.knife", tint: .orange)
        }
        if normalized.contains("erdnuss") || normalized.contains("nuss") {
            return AllergenDefinition(code: code, title: title, icon: "bolt.heart", tint: .brown)
        }
        if normalized.contains("soja") {
            return AllergenDefinition(code: code, title: title, icon: "circle.hexagongrid.fill", tint: .green)
        }
        if normalized.contains("gluten") || normalized.contains("getreide") {
            return AllergenDefinition(code: code, title: title, icon: "leaf", tint: .orange)
        }
        if normalized.contains("konserv") {
            return AllergenDefinition(code: code, title: title, icon: "archivebox.fill", tint: .gray)
        }
        if normalized.contains("farbstoff") {
            return AllergenDefinition(code: code, title: title, icon: "paintpalette.fill", tint: .pink)
        }
        if normalized.contains("antioxid") {
            return AllergenDefinition(code: code, title: title, icon: "shield.lefthalf.filled", tint: .gray)
        }
        if normalized.contains("geschmacksverst") {
            return AllergenDefinition(code: code, title: title, icon: "waveform.path.ecg", tint: .red)
        }
        if normalized.contains("geschwefelt") {
            return AllergenDefinition(code: code, title: title, icon: "cloud.fill", tint: .purple)
        }
        if normalized.contains("geschwarz") {
            return AllergenDefinition(code: code, title: title, icon: "moon.fill", tint: .black)
        }
        if normalized.contains("phosphor") || normalized.contains("phosphat") {
            return AllergenDefinition(code: code, title: title, icon: "atom", tint: .blue)
        }
        if normalized.contains("sussungsmittel") || normalized.contains("suessungsmittel") {
            return AllergenDefinition(code: code, title: title, icon: "heart.circle.fill", tint: .pink)
        }
        if normalized.contains("alkohol") {
            return AllergenDefinition(code: code, title: title, icon: "wineglass.fill", tint: .purple)
        }
        if normalized.contains("koffein") {
            return AllergenDefinition(code: code, title: title, icon: "bolt.fill", tint: .brown)
        }

        if let mapped = definitionsByCode[code] {
            return AllergenDefinition(code: code, title: title, icon: mapped.icon, tint: mapped.tint)
        }
        return AllergenDefinition(code: code, title: title, icon: "questionmark.circle.fill", tint: .gray)
    }
}

private struct AllergenBadgeView: View {
    let definition: AllergenDefinition

    var body: some View {
        VStack(spacing: 1) {
            Image(systemName: definition.icon)
                .font(.caption2)
            Text(definition.code.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(definition.tint.opacity(0.15))
        .foregroundStyle(definition.tint)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(definition.title), Code \(definition.code.uppercased())")
    }
}

private struct AllergenLegendView: View {
    let definitions: [AllergenDefinition]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Bedeutung der Codes") {
                    ForEach(definitions) { definition in
                        HStack(spacing: 10) {
                            AllergenBadgeView(definition: definition)
                            Text(definition.title)
                                .font(.subheadline)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Allergen-Legende")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fertig") {
                        dismiss()
                    }
                }
            }
        }
        .kitchenSurface()
    }
}

private struct AllergenBadgesRow: View {
    let rawCodes: String
    let legendByCode: [String: String]?
    @State private var showLegend = false

    init(rawCodes: String, legendByCode: [String: String]? = nil) {
        self.rawCodes = rawCodes
        self.legendByCode = legendByCode
    }

    private var definitions: [AllergenDefinition] {
        AllergenCatalog.definitions(for: rawCodes, customTitles: legendByCode)
    }

    var body: some View {
        if !definitions.isEmpty {
            HStack(spacing: 6) {
                ForEach(definitions.prefix(6)) { definition in
                    AllergenBadgeView(definition: definition)
                }

                if definitions.count > 6 {
                    Text("+\(definitions.count - 6)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Button {
                    showLegend = true
                } label: {
                    Image(systemName: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(KitchenTheme.accent)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Allergen-Legende anzeigen")
            }
            .sheet(isPresented: $showLegend) {
                AllergenLegendView(definitions: definitions)
            }
        }
    }
}

private struct MenuItemOptionsListView: View {
    let options: [MenuItemVariant]

    private var orderedOptions: [MenuItemVariant] {
        let priority: [MenuItemOptionKind: Int] = [.portion: 0, .variant: 1, .extra: 2]
        return options.sorted { lhs, rhs in
            let left = priority[lhs.kind] ?? 99
            let right = priority[rhs.kind] ?? 99
            if left != right { return left < right }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func tint(for kind: MenuItemOptionKind) -> Color {
        switch kind {
        case .portion:
            return .blue
        case .variant:
            return KitchenTheme.accent
        case .extra:
            return .green
        }
    }

    private var portionOptions: [MenuItemVariant] {
        orderedOptions.filter { $0.kind == .portion }
    }

    private var nonPortionOptions: [MenuItemVariant] {
        orderedOptions.filter { $0.kind != .portion }
    }

    var body: some View {
        if !orderedOptions.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                if !portionOptions.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(portionOptions) { option in
                                HStack(spacing: 5) {
                                    Image(systemName: option.kind.icon)
                                        .font(.caption2)
                                    Text(option.name)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                    Text(PriceFormatter.string(cents: option.priceCents))
                                        .font(.caption2)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .foregroundStyle(tint(for: option.kind))
                                .background(tint(for: option.kind).opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }

                ForEach(nonPortionOptions) { option in
                    HStack(spacing: 6) {
                        Image(systemName: option.kind.icon)
                            .font(.caption2)
                        Text("\(option.kind.title): \(option.name)")
                            .font(.caption)
                        Spacer()
                        Text(PriceFormatter.string(cents: option.priceCents))
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .foregroundStyle(tint(for: option.kind))
                }
            }
            .padding(.top, 2)
        }
    }
}

private struct CartCountBadge: View {
    let title: String
    let icon: String
    let count: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.16))
        .foregroundStyle(tint)
        .clipShape(Capsule())
        .accessibilityLabel("\(title): \(count)")
    }
}

struct SampleMenuView: View {
    let scanSource: String

    @EnvironmentObject private var store: KitchenLinkStore
    @EnvironmentObject private var relay: OrderRelayService
    @State private var cartQuantities: [String: Int] = [:]

    private var sections: [MenuSectionData] {
        store.menuSections
    }

    private var allItems: [MenuItemData] {
        sections.flatMap(\.items)
    }

    private var itemsByID: [String: MenuItemData] {
        Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })
    }

    private var totalItemCount: Int {
        cartQuantities.values.reduce(0, +)
    }

    private var drinkItemCount: Int {
        countForKind(.drink)
    }

    private var foodItemCount: Int {
        countForKind(.food)
    }

    private var totalPriceCents: Int {
        allItems.reduce(0) { partial, item in
            partial + item.priceCents * quantity(for: item.id)
        }
    }

    private var customerConnectionColor: Color {
        relay.isConnected ? .green : .orange
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Beispiel-Menükarte")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Geöffnet durch: \(scanSource)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Circle()
                            .fill(customerConnectionColor)
                            .frame(width: 8, height: 8)
                        Text(relay.connectionText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                    HStack {
                        Label("\(totalItemCount) Artikel", systemImage: "cart.fill")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Spacer()
                        Text(PriceFormatter.string(cents: totalPriceCents))
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(KitchenTheme.card)
                        .padding(.vertical, 2)
                )
            }

            ForEach(sections) { section in
                Section {
                    ForEach(section.items, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.displayName)
                                        .font(.headline)
                                    Text(item.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)

                                    allergenRow(for: item, in: section)

                                    MenuItemOptionsListView(options: item.variants)
                                }
                                Spacer()
                                Text(PriceFormatter.string(cents: item.priceCents))
                                    .font(.subheadline)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    removeItem(item.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(quantity(for: item.id) > 0 ? Color.red : Color.gray.opacity(0.35))
                                .disabled(quantity(for: item.id) == 0)

                                Text("\(quantity(for: item.id))")
                                    .font(.body)
                                    .frame(minWidth: 24)

                                Button {
                                    addItem(item.id)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(Color.green)

                                Spacer()

                                if quantity(for: item.id) > 0 {
                                    Text("im Warenkorb")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(KitchenTheme.surfaceRaised)
                                .padding(.vertical, 1)
                        )
                    }
                } header: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(section.title)
                        Text(section.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Menü")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                HStack(spacing: 8) {
                    NavigationLink {
                        SampleCartView(itemsByID: itemsByID, cartQuantities: $cartQuantities)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cart.fill")
                            Text("\(totalItemCount)")
                                .fontWeight(.semibold)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(KitchenTheme.brand.opacity(0.18))
                        .clipShape(Capsule())
                    }
                    .fixedSize()

                    HStack(spacing: 6) {
                        CartCountBadge(
                            title: "Getränke",
                            icon: "cup.and.saucer.fill",
                            count: drinkItemCount,
                            tint: .blue
                        )
                        CartCountBadge(
                            title: "Essen",
                            icon: "fork.knife",
                            count: foodItemCount,
                            tint: .orange
                        )
                    }
                    .font(.caption2)
                    .fixedSize()
                    .minimumScaleFactor(0.8)
                }
            }
        }
        .onAppear {
            relay.startBrowsingAsCustomer()
        }
        .kitchenSurface()
    }

    private func quantity(for itemID: String) -> Int {
        cartQuantities[itemID, default: 0]
    }

    @ViewBuilder
    private func allergenRow(for item: MenuItemData, in section: MenuSectionData) -> some View {
        if let allergenCodes = item.resolvedAllergenCodes, !allergenCodes.isEmpty {
            AllergenBadgesRow(rawCodes: allergenCodes, legendByCode: section.allergenLegend)
        }
    }

    private func addItem(_ itemID: String) {
        cartQuantities[itemID, default: 0] += 1
    }

    private func removeItem(_ itemID: String) {
        let current = cartQuantities[itemID, default: 0]
        guard current > 0 else { return }

        if current == 1 {
            cartQuantities[itemID] = nil
        } else {
            cartQuantities[itemID] = current - 1
        }
    }

    private func countForKind(_ kind: MenuItemKind) -> Int {
        allItems.reduce(0) { partial, item in
            guard item.kind == kind else { return partial }
            return partial + quantity(for: item.id)
        }
    }
}

private struct SampleCartEntry: Identifiable {
    let item: MenuItemData
    let quantity: Int

    var id: String { item.id }
    var lineTotalCents: Int { item.priceCents * quantity }
}

private struct SampleCartView: View {
    let itemsByID: [String: MenuItemData]
    @Binding var cartQuantities: [String: Int]

    @EnvironmentObject private var relay: OrderRelayService
    @State private var showOrderSuccess = false
    @State private var orderFeedbackMessage = ""

    private var entries: [SampleCartEntry] {
        cartQuantities
            .filter { $0.value > 0 }
            .compactMap { key, value in
                guard let item = itemsByID[key] else { return nil }
                return SampleCartEntry(item: item, quantity: value)
            }
            .sorted { $0.item.displayName < $1.item.displayName }
    }

    private var totalItems: Int {
        entries.reduce(0) { $0 + $1.quantity }
    }

    private var totalPriceCents: Int {
        entries.reduce(0) { $0 + $1.lineTotalCents }
    }

    var body: some View {
        List {
            Section("Verbindung") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(relay.isConnected ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(relay.connectionText)
                        .font(.subheadline)
                }
                .listRowBackground(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(KitchenTheme.card)
                        .padding(.vertical, 2)
                )
            }

            if entries.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "cart")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Dein Warenkorb ist leer.")
                            .font(.headline)
                        Text("Wähle auf der Menükarte Artikel mit dem Plus-Button aus.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 22)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(KitchenTheme.card)
                            .padding(.vertical, 2)
                    )
                }
            } else {
                Section("Positionen") {
                    ForEach(entries) { entry in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.item.displayName)
                                        .font(.headline)
                                    Text(PriceFormatter.string(cents: entry.item.priceCents))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(PriceFormatter.string(cents: entry.lineTotalCents))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }

                            HStack(spacing: 10) {
                                Button {
                                    removeItem(entry.item.id)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.red)

                                Text("\(entry.quantity)")
                                    .frame(minWidth: 24)

                                Button {
                                    addItem(entry.item.id)
                                } label: {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.title3)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.green)
                            }
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(KitchenTheme.surfaceRaised)
                                .padding(.vertical, 1)
                        )
                    }
                }

                Section("Summe") {
                    HStack {
                        Text("Artikel")
                        Spacer()
                        Text("\(totalItems)")
                    }
                    HStack {
                        Text("Gesamt")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(PriceFormatter.string(cents: totalPriceCents))
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .navigationTitle("Warenkorb")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                HStack {
                    Text("Gesamt")
                        .fontWeight(.semibold)
                    Spacer()
                    Text(PriceFormatter.string(cents: totalPriceCents))
                        .fontWeight(.semibold)
                }
                Button {
                    placeOrder()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "paperplane.fill")
                        Text("Bestellen")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(KitchenPrimaryButtonStyle())
                .disabled(entries.isEmpty)
                .opacity(entries.isEmpty ? 0.55 : 1)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .alert("Bestellung gesendet", isPresented: $showOrderSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(orderFeedbackMessage)
        }
        .kitchenSurface()
    }

    private func addItem(_ itemID: String) {
        cartQuantities[itemID, default: 0] += 1
    }

    private func removeItem(_ itemID: String) {
        let current = cartQuantities[itemID, default: 0]
        guard current > 0 else { return }

        if current == 1 {
            cartQuantities[itemID] = nil
        } else {
            cartQuantities[itemID] = current - 1
        }
    }

    private func placeOrder() {
        guard !entries.isEmpty else { return }

        let order = LiveOrderMessage(
            id: UUID().uuidString,
            createdAt: Date(),
            sourceDevice: UIDevice.current.name,
            items: entries.map {
                LiveOrderLine(
                    id: UUID().uuidString,
                    name: $0.item.displayName,
                    quantity: $0.quantity,
                    unitPriceCents: $0.item.priceCents,
                    kind: $0.item.kind
                )
            },
            totalCents: totalPriceCents
        )

        Task {
            let sentToOperator = await relay.send(order: order)
            orderFeedbackMessage = sentToOperator
                ? "Die Bestellung wurde via Internet an den Betreiber übertragen."
                : "Bestellung konnte nicht an Supabase gesendet werden."

            if sentToOperator {
                cartQuantities.removeAll()
            }
            showOrderSuccess = true
        }
    }
}

private struct OperatorEntryView: View {
    @EnvironmentObject private var store: KitchenLinkStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if store.isOperatorLoggedIn {
                    OperatorDashboardView()
                } else {
                    OperatorLoginView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Schliessen") {
                        dismiss()
                    }
                }
            }
        }
        .kitchenSurface()
    }
}

private struct OperatorLoginView: View {
    @EnvironmentObject private var store: KitchenLinkStore

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section("Login") {
                TextField("E-Mail", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()

                SecureField("Passwort", text: $password)

                Button("Einloggen") {
                    login()
                }
                .buttonStyle(KitchenPrimaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Testzugang") {
                Text("E-Mail: owner@kitchenlink.test")
                Text("Passwort: 123456")
            }
        }
        .navigationTitle("Betreiber Login")
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .onAppear {
            if email.isEmpty {
                email = "owner@kitchenlink.test"
            }
            if password.isEmpty {
                password = "123456"
            }
        }
    }

    private func login() {
        let success = store.loginOperator(email: email, password: password)
        errorMessage = success ? nil : "Login fehlgeschlagen. Bitte Zugangsdaten prüfen."
    }
}

private enum OperatorTab: String, CaseIterable, Identifiable {
    case orders
    case menu

    var id: String { rawValue }

    var title: String {
        switch self {
        case .orders:
            return "Bestellungen"
        case .menu:
            return "Menü"
        }
    }
}

private struct OperatorDashboardView: View {
    @EnvironmentObject private var store: KitchenLinkStore
    @EnvironmentObject private var relay: OrderRelayService

    @State private var selectedTab: OperatorTab = .orders

    var body: some View {
        VStack(spacing: 12) {
            Picker("Bereich", selection: $selectedTab) {
                ForEach(OperatorTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 10)

            Group {
                switch selectedTab {
                case .orders:
                    OperatorOrdersView()
                case .menu:
                    OperatorMenuEditorView()
                }
            }
        }
        .navigationTitle("Betreiber")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Logout") {
                    store.logoutOperator()
                    relay.stopNetworking()
                }
            }
        }
        .onAppear {
            relay.startHostingAsOwner()
        }
    }
}

private struct OperatorOrdersView: View {
    @EnvironmentObject private var relay: OrderRelayService

    var body: some View {
        List {
            Section("Live-Verbindung") {
                HStack(spacing: 8) {
                    Circle()
                        .fill(relay.isConnected ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(relay.connectionText)
                }

                HStack {
                    Button("Empfang starten") {
                        relay.startHostingAsOwner()
                    }
                    .buttonStyle(KitchenPrimaryButtonStyle())

                    Button("Stop") {
                        relay.stopNetworking()
                    }
                    .buttonStyle(KitchenSecondaryButtonStyle())
                }

                Text("Test: Auf einem zweiten Gerät als Kunde bestellen. Die Bestellung sollte hier sofort auftauchen.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Eingehende Bestellungen") {
                if relay.receivedOrders.isEmpty {
                    Text("Noch keine Test-Bestellungen eingegangen.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relay.receivedOrders) { order in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Bestellung \(order.id.prefix(6))")
                                    .font(.headline)
                                Spacer()
                                Text(PriceFormatter.string(cents: order.totalCents))
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                            }
                            Text("Von: \(order.sourceDevice)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(order.createdAt.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            ForEach(order.items) { line in
                                HStack {
                                    Text("\(line.quantity)x \(line.name)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(PriceFormatter.string(cents: line.lineTotalCents))
                                        .font(.subheadline)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !relay.receivedOrders.isEmpty {
                Section {
                    Button("Bestellungen leeren", role: .destructive) {
                        relay.clearReceivedOrders()
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

private struct OperatorMenuEditorView: View {
    @EnvironmentObject private var store: KitchenLinkStore

    @State private var itemName = ""
    @State private var itemDescription = ""
    @State private var itemPrice = "4,50"
    @State private var selectedKind: MenuItemKind = .drink
    @State private var selectedSectionID = ""
    @State private var formErrorMessage: String?
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showDocumentScanner = false
    @State private var importInProgress = false
    @State private var importStatusMessage: String?
    @State private var llmImportEnabled = MenuImportService.isLLMEnabled()
    @State private var llmAPIKeyInput = MenuImportService.storedLLMAPIKey()
    @State private var llmConfigMessage: String?
    @State private var importedSectionsPreview: [MenuSectionData] = []
    @State private var showImportPreview = false

    private var filteredSections: [MenuSectionData] {
        store.menuSections.filter { $0.kind == selectedKind }
    }

    var body: some View {
        Form {
            Section("Menü aus Foto importieren (Beta)") {
                Button {
                    showDocumentScanner = true
                } label: {
                    Label("Speisekarte scannen", systemImage: "doc.viewfinder")
                }
                .buttonStyle(KitchenSecondaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 6, trailing: 0))

                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 24, matching: .images, photoLibrary: .shared()) {
                    HStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                        Text("Bilder aus Mediathek wählen")
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(KitchenSecondaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 8, trailing: 0))

                if importInProgress {
                    MenuImportWhooshView()
                }

                if let importStatusMessage {
                    Text(importStatusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Toggle(isOn: $llmImportEnabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KI-Reflexion für Import nutzen")
                        Text("Besser für komplexe Karten, Varianten und Portionen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onChange(of: llmImportEnabled) { _, newValue in
                    MenuImportService.setLLMEnabled(newValue)
                }

                SecureField("OpenAI API-Key (optional)", text: $llmAPIKeyInput)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.caption)

                Button("API-Key speichern") {
                    MenuImportService.saveLLMAPIKey(llmAPIKeyInput)
                    llmConfigMessage = MenuImportService.hasConfiguredLLMAPIKey()
                        ? "API-Key gespeichert."
                        : "Kein API-Key gespeichert. Import läuft nur mit OCR-Regeln."
                }
                .buttonStyle(KitchenSecondaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))

                if let llmConfigMessage {
                    Text(llmConfigMessage)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else if llmImportEnabled && !MenuImportService.hasConfiguredLLMAPIKey() {
                    Text("Hinweis: Kein API-Key hinterlegt. KI-Reflexion ist aktuell aus.")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            Section("Neuen Artikel anlegen") {
                TextField("Name", text: $itemName)
                TextField("Beschreibung", text: $itemDescription)
                TextField("Preis (z.B. 4,50)", text: $itemPrice)
                    .keyboardType(.decimalPad)

                Picker("Typ", selection: $selectedKind) {
                    ForEach(MenuItemKind.allCases, id: \.self) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                .onChange(of: selectedKind) {
                    syncSelectedSection()
                }

                Picker("Kategorie", selection: $selectedSectionID) {
                    ForEach(filteredSections) { section in
                        Text(section.title).tag(section.id)
                    }
                }

                Button("Artikel speichern") {
                    addMenuItem()
                }
                .buttonStyle(KitchenPrimaryButtonStyle())
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if let formErrorMessage {
                    Text(formErrorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Aktuelles Menü") {
                ForEach(store.menuSections) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline)
                        ForEach(section.items, id: \.id) { item in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.displayName)
                                        .font(.subheadline)
                                    Spacer()
                                    Text(PriceFormatter.string(cents: item.priceCents))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                MenuItemOptionsListView(options: item.variants)
                                allergenRow(for: item, in: section)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section {
                Button("Demo-Menü wiederherstellen", role: .destructive) {
                    store.resetMenuToDemo()
                    syncSelectedSection()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .sheet(isPresented: $showDocumentScanner) {
            MenuDocumentScannerView { images in
                handleImportedImages(images)
            } onCancel: {}
        }
        .sheet(isPresented: $showImportPreview) {
            MenuImportReviewView(
                sections: importedSectionsPreview,
                onReplace: {
                    store.replaceMenu(with: importedSectionsPreview)
                    importStatusMessage = "Menü wurde ersetzt."
                    showImportPreview = false
                    syncSelectedSection()
                },
                onAppend: {
                    store.appendMenu(with: importedSectionsPreview)
                    importStatusMessage = "Importierte Artikel wurden hinzugefügt."
                    showImportPreview = false
                    syncSelectedSection()
                }
            )
        }
        .onAppear {
            syncSelectedSection()
        }
        .onChange(of: store.menuSections.count) {
            syncSelectedSection()
        }
        .onChange(of: selectedPhotoItems) { _, newValue in
            guard !newValue.isEmpty else { return }
            Task {
                await handlePhotoPicker(items: newValue)
            }
        }
    }

    private func syncSelectedSection() {
        let ids = Set(filteredSections.map(\.id))
        if !ids.contains(selectedSectionID) {
            selectedSectionID = filteredSections.first?.id ?? ""
        }
    }

    private func addMenuItem() {
        let trimmedName = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDescription = itemDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            formErrorMessage = "Bitte einen Artikelnamen eingeben."
            return
        }

        guard !selectedSectionID.isEmpty else {
            formErrorMessage = "Bitte eine Kategorie auswählen."
            return
        }

        guard let priceCents = parsePriceCents(from: itemPrice), priceCents >= 0 else {
            formErrorMessage = "Preis ist ungültig."
            return
        }

        store.addMenuItem(
            sectionID: selectedSectionID,
            name: trimmedName,
            description: trimmedDescription.isEmpty ? "Ohne Beschreibung" : trimmedDescription,
            priceCents: priceCents,
            kind: selectedKind
        )

        formErrorMessage = nil
        itemName = ""
        itemDescription = ""
        itemPrice = "4,50"
    }

    private func parsePriceCents(from text: String) -> Int? {
        let normalized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard let price = Double(normalized), price >= 0 else {
            return nil
        }
        return Int((price * 100).rounded())
    }

    @ViewBuilder
    private func allergenRow(for item: MenuItemData, in section: MenuSectionData) -> some View {
        if let allergenCodes = item.resolvedAllergenCodes, !allergenCodes.isEmpty {
            AllergenBadgesRow(rawCodes: allergenCodes, legendByCode: section.allergenLegend)
        }
    }

    private func handleImportedImages(_ images: [UIImage]) {
        guard !images.isEmpty else {
            importStatusMessage = "Es wurden keine Bilder übergeben."
            return
        }

        importInProgress = true
        let semanticMode = MenuImportService.isLLMEnabled() && MenuImportService.hasConfiguredLLMAPIKey()
        importStatusMessage = semanticMode
            ? "OCR + KI-Reflexion startet (0/\(images.count))..."
            : "Texterkennung startet (0/\(images.count))..."

        Task {
            do {
                let sections = try await MenuImportService.importSections(from: images) { completed, total in
                    await MainActor.run {
                        if semanticMode, completed == total {
                            importStatusMessage = "OCR fertig. KI interpretiert die Speisekarte (mit Zeitlimit)..."
                        } else {
                            importStatusMessage = semanticMode
                                ? "OCR: Seite \(completed)/\(total) analysiert..."
                                : "Texterkennung: Seite \(completed)/\(total) analysiert..."
                        }
                    }
                }
                importedSectionsPreview = sections
                let diagnostics = MenuImportService.lastImportDiagnostics()
                importStatusMessage = semanticMode
                    ? "Import erkannt: \(sections.reduce(0) { $0 + $1.items.count }) Artikel.\n\(diagnostics)"
                    : "Import erkannt: \(sections.reduce(0) { $0 + $1.items.count }) Artikel.\n\(diagnostics)"
                showImportPreview = true
            } catch MenuImportService.ImportError.noMenuItemsDetected {
                importStatusMessage = "Keine Artikel erkannt. Bitte ein klareres Foto oder einen Scan versuchen.\n\(MenuImportService.lastImportDiagnostics())"
            } catch {
                importStatusMessage = "Import fehlgeschlagen: \(error.localizedDescription)"
            }
            importInProgress = false
        }
    }

    private func handlePhotoPicker(items: [PhotosPickerItem]) async {
        importInProgress = true
        importStatusMessage = "Bilder werden geladen..."

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

            guard !images.isEmpty else {
                importStatusMessage = "Keines der ausgewählten Bilder konnte geladen werden."
                importInProgress = false
                selectedPhotoItems = []
                return
            }

            selectedPhotoItems = []
            importStatusMessage = "\(images.count) Bild(er) geladen. Texterkennung startet..."
            handleImportedImages(images)
        } catch {
            importStatusMessage = "Bild-Upload fehlgeschlagen: \(error.localizedDescription)"
            importInProgress = false
            selectedPhotoItems = []
        }
    }
}

private struct MenuImportWhooshView: View {
    @State private var sweep = false
    @State private var pulse = false
    @State private var rotate = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(KitchenTheme.brand.opacity(0.15))
                    .frame(width: 38, height: 38)
                    .scaleEffect(pulse ? 1.08 : 0.88)
                    .opacity(pulse ? 0.75 : 0.35)

                Circle()
                    .stroke(KitchenTheme.brand.opacity(0.55), lineWidth: 1.4)
                    .frame(width: 38, height: 38)

                Image(systemName: "doc.text.viewfinder")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(KitchenTheme.brandDark)

                Image(systemName: "sparkles")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(KitchenTheme.accent)
                    .offset(x: 12, y: -12)
                    .rotationEffect(.degrees(rotate ? 24 : -24))
            }

            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule(style: .continuous)
                        .fill(KitchenTheme.surfaceRaised.opacity(0.75))
                        .frame(height: 12)

                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .clear,
                                    KitchenTheme.brand.opacity(0.18),
                                    KitchenTheme.accent.opacity(0.92),
                                    KitchenTheme.brand.opacity(0.18),
                                    .clear
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(72, width * 0.36), height: 12)
                        .offset(x: sweep ? width : -max(72, width * 0.36))
                        .blur(radius: 1.2)
                        .blendMode(.plusLighter)
                }
                .overlay(alignment: .leading) {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(KitchenTheme.brand.opacity(0.95))
                        Circle()
                            .fill(KitchenTheme.brand.opacity(0.8))
                        Circle()
                            .fill(KitchenTheme.accent.opacity(0.95))
                    }
                    .frame(height: 8)
                    .padding(.leading, 9)
                    .opacity(0.65)
                }
            }
            .frame(height: 16)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Import wird analysiert")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.72).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
            withAnimation(.linear(duration: 0.62).repeatForever(autoreverses: true)) {
                rotate.toggle()
            }
            withAnimation(.easeInOut(duration: 1.02).repeatForever(autoreverses: false)) {
                sweep.toggle()
            }
        }
    }
}

private struct MenuDocumentScannerView: UIViewControllerRepresentable {
    let onComplete: ([UIImage]) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onComplete: ([UIImage]) -> Void
        let onCancel: () -> Void

        init(onComplete: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onComplete = onComplete
            self.onCancel = onCancel
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
            onCancel()
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            images.reserveCapacity(scan.pageCount)
            for index in 0 ..< scan.pageCount {
                images.append(scan.imageOfPage(at: index))
            }
            controller.dismiss(animated: true)
            onComplete(images)
        }
    }
}

private struct MenuImportReviewView: View {
    let sections: [MenuSectionData]
    let onReplace: () -> Void
    let onAppend: () -> Void
    private let sectionConfidenceWarningThreshold = 0.72

    private var totalItemCount: Int {
        sections.reduce(0) { $0 + $1.items.count }
    }

    private var lowConfidenceSectionCount: Int {
        sections.filter { $0.importConfidence < sectionConfidenceWarningThreshold }.count
    }

    @ViewBuilder
    private func allergenRow(for item: MenuItemData, in section: MenuSectionData) -> some View {
        if let allergenCodes = item.resolvedAllergenCodes, !allergenCodes.isEmpty {
            AllergenBadgesRow(rawCodes: allergenCodes, legendByCode: section.allergenLegend)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Import-Zusammenfassung") {
                    HStack {
                        Label("\(sections.count) Kategorien", systemImage: "square.grid.2x2")
                        Spacer()
                        Label("\(totalItemCount) Artikel", systemImage: "list.bullet")
                    }
                    .font(.subheadline)

                    if lowConfidenceSectionCount > 0 {
                        Label("\(lowConfidenceSectionCount) Kategorie(n) bitte prüfen", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                ForEach(sections) { section in
                    Section {
                        ForEach(section.items, id: \.id) { item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top) {
                                    Text(item.displayName)
                                        .font(.headline)
                                    Spacer()
                                    Text(PriceFormatter.string(cents: item.priceCents))
                                        .font(.subheadline)
                                }

                                if !item.description.isEmpty, item.description != "Automatisch importiert" {
                                    Text(item.description)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                allergenRow(for: item, in: section)

                                MenuItemOptionsListView(options: item.variants)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        HStack {
                            Text(section.title)
                            if section.importConfidence < sectionConfidenceWarningThreshold {
                                Spacer()
                                Label("Bitte prüfen", systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Import-Prüfung")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 10) {
                    Button {
                        onReplace()
                    } label: {
                        Label("Bestehendes Menü ersetzen", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .buttonStyle(KitchenPrimaryButtonStyle())

                    Button {
                        onAppend()
                    } label: {
                        Label("Import als neue Kategorien hinzufügen", systemImage: "plus.circle")
                    }
                    .buttonStyle(KitchenSecondaryButtonStyle())
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .kitchenSurface()
    }
}

private enum MenuImportService {
    enum ImportError: LocalizedError {
        case imageConversionFailed
        case noMenuItemsDetected
        case invalidAPIKey
        case llmImportFailed(String)

        var errorDescription: String? {
            switch self {
            case .imageConversionFailed:
                return "Bild konnte nicht verarbeitet werden."
            case .noMenuItemsDetected:
                return "Keine Artikel erkannt."
            case .invalidAPIKey:
                return "OpenAI API-Key ungültig oder abgelaufen. Bitte neuen Key speichern."
            case let .llmImportFailed(reason):
                return "KI-Import fehlgeschlagen: \(reason)"
            }
        }
    }

    private struct OCRLineToken {
        let text: String
        let boundingBox: CGRect
        let pageIndex: Int
    }

    private struct PendingMenuItem {
        let title: String
        let kind: MenuItemKind
        var descriptions: [String]
        var allergenCodes: String?
    }

    private static let llmEnabledStorageKey = "kitchenlink.import.llm.enabled"
    private static let llmAPIKeyStorageKey = "kitchenlink.import.llm.openai.key"
    private static let llmModelDefault = "gpt-4.1"
    private static var lastImportDiagnosticsStorage = "Nur OCR-Regeln genutzt."
    private static let llmPrimaryTimeoutSeconds: Double = 36
    private static let llmRetryTimeoutSeconds: Double = 22
    private static let llmSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 35
        configuration.timeoutIntervalForResource = 50
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    static func isLLMEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: llmEnabledStorageKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: llmEnabledStorageKey)
    }

    static func setLLMEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: llmEnabledStorageKey)
    }

    static func storedLLMAPIKey() -> String {
        UserDefaults.standard.string(forKey: llmAPIKeyStorageKey) ?? ""
    }

    static func saveLLMAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            UserDefaults.standard.removeObject(forKey: llmAPIKeyStorageKey)
        } else {
            UserDefaults.standard.set(trimmed, forKey: llmAPIKeyStorageKey)
        }
    }

    static func hasConfiguredLLMAPIKey() -> Bool {
        resolvedLLMAPIKey != nil
    }

    static func lastImportDiagnostics() -> String {
        lastImportDiagnosticsStorage
    }

    private static var resolvedLLMAPIKey: String? {
        let stored = storedLLMAPIKey().trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty { return stored }

        if let bundled = Bundle.main.object(forInfoDictionaryKey: "KITCHENLINK_OPENAI_API_KEY") as? String {
            let trimmed = bundled.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }

        if let environment = ProcessInfo.processInfo.environment["KITCHENLINK_OPENAI_API_KEY"] {
            let trimmed = environment.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    static func importSections(
        from images: [UIImage],
        progress: (@Sendable (_ completed: Int, _ total: Int) async -> Void)? = nil
    ) async throws -> [MenuSectionData] {
        lastImportDiagnosticsStorage = "Nur OCR-Regeln genutzt."
        var allLines: [OCRLineToken] = []
        let totalPages = images.count

        for (pageIndex, image) in images.enumerated() {
            let lines = try await recognizeLines(in: image, pageIndex: pageIndex)
            allLines.append(contentsOf: lines)
            await progress?(pageIndex + 1, totalPages)
        }

        let detectedLegend = detectAllergenLegend(from: allLines)
        let sections: [MenuSectionData]

        if isLLMEnabled() {
            let llmOutcome = await parseSectionsWithLLM(
                from: allLines,
                sourceImages: images,
                allergenLegend: detectedLegend
            )
            if let semanticSections = llmOutcome.sections {
                sections = semanticSections
            } else {
                if llmOutcome.message.localizedCaseInsensitiveContains("api-key ungültig") ||
                    llmOutcome.message.localizedCaseInsensitiveContains("http 401") ||
                    llmOutcome.message.localizedCaseInsensitiveContains("incorrect api key") {
                    lastImportDiagnosticsStorage = llmOutcome.message
                    throw ImportError.invalidAPIKey
                }
                lastImportDiagnosticsStorage = llmOutcome.message
                throw ImportError.llmImportFailed(llmOutcome.message)
            }
            lastImportDiagnosticsStorage = llmOutcome.message
        } else {
            sections = parseLinesToSections(allLines, allergenLegend: detectedLegend)
            lastImportDiagnosticsStorage = "KI-Reflexion deaktiviert. Nur OCR-Regeln genutzt."
        }

        let itemCount = sections.reduce(0) { $0 + $1.items.count }
        guard itemCount > 0 else {
            throw ImportError.noMenuItemsDetected
        }
        return sections
    }

    private struct OpenAIChatRequest: Encodable {
        struct Message: Encodable {
            enum Content: Encodable {
                case text(String)
                case parts([Part])

                func encode(to encoder: Encoder) throws {
                    switch self {
                    case let .text(value):
                        var container = encoder.singleValueContainer()
                        try container.encode(value)
                    case let .parts(parts):
                        var container = encoder.unkeyedContainer()
                        for part in parts {
                            try container.encode(part)
                        }
                    }
                }
            }

            struct Part: Encodable {
                struct ImageURL: Encodable {
                    let url: String
                    let detail: String
                }

                let type: String
                let text: String?
                let imageURL: ImageURL?

                enum CodingKeys: String, CodingKey {
                    case type
                    case text
                    case imageURL = "image_url"
                }

                static func text(_ value: String) -> Part {
                    Part(type: "text", text: value, imageURL: nil)
                }

                static func image(url: String, detail: String = "high") -> Part {
                    Part(type: "image_url", text: nil, imageURL: ImageURL(url: url, detail: detail))
                }
            }

            let role: String
            let content: Content
        }

        struct ResponseFormat: Encodable {
            let type: String
        }

        let model: String
        let temperature: Double
        let responseFormat: ResponseFormat
        let messages: [Message]

        enum CodingKeys: String, CodingKey {
            case model
            case temperature
            case responseFormat = "response_format"
            case messages
        }
    }

    private struct OpenAIChatResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String
            }

            let message: Message
        }

        let choices: [Choice]
    }

    private struct LLMMenuRoot: Decodable {
        let sections: [LLMSectionPayload]

        enum CodingKeys: String, CodingKey {
            case sections
            case menu
        }

        init(from decoder: Decoder) throws {
            if let container = try? decoder.container(keyedBy: CodingKeys.self),
               let sections = try? container.decode([LLMSectionPayload].self, forKey: .sections) {
                self.sections = sections
                return
            }

            if let container = try? decoder.container(keyedBy: CodingKeys.self),
               let sections = try? container.decode([LLMSectionPayload].self, forKey: .menu) {
                self.sections = sections
                return
            }

            if let decoded = try? [LLMSectionPayload](from: decoder) {
                self.sections = decoded
                return
            }
            self.sections = []
        }
    }

    private struct LLMSectionPayload: Decodable {
        let title: String
        let subtitle: String?
        let kindRaw: String?
        let items: [LLMItemPayload]

        enum CodingKeys: String, CodingKey {
            case title
            case subtitle
            case kind
            case type
            case items
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            title = (try? container.decode(String.self, forKey: .title)) ?? ""
            subtitle = try? container.decodeIfPresent(String.self, forKey: .subtitle)
            kindRaw = (try? container.decodeIfPresent(String.self, forKey: .kind)) ?? (try? container.decodeIfPresent(String.self, forKey: .type))
            items = (try? container.decode([LLMItemPayload].self, forKey: .items)) ?? []
        }
    }

    private struct LLMItemPayload: Decodable {
        let name: String
        let description: String?
        let priceCents: Int
        let kindRaw: String?
        let allergenCodesRaw: [String]
        let options: [LLMOptionPayload]

        enum CodingKeys: String, CodingKey {
            case name
            case description
            case details
            case priceCents
            case price
            case kind
            case type
            case allergenCodes
            case allergens
            case options
            case variants
            case extras
            case portions
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? container.decode(String.self, forKey: .name)) ?? ""
            description = (try? container.decodeIfPresent(String.self, forKey: .description))
                ?? (try? container.decodeIfPresent(String.self, forKey: .details))
            kindRaw = (try? container.decodeIfPresent(String.self, forKey: .kind))
                ?? (try? container.decodeIfPresent(String.self, forKey: .type))

            priceCents = Self.decodePriceCents(
                from: container,
                centsKey: .priceCents,
                priceKey: .price
            ) ?? 0

            if let codes = try? container.decode([String].self, forKey: .allergenCodes) {
                allergenCodesRaw = codes
            } else if let codes = try? container.decode([String].self, forKey: .allergens) {
                allergenCodesRaw = codes
            } else if let single = try? container.decode(String.self, forKey: .allergenCodes) {
                allergenCodesRaw = [single]
            } else if let single = try? container.decode(String.self, forKey: .allergens) {
                allergenCodesRaw = [single]
            } else {
                allergenCodesRaw = []
            }

            var mergedOptions: [LLMOptionPayload] = []
            if let options = try? container.decode([LLMOptionPayload].self, forKey: .options) {
                mergedOptions.append(contentsOf: options)
            }
            if let variants = try? container.decode([LLMOptionPayload].self, forKey: .variants) {
                mergedOptions.append(contentsOf: variants.map { $0.with(kind: .variant) })
            }
            if let extras = try? container.decode([LLMOptionPayload].self, forKey: .extras) {
                mergedOptions.append(contentsOf: extras.map { $0.with(kind: .extra) })
            }
            if let portions = try? container.decode([LLMOptionPayload].self, forKey: .portions) {
                mergedOptions.append(contentsOf: portions.map { $0.with(kind: .portion) })
            }
            options = mergedOptions
        }

        private static func decodePriceCents(
            from container: KeyedDecodingContainer<CodingKeys>,
            centsKey: CodingKeys,
            priceKey: CodingKeys
        ) -> Int? {
            if let cents = try? container.decode(Int.self, forKey: centsKey), cents > 0 {
                return cents
            }
            if let text = try? container.decode(String.self, forKey: centsKey),
               let cents = MenuImportService.parseLoosePriceToCents(text) {
                return cents
            }
            if let value = try? container.decode(Double.self, forKey: centsKey), value > 0 {
                return Int(value.rounded())
            }

            if let text = try? container.decode(String.self, forKey: priceKey),
               let cents = MenuImportService.parseLoosePriceToCents(text) {
                return cents
            }
            if let value = try? container.decode(Double.self, forKey: priceKey), value > 0 {
                if value < 100 {
                    return Int((value * 100).rounded())
                }
                return Int(value.rounded())
            }
            if let cents = try? container.decode(Int.self, forKey: priceKey), cents > 0 {
                if cents < 100 {
                    return cents * 100
                }
                return cents
            }
            return nil
        }
    }

    private struct LLMOptionPayload: Decodable {
        let name: String
        let priceCents: Int
        let kind: MenuItemOptionKind?

        enum CodingKeys: String, CodingKey {
            case name
            case priceCents
            case price
            case kind
            case type
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            name = (try? container.decode(String.self, forKey: .name)) ?? ""

            if let cents = try? container.decode(Int.self, forKey: .priceCents), cents > 0 {
                priceCents = cents
            } else if let text = try? container.decode(String.self, forKey: .priceCents),
                      let cents = MenuImportService.parseLoosePriceToCents(text) {
                priceCents = cents
            } else if let text = try? container.decode(String.self, forKey: .price),
                      let cents = MenuImportService.parseLoosePriceToCents(text) {
                priceCents = cents
            } else if let value = try? container.decode(Double.self, forKey: .price), value > 0 {
                priceCents = value < 100 ? Int((value * 100).rounded()) : Int(value.rounded())
            } else {
                priceCents = 0
            }

            let kindText = (try? container.decodeIfPresent(String.self, forKey: .kind))
                ?? (try? container.decodeIfPresent(String.self, forKey: .type))
            kind = MenuImportService.mapOptionKind(from: kindText)
        }

        func with(kind forcedKind: MenuItemOptionKind) -> LLMOptionPayload {
            LLMOptionPayload(name: name, priceCents: priceCents, kind: forcedKind)
        }

        private init(name: String, priceCents: Int, kind: MenuItemOptionKind?) {
            self.name = name
            self.priceCents = priceCents
            self.kind = kind
        }
    }

    private struct LLMParseOutcome {
        let sections: [MenuSectionData]?
        let message: String
    }

    private static func parseSectionsWithLLM(
        from lines: [OCRLineToken],
        sourceImages: [UIImage],
        allergenLegend: [String: String]
    ) async -> LLMParseOutcome {
        guard let apiKey = resolvedLLMAPIKey else {
            return LLMParseOutcome(
                sections: nil,
                message: "KI-Reflexion übersprungen: kein OpenAI API-Key hinterlegt."
            )
        }

        if sourceImages.count > 1 {
            return await parseSectionsWithLLMPageByPage(
                apiKey: apiKey,
                lines: lines,
                sourceImages: sourceImages,
                allergenLegend: allergenLegend
            )
        }

        let ocrText = makeLLMLineDump(from: lines)
        let primaryImageParts = makeLLMImageParts(
            from: sourceImages,
            maxPages: 2,
            maxDimension: 1400,
            maxRawBytes: 3_000_000,
            perImageMaxBytes: 1_000_000,
            detail: "high"
        )
        guard !primaryImageParts.isEmpty else {
            return LLMParseOutcome(
                sections: nil,
                message: "KI-Reflexion übersprungen: keine nutzbaren Bilder für Vision-Modell."
            )
        }

        let legendSummary = makeLegendSummary(allergenLegend)

        let systemPrompt = """
        Du bist ein präziser Parser für deutsche Speisekarten.
        Primäre Quelle sind die Bilder. OCR kann fehlerhaft sein und dient nur als schwacher Zusatzkontext.
        Gib ausschließlich JSON zurück, ohne Markdown.
        Verwende dieses Schema:
        {
          "sections": [
            {
              "title": "string",
              "subtitle": "string",
              "kind": "food|drink",
              "items": [
                {
                  "name": "string",
                  "description": "string",
                  "price_cents": 1290,
                  "allergen_codes": ["a1","f","2"],
                  "options": [
                    { "name": "Klein", "price_cents": 690, "kind": "portion" },
                    { "name": "mit Käse", "price_cents": 120, "kind": "extra" },
                    { "name": "Pute", "price_cents": 540, "kind": "variant" }
                  ]
                }
              ]
            }
          ]
        }
        Regeln:
        - Nutze alle übergebenen Seitenbilder in ihrer Reihenfolge (Seite 1, Seite 2, ...).
        - 'portion': klein/groß/halbe Portion etc.
        - 'extra': optionale Zuschläge (extra, plus, Zusatz).
        - 'variant': alternative Ausprägungen desselben Gerichts.
        - Fasse keine reinen Allergenkürzel als Gericht auf.
        - Wenn klein/groß existiert, kein doppeltes Gericht erzeugen, sondern Portionen in options.
        - Preise immer als Cent-Integer.
        """

        let userPrompt = """
        OCR-Linien (zusätzlicher Kontext):
        \(ocrText)

        Erkannte Allergen-Legende:
        \(legendSummary)

        Es gibt keinen verlässlichen Vorparser. Nutze primär die Bildinhalte.
        """

        let primaryAttempt = await runLLMMenuCallWithTimeout(
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            imageParts: primaryImageParts,
            timeoutSeconds: llmPrimaryTimeoutSeconds
        )

        let root: LLMMenuRoot
        let usedImageCount: Int
        if let parsedRoot = primaryAttempt.root {
            root = parsedRoot
            usedImageCount = imagePartCount(in: primaryImageParts)
        } else {
            let primaryError = primaryAttempt.errorMessage ?? "Unbekannter Fehler"
            let shouldRetrySlim = primaryError.localizedCaseInsensitiveContains("timed out") ||
                primaryError.localizedCaseInsensitiveContains("network connection was lost") ||
                primaryError.localizedCaseInsensitiveContains("request timeout")

            guard shouldRetrySlim else {
                return LLMParseOutcome(
                    sections: nil,
                    message: "KI-Reflexion fehlgeschlagen: \(primaryError)"
                )
            }

            let slimImageParts = makeLLMImageParts(
                from: sourceImages,
                maxPages: 3,
                maxDimension: 1024,
                maxRawBytes: 1_400_000,
                perImageMaxBytes: 520_000,
                detail: "low"
            )

            guard !slimImageParts.isEmpty else {
                return LLMParseOutcome(
                    sections: nil,
                    message: "KI-Timeout. Kein reduzierter Vision-Retry möglich."
                )
            }

            let retryAttempt = await runLLMMenuCallWithTimeout(
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                imageParts: slimImageParts,
                timeoutSeconds: llmRetryTimeoutSeconds
            )

            if let parsedRoot = retryAttempt.root {
                root = parsedRoot
                usedImageCount = imagePartCount(in: slimImageParts)
            } else {
                let retryError = retryAttempt.errorMessage ?? "Unbekannter Fehler"
                return LLMParseOutcome(
                    sections: nil,
                    message: "KI-Reflexion Timeout/Fehler (\(retryError))."
                )
            }
        }

        let mappedSections = mapLLMSections(root.sections, allergenLegend: allergenLegend)
        guard !mappedSections.isEmpty else {
            return LLMParseOutcome(sections: nil, message: "KI-Reflexion lieferte keine nutzbaren Menüdaten.")
        }

        let mappedItems = mappedSections.reduce(0) { $0 + $1.items.count }
        if mappedItems > 420 {
            return LLMParseOutcome(sections: nil, message: "KI-Reflexion verworfen: unplausibel viele Artikel.")
        }

        return LLMParseOutcome(
            sections: mappedSections,
            message: "Vision-KI aktiv: \(mappedItems) Artikel aus \(usedImageCount) Bild(ern) strukturiert."
        )
    }

    private static func parseSectionsWithLLMPageByPage(
        apiKey: String,
        lines: [OCRLineToken],
        sourceImages: [UIImage],
        allergenLegend: [String: String]
    ) async -> LLMParseOutcome {
        let legendSummary = makeLegendSummary(allergenLegend)
        var collectedSections: [MenuSectionData] = []
        var pageErrors: [String] = []
        var successfulPages = 0

        for (pageIndex, image) in sourceImages.enumerated() {
            let pageNumber = pageIndex + 1
            let pageLines = lines.filter { $0.pageIndex == pageIndex }
            let ocrContext = String(makeLLMLineDump(from: pageLines).prefix(7_000))

            let imageParts = makeLLMImageParts(
                from: [image],
                maxPages: 1,
                maxDimension: 1400,
                maxRawBytes: 1_000_000,
                perImageMaxBytes: 1_000_000,
                detail: "high"
            )
            guard !imageParts.isEmpty else {
                pageErrors.append("Seite \(pageNumber): kein nutzbares Bild")
                continue
            }

            let systemPrompt = """
            Du bist ein präziser Parser für deutsche Speisekarten.
            Du erhältst genau eine Seite der Karte.
            Gib ausschließlich JSON zurück, ohne Markdown.
            Verwende dieses Schema:
            {
              "sections": [
                {
                  "title": "string",
                  "subtitle": "string",
                  "kind": "food|drink",
                  "items": [
                    {
                      "name": "string",
                      "description": "string",
                      "price_cents": 1290,
                      "allergen_codes": ["a","f","2"],
                      "options": [
                        { "name": "Klein", "price_cents": 690, "kind": "portion" },
                        { "name": "mit Käse", "price_cents": 120, "kind": "extra" },
                        { "name": "Pute", "price_cents": 540, "kind": "variant" }
                      ]
                    }
                  ]
                }
              ]
            }
            Regeln:
            - Erfasse alle erkennbaren Artikel dieser Seite.
            - 'portion': klein/groß/0,2L/0,4L etc.
            - 'extra': optionale Zuschläge.
            - 'variant': alternative Ausprägungen.
            - Fasse keine reinen Allergenkürzel als Gericht auf.
            - Preise immer als Cent-Integer.
            """

            let userPrompt = """
            Aktuelle Seite: \(pageNumber) von \(sourceImages.count)

            OCR-Linien dieser Seite (nur Zusatzkontext):
            \(ocrContext)

            Erkannte Allergen-Legende:
            \(legendSummary)
            """

            let primaryAttempt = await runLLMMenuCallWithTimeout(
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                userPrompt: userPrompt,
                imageParts: imageParts,
                timeoutSeconds: 45
            )

            var parsedRoot = primaryAttempt.root
            var lastError = primaryAttempt.errorMessage ?? "Unbekannter Fehler"

            if parsedRoot == nil {
                if lastError.localizedCaseInsensitiveContains("http 401") ||
                    lastError.localizedCaseInsensitiveContains("incorrect api key") ||
                    lastError.localizedCaseInsensitiveContains("api-key ungültig") {
                    return LLMParseOutcome(
                        sections: nil,
                        message: "KI-Reflexion fehlgeschlagen: API-Key ungültig (HTTP 401)"
                    )
                }

                let shouldRetry = lastError.localizedCaseInsensitiveContains("timed out") ||
                    lastError.localizedCaseInsensitiveContains("timeout") ||
                    lastError.localizedCaseInsensitiveContains("network connection was lost")
                if shouldRetry {
                    let slimParts = makeLLMImageParts(
                        from: [image],
                        maxPages: 1,
                        maxDimension: 1024,
                        maxRawBytes: 480_000,
                        perImageMaxBytes: 480_000,
                        detail: "low"
                    )
                    if !slimParts.isEmpty {
                        let retryAttempt = await runLLMMenuCallWithTimeout(
                            apiKey: apiKey,
                            systemPrompt: systemPrompt,
                            userPrompt: userPrompt,
                            imageParts: slimParts,
                            timeoutSeconds: 26
                        )
                        parsedRoot = retryAttempt.root
                        lastError = retryAttempt.errorMessage ?? lastError
                    }
                }
            }

            guard let root = parsedRoot else {
                pageErrors.append("Seite \(pageNumber): \(lastError)")
                continue
            }

            let mappedSections = mapLLMSections(root.sections, allergenLegend: allergenLegend)
            guard !mappedSections.isEmpty else {
                pageErrors.append("Seite \(pageNumber): keine nutzbaren Menüdaten")
                continue
            }

            collectedSections = mergeImportedSections(collectedSections, with: mappedSections)
            successfulPages += 1
        }

        guard !collectedSections.isEmpty else {
            let reason = pageErrors.isEmpty ? "Unbekannter Fehler" : pageErrors.joined(separator: " | ")
            return LLMParseOutcome(
                sections: nil,
                message: "KI-Reflexion seitenweise fehlgeschlagen: \(reason)"
            )
        }

        guard successfulPages == sourceImages.count else {
            let reason = pageErrors.isEmpty ? "Nicht alle Seiten wurden erkannt." : pageErrors.joined(separator: " | ")
            return LLMParseOutcome(
                sections: nil,
                message: "KI-Reflexion unvollständig: \(successfulPages)/\(sourceImages.count) Seiten erkannt. \(reason)"
            )
        }

        let itemCount = collectedSections.reduce(0) { $0 + $1.items.count }
        let errorSuffix: String = {
            guard !pageErrors.isEmpty else { return "" }
            return " | Teilfehler: \(pageErrors.prefix(2).joined(separator: " | "))"
        }()
        return LLMParseOutcome(
            sections: collectedSections,
            message: "Vision-KI seitenweise: \(itemCount) Artikel aus \(successfulPages)/\(sourceImages.count) Seiten." + errorSuffix
        )
    }

    private struct LLMCallOutcome {
        let root: LLMMenuRoot?
        let errorMessage: String?
    }

    private static func runLLMMenuCallWithTimeout(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        imageParts: [OpenAIChatRequest.Message.Part],
        timeoutSeconds: Double
    ) async -> LLMCallOutcome {
        await withTaskGroup(of: LLMCallOutcome.self) { group in
            group.addTask {
                await runLLMMenuCall(
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    imageParts: imageParts
                )
            }

            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                return LLMCallOutcome(root: nil, errorMessage: "timeout nach \(Int(timeoutSeconds))s")
            }

            let first = await group.next() ?? LLMCallOutcome(root: nil, errorMessage: "Unbekannter KI-Fehler")
            group.cancelAll()
            return first
        }
    }

    private static func runLLMMenuCall(
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        imageParts: [OpenAIChatRequest.Message.Part]
    ) async -> LLMCallOutcome {
        do {
            let requestBody = OpenAIChatRequest(
                model: llmModelDefault,
                temperature: 0.1,
                responseFormat: .init(type: "json_object"),
                messages: [
                    .init(role: "system", content: .text(systemPrompt)),
                    .init(
                        role: "user",
                        content: .parts([.text(userPrompt)] + imageParts)
                    )
                ]
            )

            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try JSONEncoder().encode(requestBody)

            let (data, response) = try await llmSession.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return LLMCallOutcome(root: nil, errorMessage: "ungültige HTTP-Antwort")
            }
            guard (200 ... 299).contains(http.statusCode) else {
                if http.statusCode == 401 {
                    return LLMCallOutcome(root: nil, errorMessage: "API-Key ungültig (HTTP 401)")
                }
                let body = String(data: data, encoding: .utf8) ?? ""
                let shortBody = body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(180)
                return LLMCallOutcome(root: nil, errorMessage: "HTTP \(http.statusCode): \(shortBody)")
            }

            let chat = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
            guard let content = chat.choices.first?.message.content,
                  let jsonText = extractJSONObject(from: content),
                  let jsonData = jsonText.data(using: .utf8) else {
                return LLMCallOutcome(root: nil, errorMessage: "Antwort ohne parsebares JSON")
            }

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard let root = try? decoder.decode(LLMMenuRoot.self, from: jsonData) else {
                return LLMCallOutcome(root: nil, errorMessage: "JSON konnte nicht ins Menümodell übertragen werden")
            }
            return LLMCallOutcome(root: root, errorMessage: nil)
        } catch {
            return LLMCallOutcome(root: nil, errorMessage: error.localizedDescription)
        }
    }

    private static func makeLLMImageParts(
        from images: [UIImage],
        maxPages: Int,
        maxDimension: CGFloat,
        maxRawBytes: Int,
        perImageMaxBytes: Int,
        detail: String
    ) -> [OpenAIChatRequest.Message.Part] {
        let cappedPageCount = min(images.count, maxPages)
        var parts: [OpenAIChatRequest.Message.Part] = []
        var rawByteBudget = 0

        for (pageOffset, image) in images.prefix(cappedPageCount).enumerated() {
            let remainingSlots = max(1, cappedPageCount - pageOffset)
            let remainingBudget = maxRawBytes - rawByteBudget
            if remainingBudget < 120_000 { break }
            let dynamicPerImageBudget = min(perImageMaxBytes, max(120_000, remainingBudget / remainingSlots))

            let normalized = image.kitchenNormalized()
            var dynamicMaxDimension = maxDimension
            var prepared = resizedForLLM(normalized, maxDimension: dynamicMaxDimension)

            var bestData: Data?
            for _ in 0..<6 {
                var quality: CGFloat = 0.72
                var data = prepared.jpegData(compressionQuality: quality)
                while let current = data, current.count > dynamicPerImageBudget, quality > 0.2 {
                    quality -= 0.07
                    data = prepared.jpegData(compressionQuality: quality)
                }

                if let current = data, current.count <= dynamicPerImageBudget {
                    bestData = current
                    break
                }

                dynamicMaxDimension *= 0.84
                if dynamicMaxDimension < 700 { break }
                prepared = resizedForLLM(normalized, maxDimension: dynamicMaxDimension)
            }

            if bestData == nil {
                bestData = prepared.jpegData(compressionQuality: 0.2)
            }

            guard let jpeg = bestData else { continue }
            if jpeg.count > remainingBudget { continue }
            rawByteBudget += jpeg.count

            let dataURL = "data:image/jpeg;base64,\(jpeg.base64EncodedString())"
            parts.append(.text("Seite \(pageOffset + 1)"))
            parts.append(.image(url: dataURL, detail: detail))
        }

        return parts
    }

    private static func imagePartCount(in parts: [OpenAIChatRequest.Message.Part]) -> Int {
        parts.reduce(0) { partial, part in
            partial + (part.imageURL == nil ? 0 : 1)
        }
    }

    private static func resizedForLLM(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    private static func makeLLMLineDump(from lines: [OCRLineToken]) -> String {
        let sorted = lines
            .map { OCRLineToken(text: normalizeLine($0.text), boundingBox: $0.boundingBox, pageIndex: $0.pageIndex) }
            .filter { !$0.text.isEmpty }
            .sorted {
                if $0.pageIndex != $1.pageIndex {
                    return $0.pageIndex < $1.pageIndex
                }
                let yDiff = abs($0.boundingBox.midY - $1.boundingBox.midY)
                if yDiff > 0.012 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }

        let formatted = sorted.enumerated().map { index, token in
            let page = token.pageIndex + 1
            let x = String(format: "%.3f", token.boundingBox.minX)
            let y = String(format: "%.3f", token.boundingBox.midY)
            return "p\(page) #\(index + 1) [x=\(x) y=\(y)] \(token.text)"
        }.joined(separator: "\n")

        return String(formatted.prefix(42_000))
    }

    private static func makeLegendSummary(_ legend: [String: String]) -> String {
        guard !legend.isEmpty else { return "keine" }
        let pairs = legend
            .sorted { lhs, rhs in lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending }
            .map { "\($0.key)=\($0.value)" }
        return pairs.joined(separator: ", ")
    }

    private static func makeFallbackSummary(from sections: [MenuSectionData]) -> String {
        guard !sections.isEmpty else { return "leer" }
        let compact = sections.prefix(40).map { section in
            let itemPreview = section.items.prefix(8).map { item in
                let optionsPreview = item.variants.prefix(4).map {
                    "\($0.kind.rawValue):\($0.name)=\($0.priceCents)"
                }.joined(separator: "|")
                return "[\(item.name) \(item.priceCents) opt{\(optionsPreview)}]"
            }.joined(separator: " ")
            return "Section(\(section.title), kind=\(section.kind.rawValue)): \(itemPreview)"
        }.joined(separator: "\n")
        return String(compact.prefix(20_000))
    }

    private static func mapLLMSections(_ payloadSections: [LLMSectionPayload], allergenLegend: [String: String]) -> [MenuSectionData] {
        var sections: [MenuSectionData] = []

        for payload in payloadSections {
            let title = sanitizeImportedTitle(payload.title)
            guard !title.isEmpty else { continue }

            let sectionKind = mapMenuKind(from: payload.kindRaw) ?? inferKind(from: title)
            let subtitle = sanitizeImportedTitle(payload.subtitle ?? "")

            var items: [MenuItemData] = []
            for itemPayload in payload.items {
                let rawName = sanitizeImportedTitle(itemPayload.name)
                let splitName = AllergenCodeParser.splitNameAndAllergenCodes(from: rawName)
                let name = splitName.name
                guard !name.isEmpty, !isLikelyAllergenOnlyName(name), name.count >= 2 else { continue }
                guard itemPayload.priceCents > 0 else { continue }

                let itemKind = mapMenuKind(from: itemPayload.kindRaw) ?? sectionKind
                let description = sanitizeImportedTitle(itemPayload.description ?? "")
                let mergedCodeInput = itemPayload.allergenCodesRaw + [splitName.allergenCodes].compactMap { $0 }
                let codes = mergeAllergenCodes(mergedCodeInput)

                let options = deduplicateOptions(itemPayload.options.compactMap { option in
                    let optionName = sanitizeImportedTitle(option.name)
                    guard !optionName.isEmpty, option.priceCents > 0 else { return nil }
                    return MenuItemVariant(
                        id: "import-option-\(UUID().uuidString)",
                        name: optionName,
                        priceCents: option.priceCents,
                        kind: option.kind ?? inferOptionKind(from: optionName)
                    )
                })

                items.append(
                    MenuItemData(
                        id: "import-item-\(UUID().uuidString)",
                        name: name,
                        description: description.isEmpty ? "Automatisch importiert" : description,
                        priceCents: itemPayload.priceCents,
                        kind: itemKind,
                        variants: options,
                        allergenCodes: codes
                    )
                )
            }

            guard !items.isEmpty else { continue }

            sections.append(
                MenuSectionData(
                    id: "import-section-\(UUID().uuidString)",
                    title: title,
                    subtitle: subtitle.isEmpty ? "Importiert" : subtitle,
                    kind: sectionKind,
                    items: items,
                    importConfidence: 0.9,
                    allergenLegend: allergenLegend.isEmpty ? nil : allergenLegend
                )
            )
        }

        return sections
    }

    private static func mergeImportedSections(_ base: [MenuSectionData], with incoming: [MenuSectionData]) -> [MenuSectionData] {
        var result = base

        func sectionKey(_ section: MenuSectionData) -> String {
            "\(section.kind.rawValue)|\(normalizedForMatching(section.title).replacingOccurrences(of: " ", with: ""))"
        }

        func itemKey(_ item: MenuItemData) -> String {
            "\(item.kind.rawValue)|\(normalizedForMatching(item.name))|\(item.priceCents)"
        }

        for section in incoming {
            if let sectionIndex = result.firstIndex(where: { sectionKey($0) == sectionKey(section) }) {
                var existingSection = result[sectionIndex]

                if (existingSection.subtitle == "Importiert" || existingSection.subtitle == "Automatisch erkannt" || existingSection.subtitle.isEmpty),
                   !section.subtitle.isEmpty {
                    existingSection.subtitle = section.subtitle
                }

                for item in section.items {
                    if let itemIndex = existingSection.items.firstIndex(where: { itemKey($0) == itemKey(item) }) {
                        var existingItem = existingSection.items[itemIndex]
                        existingItem.variants = deduplicateOptions(existingItem.variants + item.variants)
                        existingItem.allergenCodes = mergeAllergenCodes([existingItem.allergenCodes, item.allergenCodes].compactMap { $0 })
                        if (existingItem.description == "Automatisch importiert" || existingItem.description.isEmpty),
                           !item.description.isEmpty {
                            existingItem.description = item.description
                        }
                        existingSection.items[itemIndex] = existingItem
                    } else {
                        existingSection.items.append(item)
                    }
                }

                existingSection.importConfidence = max(existingSection.importConfidence, section.importConfidence)
                if existingSection.allergenLegend == nil || existingSection.allergenLegend?.isEmpty == true {
                    existingSection.allergenLegend = section.allergenLegend
                }
                result[sectionIndex] = existingSection
            } else {
                result.append(section)
            }
        }

        return result
    }

    private static func deduplicateOptions(_ options: [MenuItemVariant]) -> [MenuItemVariant] {
        var seen: Set<String> = []
        var result: [MenuItemVariant] = []
        for option in options {
            let key = "\(option.kind.rawValue)|\(normalizedForMatching(option.name))|\(option.priceCents)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(option)
        }
        return result
    }

    private static func mergeAllergenCodes(_ rawCodes: [String]) -> String? {
        let tokens = rawCodes.flatMap { AllergenCodeParser.tokens(from: $0) }
        guard !tokens.isEmpty else { return nil }

        var seen: Set<String> = []
        let unique = tokens.filter { code in
            guard !seen.contains(code) else { return false }
            seen.insert(code)
            return true
        }
        return unique.joined(separator: ",")
    }

    private static func sanitizeImportedTitle(_ text: String) -> String {
        normalizeLine(text)
            .replacingOccurrences(of: #"[|]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mapMenuKind(from raw: String?) -> MenuItemKind? {
        guard let raw else { return nil }
        let normalized = normalizedForMatching(raw)
        if normalized.contains("drink") || normalized.contains("getrank") || normalized.contains("getraenk") || normalized.contains("getraenk") || normalized.contains("cocktail") || normalized.contains("bier") || normalized.contains("wein") {
            return .drink
        }
        if normalized.contains("food") || normalized.contains("speise") || normalized.contains("essen") {
            return .food
        }
        return nil
    }

    private static func inferOptionKind(from text: String) -> MenuItemOptionKind {
        let normalized = normalizedForMatching(text)
        if normalized.contains("klein") || normalized.contains("gross") || normalized.contains("gro") || normalized.contains("mittel") || normalized.contains("portion") || normalized.contains("halbe") {
            return .portion
        }
        if normalized.contains("extra") || normalized.contains("zusatz") || normalized.hasPrefix("+") {
            return .extra
        }
        return .variant
    }

    private static func mapOptionKind(from raw: String?) -> MenuItemOptionKind? {
        guard let raw else { return nil }
        let normalized = normalizedForMatching(raw)
        if normalized.contains("portion") || normalized.contains("size") || normalized.contains("groesse") || normalized.contains("grosse") {
            return .portion
        }
        if normalized.contains("extra") || normalized.contains("addon") || normalized.contains("zusatz") {
            return .extra
        }
        if normalized.contains("variant") || normalized.contains("option") || normalized.contains("wahl") {
            return .variant
        }
        return nil
    }

    private static func parseLoosePriceToCents(_ text: String) -> Int? {
        let cleaned = text
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: #"[^\d,\.]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        if let cents = Int(cleaned), cleaned.count <= 3 {
            return cents * 100
        }

        let normalized = cleaned.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value > 0 else {
            return nil
        }
        if value < 100 {
            return Int((value * 100).rounded())
        }
        return Int(value.rounded())
    }

    private static func extractJSONObject(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return trimmed
        }

        if let startObject = trimmed.firstIndex(of: "{"),
           let endObject = trimmed.lastIndex(of: "}") {
            return String(trimmed[startObject ... endObject])
        }

        if let startArray = trimmed.firstIndex(of: "["),
           let endArray = trimmed.lastIndex(of: "]") {
            return "{ \"sections\": \(trimmed[startArray ... endArray]) }"
        }
        return nil
    }

    private static func recognizeLines(in image: UIImage, pageIndex: Int) async throws -> [OCRLineToken] {
        let normalized = image.kitchenNormalized()
        let enhanced = normalized.kitchenEnhancedForOCR()

        guard normalized.cgImage != nil else {
            throw ImportError.imageConversionFailed
        }

        let primary = try await runOCR(on: enhanced, pageIndex: pageIndex)
        let secondary = try await runOCR(on: normalized, pageIndex: pageIndex)
        return mergeOCRLines(primary: primary, secondary: secondary)
    }

    private static func runOCR(on image: UIImage, pageIndex: Int) async throws -> [OCRLineToken] {
        guard let cgImage = image.cgImage else {
            throw ImportError.imageConversionFailed
        }

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[OCRLineToken], Error>) in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines: [OCRLineToken] = observations.compactMap { observation in
                    guard let candidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    let cleaned = normalizeLine(candidate.string)
                    guard !cleaned.isEmpty else { return nil }
                    return OCRLineToken(text: cleaned, boundingBox: observation.boundingBox, pageIndex: pageIndex)
                }
                continuation.resume(returning: lines)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["de-DE", "it-IT", "en-US"]
            request.customWords = [
                "wahlweise", "hähnchen", "haehnchen", "ziegenfrischkäse", "roquefort",
                "pappardelle", "rigatoni", "spaghetti", "burrata", "parmesan",
                "formaggio", "capra", "mac", "meatballs", "ofenkartoffel",
                "brötchen", "broetchen", "matjes", "scampi", "lachsfilet"
            ]
            request.minimumTextHeight = 0.008

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func mergeOCRLines(primary: [OCRLineToken], secondary: [OCRLineToken]) -> [OCRLineToken] {
        var result = primary
        for line in secondary {
            let exists = result.contains {
                $0.pageIndex == line.pageIndex &&
                abs($0.boundingBox.midY - line.boundingBox.midY) < 0.012 &&
                    $0.text.compare(line.text, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
            if !exists {
                result.append(line)
            }
        }
        return result
    }

    private static func detectAllergenLegend(from lines: [OCRLineToken]) -> [String: String] {
        let normalizedLines = lines
            .map { OCRLineToken(text: normalizeLine($0.text), boundingBox: $0.boundingBox, pageIndex: $0.pageIndex) }
            .filter { $0.text.count >= 3 }

        let pagesWithAllergenHeading = Set(
            normalizedLines.compactMap { token -> Int? in
                let normalized = normalizedForMatching(token.text)
                return normalized.contains("allergene") ? token.pageIndex : nil
            }
        )
        let pagesWithAdditivesHeading = Set(
            normalizedLines.compactMap { token -> Int? in
                let normalized = normalizedForMatching(token.text)
                return normalized.contains("zusatzstoff") ? token.pageIndex : nil
            }
        )

        var mapping: [String: String] = [:]
        for token in normalizedLines {
            guard parsePriceOnly(from: token.text) == nil else { continue }
            let entries = parseLegendEntries(from: token.text)
            guard !entries.isEmpty else { continue }

            for entry in entries {
                let code = entry.code.lowercased()
                guard mapping[code] == nil else { continue }
                let isNumericCode = Int(code) != nil

                if isNumericCode {
                    if !pagesWithAdditivesHeading.isEmpty && !pagesWithAdditivesHeading.contains(token.pageIndex) {
                        continue
                    }
                } else if !pagesWithAllergenHeading.isEmpty && !pagesWithAllergenHeading.contains(token.pageIndex) {
                    continue
                }

                let titleNormalized = normalizedForMatching(entry.title)
                let wordCount = titleNormalized.split(separator: " ").count
                if wordCount < 1 { continue }
                if !isNumericCode {
                    let looksLikeAllergenDescription =
                        titleNormalized.contains("erzeug") ||
                        titleNormalized.contains("halt") ||
                        titleNormalized.contains("gluten") ||
                        titleNormalized.contains("fisch") ||
                        titleNormalized.contains("senf") ||
                        titleNormalized.contains("sellerie") ||
                        titleNormalized.contains("krebstier") ||
                        titleNormalized.contains("sesam") ||
                        titleNormalized.contains("milch") ||
                        titleNormalized.contains("weizen") ||
                        titleNormalized.contains("dinkel") ||
                        titleNormalized.contains("zwiebel") ||
                        titleNormalized.contains("knoblauch")
                    if !looksLikeAllergenDescription && wordCount < 2 {
                        continue
                    }
                }

                mapping[code] = entry.title
            }
        }

        return mapping
    }

    private static func parseLegendEntries(from line: String) -> [(code: String, title: String)] {
        let normalizedLine = AllergenCodeParser
            .normalizeSuperscriptCharacters(in: line)
            .replacingOccurrences(of: "•", with: "*")
            .replacingOccurrences(of: "·", with: "*")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLine.isEmpty else { return [] }

        let candidates = normalizedLine
            .split(whereSeparator: { $0 == "*" || $0 == ";" })
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let segments = candidates.isEmpty ? [normalizedLine] : candidates

        var entries: [(code: String, title: String)] = []
        var seenCodes: Set<String> = []

        func appendEntry(code rawCode: String, title rawTitle: String) {
            guard let code = AllergenCodeParser.tokens(from: rawCode).first else { return }
            guard !seenCodes.contains(code) else { return }

            var title = rawTitle
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"[.;:,]+$"#, with: "", options: .regularExpression)

            title = title.replacingOccurrences(
                of: #"^(allergene|zusatzstoffe?)\s*[:\-]?\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            guard !title.isEmpty else { return }

            seenCodes.insert(code)
            entries.append((code, title))
        }

        let titleEqualsCodePattern = #"(?i)([^,;:=]{2,}?)\s*=\s*([a-z]{1,2}[0-9]{0,2}|[0-9]{1,2})"#
        let leadingCodePatterns = [
            #"(?i)^\s*([a-n](?:[0-9])?|[0-9]{1,2})\s*[-:.)]?\s+(.+?)\s*$"#,
            #"(?i)^\s*([a-n](?:[0-9])?|[0-9]{1,2})\s*[-:.)]?\s*([A-Za-zÄÖÜäöüß].+?)\s*$"#,
            #"(?i)^\s*([a-n](?:[0-9])?|[0-9]{1,2})([A-Za-zÄÖÜäöüß].+?)\s*$"#
        ]

        for segment in segments {
            if let regex = try? NSRegularExpression(pattern: titleEqualsCodePattern) {
                let matches = regex.matches(in: segment, range: NSRange(segment.startIndex..., in: segment))
                for match in matches {
                    guard let titleRange = Range(match.range(at: 1), in: segment),
                          let codeRange = Range(match.range(at: 2), in: segment) else {
                        continue
                    }
                    appendEntry(code: String(segment[codeRange]), title: String(segment[titleRange]))
                }
            }

            for pattern in leadingCodePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern),
                      let match = regex.firstMatch(in: segment, range: NSRange(segment.startIndex..., in: segment)),
                      let codeRange = Range(match.range(at: 1), in: segment),
                      let titleRange = Range(match.range(at: 2), in: segment) else {
                    continue
                }

                appendEntry(code: String(segment[codeRange]), title: String(segment[titleRange]))
                break
            }
        }

        return entries
    }

    private static func parseLinesToSections(_ lines: [OCRLineToken], allergenLegend: [String: String]) -> [MenuSectionData] {
        var sections: [MenuSectionData] = []
        var currentSectionIndex: Int?
        var pendingItem: PendingMenuItem?
        var lastInsertedIndexPath: (section: Int, item: Int)?
        var pendingVariantName: String?
        var pendingVariantKind: MenuItemOptionKind?
        var pendingVariantTarget: (section: Int, item: Int)?
        var pendingVariantRowMidY: CGFloat?
        var sizeHeadersByContext: [ColumnKey: [String]] = [:]
        struct ColumnKey: Hashable {
            let pageIndex: Int
            let column: Int
        }

        let normalizedLines = lines
            .map { OCRLineToken(text: normalizeLine($0.text), boundingBox: $0.boundingBox, pageIndex: $0.pageIndex) }
            .filter { $0.text.count >= 2 }

        func sortForReading(_ lines: [OCRLineToken]) -> [OCRLineToken] {
            lines.sorted {
                if $0.pageIndex != $1.pageIndex {
                    return $0.pageIndex < $1.pageIndex
                }
                let yDiff = abs($0.boundingBox.midY - $1.boundingBox.midY)
                if yDiff > 0.012 {
                    return $0.boundingBox.midY > $1.boundingBox.midY
                }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
        }

        func percentile(_ sortedValues: [CGFloat], _ percentile: Double) -> CGFloat? {
            guard !sortedValues.isEmpty else { return nil }
            let clamped = min(max(percentile, 0.0), 1.0)
            let index = Int((Double(sortedValues.count - 1) * clamped).rounded())
            return sortedValues[max(0, min(sortedValues.count - 1, index))]
        }

        func detectColumnSplit(for pageLines: [OCRLineToken]) -> CGFloat? {
            let contentLines = pageLines.filter { parsePriceOnly(from: $0.text) == nil }
            let left = contentLines.filter { $0.boundingBox.midX < 0.48 }
            let right = contentLines.filter { $0.boundingBox.midX > 0.56 }
            guard left.count >= 6, right.count >= 6 else { return nil }

            let leftMaxXs = left.map(\.boundingBox.maxX).sorted()
            let rightMinXs = right.map(\.boundingBox.minX).sorted()
            guard let leftEdge = percentile(leftMaxXs, 0.82),
                  let rightEdge = percentile(rightMinXs, 0.18),
                  leftEdge < rightEdge else {
                return nil
            }

            let split = (leftEdge + rightEdge) / 2.0
            guard split > 0.38, split < 0.68 else { return nil }
            return split
        }

        let groupedByPage = Dictionary(grouping: normalizedLines, by: \.pageIndex)
        let orderedPages = groupedByPage.keys.sorted()

        var readingOrderContexts: [(token: OCRLineToken, key: ColumnKey)] = []
        for page in orderedPages {
            let pageLines = groupedByPage[page] ?? []
            if let split = detectColumnSplit(for: pageLines) {
                let leftColumn = sortForReading(pageLines.filter { $0.boundingBox.midX < split })
                let rightColumn = sortForReading(pageLines.filter { $0.boundingBox.midX >= split })
                readingOrderContexts.append(contentsOf: leftColumn.map { ($0, ColumnKey(pageIndex: page, column: 0)) })
                readingOrderContexts.append(contentsOf: rightColumn.map { ($0, ColumnKey(pageIndex: page, column: 1)) })
            } else {
                let singleColumn = sortForReading(pageLines)
                readingOrderContexts.append(contentsOf: singleColumn.map { ($0, ColumnKey(pageIndex: page, column: 0)) })
            }
        }

        let rightPriceColumnMinXByContext: [ColumnKey: CGFloat] = Dictionary(
            uniqueKeysWithValues: Set(readingOrderContexts.map(\.key)).map { key in
                let contextLines = readingOrderContexts
                    .filter { $0.key == key }
                    .map(\.token)
                let priceXs = contextLines.compactMap { token -> CGFloat? in
                    parsePriceOnly(from: token.text) != nil ? token.boundingBox.minX : nil
                }
                guard !priceXs.isEmpty else { return (key, key.column == 0 ? 0.56 : 0.78) }
                let sortedXs = priceXs.sorted()
                let percentileIndex = Int(Double(sortedXs.count - 1) * 0.35)
                let anchorX = sortedXs[max(0, percentileIndex)]
                return (key, max(0.22, anchorX - 0.03))
            }
        )

        let medianLineHeightByPage: [Int: CGFloat] = Dictionary(
            uniqueKeysWithValues: Set(normalizedLines.map(\.pageIndex)).map { pageIndex in
                let heights = normalizedLines
                    .filter { $0.pageIndex == pageIndex }
                    .map(\.boundingBox.height)
                    .sorted()
                guard !heights.isEmpty else { return (pageIndex, 0.0) }
                let middle = heights.count / 2
                let median = heights.count.isMultiple(of: 2)
                    ? (heights[middle - 1] + heights[middle]) / 2.0
                    : heights[middle]
                return (pageIndex, median)
            }
        )

        func ensureSection(for kind: MenuItemKind) -> Int {
            if let currentSectionIndex {
                return currentSectionIndex
            }

            let fallback = MenuSectionData(
                id: "import-section-\(UUID().uuidString)",
                title: kind == .drink ? "Getränke (Import)" : "Speisen (Import)",
                subtitle: "Automatisch erkannt",
                kind: kind,
                items: [],
                importConfidence: 0.58,
                allergenLegend: allergenLegend.isEmpty ? nil : allergenLegend
            )
            sections.append(fallback)
            let idx = sections.indices.last!
            currentSectionIndex = idx
            return idx
        }

        func appendItem(name: String, description: String, priceCents: Int, kind: MenuItemKind, allergenCodes: String? = nil) {
            let cleaned = splitNameAndAllergenCodes(from: name)
            let targetIndex = ensureSection(for: kind)
            let item = MenuItemData(
                id: "import-item-\(UUID().uuidString)",
                name: cleaned.name,
                description: description.isEmpty ? "Automatisch importiert" : description,
                priceCents: priceCents,
                kind: kind,
                allergenCodes: allergenCodes ?? cleaned.allergenCodes
            )
            sections[targetIndex].items.append(item)
            if let itemIndex = sections[targetIndex].items.indices.last {
                lastInsertedIndexPath = (targetIndex, itemIndex)
            }
        }

        func appendVariant(name: String, priceCents: Int, kind: MenuItemOptionKind, to target: (section: Int, item: Int)) {
            guard sections.indices.contains(target.section),
                  sections[target.section].items.indices.contains(target.item) else {
                return
            }

            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedName.isEmpty else { return }

            let exists = sections[target.section].items[target.item].variants.contains {
                $0.name.compare(normalizedName, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame &&
                    $0.kind == kind &&
                    $0.priceCents == priceCents
            }
            if exists { return }

            sections[target.section].items[target.item].variants.append(
                MenuItemVariant(
                    id: "import-variant-\(UUID().uuidString)",
                    name: normalizedName,
                    priceCents: priceCents,
                    kind: kind
                )
            )
        }

        func sectionLookupKey(_ title: String) -> String {
            normalizedForMatching(title)
                .replacingOccurrences(of: " ", with: "")
        }

        func clearPendingVariant() {
            pendingVariantName = nil
            pendingVariantKind = nil
            pendingVariantTarget = nil
            pendingVariantRowMidY = nil
        }

        func mergeCodeStrings(_ first: String?, _ second: String?) -> String? {
            let combined = [first, second]
                .compactMap { $0 }
                .flatMap { AllergenCodeParser.tokens(from: $0) }
            guard !combined.isEmpty else { return nil }

            var seen: Set<String> = []
            let unique = combined.filter { token in
                guard !seen.contains(token) else { return false }
                seen.insert(token)
                return true
            }
            return unique.joined(separator: ",")
        }

        func detectSizeHeaders(in text: String) -> [String] {
            let pattern = #"(?i)\b([0-9](?:[.,][0-9])?)\s*l\b"#
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
            let nsRange = NSRange(text.startIndex..., in: text)
            let matches = regex.matches(in: text, range: nsRange)
            guard !matches.isEmpty else { return [] }

            var result: [String] = []
            for match in matches {
                guard let valueRange = Range(match.range(at: 1), in: text) else { continue }
                let value = String(text[valueRange]).replacingOccurrences(of: ".", with: ",")
                result.append("\(value) L")
            }
            return result
        }

        func parseInlineItemWithMultiplePrices(from line: String) -> (name: String, prices: [Int], allergenCodes: String?)? {
            guard line.rangeOfCharacter(from: .letters) != nil else { return nil }
            guard let regex = try? NSRegularExpression(pattern: #"[0-9]{1,3}[.,][0-9]{2}"#) else { return nil }

            let nsRange = NSRange(line.startIndex..., in: line)
            let matches = regex.matches(in: line, range: nsRange)
            guard matches.count >= 2 else { return nil }

            var prices: [Int] = []
            for match in matches {
                guard let valueRange = Range(match.range, in: line) else { continue }
                let value = String(line[valueRange])
                if let cents = parsePriceCents(value), cents > 0 {
                    prices.append(cents)
                }
            }
            guard prices.count >= 2 else { return nil }

            var nameCandidate = line
            let replacements = matches.compactMap { Range($0.range, in: line) }.reversed()
            for range in replacements {
                nameCandidate.removeSubrange(range)
            }
            nameCandidate = nameCandidate
                .replacingOccurrences(of: "€", with: " ")
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nameCandidate.isEmpty else { return nil }

            let split = splitNameAndAllergenCodes(from: nameCandidate)
            guard !split.name.isEmpty, !isLikelyAllergenOnlyName(split.name) else { return nil }
            return (split.name, prices, split.allergenCodes)
        }

        func isLikelySizeHeaderLine(_ line: String, sizeHeaders: [String]) -> Bool {
            guard sizeHeaders.count >= 2 else { return false }
            guard parseInlineItem(from: line) == nil else { return false }
            guard parseInlineItemWithMultiplePrices(from: line) == nil else { return false }

            let normalized = normalizedForMatching(line)
            if normalized.contains("softdrink") ||
                normalized.contains("getraenk") ||
                normalized.contains("bier") ||
                normalized.contains("saft") ||
                normalized.contains("wasser") ||
                normalized.contains("schorle") ||
                normalized.contains("cocktail") {
                return true
            }

            let compact = normalized.replacingOccurrences(of: " ", with: "")
            return compact.range(of: #"^[0-9,\.l]+$"#, options: .regularExpression) != nil
        }

        func sectionDetectionConfidence(_ context: (token: OCRLineToken, key: ColumnKey), at index: Int) -> Double? {
            let token = context.token
            let line = token.text
            let isRightColumn = context.key.column > 0
            let maxExpectedSectionX: CGFloat = isRightColumn ? 0.88 : 0.44
            guard isLikelySectionLine(line) else { return nil }
            guard !isLikelySectionCommentLine(line) else { return nil }
            guard parseInlineItem(from: line) == nil else { return nil }
            guard parsePriceOnly(from: line) == nil else { return nil }
            guard parseVariantTitle(from: line) == nil else { return nil }
            guard token.boundingBox.minX <= maxExpectedSectionX else { return nil }

            let rightPriceColumnMinX = rightPriceColumnMinXByContext[context.key] ?? 0.56
            let hasPriceOnSameRow = readingOrderContexts.contains { candidateContext in
                let candidate = candidateContext.token
                return candidateContext.key == context.key &&
                    candidate.boundingBox.minX >= rightPriceColumnMinX &&
                    abs(candidate.boundingBox.midY - token.boundingBox.midY) <= 0.012 &&
                    parsePriceOnly(from: candidate.text) != nil
            }
            if hasPriceOnSameRow { return nil }

            let lastIndex = readingOrderContexts.count - 1
            guard index < lastIndex else { return nil }
            let lookaheadEnd = min(lastIndex, index + 10)
            let hasMenuEntriesSoon = readingOrderContexts[(index + 1)...lookaheadEnd].contains { candidateContext in
                guard candidateContext.key == context.key else { return false }
                let candidate = candidateContext.token
                if parseInlineItem(from: candidate.text) != nil { return true }
                if parseSizeVariantInline(from: candidate.text) != nil { return true }
                return candidate.boundingBox.minX >= rightPriceColumnMinX && parsePriceOnly(from: candidate.text) != nil
            }
            guard hasMenuEntriesSoon else { return nil }

            let isKnownHeading = isKnownSectionHeading(line)
            let medianHeight = medianLineHeightByPage[token.pageIndex] ?? 0.0
            let isVisuallyProminent = medianHeight > 0 && token.boundingBox.height >= medianHeight * 1.10
            let isLeftStrong = isRightColumn ? token.boundingBox.minX <= 0.62 : token.boundingBox.minX <= 0.28
            let isLeftAcceptable = isRightColumn ? token.boundingBox.minX <= 0.78 : token.boundingBox.minX <= 0.44
            let normalized = normalizedForMatching(line)
            let wordCount = normalized.split(separator: " ").count
            let isTitleLength = wordCount >= 1 && wordCount <= 4 && line.count <= 36

            var score = 0.28
            if isKnownHeading { score += 0.42 }
            if isVisuallyProminent { score += 0.18 }
            if isLeftStrong { score += 0.08 }
            else if isLeftAcceptable { score += 0.04 }
            if isTitleLength { score += 0.08 }
            if hasMenuEntriesSoon { score += 0.12 }
            if line.contains(",") || line.contains(".") || line.contains(";") { score -= 0.10 }
            if isLikelySectionCommentLine(line) { score -= 0.25 }

            score = min(max(score, 0.0), 0.99)
            let threshold = isKnownHeading ? 0.58 : 0.70
            guard score >= threshold else { return nil }
            return score
        }

        var previousContextKey: ColumnKey?

        for (tokenIndex, context) in readingOrderContexts.enumerated() {
            let token = context.token
            let line = token.text
            let rightPriceColumnMinX = rightPriceColumnMinXByContext[context.key] ?? 0.56

            if previousContextKey != context.key {
                clearPendingVariant()
                previousContextKey = context.key
            }

            if parsePriceOnly(from: line) == nil {
                let sizeHeaders = detectSizeHeaders(in: line)
                if isLikelySizeHeaderLine(line, sizeHeaders: sizeHeaders) {
                    sizeHeadersByContext[context.key] = sizeHeaders
                    continue
                }
            }

            if let sectionConfidence = sectionDetectionConfidence(context, at: tokenIndex) {
                clearPendingVariant()
                let title = sanitizedSectionTitle(from: line)
                let kind = inferKind(from: title)
                let titleKey = sectionLookupKey(title)

                if let existingSectionIndex = sections.firstIndex(where: { sectionLookupKey($0.title) == titleKey }) {
                    sections[existingSectionIndex].importConfidence = max(sections[existingSectionIndex].importConfidence, sectionConfidence)
                    currentSectionIndex = existingSectionIndex
                } else {
                    let section = MenuSectionData(
                        id: "import-section-\(UUID().uuidString)",
                        title: title,
                        subtitle: "Importiert",
                        kind: kind,
                        items: [],
                        importConfidence: sectionConfidence,
                        allergenLegend: allergenLegend.isEmpty ? nil : allergenLegend
                    )
                    sections.append(section)
                    currentSectionIndex = sections.indices.last
                }
                pendingItem = nil
                continue
            }

            if let (variantName, variantPriceCents, variantKind) = parseVariantInline(from: line),
               let target = lastInsertedIndexPath {
                appendVariant(name: variantName, priceCents: variantPriceCents, kind: variantKind, to: target)
                clearPendingVariant()
                continue
            }

            if let (variantName, variantPriceCents, variantKind) = parseSizeVariantInline(from: line) {
                clearPendingVariant()

                if let pending = pendingItem {
                    appendItem(
                        name: pending.title,
                        description: pending.descriptions.joined(separator: " "),
                        priceCents: variantPriceCents,
                        kind: pending.kind,
                        allergenCodes: pending.allergenCodes
                    )
                    if let target = lastInsertedIndexPath {
                        appendVariant(name: variantName, priceCents: variantPriceCents, kind: variantKind, to: target)
                    }
                    pendingItem = nil
                } else if let target = lastInsertedIndexPath {
                    appendVariant(name: variantName, priceCents: variantPriceCents, kind: variantKind, to: target)
                }
                continue
            }

            if let (variantName, variantKind) = parseVariantTitle(from: line),
               let target = lastInsertedIndexPath {
                pendingVariantName = variantName
                pendingVariantKind = variantKind
                pendingVariantTarget = target
                pendingVariantRowMidY = token.boundingBox.midY
                continue
            }

            if let (name, prices, allergenCodes) = parseInlineItemWithMultiplePrices(from: line) {
                clearPendingVariant()
                appendItem(
                    name: name,
                    description: "Automatisch importiert",
                    priceCents: prices[0],
                    kind: inferKind(from: name),
                    allergenCodes: allergenCodes
                )

                if let target = lastInsertedIndexPath {
                    let sizeHeaders = sizeHeadersByContext[context.key] ?? []
                    for index in 0..<prices.count {
                        let optionName: String
                        if index < sizeHeaders.count {
                            optionName = sizeHeaders[index]
                        } else {
                            optionName = "Variante \(index + 1)"
                        }
                        appendVariant(name: optionName, priceCents: prices[index], kind: .portion, to: target)
                    }
                }
                pendingItem = nil
                continue
            }

            if let (name, priceCents, allergenCodes) = parseInlineItem(from: line) {
                clearPendingVariant()

                if let pending = pendingItem, shouldAttachInlineNameToPendingItem(name) {
                    var descriptionParts = pending.descriptions
                    if !isLikelyAllergenOnlyName(name) {
                        descriptionParts.append(name)
                    }
                    appendItem(
                        name: pending.title,
                        description: descriptionParts.joined(separator: " "),
                        priceCents: priceCents,
                        kind: pending.kind,
                        allergenCodes: mergeCodeStrings(pending.allergenCodes, allergenCodes)
                    )
                    pendingItem = nil
                    continue
                }

                if isLikelyAllergenOnlyName(name) {
                    if var pending = pendingItem {
                        pending.allergenCodes = mergeCodeStrings(pending.allergenCodes, allergenCodes ?? name)
                        pendingItem = pending
                    }
                    continue
                }

                if let normalizedVariant = normalizedSizeLabel(from: name), let target = lastInsertedIndexPath {
                    appendVariant(name: normalizedVariant, priceCents: priceCents, kind: .portion, to: target)
                    pendingItem = nil
                    continue
                }

                appendItem(
                    name: name,
                    description: "Automatisch importiert",
                    priceCents: priceCents,
                    kind: inferKind(from: name),
                    allergenCodes: allergenCodes
                )
                pendingItem = nil
                continue
            }

            if let priceCents = parsePriceOnly(from: line) {
                let isRightAlignedPrice = token.boundingBox.minX >= rightPriceColumnMinX
                let matchesPendingVariantRow: Bool = {
                    guard let pendingVariantRowMidY else { return false }
                    return abs(token.boundingBox.midY - pendingVariantRowMidY) <= 0.03
                }()

                if isRightAlignedPrice,
                   let variantName = pendingVariantName,
                   let variantKind = pendingVariantKind,
                   let variantTarget = pendingVariantTarget,
                   matchesPendingVariantRow {
                    appendVariant(name: variantName, priceCents: priceCents, kind: variantKind, to: variantTarget)
                    clearPendingVariant()
                    continue
                }

                if isRightAlignedPrice, let pending = pendingItem {
                    clearPendingVariant()
                    appendItem(
                        name: pending.title,
                        description: pending.descriptions.joined(separator: " "),
                        priceCents: priceCents,
                        kind: pending.kind,
                        allergenCodes: pending.allergenCodes
                    )
                    pendingItem = nil
                } else if let lastInsertedIndexPath, isRightAlignedPrice {
                    var item = sections[lastInsertedIndexPath.section].items[lastInsertedIndexPath.item]
                    if item.priceCents == 0 {
                        item.priceCents = priceCents
                        sections[lastInsertedIndexPath.section].items[lastInsertedIndexPath.item] = item
                    }
                }
                continue
            }

            let hasPriceOnSameRow = readingOrderContexts.contains { candidateContext in
                let candidate = candidateContext.token
                return candidateContext.key == context.key &&
                    candidate.boundingBox.minX >= rightPriceColumnMinX &&
                    abs(candidate.boundingBox.midY - token.boundingBox.midY) <= 0.012 &&
                    parsePriceOnly(from: candidate.text) != nil
            }

            if isLikelyItemTitleLine(line, hasAlignedPrice: hasPriceOnSameRow) {
                clearPendingVariant()
                pendingItem = PendingMenuItem(
                    title: line,
                    kind: inferKind(from: line),
                    descriptions: [],
                    allergenCodes: nil
                )
                continue
            }

            if var pending = pendingItem {
                if let standaloneCodes = parseStandaloneAllergenCodes(from: line) {
                    pending.allergenCodes = mergeCodeStrings(pending.allergenCodes, standaloneCodes)
                    pendingItem = pending
                    continue
                }

                if isLikelySectionCommentLine(line), let currentSectionIndex {
                    let existing = sections[currentSectionIndex].subtitle
                    let defaultSubtitles = ["Importiert", "Automatisch erkannt"]

                    if existing.isEmpty || defaultSubtitles.contains(existing) {
                        sections[currentSectionIndex].subtitle = line
                    } else if !existing.localizedCaseInsensitiveContains(line) {
                        sections[currentSectionIndex].subtitle += " " + line
                    }
                    pendingItem = nil
                } else {
                    pending.descriptions.append(line)
                    pendingItem = pending
                }
            } else if let currentSectionIndex, isLikelySectionCommentLine(line) {
                let existing = sections[currentSectionIndex].subtitle
                let defaultSubtitles = ["Importiert", "Automatisch erkannt"]

                if existing.isEmpty || defaultSubtitles.contains(existing) {
                    sections[currentSectionIndex].subtitle = line
                } else if !existing.localizedCaseInsensitiveContains(line) {
                    sections[currentSectionIndex].subtitle += " " + line
                }
            } else if let lastInsertedIndexPath {
                var existing = sections[lastInsertedIndexPath.section].items[lastInsertedIndexPath.item]
                if let standaloneCodes = parseStandaloneAllergenCodes(from: line) {
                    existing.allergenCodes = mergeCodeStrings(existing.allergenCodes, standaloneCodes)
                } else {
                    let merged = existing.description == "Automatisch importiert" ? line : existing.description + " " + line
                    existing.description = merged
                }
                sections[lastInsertedIndexPath.section].items[lastInsertedIndexPath.item] = existing
            }
        }

        clearPendingVariant()
        var filtered = sections.filter { !$0.items.isEmpty }
        if !allergenLegend.isEmpty {
            for index in filtered.indices where filtered[index].allergenLegend == nil {
                filtered[index].allergenLegend = allergenLegend
            }
        }
        return filtered
    }

    private static func parseVariantInline(from line: String) -> (String, Int, MenuItemOptionKind)? {
        guard let (candidateName, priceCents, _) = parseInlineItem(from: line),
              let (variantName, variantKind) = parseVariantTitle(from: candidateName) else {
            return nil
        }
        return (variantName, priceCents, variantKind)
    }

    private static func parseVariantTitle(from line: String) -> (String, MenuItemOptionKind)? {
        let cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return nil }

        let normalized = normalizedForMatching(cleaned)
        let startsWithWahlweiseFamily = normalized.hasPrefix("wahlweise") || (normalized.hasPrefix("wah") && normalized.contains("weise"))
        let startsAsVariant =
            startsWithWahlweiseFamily ||
            normalized.hasPrefix("mit extra") ||
            normalized.hasPrefix("extra ") ||
            normalized.hasPrefix("optional ") ||
            normalized.hasPrefix("add on ") ||
            normalized.hasPrefix("addon ") ||
            normalized.hasPrefix("zusatz ")

        guard startsAsVariant else { return nil }
        let optionKind: MenuItemOptionKind = startsWithWahlweiseFamily ? .variant : .extra

        var variantText = cleaned
            .replacingOccurrences(of: #"^[+\-•]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(
                of: #"(?i)^\s*(?:wah[l1i!|]\w*(?:\s+mit)?|extra(?:\s+mit)?|optional(?:\s+mit)?|add(?:\s+on)?|zusatz)\s+"#,
                with: "",
                options: .regularExpression
            )
            .replacingOccurrences(of: #"(?i)^mit\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        variantText = variantText.replacingOccurrences(of: #"[.\-·]{2,}"#, with: " ", options: .regularExpression)
        guard variantText.count >= 2 else { return nil }
        return (variantText, optionKind)
    }

    private static func parseSizeVariantInline(from line: String) -> (String, Int, MenuItemOptionKind)? {
        guard let (name, priceCents, _) = parseInlineItem(from: line),
              let normalized = normalizedSizeLabel(from: name) else {
            return nil
        }
        return (normalized, priceCents, .portion)
    }

    private static func normalizedSizeLabel(from text: String) -> String? {
        let normalized = normalizedForMatching(text)
        if normalized == "klein" || normalized == "small" {
            return "Klein"
        }
        if normalized == "gross" || normalized == "gro" || normalized == "large" {
            return "Groß"
        }
        if normalized == "mittel" || normalized == "medium" {
            return "Mittel"
        }
        return nil
    }

    private static func shouldAttachInlineNameToPendingItem(_ name: String) -> Bool {
        if isLikelyAllergenOnlyName(name) {
            return true
        }

        let normalized = normalizedForMatching(name)
        if normalizedSizeLabel(from: name) != nil {
            return true
        }

        let continuationPrefixes = [
            "und ", "mit ", "dazu ", "oder ", "in ", "an ", "auf ", "vom ", "von "
        ]
        if continuationPrefixes.contains(where: { normalized.hasPrefix($0) }) {
            return true
        }
        return false
    }

    private static func isLikelyAllergenOnlyName(_ name: String) -> Bool {
        let normalized = normalizeLine(name)
            .replacingOccurrences(of: #"[()\[\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return true }

        let tokens = AllergenCodeParser.tokens(from: normalized)
        guard !tokens.isEmpty else { return false }

        let compact = normalized
            .lowercased()
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"[.;:/|]"#, with: ",", options: .regularExpression)
            .replacingOccurrences(of: #"[^a-z0-9,]"#, with: "", options: .regularExpression)
        guard !compact.isEmpty else { return true }

        let estimatedCodeChars = tokens.reduce(0) { $0 + $1.count }
        return compact.count <= estimatedCodeChars + 2
    }

    private static func parseStandaloneAllergenCodes(from line: String) -> String? {
        let normalized = normalizeLine(line)
            .replacingOccurrences(of: #"[()\[\]]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }
        guard isLikelyAllergenOnlyName(normalized) else { return nil }
        let tokens = AllergenCodeParser.tokens(from: normalized)
        guard !tokens.isEmpty else { return nil }
        return tokens.joined(separator: ",")
    }

    private static func parseInlineItem(from line: String) -> (String, Int, String?)? {
        let pattern = #"^(.*?)[\s\.\-·_]*([0-9]{1,3}(?:[.,][0-9]{1,2}))\s*(?:€|EUR|eur)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let nameRange = Range(match.range(at: 1), in: line),
              let trailingPriceRange = Range(match.range(at: 2), in: line) else {
            return nil
        }

        let nameText = String(line[nameRange])
        let priceText = String(line[trailingPriceRange])
        guard let priceCents = parsePriceCents(priceText), priceCents > 0 else {
            return nil
        }

        let cleanedName = nameText
            .replacingOccurrences(of: #"[.\-·]{2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedName.count >= 2 else {
            return nil
        }

        let split = splitNameAndAllergenCodes(from: cleanedName)
        return (split.name, priceCents, split.allergenCodes)
    }

    private static func parsePriceOnly(from line: String) -> Int? {
        let cleaned = line
            .replacingOccurrences(of: "€", with: "")
            .replacingOccurrences(of: "EUR", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: #"^[^\p{L}0-9]*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let pattern = #"^[0-9]{1,3}(?:[.,][0-9]{1,2})$"#
        guard cleaned.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }
        return parsePriceCents(cleaned)
    }

    private static func parsePriceCents(_ text: String) -> Int? {
        let normalized = text.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(normalized), value >= 0 else {
            return nil
        }
        return Int((value * 100).rounded())
    }

    private static func splitNameAndAllergenCodes(from text: String) -> (name: String, allergenCodes: String?) {
        AllergenCodeParser.splitNameAndAllergenCodes(from: text)
    }

    private static func inferKind(from text: String) -> MenuItemKind {
        let lowered = text.lowercased()
        let drinkKeywords = [
            "getraenke", "getränke", "drink", "cocktail", "bier", "wein",
            "spritz", "espresso", "kaffee", "tee", "saft", "cola", "wasser",
            "limo", "limonade"
        ]

        if drinkKeywords.contains(where: lowered.contains) {
            return .drink
        }
        return .food
    }

    private static func isLikelyItemTitleLine(_ text: String, hasAlignedPrice: Bool) -> Bool {
        if parseVariantTitle(from: text) != nil {
            return false
        }
        if isLikelyAllergenOnlyName(text) {
            return false
        }
        if normalizedSizeLabel(from: text) != nil {
            return false
        }

        let normalized = normalizedForMatching(text)
        if normalized.hasPrefix("wah") && normalized.contains("weise") {
            return false
        }
        if normalized.hasPrefix("mit extra") || normalized.hasPrefix("extra ") || normalized.hasPrefix("optional ") {
            return false
        }

        if normalized.hasPrefix("mit ") || normalized.hasPrefix("ohne ") {
            return false
        }

        if let firstLetter = text.first(where: { $0.isLetter }), firstLetter.isLowercase, !hasAlignedPrice {
            return false
        }

        if hasAlignedPrice {
            return true
        }

        if text.contains(",") || text.contains(";") {
            return false
        }

        let words = text.split(separator: " ")
        guard words.count >= 1, words.count <= 8 else { return false }
        if text.count > 42 { return false }
        if text.contains(where: \.isNumber) { return false }

        return true
    }

    private static func isKnownSectionHeading(_ text: String) -> Bool {
        let normalized = normalizedForMatching(text)
        let compact = normalized.replacingOccurrences(of: " ", with: "")

        let knownCompactHeaders: Set<String> = [
            "vorspeisen", "hauptgerichte", "dessert", "desserts", "speisen", "snacks",
            "salate", "salat", "pizza", "pasta", "burger", "getraenke", "drinks",
            "cocktails", "kaffee", "tee", "bier", "wein", "beilagen",
            "ofenkartoffel", "ofenkartoffeln"
        ]
        if knownCompactHeaders.contains(compact) {
            return true
        }

        let knownPhrases: Set<String> = [
            "ofenkartoffel in folie",
            "ofenkartoffeln in folie",
            "pasta und fleisch",
            "pasta neutral"
        ]
        return knownPhrases.contains(normalized)
    }

    private static func isLikelySectionCommentLine(_ text: String) -> Bool {
        let normalized = normalizedForMatching(text)
        let words = normalized.split(separator: " ")
        guard words.count >= 4 else { return false }

        let startsLikeComment =
            normalized.hasPrefix("zu allen ") ||
            normalized.hasPrefix("zu jedem ") ||
            normalized.hasPrefix("wir reichen ") ||
            normalized.hasPrefix("wir servieren ") ||
            normalized.hasPrefix("dazu reichen ") ||
            normalized.hasPrefix("alle ")

        let verbMarkers: Set<String> = ["reichen", "servieren", "enthalten", "werden", "inklusive", "beilage"]
        let hasVerbMarker = words.contains { verbMarkers.contains(String($0)) }

        return startsLikeComment || (hasVerbMarker && text.hasSuffix("."))
    }

    private static func isLikelySectionLine(_ text: String) -> Bool {
        guard !text.contains(where: \.isNumber) else { return false }
        guard parseInlineItem(from: text) == nil else { return false }
        guard !isLikelySectionCommentLine(text) else { return false }

        if isKnownSectionHeading(text) {
            return true
        }

        let normalized = normalizedForMatching(text)
        let words = normalized.split(separator: " ")
        guard !words.isEmpty, words.count <= 4 else { return false }
        if text.contains(",") || text.contains(".") || text.contains(";") {
            return false
        }

        let isAllCapsHeader = text == text.uppercased() && text.count <= 30
        let rawWords = text.split(separator: " ")
        let startsUppercaseWords = rawWords.filter { $0.first?.isUppercase == true }.count
        let isTitleLikeHeader = text.count <= 36 && startsUppercaseWords >= max(1, rawWords.count - 2)
        return isAllCapsHeader || isTitleLikeHeader
    }

    private static func sanitizedSectionTitle(from text: String) -> String {
        text
            .replacingOccurrences(of: ":", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizedForMatching(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "de_DE"))
            .lowercased()
            .replacingOccurrences(of: "1", with: "l")
            .replacingOccurrences(of: "|", with: "l")
            .replacingOccurrences(of: "!", with: "l")
            .replacingOccurrences(of: "0", with: "o")
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func normalizeLine(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension UIImage {
    func kitchenNormalized() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func kitchenEnhancedForOCR() -> UIImage {
        guard let ciImage = CIImage(image: self) else {
            return self
        }

        let monochrome = ciImage.applyingFilter("CIPhotoEffectMono")
        let contrasted = monochrome.applyingFilter(
            "CIColorControls",
            parameters: [
                kCIInputContrastKey: 1.35,
                kCIInputBrightnessKey: 0.06,
                kCIInputSaturationKey: 0.0
            ]
        )
        let sharpened = contrasted.applyingFilter(
            "CISharpenLuminance",
            parameters: [kCIInputSharpnessKey: 0.7]
        )

        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(sharpened, from: sharpened.extent) else {
            return self
        }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }
}

@MainActor
final class KitchenLinkStore: ObservableObject {
    @Published var menuSections: [MenuSectionData]
    @Published var isOperatorLoggedIn = false

    private let ownerEmail = "owner@kitchenlink.test"
    private let ownerPassword = "123456"
    private let menuStorageKey = "kitchenlink.menu.v1"

    init() {
        if let loaded = Self.loadMenuFromDefaults(storageKey: menuStorageKey) {
            menuSections = loaded
        } else {
            menuSections = DemoMenuFactory.buildDefaultSections()
        }
    }

    func loginOperator(email: String, password: String) -> Bool {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let success = normalizedEmail == ownerEmail && normalizedPassword == ownerPassword
        isOperatorLoggedIn = success
        return success
    }

    func logoutOperator() {
        isOperatorLoggedIn = false
    }

    func addMenuItem(sectionID: String, name: String, description: String, priceCents: Int, kind: MenuItemKind) {
        guard let index = menuSections.firstIndex(where: { $0.id == sectionID }) else {
            return
        }

        let item = MenuItemData(
            id: "custom-\(UUID().uuidString)",
            name: name,
            description: description,
            priceCents: priceCents,
            kind: kind
        )
        menuSections[index].items.append(item)
        saveMenuToDefaults()
    }

    func replaceMenu(with sections: [MenuSectionData]) {
        guard !sections.isEmpty else { return }
        menuSections = sections
        saveMenuToDefaults()
    }

    func appendMenu(with sections: [MenuSectionData]) {
        guard !sections.isEmpty else { return }
        menuSections.append(contentsOf: sections)
        saveMenuToDefaults()
    }

    func resetMenuToDemo() {
        menuSections = DemoMenuFactory.buildDefaultSections()
        saveMenuToDefaults()
    }

    private func saveMenuToDefaults() {
        do {
            let data = try JSONEncoder().encode(menuSections)
            UserDefaults.standard.set(data, forKey: menuStorageKey)
        } catch {
            print("Menu save failed: \(error.localizedDescription)")
        }
    }

    private static func loadMenuFromDefaults(storageKey: String) -> [MenuSectionData]? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode([MenuSectionData].self, from: data)
        } catch {
            return nil
        }
    }
}

struct LiveOrderLine: Identifiable, Codable {
    let id: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kind: MenuItemKind

    var lineTotalCents: Int {
        quantity * unitPriceCents
    }
}

struct LiveOrderMessage: Identifiable, Codable {
    let id: String
    let createdAt: Date
    let sourceDevice: String
    let items: [LiveOrderLine]
    let totalCents: Int
}

@MainActor
final class OrderRelayService: ObservableObject {
    enum Mode {
        case idle
        case owner
        case customer
    }

    @Published private(set) var mode: Mode = .idle
    @Published private(set) var connectionText = "Nicht verbunden"
    @Published private(set) var isConnected = false
    @Published var receivedOrders: [LiveOrderMessage] = []

    private let supabaseBaseURL = URL(string: "https://kiqboyshhsogvdvnleup.supabase.co/rest/v1")!
    private let supabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtpcWJveXNoaHNvZ3Zkdm5sZXVwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE2MjM1MDcsImV4cCI6MjA4NzE5OTUwN30.50-vumCzVs3BNhLrwgqZY6v0ZvAcqBU4P8Crrg0gBdc"
    private var pollingTask: Task<Void, Never>?
    private let session = URLSession.shared

    func startHostingAsOwner() {
        guard mode != .owner else {
            return
        }
        mode = .owner
        isConnected = true
        connectionText = "Supabase aktiv - empfange Bestellungen"
        startPollingOrders()
    }

    func startBrowsingAsCustomer() {
        guard mode != .customer else {
            return
        }
        mode = .customer
        isConnected = true
        connectionText = "Mit Supabase verbunden"
    }

    func send(order: LiveOrderMessage) async -> Bool {
        do {
            let createdOrder = try await createRemoteOrder(order)
            try await createRemoteOrderItems(orderID: createdOrder.id, lines: order.items)
            if mode == .owner {
                try await loadOrdersFromBackend()
            }
            connectionText = "Mit Supabase verbunden"
            isConnected = true
            return true
        } catch {
            connectionText = "Supabase Fehler: \(error.localizedDescription)"
            isConnected = false
            return false
        }
    }

    func clearReceivedOrders() {
        receivedOrders.removeAll()
    }

    func stopNetworking(keepMode: Bool = false) {
        pollingTask?.cancel()
        pollingTask = nil

        if !keepMode {
            mode = .idle
            isConnected = false
            connectionText = "Nicht verbunden"
        }
    }

    private func startPollingOrders() {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled && self.mode == .owner {
                do {
                    try await self.loadOrdersFromBackend()
                    self.connectionText = "Supabase aktiv - empfange Bestellungen"
                    self.isConnected = true
                } catch {
                    self.connectionText = "Supabase Fehler: \(error.localizedDescription)"
                    self.isConnected = false
                }
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    private func loadOrdersFromBackend() async throws {
        var components = URLComponents(url: supabaseBaseURL.appendingPathComponent("orders"), resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "select", value: "id,created_at,source_device,total_cents,status,order_items(id,name,quantity,unit_price_cents,kind)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: "50")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        applySupabaseHeaders(to: &request)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        let rows = try JSONDecoder().decode([SupabaseOrderRow].self, from: data)
        receivedOrders = rows.map(\.asLiveOrder)
    }

    private func createRemoteOrder(_ order: LiveOrderMessage) async throws -> SupabaseInsertedOrder {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("orders"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")

        let payload = [
            SupabaseCreateOrderRequest(
                sourceDevice: order.sourceDevice,
                totalCents: order.totalCents,
                status: "pending"
            )
        ]
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        try validateResponse(response)

        guard let created = try JSONDecoder().decode([SupabaseInsertedOrder].self, from: data).first else {
            throw URLError(.badServerResponse)
        }
        return created
    }

    private func createRemoteOrderItems(orderID: String, lines: [LiveOrderLine]) async throws {
        var request = URLRequest(url: supabaseBaseURL.appendingPathComponent("order_items"))
        request.httpMethod = "POST"
        applySupabaseHeaders(to: &request)

        let payload = lines.map {
            SupabaseCreateOrderItemRequest(
                orderID: orderID,
                name: $0.name,
                quantity: $0.quantity,
                unitPriceCents: $0.unitPriceCents,
                kind: $0.kind.rawValue
            )
        }
        request.httpBody = try JSONEncoder().encode(payload)

        let (_, response) = try await session.data(for: request)
        try validateResponse(response)
    }

    private func applySupabaseHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(supabaseAnonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    }

    private func validateResponse(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
    }
}

private struct SupabaseCreateOrderRequest: Encodable {
    let sourceDevice: String
    let totalCents: Int
    let status: String

    enum CodingKeys: String, CodingKey {
        case sourceDevice = "source_device"
        case totalCents = "total_cents"
        case status
    }
}

private struct SupabaseInsertedOrder: Decodable {
    let id: String
}

private struct SupabaseCreateOrderItemRequest: Encodable {
    let orderID: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kind: String

    enum CodingKeys: String, CodingKey {
        case orderID = "order_id"
        case name
        case quantity
        case unitPriceCents = "unit_price_cents"
        case kind
    }
}

private struct SupabaseOrderRow: Decodable {
    let id: String
    let createdAtRaw: String
    let sourceDevice: String
    let totalCents: Int
    let orderItems: [SupabaseOrderItemRow]

    enum CodingKeys: String, CodingKey {
        case id
        case createdAtRaw = "created_at"
        case sourceDevice = "source_device"
        case totalCents = "total_cents"
        case orderItems = "order_items"
    }

    var asLiveOrder: LiveOrderMessage {
        LiveOrderMessage(
            id: id,
            createdAt: Self.parseDate(createdAtRaw) ?? .now,
            sourceDevice: sourceDevice,
            items: orderItems.map(\.asLiveLine),
            totalCents: totalCents
        )
    }

    private static func parseDate(_ raw: String) -> Date? {
        let formatterWithFractional = ISO8601DateFormatter()
        formatterWithFractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        if let date = formatterWithFractional.date(from: raw) {
            return date
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: raw)
    }
}

private struct SupabaseOrderItemRow: Decodable {
    let id: String
    let name: String
    let quantity: Int
    let unitPriceCents: Int
    let kindRaw: String

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case quantity
        case unitPriceCents = "unit_price_cents"
        case kindRaw = "kind"
    }

    var asLiveLine: LiveOrderLine {
        LiveOrderLine(
            id: id,
            name: name,
            quantity: quantity,
            unitPriceCents: unitPriceCents,
            kind: MenuItemKind(rawValue: kindRaw) ?? .food
        )
    }
}
