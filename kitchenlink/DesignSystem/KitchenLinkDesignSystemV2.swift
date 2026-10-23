import SwiftUI
import UIKit

// MARK: - Palette

/// Semantic colors for the "Tactile Hospitality Tech" design language (docs/DESIGN_SYSTEM.md).
///
/// Bridges the warm natural dining room aesthetic (Canvas, Linen, Terracotta) with
/// high-contrast precision in service (Espresso Dark POS & KDS, Relay Emerald, Amber Alerts).
enum KitchenLinkV2Palette {
    struct RGB: Hashable, Sendable {
        let red: Double
        let green: Double
        let blue: Double
        let opacity: Double

        init(hex: Int, opacity: Double = 1) {
            red = Double((hex >> 16) & 0xFF) / 255
            green = Double((hex >> 8) & 0xFF) / 255
            blue = Double(hex & 0xFF) / 255
            self.opacity = opacity
        }

        func contrastRatio(against other: RGB) -> Double {
            let lighter = max(relativeLuminance, other.relativeLuminance)
            let darker = min(relativeLuminance, other.relativeLuminance)
            return (lighter + 0.05) / (darker + 0.05)
        }

        private var relativeLuminance: Double {
            func linearized(_ component: Double) -> Double {
                component <= 0.04045
                    ? component / 12.92
                    : pow((component + 0.055) / 1.055, 2.4)
            }

            return 0.2126 * linearized(red)
                + 0.7152 * linearized(green)
                + 0.0722 * linearized(blue)
        }

        fileprivate var uiColor: UIColor {
            UIColor(
                red: CGFloat(red),
                green: CGFloat(green),
                blue: CGFloat(blue),
                alpha: CGFloat(opacity)
            )
        }
    }

    enum Brand {
        static let grape = Color(rgb: RGB(hex: 0xC84B31)) // Canonical Terracotta accent
        static let deep = Color(rgb: RGB(hex: 0x141413))  // Espresso Ink
        static let carbon = Color(rgb: RGB(hex: 0x1C1B19)) // Charcoal Ink
    }

    enum Surface {
        static let base = adaptive(light: RGB(hex: 0xFAF7F2), dark: RGB(hex: 0x141413)) // Canvas / Dark
        static let raised = adaptive(light: RGB(hex: 0xFFFFFF), dark: RGB(hex: 0x1C1B19)) // Surface
        static let recessed = adaptive(light: RGB(hex: 0xF2ECE4), dark: RGB(hex: 0x262523)) // Subtle
        static let kitchenBase = Brand.deep
    }

    enum Content {
        static let primary = adaptive(light: RGB(hex: 0x1C1B19), dark: RGB(hex: 0xFAF7F2)) // Charcoal / Canvas
        static let secondary = adaptive(light: RGB(hex: 0x6E6A63), dark: RGB(hex: 0xA8A39B)) // Muted
        static let muted = adaptive(light: RGB(hex: 0x8C877E), dark: RGB(hex: 0x948F86))
        static let onPrimaryAction = Color(rgb: RGB(hex: 0xFFFFFF)) // White text on Terracotta CTA
    }

    enum Border {
        static let subtle = adaptive(
            light: RGB(hex: 0xE6E0D6),
            dark: RGB(hex: 0x2E2D2A)
        )
        static let control = adaptive(light: RGB(hex: 0x8C877E), dark: RGB(hex: 0x888896))
        static let focusRing = adaptive(light: RGB(hex: 0xC84B31), dark: RGB(hex: 0xC84B31))
    }

    enum Action {
        /// For one persistent primary action in a visible working context.
        static let persistentPrimary = Color(rgb: RGB(hex: 0xC84B31)) // Burnt Terracotta
        static let persistentPrimaryPressed = Color(rgb: RGB(hex: 0xAF3F27))

        /// For the logo handoff only, or a brief successful handoff animation.
        static let logoHandoff = Color(rgb: RGB(hex: 0xC84B31))
    }

