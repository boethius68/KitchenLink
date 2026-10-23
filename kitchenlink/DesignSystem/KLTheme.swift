import SwiftUI
import UIKit

// MARK: - KitchenLink "Tactile Hospitality Tech" Design System (SwiftUI)
// Canonical Reference: docs/DESIGN_SYSTEM.md

public enum KLTheme {
    // MARK: - RGB / Hex Color Representation
    public struct HexColor: Sendable, Hashable {
        public let red: Double
        public let green: Double
        public let blue: Double
        public let alpha: Double

        public init(hex: Int, alpha: Double = 1.0) {
            self.red = Double((hex >> 16) & 0xFF) / 255.0
            self.green = Double((hex >> 8) & 0xFF) / 255.0
            self.blue = Double(hex & 0xFF) / 255.0
            self.alpha = alpha
        }

        public var color: Color {
            Color(red: red, green: green, blue: blue, opacity: alpha)
        }

        public var uiColor: UIColor {
            UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: CGFloat(alpha))
        }
    }

    public static func adaptiveColor(light: HexColor, dark: HexColor) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? dark.uiColor : light.uiColor
        })
    }

    // MARK: - Canonical Color Tokens
    public enum Colors {
        /// Warm Alabaster (`#FAF7F2`) — light surfaces / paper receipts
        public static let klCanvas = HexColor(hex: 0xFAF7F2).color

        /// Pure Linen (`#FFFFFF` in Light / `#1C1B19` in Dark Mode) — elevated cards & sheets
        public static let klSurface = adaptiveColor(
            light: HexColor(hex: 0xFFFFFF),
            dark: HexColor(hex: 0x1C1B19)
        )

        /// Stone Wash (`#F2ECE4` in Light / `#262523` in Dark Mode) — pills, badges, secondary surfaces
        public static let klSubtle = adaptiveColor(
            light: HexColor(hex: 0xF2ECE4),
            dark: HexColor(hex: 0x262523)
        )

        /// Espresso Ink (`#141413`) — primary dark POS & KDS background
        public static let klDark = HexColor(hex: 0x141413).color

        /// Charcoal Ink (`#1C1B19` in Light / `#FAF7F2` in Dark) — primary typography
        public static let klCharcoal = adaptiveColor(
            light: HexColor(hex: 0x1C1B19),
            dark: HexColor(hex: 0xFAF7F2)
        )

        /// Warm Slate (`#6E6A63` in Light / `#A8A39B` in Dark) — secondary metadata & descriptions
        public static let klMuted = adaptiveColor(
            light: HexColor(hex: 0x6E6A63),
            dark: HexColor(hex: 0xA8A39B)
        )

        /// Burnt Terracotta (`#C84B31`) — primary brand accent, primary CTA, fire course, active table
        public static let klTerracotta = HexColor(hex: 0xC84B31).color

        /// Sage Leaf (`#3D5A45` in Light / `#5E8468` in Dark) — fiscal/compliance, GoBD & dietary tags
        public static let klSage = adaptiveColor(
            light: HexColor(hex: 0x3D5A45),
            dark: HexColor(hex: 0x5E8468)
        )

        /// Relay Emerald (`#10B981`) — Local LAN Relay active / synced
        public static let klEmerald = HexColor(hex: 0x10B981).color

        /// Amber Alert (`#F59E0B`) — Offline queue / understaffing warning / pending sync
        public static let klAmber = HexColor(hex: 0xF59E0B).color

        /// Warm Rule (`#E6E0D6` in Light / `#2E2D2A` in Dark) — 1px hairlines & dividers
        public static let klBorder = adaptiveColor(
            light: HexColor(hex: 0xE6E0D6),
            dark: HexColor(hex: 0x2E2D2A)
        )
    }

    // Direct access convenience
    public static var canvas: Color { Colors.klCanvas }
    public static var surface: Color { Colors.klSurface }
    public static var subtle: Color { Colors.klSubtle }
    public static var dark: Color { Colors.klDark }
    public static var charcoal: Color { Colors.klCharcoal }
    public static var muted: Color { Colors.klMuted }
    public static var terracotta: Color { Colors.klTerracotta }
    public static var sage: Color { Colors.klSage }
    public static var emerald: Color { Colors.klEmerald }
    public static var amber: Color { Colors.klAmber }
    public static var border: Color { Colors.klBorder }

    // MARK: - Typography Tokens (Mirrors Newsreader, Plus Jakarta Sans, JetBrains Mono)
    public enum Typography {
        /// Editorial / Venue & Section Headers: Newsreader analog (.system(..., design: .serif))
        public static func editorialTitle(_ style: Font.TextStyle = .title2, weight: Font.Weight = .medium) -> Font {
            .system(style, design: .serif).weight(weight)
        }

        /// Operational UI & Dish Titles: Plus Jakarta Sans analog (.system(..., design: .default))
        public static func operational(_ style: Font.TextStyle = .body, weight: Font.Weight = .regular) -> Font {
            .system(style, design: .default).weight(weight)
        }

        public static func dishTitle(_ style: Font.TextStyle = .headline, weight: Font.Weight = .semibold) -> Font {
            .system(style, design: .default).weight(weight)
        }

        /// Prices, Timers, Table Badges, PIN pads & TSE/Fiscal Metadata: JetBrains Mono analog
        public static func tabularMono(_ style: Font.TextStyle = .callout, weight: Font.Weight = .medium) -> Font {
            .system(style, design: .monospaced).weight(weight).monospacedDigit()
        }

        public static func tabularMono(size: CGFloat, weight: Font.Weight = .medium) -> Font {
            .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
        }

        public static func tabularPrice(_ style: Font.TextStyle = .body, weight: Font.Weight = .semibold) -> Font {
            .system(style, design: .monospaced).weight(weight).monospacedDigit()
        }

        public static func tabularPrice(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
            .system(size: size, weight: weight, design: .monospaced).monospacedDigit()
        }
    }
}

