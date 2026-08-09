import AppKit
import SwiftUI

/// The warm, papery palette of the About This Mac window, in both appearances.
enum Theme {

    static func dynamic(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        }
    }

    static let canvasTop = dynamic(
        light: NSColor(srgbRed: 0.988, green: 0.976, blue: 0.957, alpha: 1),
        dark: NSColor(srgbRed: 0.129, green: 0.125, blue: 0.118, alpha: 1)
    )

    static let canvasBottom = dynamic(
        light: NSColor(srgbRed: 0.961, green: 0.945, blue: 0.918, alpha: 1),
        dark: NSColor(srgbRed: 0.086, green: 0.082, blue: 0.078, alpha: 1)
    )

    static let hairline = dynamic(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.07),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.09)
    )

    static var canvasGradient: LinearGradient {
        LinearGradient(colors: [Color(nsColor: canvasTop), Color(nsColor: canvasBottom)],
                       startPoint: .top, endPoint: .bottom)
    }

    // Machined aluminium, midnight finish.
    static let shellLight = Color(red: 0.271, green: 0.290, blue: 0.318)
    static let shellDark = Color(red: 0.129, green: 0.145, blue: 0.169)
    static let shellEdge = Color(red: 0.408, green: 0.435, blue: 0.475)
    static let shellBase = Color(red: 0.196, green: 0.212, blue: 0.239)

    static let screenOnTop = Color(red: 0.325, green: 0.647, blue: 1.0)
    static let screenOnBottom = Color(red: 0.114, green: 0.435, blue: 0.878)
    static let screenOffTop = Color(red: 0.180, green: 0.192, blue: 0.212)
    static let screenOffBottom = Color(red: 0.106, green: 0.114, blue: 0.129)

    static let glow = Color(red: 0.325, green: 0.647, blue: 1.0)
    static let liveDot = Color(red: 0.243, green: 0.741, blue: 0.416)
}