    enum Urgency {
        static let freshSymbol = adaptive(light: RGB(hex: 0x10B981), dark: RGB(hex: 0x10B981)) // Relay Emerald
        static let freshText = adaptive(light: RGB(hex: 0x059669), dark: RGB(hex: 0x34D399))
        static let neutralSymbol = adaptive(light: RGB(hex: 0x6E6A63), dark: RGB(hex: 0xA8A39B))
        static let neutralText = adaptive(light: RGB(hex: 0x6E6A63), dark: RGB(hex: 0xA8A39B))
        static let waitingSymbol = adaptive(light: RGB(hex: 0xF59E0B), dark: RGB(hex: 0xF59E0B)) // Amber Alert
        static let waitingText = adaptive(light: RGB(hex: 0xD97706), dark: RGB(hex: 0xFBBF24))
        static let criticalSymbol = adaptive(light: RGB(hex: 0xC84B31), dark: RGB(hex: 0xEF6E64)) // Terracotta
        static let criticalText = adaptive(light: RGB(hex: 0xC84B31), dark: RGB(hex: 0xEF6E64))
    }

    private static func adaptive(light: RGB, dark: RGB) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
        })
    }
}

private extension Color {
    init(rgb: KitchenLinkV2Palette.RGB) {
        self.init(uiColor: rgb.uiColor)
    }
}

// MARK: - Status semantics

/// The operation kind is intentionally independent from its urgency.
/// Adding a new operation requires an explicit glyph and accessibility label.
enum KitchenLinkV2Operation: Hashable, Sendable {
    case order
    case payment
    case connection
    case change

    var accessibilityLabel: String {
        switch self {
        case .order:
            return "Bestellung, Kreis"
        case .payment:
            return "Zahlung, Raute"
        case .connection:
            return "Verbindung, durchgestrichener Ring"
        case .change:
            return "Aenderung, Quadrat"
        }
    }
}

enum KitchenLinkV2Urgency: Hashable, Sendable {
    case fresh
    case neutral
    case waiting
    case critical

    var accessibilityLabel: String {
        switch self {
        case .fresh:
            return "frisch"
        case .neutral:
            return "neutral"
        case .waiting:
            return "wartet auf Aufmerksamkeit"
        case .critical:
            return "kritisch"
        }
    }

    var symbolColor: Color {
        switch self {
        case .fresh:
            return KitchenLinkV2Palette.Urgency.freshSymbol
        case .neutral:
            return KitchenLinkV2Palette.Urgency.neutralSymbol
        case .waiting:
            return KitchenLinkV2Palette.Urgency.waitingSymbol
        case .critical:
            return KitchenLinkV2Palette.Urgency.criticalSymbol
        }
    }

    var textColor: Color {
        switch self {
        case .fresh:
            return KitchenLinkV2Palette.Urgency.freshText
        case .neutral:
            return KitchenLinkV2Palette.Urgency.neutralText
        case .waiting:
            return KitchenLinkV2Palette.Urgency.waitingText
        case .critical:
            return KitchenLinkV2Palette.Urgency.criticalText
        }
    }
}

struct KitchenLinkV2Status: Hashable, Sendable {
    let operation: KitchenLinkV2Operation
    let urgency: KitchenLinkV2Urgency
    let verb: String

    init(operation: KitchenLinkV2Operation, urgency: KitchenLinkV2Urgency, verb: String) {
        self.operation = operation
        self.urgency = urgency
        self.verb = verb
    }

    var accessibilityLabel: String {
        "\(operation.accessibilityLabel), \(urgency.accessibilityLabel): \(verb)"
    }
}

struct KitchenLinkV2OperationGlyph: View {
    let operation: KitchenLinkV2Operation
    let color: Color
    var size: CGFloat = 14

