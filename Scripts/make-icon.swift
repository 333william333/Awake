#!/usr/bin/env swift
//
// Draws Resources/AppIcon.icns from vectors — same MacBook, same paper
// background as the window. No image assets live in this repository.
//
// Usage: swift Scripts/make-icon.swift [output.icns]
//

import AppKit

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : FileManager.default.currentDirectoryPath + "/Resources/AppIcon.icns"

// MARK: - Palette

func srgb(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
    CGColor(srgbRed: r, green: g, blue: b, alpha: a)
}

let paperTop = srgb(0.992, 0.984, 0.968)
let paperBottom = srgb(0.933, 0.910, 0.867)
let shellLight = srgb(0.271, 0.290, 0.318)
let shellDark = srgb(0.129, 0.145, 0.169)
let shellEdge = srgb(0.408, 0.435, 0.475)
let shellBase = srgb(0.196, 0.212, 0.239)
let screenTop = srgb(0.325, 0.647, 1.0)
let screenBottom = srgb(0.114, 0.435, 0.878)

func gradient(_ colors: [CGColor], _ locations: [CGFloat] = [0, 1]) -> CGGradient {
    CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
               colors: colors as CFArray,
               locations: locations)!
}

// MARK: - Drawing

/// `side` is the pixel size of the square canvas; every measurement below is
/// expressed against a 1024 reference grid.
func drawIcon(in context: CGContext, side: CGFloat) {
    let unit = side / 1024
    context.translateBy(x: 0, y: side)
    context.scaleBy(x: 1, y: -1) // y grows downwards, like the app's Canvas

    // Rounded plate.
    let plate = CGRect(x: 100 * unit, y: 84 * unit, width: 824 * unit, height: 824 * unit)
    let platePath = CGPath(roundedRect: plate, cornerWidth: 185 * unit, cornerHeight: 185 * unit, transform: nil)

    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: -22 * unit),
                      blur: 40 * unit,
                      color: srgb(0, 0, 0, 0.28))
    context.addPath(platePath)
    context.setFillColor(paperTop)
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(platePath)
    context.clip()
    context.drawLinearGradient(gradient([paperTop, paperBottom]),
                               start: CGPoint(x: 0, y: plate.minY),
                               end: CGPoint(x: 0, y: plate.maxY),
                               options: [])

    // Glow behind the machine.
    context.drawRadialGradient(
        gradient([srgb(0.325, 0.647, 1.0, 0.30), srgb(0.325, 0.647, 1.0, 0)]),
        startCenter: CGPoint(x: side / 2, y: 470 * unit), startRadius: 20 * unit,
        endCenter: CGPoint(x: side / 2, y: 470 * unit), endRadius: 330 * unit,
        options: [])
    context.restoreGState()

    // Inner light along the top edge.
    context.saveGState()
    context.addPath(platePath)
    context.clip()
    context.setStrokeColor(srgb(1, 1, 1, 0.75))
    context.setLineWidth(3 * unit)
    context.addPath(platePath)
    context.strokePath()
    context.restoreGState()

    drawMacBook(in: context, unit: unit, centreX: side / 2, top: 348 * unit, width: 540 * unit)
}

