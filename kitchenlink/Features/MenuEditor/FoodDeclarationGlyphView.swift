import SwiftUI

/// Plattformneutrale semantische Namen der KitchenLink-Kennzeichnungsicons.
/// Die iOS-Darstellung ist vektorbasiert; das Gast-Web zeichnet denselben
/// Wortschatz als Inline-SVG, ohne Rasterasset oder externe Icon-Abhängigkeit.
enum FoodDeclarationGlyph: String, Sendable {
    case wheat, crustacean, egg, fish, peanut, soy, milk, treeNut
    case celery, mustard, sesame, sulfite, lupin, mollusc
    case colorant, preservative, antioxidant, nitrite, nitrate, curingSalts
    case flavorEnhancer, blackened, waxed, phosphate, sweetener, tableSweetener
    case phenylalanine, polyols, quinine, caffeine, liquorice
    case genericAdditive, notice, unknown
}

struct FoodDeclarationGlyphView: View {
    let glyph: FoodDeclarationGlyph
    var size: CGFloat = 24

    var body: some View {
        Group {
            switch glyph {
            case .sulfite:
                formula("SO₂")
            case .nitrite:
                formula("NO₂")
            case .nitrate:
                formula("NO₃")
            case .curingSalts:
                formula("N₂")
            case .phosphate:
                formula("PO₄")
            case .phenylalanine:
                formula("Phe", scale: 0.37)
            case .polyols:
                formula("10%", scale: 0.34)
            case .quinine:
                formula("Q")
            case .genericAdditive:
                formula("E")
            case .caffeine:
                Image(systemName: "cup.and.saucer.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            case .colorant:
                Image(systemName: "paintpalette.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .preservative:
                Image(systemName: "jar.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            case .antioxidant:
                Image(systemName: "shield.lefthalf.filled")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .flavorEnhancer:
                Image(systemName: "wave.3.up")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .blackened:
                Image(systemName: "circle.lefthalf.filled")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            case .waxed:
                Image(systemName: "sparkles")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .sweetener:
                Image(systemName: "cube.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.12)
            case .tableSweetener:
                Image(systemName: "takeoutbag.and.cup.and.straw.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .liquorice:
                Image(systemName: "hurricane")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.08)
            case .notice:
                Image(systemName: "text.bubble.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.10)
            case .unknown:
                Image(systemName: "questionmark")
                    .font(.system(size: size * 0.62, weight: .bold, design: .rounded))
            default:
                FoodPictogramCanvas(glyph: glyph)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    private func formula(_ value: String, scale: CGFloat = 0.43) -> some View {
        Text(value)
            .font(.system(size: size * scale, weight: .black, design: .rounded))
            .minimumScaleFactor(0.65)
            .lineLimit(1)
    }
}

private struct FoodPictogramCanvas: View {
    let glyph: FoodDeclarationGlyph

    var body: some View {
        Canvas { context, canvasSize in
            let scale = min(canvasSize.width, canvasSize.height) / 24
            context.scaleBy(x: scale, y: scale)
            let stroke = StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round)

            func line(_ points: [CGPoint]) {
                guard let first = points.first else { return }
                var path = Path()
                path.move(to: first)
                for point in points.dropFirst() { path.addLine(to: point) }
                context.stroke(path, with: .color(.primary), style: stroke)
            }

            func ellipse(_ rect: CGRect, filled: Bool = false) {
                let path = Path(ellipseIn: rect)
                if filled { context.fill(path, with: .color(.primary)) }
                else { context.stroke(path, with: .color(.primary), style: stroke) }
            }

            switch glyph {
            case .wheat:
                line([CGPoint(x: 12, y: 21), CGPoint(x: 12, y: 4)])
                for (x, y, angle) in [(8.0, 7.0, -0.55), (16.0, 9.5, 0.55), (8.0, 12.0, -0.55), (16.0, 14.5, 0.55)] {
                    var grain = Path(ellipseIn: CGRect(x: x - 2.4, y: y - 1.25, width: 4.8, height: 2.5))
                    grain = grain.applying(CGAffineTransform(translationX: -x, y: -y))
                        .applying(CGAffineTransform(rotationAngle: angle))
                        .applying(CGAffineTransform(translationX: x, y: y))
                    context.fill(grain, with: .color(.primary))
                }
            case .egg:
                var egg = Path()
                egg.move(to: CGPoint(x: 12, y: 2.5))
                egg.addCurve(to: CGPoint(x: 4.8, y: 15), control1: CGPoint(x: 8.5, y: 4.5), control2: CGPoint(x: 4.8, y: 10.2))
                egg.addCurve(to: CGPoint(x: 12, y: 21.5), control1: CGPoint(x: 4.8, y: 19.3), control2: CGPoint(x: 8.2, y: 21.5))
                egg.addCurve(to: CGPoint(x: 19.2, y: 15), control1: CGPoint(x: 15.8, y: 21.5), control2: CGPoint(x: 19.2, y: 19.3))
                egg.addCurve(to: CGPoint(x: 12, y: 2.5), control1: CGPoint(x: 19.2, y: 10.2), control2: CGPoint(x: 15.5, y: 4.5))
                context.stroke(egg, with: .color(.primary), style: stroke)
                ellipse(CGRect(x: 8.6, y: 11, width: 6.8, height: 6.8), filled: true)
            case .fish:
                var body = Path()
                body.move(to: CGPoint(x: 3, y: 12))
                body.addCurve(to: CGPoint(x: 16.5, y: 6.5), control1: CGPoint(x: 7, y: 6.8), control2: CGPoint(x: 12.5, y: 6.2))
                body.addCurve(to: CGPoint(x: 16.5, y: 17.5), control1: CGPoint(x: 12.5, y: 17.8), control2: CGPoint(x: 7, y: 17.2))
                body.closeSubpath()
                context.stroke(body, with: .color(.primary), style: stroke)
                line([CGPoint(x: 16.5, y: 8), CGPoint(x: 21, y: 5.5), CGPoint(x: 20, y: 12), CGPoint(x: 21, y: 18.5), CGPoint(x: 16.5, y: 16)])
                ellipse(CGRect(x: 7.5, y: 9.2, width: 2.1, height: 2.1), filled: true)
            case .milk:
                var carton = Path()
                carton.move(to: CGPoint(x: 6, y: 7))
                carton.addLine(to: CGPoint(x: 10, y: 2.8))
                carton.addLine(to: CGPoint(x: 17.5, y: 5.8))
                carton.addLine(to: CGPoint(x: 18, y: 21))
                carton.addLine(to: CGPoint(x: 6, y: 21))
                carton.closeSubpath()
                context.stroke(carton, with: .color(.primary), style: stroke)
                line([CGPoint(x: 6, y: 7), CGPoint(x: 14, y: 8.5), CGPoint(x: 17.5, y: 5.8)])
                line([CGPoint(x: 14, y: 8.5), CGPoint(x: 14, y: 21)])
                line([CGPoint(x: 10, y: 2.8), CGPoint(x: 10, y: 7.7)])
            case .peanut:
                var shell = Path()
                shell.move(to: CGPoint(x: 7.5, y: 3.5))
                shell.addCurve(to: CGPoint(x: 12, y: 9.5), control1: CGPoint(x: 3.8, y: 6), control2: CGPoint(x: 6.2, y: 10))
                shell.addCurve(to: CGPoint(x: 16.5, y: 20.5), control1: CGPoint(x: 17.8, y: 14), control2: CGPoint(x: 20.2, y: 18))
                shell.addCurve(to: CGPoint(x: 12, y: 14.5), control1: CGPoint(x: 20.2, y: 18), control2: CGPoint(x: 17.8, y: 14))
                shell.addCurve(to: CGPoint(x: 7.5, y: 3.5), control1: CGPoint(x: 6.2, y: 10), control2: CGPoint(x: 3.8, y: 6))
                context.stroke(shell, with: .color(.primary), style: stroke)
                line([CGPoint(x: 7, y: 7), CGPoint(x: 16.8, y: 17)])
                line([CGPoint(x: 10.5, y: 5.3), CGPoint(x: 7, y: 10)])
                line([CGPoint(x: 17, y: 13.5), CGPoint(x: 13.5, y: 18.5)])
            case .soy:
                var pod = Path()
                pod.move(to: CGPoint(x: 4, y: 16.5))
                pod.addCurve(to: CGPoint(x: 20, y: 6), control1: CGPoint(x: 8, y: 6), control2: CGPoint(x: 16, y: 3.5))
                pod.addCurve(to: CGPoint(x: 4, y: 16.5), control1: CGPoint(x: 17.5, y: 17), control2: CGPoint(x: 9, y: 21))
                context.stroke(pod, with: .color(.primary), style: stroke)
                ellipse(CGRect(x: 7, y: 12, width: 3.2, height: 3.2), filled: true)
                ellipse(CGRect(x: 11.3, y: 8.7, width: 3.2, height: 3.2), filled: true)
                ellipse(CGRect(x: 15.4, y: 6.5, width: 3, height: 3), filled: true)
            case .treeNut:
                var nut = Path()
                nut.move(to: CGPoint(x: 12, y: 6))
                nut.addCurve(to: CGPoint(x: 5, y: 13), control1: CGPoint(x: 8, y: 7), control2: CGPoint(x: 5, y: 10))
                nut.addCurve(to: CGPoint(x: 12, y: 21), control1: CGPoint(x: 5, y: 18), control2: CGPoint(x: 8, y: 21))
                nut.addCurve(to: CGPoint(x: 19, y: 13), control1: CGPoint(x: 16, y: 21), control2: CGPoint(x: 19, y: 18))
                nut.addCurve(to: CGPoint(x: 12, y: 6), control1: CGPoint(x: 19, y: 10), control2: CGPoint(x: 16, y: 7))
                context.stroke(nut, with: .color(.primary), style: stroke)
                line([CGPoint(x: 7, y: 8), CGPoint(x: 17, y: 8)])
                line([CGPoint(x: 12, y: 6), CGPoint(x: 14, y: 2.5)])
            case .celery:
                line([CGPoint(x: 8, y: 21), CGPoint(x: 10, y: 8)])
                line([CGPoint(x: 12, y: 21), CGPoint(x: 12, y: 6)])
                line([CGPoint(x: 16, y: 21), CGPoint(x: 14, y: 8)])
                ellipse(CGRect(x: 5, y: 3, width: 6, height: 5), filled: true)
                ellipse(CGRect(x: 10, y: 1.8, width: 6, height: 5), filled: true)
                ellipse(CGRect(x: 14, y: 4, width: 5.5, height: 4.5), filled: true)
                line([CGPoint(x: 6.5, y: 21), CGPoint(x: 17.5, y: 21)])
            case .mustard:
                var jar = Path(roundedRect: CGRect(x: 5, y: 6.5, width: 14, height: 14), cornerRadius: 3)
                context.stroke(jar, with: .color(.primary), style: stroke)
                line([CGPoint(x: 7, y: 3.5), CGPoint(x: 17, y: 3.5), CGPoint(x: 18, y: 6.5), CGPoint(x: 6, y: 6.5), CGPoint(x: 7, y: 3.5)])
                ellipse(CGRect(x: 9, y: 10.5, width: 6, height: 6), filled: true)
            case .sesame:
                for rect in [CGRect(x: 5, y: 7, width: 5, height: 9), CGRect(x: 10, y: 3, width: 5, height: 9), CGRect(x: 14, y: 11, width: 5, height: 9)] {
                    context.stroke(Path(ellipseIn: rect), with: .color(.primary), style: stroke)
                }
            case .lupin:
                line([CGPoint(x: 12, y: 21), CGPoint(x: 12, y: 7)])
                ellipse(CGRect(x: 8.5, y: 2, width: 7, height: 7), filled: true)
                ellipse(CGRect(x: 5.5, y: 6, width: 6, height: 5), filled: true)
                ellipse(CGRect(x: 12.5, y: 7, width: 6, height: 5), filled: true)
                ellipse(CGRect(x: 7, y: 11, width: 5, height: 4), filled: true)
                ellipse(CGRect(x: 12.5, y: 12, width: 5, height: 4), filled: true)
            case .mollusc:
                var shell = Path()
                shell.move(to: CGPoint(x: 3.5, y: 18.5))
                shell.addCurve(to: CGPoint(x: 12, y: 4), control1: CGPoint(x: 3.5, y: 10), control2: CGPoint(x: 7, y: 4))
                shell.addCurve(to: CGPoint(x: 20.5, y: 18.5), control1: CGPoint(x: 17, y: 4), control2: CGPoint(x: 20.5, y: 10))
                shell.closeSubpath()
                context.stroke(shell, with: .color(.primary), style: stroke)
                for x in [7.0, 10.2, 13.8, 17.0] {
                    line([CGPoint(x: 12, y: 5), CGPoint(x: x, y: 18)])
                }
                line([CGPoint(x: 4, y: 18.5), CGPoint(x: 20, y: 18.5)])
            case .crustacean:
                var shrimp = Path()
                shrimp.move(to: CGPoint(x: 19, y: 7))
                shrimp.addCurve(to: CGPoint(x: 8, y: 6), control1: CGPoint(x: 15, y: 2.5), control2: CGPoint(x: 8, y: 3))
                shrimp.addCurve(to: CGPoint(x: 12, y: 18), control1: CGPoint(x: 3, y: 9), control2: CGPoint(x: 5, y: 17))
                shrimp.addCurve(to: CGPoint(x: 18, y: 13), control1: CGPoint(x: 15, y: 18), control2: CGPoint(x: 18, y: 16))
                context.stroke(shrimp, with: .color(.primary), style: stroke)
                line([CGPoint(x: 8, y: 7), CGPoint(x: 15, y: 15)])
                line([CGPoint(x: 12, y: 5), CGPoint(x: 18, y: 11)])
                line([CGPoint(x: 18, y: 6), CGPoint(x: 22, y: 3)])
                line([CGPoint(x: 18, y: 7), CGPoint(x: 22, y: 8)])
                ellipse(CGRect(x: 16, y: 5, width: 1.8, height: 1.8), filled: true)
            default:
                ellipse(CGRect(x: 4, y: 4, width: 16, height: 16))
            }
        }
    }
}