    var body: some View {
        Group {
            switch operation {
            case .order:
                Circle().fill(color)
            case .payment:
                DiamondShape().fill(color)
            case .connection:
                ConnectionShape().stroke(color, lineWidth: max(2, size * 0.14))
            case .change:
                RoundedRectangle(cornerRadius: size * 0.14, style: .continuous).fill(color)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct KitchenLinkV2StatusLabel: View {
    let status: KitchenLinkV2Status

    var body: some View {
        HStack(spacing: KitchenLinkV2Spacing.small) {
            KitchenLinkV2OperationGlyph(
                operation: status.operation,
                color: status.urgency.symbolColor
            )

            Text(status.verb)
                .font(KitchenLinkV2Typography.meta)
                .foregroundStyle(status.urgency.textColor)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status.accessibilityLabel)
    }
}

private struct DiamondShape: Shape {
    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            path.closeSubpath()
        }
    }
}

private struct ConnectionShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path(ellipseIn: rect.insetBy(dx: rect.width * 0.12, dy: rect.height * 0.12))
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.16, y: rect.maxY - rect.height * 0.16))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.16, y: rect.minY + rect.height * 0.16))
        return path
    }
}

// MARK: - Type, spacing, and focus

enum KitchenLinkV2GuestMenuMetrics {
    static let itemTitlePointSize: CGFloat = 20
    static let itemPricePointSize: CGFloat = 16
    /// Glyphengröße der ruhigen Gastzeile: kleiner als früher, dafür ohne
    /// Badge-Box — die Kennzeichnung liest sich als Fußnote.
    static let declarationVisualSize: CGFloat = 18
    static let minimumTapTarget: CGFloat = 44
}

/// Bricht kompakte Kennzeichnungssymbole zeilenweise um, statt sie zu kürzen:
/// Pflichtdeklarationen dürfen nie hinter einem Sammelindikator verschwinden.
struct KitchenLinkV2WrappingRow: Layout {
    var horizontalSpacing: CGFloat = 2
    var verticalSpacing: CGFloat = 2

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let contentWidth = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +)
            + verticalSpacing * CGFloat(max(0, rows.count - 1))
        let width = rows.count > 1 ? (proposal.width ?? contentWidth) : contentWidth
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + horizontalSpacing
            }
            y += row.height + verticalSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.indices.isEmpty,
               current.width + horizontalSpacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            let spacing = current.indices.isEmpty ? 0 : horizontalSpacing
            current.indices.append(index)
            current.width += spacing + size.width
            current.height = max(current.height, size.height)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

enum KitchenLinkV2Typography {
    static let display = font(
        named: "BricolageGrotesque-ExtraBold",
        size: 28,
        relativeTo: .title,
        fallback: .system(.title, design: .rounded).weight(.heavy)
    )
    static let section = font(
        named: "BricolageGrotesque-Bold",
        size: 20,
        relativeTo: .title3,
        fallback: .system(.title3, design: .rounded).weight(.bold)
    )
    static let compactSection = font(
        named: "BricolageGrotesque-Bold",
        size: 16,
        relativeTo: .headline,
        fallback: .system(.headline, design: .rounded).weight(.bold)
    )
    static let primaryLine = font(
        named: "SourceSans3-Semibold",
        size: 17,
        relativeTo: .body,
        fallback: .system(.body).weight(.semibold)
    )
    static let menuItemTitle = font(
        named: "SourceSans3-Bold",
        size: KitchenLinkV2GuestMenuMetrics.itemTitlePointSize,
        relativeTo: .title3,
        fallback: .system(.title3).weight(.bold)
    )
    static let menuItemPrice = font(
        named: "SourceSans3-Semibold",
        size: KitchenLinkV2GuestMenuMetrics.itemPricePointSize,
        relativeTo: .subheadline,
        fallback: .system(.subheadline).weight(.semibold)
    )
    static let secondaryLine = font(
        named: "SourceSans3-Regular",
        size: 15,
        relativeTo: .subheadline,
        fallback: .system(.subheadline)
    )
    static let meta = font(
        named: "SourceSans3-Semibold",
        size: 13,
        relativeTo: .caption,
        fallback: .system(.caption).weight(.semibold)
    )
    static let primaryButton = font(
        named: "SourceSans3-Bold",
        size: 16,
        relativeTo: .headline,
        fallback: .system(.headline).weight(.bold)
    )
    static let kitchenTitle = font(
        named: "BricolageGrotesque-ExtraBold",
        size: 22,
        relativeTo: .title2,
        fallback: .system(.title2, design: .rounded).weight(.heavy)
    )
    static let kitchenStatus = font(
        named: "SourceSans3-Bold",
        size: 15,
        relativeTo: .subheadline,
        fallback: .system(.subheadline).weight(.bold)
    )