func drawMacBook(in context: CGContext, unit: CGFloat, centreX: CGFloat, top: CGFloat, width: CGFloat) {
    let lidWidth = width * 0.755
    let lidHeight = lidWidth * 0.652 // the window's glyph, to the pixel
    let lidRect = CGRect(x: centreX - lidWidth / 2, y: top, width: lidWidth, height: lidHeight)
    let corner = lidWidth * 0.055

    // Contact shadow.
    context.saveGState()
    context.drawRadialGradient(
        gradient([srgb(0, 0, 0, 0.22), srgb(0, 0, 0, 0)]),
        startCenter: CGPoint(x: centreX, y: lidRect.maxY + width * 0.075), startRadius: 2 * unit,
        endCenter: CGPoint(x: centreX, y: lidRect.maxY + width * 0.075), endRadius: width * 0.46,
        options: [])
    context.restoreGState()

    // Lid.
    let lid = CGPath(roundedRect: lidRect, cornerWidth: corner, cornerHeight: corner, transform: nil)
    context.saveGState()
    context.addPath(lid)
    context.clip()
    context.drawLinearGradient(gradient([shellLight, shellDark]),
                               start: CGPoint(x: 0, y: lidRect.minY),
                               end: CGPoint(x: 0, y: lidRect.maxY),
                               options: [])
    context.restoreGState()
    context.addPath(lid)
    context.setStrokeColor(shellEdge)
    context.setLineWidth(2.6 * unit)
    context.strokePath()

    // Display.
    let bezel = lidWidth * 0.042
    let screenRect = lidRect.insetBy(dx: bezel, dy: bezel)
    let screen = CGPath(roundedRect: screenRect,
                        cornerWidth: corner * 0.62, cornerHeight: corner * 0.62, transform: nil)
    context.saveGState()
    context.addPath(screen)
    context.clip()
    context.drawLinearGradient(gradient([screenTop, screenBottom]),
                               start: CGPoint(x: screenRect.minX, y: screenRect.minY),
                               end: CGPoint(x: screenRect.maxX, y: screenRect.maxY),
                               options: [])

    // Sheen.
    let sheen = CGMutablePath()
    sheen.move(to: CGPoint(x: screenRect.minX, y: screenRect.minY))
    sheen.addLine(to: CGPoint(x: screenRect.maxX, y: screenRect.minY))
    sheen.addLine(to: CGPoint(x: screenRect.maxX, y: screenRect.minY + screenRect.height * 0.34))
    sheen.addLine(to: CGPoint(x: screenRect.minX, y: screenRect.minY + screenRect.height * 0.52))
    sheen.closeSubpath()
    context.addPath(sheen)
    context.clip()
    context.drawLinearGradient(gradient([srgb(1, 1, 1, 0.22), srgb(1, 1, 1, 0)]),
                               start: CGPoint(x: screenRect.minX, y: screenRect.minY),
                               end: CGPoint(x: screenRect.minX, y: screenRect.maxY),
                               options: [])
    context.restoreGState()

    // Camera housing.
    let notchWidth = lidWidth * 0.155
    let notch = CGPath(roundedRect: CGRect(x: centreX - notchWidth / 2,
                                           y: lidRect.minY + bezel - unit,
                                           width: notchWidth, height: bezel * 0.9),
                       cornerWidth: bezel * 0.35, cornerHeight: bezel * 0.35, transform: nil)
    context.addPath(notch)
    context.setFillColor(shellDark)
    context.fillPath()

    // Base.
    let baseTop = lidRect.maxY + 2 * unit
    let baseBottom = baseTop + width * 0.055
    let half = width / 2
    let base = CGMutablePath()
    base.move(to: CGPoint(x: lidRect.minX - 2 * unit, y: baseTop))
    base.addLine(to: CGPoint(x: lidRect.maxX + 2 * unit, y: baseTop))
    base.addLine(to: CGPoint(x: centreX + half, y: baseBottom - width * 0.022))
    base.addQuadCurve(to: CGPoint(x: centreX + half - width * 0.03, y: baseBottom),
                      control: CGPoint(x: centreX + half, y: baseBottom))
    base.addLine(to: CGPoint(x: centreX - half + width * 0.03, y: baseBottom))
    base.addQuadCurve(to: CGPoint(x: centreX - half, y: baseBottom - width * 0.022),
                      control: CGPoint(x: centreX - half, y: baseBottom))
    base.closeSubpath()

    context.saveGState()
    context.addPath(base)
    context.clip()
    context.drawLinearGradient(gradient([shellEdge, shellBase]),
                               start: CGPoint(x: 0, y: baseTop),
                               end: CGPoint(x: 0, y: baseBottom),
                               options: [])
    context.restoreGState()

    // Finger recess.
    let recessWidth = width * 0.17
    let recessHeight = width * 0.016
    let recess = CGPath(roundedRect: CGRect(x: centreX - recessWidth / 2,
                                            y: baseBottom - recessHeight,
                                            width: recessWidth, height: recessHeight),
                        cornerWidth: recessHeight / 2, cornerHeight: recessHeight / 2, transform: nil)
    context.addPath(recess)
    context.setFillColor(shellDark)
    context.fillPath()
}

// MARK: - Output

func renderPNG(side: Int) -> Data {
    let representation = NSBitmapImageRep(bitmapDataPlanes: nil,
                                          pixelsWide: side, pixelsHigh: side,
                                          bitsPerSample: 8, samplesPerPixel: 4,
                                          hasAlpha: true, isPlanar: false,
                                          colorSpaceName: .deviceRGB,
                                          bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let graphics = NSGraphicsContext(bitmapImageRep: representation)!
    NSGraphicsContext.current = graphics
    graphics.cgContext.setAllowsAntialiasing(true)
    drawIcon(in: graphics.cgContext, side: CGFloat(side))
    NSGraphicsContext.restoreGraphicsState()
    return representation.representation(using: .png, properties: [:])!
}

let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory())
    .appendingPathComponent("Awake-\(UUID().uuidString).iconset")
try? FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let variants: [(name: String, side: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]

for variant in variants {
    try! renderPNG(side: variant.side).write(to: iconsetURL.appendingPathComponent(variant.name))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", outputPath]
try! iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconsetURL)

guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write(Data("iconutil failed\n".utf8))
    exit(1)
}
print("Wrote \(outputPath)")
