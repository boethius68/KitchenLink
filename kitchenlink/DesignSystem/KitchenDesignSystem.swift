import SwiftUI
import UIKit

enum KitchenTheme {
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

struct KitchenBackground: View {
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

struct KitchenSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack {
            KitchenBackground()
            content
        }
        .tint(KitchenTheme.brand)
        .fontDesign(.rounded)
    }
}

extension View {
    func kitchenSurface() -> some View {
        modifier(KitchenSurfaceModifier())
    }
}

struct KitchenCard<Content: View>: View {
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

struct KitchenPrimaryButtonStyle: ButtonStyle {
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

struct KitchenSecondaryButtonStyle: ButtonStyle {
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