    private static func font(
        named name: String,
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle,
        fallback: Font
    ) -> Font {
        guard UIFont(name: name, size: size) != nil else {
            return fallback
        }
        return .custom(name, size: size, relativeTo: textStyle)
    }
}

enum KitchenLinkV2Spacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
    static let xxLarge: CGFloat = 32
}

enum KitchenLinkV2Radius {
    static let label: CGFloat = 6
    static let compact: CGFloat = 9
    static let control: CGFloat = 12
    static let card: CGFloat = 14
    static let sheet: CGFloat = 20
}

extension View {
    func kitchenLinkV2FocusRing(isFocused: Bool) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                .stroke(KitchenLinkV2Palette.Border.focusRing, lineWidth: 2)
                .opacity(isFocused ? 1 : 0)
        }
    }

    func kitchenLinkV2TabularNumbers() -> some View {
        monospacedDigit()
    }
}

// MARK: - Surfaces and controls

struct KitchenLinkV2Surface<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(KitchenLinkV2Palette.Surface.base)
            .foregroundStyle(KitchenLinkV2Palette.Content.primary)
    }
}

struct KitchenLinkV2Card<Content: View>: View {
    private let content: Content
    private let padding: CGFloat

    init(padding: CGFloat = KitchenLinkV2Spacing.large, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    .fill(KitchenLinkV2Palette.Surface.raised)
            }
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.card, style: .continuous)
                    .stroke(KitchenLinkV2Palette.Border.subtle, lineWidth: 1)
            }
    }
}

/// Use for the single persistent primary action in a visible working context.
struct KitchenLinkV2PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KitchenLinkV2Typography.primaryButton)
            .foregroundStyle(isEnabled
                ? KitchenLinkV2Palette.Content.onPrimaryAction
                : KitchenLinkV2Palette.Content.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return KitchenLinkV2Palette.Surface.recessed
        }

        return isPressed
            ? KitchenLinkV2Palette.Action.persistentPrimaryPressed
            : KitchenLinkV2Palette.Action.persistentPrimary
    }
}

/// High-emphasis completion action on the permanently dark kitchen surface
/// (bump). Deliberately grape-neutral instead of lemon: advancing a ticket is
/// a repeated per-ticket action, and lemon never appears in kitchen status.
/// The light fill (content.light on Traube) reaches ~12:1 against the ticket
/// and stays operable with wet hands through the full-width 52pt target.
struct KitchenLinkV2KitchenBumpButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KitchenLinkV2Typography.primaryButton)
            .foregroundStyle(isEnabled
                ? Color(rgb: KitchenLinkV2Palette.RGB(hex: 0x141413))
                : Color(rgb: KitchenLinkV2Palette.RGB(hex: 0x6E6A63)))
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .clipShape(RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        guard isEnabled else {
            return Color(rgb: KitchenLinkV2Palette.RGB(hex: 0x262523))
        }

        return isPressed
            ? Color(rgb: KitchenLinkV2Palette.RGB(hex: 0xE6E0D6))
            : Color(rgb: KitchenLinkV2Palette.RGB(hex: 0xFAF7F2))
    }
}

struct KitchenLinkV2SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(KitchenLinkV2Typography.primaryButton)
            .foregroundStyle(isEnabled
                ? KitchenLinkV2Palette.Content.primary
                : KitchenLinkV2Palette.Content.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, KitchenLinkV2Spacing.large)
            .background(
                KitchenLinkV2Palette.Surface.raised
                    .opacity(isEnabled ? (configuration.isPressed ? 0.78 : 1) : 0.55)
            )
            .overlay {
                RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous)
                    .stroke(KitchenLinkV2Palette.Border.control, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: KitchenLinkV2Radius.control, style: .continuous))
            .scaleEffect(configuration.isPressed && isEnabled ? 0.99 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