// MARK: - Color Extensions for Idiomatic SwiftUI Syntax

public extension Color {
    static var klCanvas: Color { KLTheme.Colors.klCanvas }
    static var klSurface: Color { KLTheme.Colors.klSurface }
    static var klSubtle: Color { KLTheme.Colors.klSubtle }
    static var klDark: Color { KLTheme.Colors.klDark }
    static var klCharcoal: Color { KLTheme.Colors.klCharcoal }
    static var klMuted: Color { KLTheme.Colors.klMuted }
    static var klTerracotta: Color { KLTheme.Colors.klTerracotta }
    static var klSage: Color { KLTheme.Colors.klSage }
    static var klEmerald: Color { KLTheme.Colors.klEmerald }
    static var klAmber: Color { KLTheme.Colors.klAmber }
    static var klBorder: Color { KLTheme.Colors.klBorder }
}

// MARK: - View Modifiers & Helpers

public extension View {
    /// Enforces tabular numerals across any monospaced or numbers element
    func klTabularDigits() -> some View {
        self.monospacedDigit()
    }

    /// Surfaces an elevated card according to "Tactile Hospitality Tech" specs
    func klCardStyle(
        backgroundColor: Color = Color.klSurface,
        borderColor: Color = Color.klBorder,
        cornerRadius: CGFloat = 14,
        padding: CGFloat = 16
    ) -> some View {
        self
            .padding(padding)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundColor)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            }
    }

    /// Renders a quiet inline badge for allergens, room status or fiscal indicators
    func klBadgeStyle(
        backgroundColor: Color = Color.klSubtle,
        foregroundColor: Color = Color.klMuted,
        cornerRadius: CGFloat = 6
    ) -> some View {
        self
            .font(.system(.caption2, design: .monospaced).weight(.medium).monospacedDigit())
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
}

// MARK: - Button Styles

/// Primary Terracotta action button for POS / Floor Plan
public struct KLTerracottaButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let minHeight: CGFloat

    public init(minHeight: CGFloat = 46) {
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .default).weight(.semibold))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? (configuration.isPressed ? Color.klTerracotta.opacity(0.85) : Color.klTerracotta) : Color.klMuted.opacity(0.4))
            )
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Dark Espresso button for KDS bump / Secondary high-contrast action
public struct KLDarkButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let minHeight: CGFloat

    public init(minHeight: CGFloat = 46) {
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .default).weight(.semibold))
            .foregroundStyle(Color.klCanvas)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isEnabled ? (configuration.isPressed ? Color.klDark.opacity(0.8) : Color.klDark) : Color.klMuted.opacity(0.3))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.klBorder, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Quiet secondary action button
public struct KLSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    private let minHeight: CGFloat

    public init(minHeight: CGFloat = 44) {
        self.minHeight = minHeight
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.subheadline, design: .default).weight(.medium))
            .foregroundStyle(isEnabled ? Color.klCharcoal : Color.klMuted)
            .frame(maxWidth: .infinity, minHeight: minHeight)
            .padding(.horizontal, 14)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.klSubtle.opacity(configuration.isPressed ? 0.7 : 1.0))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.klBorder, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed && isEnabled ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
