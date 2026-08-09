import SwiftUI

/// The hero illustration: one `Canvas`, a handful of paths, no image assets and
/// no animation loop. It rasterises when `isOn` flips and then costs nothing.
struct MacBookGlyph: View {

    var isOn: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(colors: [Theme.glow.opacity(isOn ? 0.26 : 0),
                                            Theme.glow.opacity(0)],
                                   center: .center, startRadius: 4, endRadius: 88)
                )
                .frame(width: 190, height: 190)
                .blur(radius: 6)
                .allowsHitTesting(false)

            Canvas(rendersAsynchronously: false) { context, size in
                draw(in: &context, size: size)
            }
            .frame(width: 176, height: 118)
        }
        .frame(width: 176, height: 118)
        .animation(.easeInOut(duration: 0.28), value: isOn)
        .accessibilityHidden(true)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let width = size.width
        let height = size.height

        let lidWidth = width * 0.755
        let lidHeight = height * 0.735
        let lidRect = CGRect(x: (width - lidWidth) / 2, y: 1, width: lidWidth, height: lidHeight)
        let corner = lidWidth * 0.055

        // Contact shadow.
        let shadow = Path(ellipseIn: CGRect(x: width * 0.09, y: height - 12,
                                            width: width * 0.82, height: 13))
        context.fill(shadow, with: .radialGradient(
            Gradient(colors: [.black.opacity(0.20), .black.opacity(0)]),
            center: CGPoint(x: width / 2, y: height - 5.5),
            startRadius: 1, endRadius: width * 0.42))

        // Lid.
        let lid = Path(roundedRect: lidRect, cornerRadius: corner, style: .continuous)
        context.fill(lid, with: .linearGradient(
            Gradient(colors: [Theme.shellLight, Theme.shellDark]),
            startPoint: CGPoint(x: 0, y: lidRect.minY),
            endPoint: CGPoint(x: 0, y: lidRect.maxY)))
        context.stroke(lid, with: .color(Theme.shellEdge.opacity(0.6)), lineWidth: 0.8)

        // Display.
        let bezel = lidWidth * 0.042
        let screenRect = lidRect.insetBy(dx: bezel, dy: bezel)
        let screen = Path(roundedRect: screenRect, cornerRadius: corner * 0.62, style: .continuous)
        context.fill(screen, with: .linearGradient(
            Gradient(colors: isOn ? [Theme.screenOnTop, Theme.screenOnBottom]
                                  : [Theme.screenOffTop, Theme.screenOffBottom]),
            startPoint: CGPoint(x: screenRect.minX, y: screenRect.minY),
            endPoint: CGPoint(x: screenRect.maxX, y: screenRect.maxY)))

        // Glass sheen across the upper third.
        var sheen = Path()
        sheen.move(to: CGPoint(x: screenRect.minX, y: screenRect.minY))
        sheen.addLine(to: CGPoint(x: screenRect.maxX, y: screenRect.minY))
        sheen.addLine(to: CGPoint(x: screenRect.maxX, y: screenRect.minY + screenRect.height * 0.34))
        sheen.addLine(to: CGPoint(x: screenRect.minX, y: screenRect.minY + screenRect.height * 0.52))
        sheen.closeSubpath()
        context.fill(sheen, with: .linearGradient(
            Gradient(colors: [.white.opacity(isOn ? 0.18 : 0.05), .white.opacity(0)]),
            startPoint: CGPoint(x: screenRect.minX, y: screenRect.minY),
            endPoint: CGPoint(x: screenRect.minX, y: screenRect.maxY * 0.75)))

        // Camera housing.
        let notchWidth = lidWidth * 0.155
        let notch = Path(roundedRect: CGRect(x: (width - notchWidth) / 2,
                                             y: lidRect.minY + bezel - 0.5,
                                             width: notchWidth, height: bezel * 0.9),
                         cornerRadius: bezel * 0.35, style: .continuous)
        context.fill(notch, with: .color(Theme.shellDark))

        // Base, seen slightly from above.
        let baseTop = lidRect.maxY + 1
        let baseBottom = baseTop + height * 0.055
        var base = Path()
        base.move(to: CGPoint(x: lidRect.minX - 1, y: baseTop))
        base.addLine(to: CGPoint(x: lidRect.maxX + 1, y: baseTop))
        base.addLine(to: CGPoint(x: width - 3, y: baseBottom - 3))
        base.addQuadCurve(to: CGPoint(x: width - 8, y: baseBottom),
                          control: CGPoint(x: width - 3.5, y: baseBottom))
        base.addLine(to: CGPoint(x: 8, y: baseBottom))
        base.addQuadCurve(to: CGPoint(x: 3, y: baseBottom - 3),
                          control: CGPoint(x: 3.5, y: baseBottom))
        base.closeSubpath()
        context.fill(base, with: .linearGradient(
            Gradient(colors: [Theme.shellEdge.opacity(0.9), Theme.shellBase]),
            startPoint: CGPoint(x: 0, y: baseTop),
            endPoint: CGPoint(x: 0, y: baseBottom)))

        // Finger recess.
        let recessWidth = width * 0.17
        let recess = Path(roundedRect: CGRect(x: (width - recessWidth) / 2,
                                              y: baseBottom - 2.4,
                                              width: recessWidth, height: 2.4),
                          cornerRadius: 1.2, style: .continuous)
        context.fill(recess, with: .color(Theme.shellDark.opacity(0.85)))
    }
}
