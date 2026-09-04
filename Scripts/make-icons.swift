#!/usr/bin/env swift
//
// Generates the app icon and the menu bar icon.
//
// The artwork is drawn in code rather than checked in as opaque binaries, so
// it can be tweaked and regenerated. Everything here is original: Apple's OSD
// PDFs are used at runtime for the HUD itself, but they are not redistributed,
// so the icon draws its own speaker glyph.
//
// Usage: swift Scripts/make-icons.swift

import AppKit

// MARK: - Drawing helpers

/// Draws a speaker with waves, sized to fit `rect`.
func drawSpeaker(in rect: NSRect, color: NSColor) {
    color.setFill()
    color.setStroke()

    let unit = rect.width / 100
    func x(_ v: CGFloat) -> CGFloat { rect.minX + v * unit }
    func y(_ v: CGFloat) -> CGFloat { rect.minY + v * unit }

    // Body: a rectangle for the driver plus a triangular cone.
    let body = NSBezierPath()
    body.move(to: NSPoint(x: x(4), y: y(38)))
    body.line(to: NSPoint(x: x(20), y: y(38)))
    body.line(to: NSPoint(x: x(40), y: y(16)))
    body.line(to: NSPoint(x: x(40), y: y(84)))
    body.line(to: NSPoint(x: x(20), y: y(62)))
    body.line(to: NSPoint(x: x(4), y: y(62)))
    body.close()
    body.fill()

    // Three concentric waves.
    for (index, radius) in [22.0, 36.0, 50.0].enumerated() {
        let wave = NSBezierPath()
        let lineWidth = 7.0 - Double(index) * 0.5
        wave.appendArc(
            withCenter: NSPoint(x: x(44), y: y(50)),
            radius: radius * unit,
            startAngle: -42,
            endAngle: 42
        )
        wave.lineWidth = lineWidth * unit
        wave.lineCapStyle = .round
        wave.stroke()
    }
}

/// Draws the 16-cell level bar: square cells, hairline separators, matching the
/// HUD itself.
func drawLevelBar(in rect: NSRect, filled: Int, color: NSColor) {
    let count = 16
    let gap = rect.width * 0.006
    let cellWidth = (rect.width - gap * CGFloat(count - 1)) / CGFloat(count)

    for index in 0..<count {
        let cell = NSRect(
            x: rect.minX + CGFloat(index) * (cellWidth + gap),
            y: rect.minY,
            width: cellWidth,
            height: rect.height
        )
        (index < filled ? color : color.withAlphaComponent(0.25)).setFill()
        cell.fill()
    }
}

// MARK: - App icon

/// One 1024pt master; every other size is produced by scaling it.
func makeAppIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let scale = size / 1024

    // macOS icons sit inset within the canvas with a rounded-rect body.
    let body = NSRect(x: 100 * scale, y: 100 * scale, width: 824 * scale, height: 824 * scale)
    let shape = NSBezierPath(roundedRect: body, xRadius: 185 * scale, yRadius: 185 * scale)

    // Dark HUD-like backing, echoing the panel the app draws.
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedWhite: 0.24, alpha: 1),
            NSColor(calibratedWhite: 0.10, alpha: 1),
        ]
    )
    shape.addClip()
    gradient?.draw(in: body, angle: -90)

    // A soft top highlight, so it doesn't read as flat.
    NSColor(calibratedWhite: 1, alpha: 0.10).setFill()
    NSBezierPath(
        roundedRect: body.insetBy(dx: 8 * scale, dy: 8 * scale),
        xRadius: 177 * scale,
        yRadius: 177 * scale
    ).fill()
    gradient?.draw(in: body.insetBy(dx: 10 * scale, dy: 10 * scale), angle: -90)

    drawSpeaker(
        in: NSRect(x: 300 * scale, y: 420 * scale, width: 424 * scale, height: 340 * scale),
        color: .white
    )
    drawLevelBar(
        in: NSRect(x: 250 * scale, y: 300 * scale, width: 524 * scale, height: 46 * scale),
        filled: 11,
        color: .white
    )

    return image
}

// MARK: - Menu bar icon

/// A template image: monochrome with alpha, so macOS tints it for light, dark,
/// and highlighted menu bars automatically.
func makeMenuBarIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let scale = size / 36
    let black = NSColor.black

    // A rounded square standing for the HUD panel.
    let panel = NSRect(x: 3 * scale, y: 5 * scale, width: 30 * scale, height: 26 * scale)
    let outline = NSBezierPath(roundedRect: panel, xRadius: 6 * scale, yRadius: 6 * scale)
    outline.lineWidth = 2.4 * scale
    black.setStroke()
    outline.stroke()

    // Cells inside it, partly filled — the app's defining detail at a glance.
    drawLevelBar(
        in: NSRect(x: 8 * scale, y: 11 * scale, width: 20 * scale, height: 6 * scale),
        filled: 3,
        color: black
    )

    image.unlockFocus()
    image.lockFocus()
    image.isTemplate = true
    return image
}

// MARK: - Output

func writePNG(_ image: NSImage, to path: String) {
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else {
        fatalError("could not encode \(path)")
    }
    try! png.write(to: URL(fileURLWithPath: path))
}

let fileManager = FileManager.default
let iconset = "Resources/AppIcon.iconset"
try? fileManager.removeItem(atPath: iconset)
try! fileManager.createDirectory(atPath: iconset, withIntermediateDirectories: true)

// The sizes iconutil expects for a complete .icns.
for (size, name) in [
    (16, "icon_16x16"), (32, "icon_16x16@2x"),
    (32, "icon_32x32"), (64, "icon_32x32@2x"),
    (128, "icon_128x128"), (256, "icon_128x128@2x"),
    (256, "icon_256x256"), (512, "icon_256x256@2x"),
    (512, "icon_512x512"), (1024, "icon_512x512@2x"),
] {
    writePNG(makeAppIcon(size: CGFloat(size)), to: "\(iconset)/\(name).png")
}

writePNG(makeMenuBarIcon(size: 18), to: "Resources/MenuBarIcon.png")
writePNG(makeMenuBarIcon(size: 36), to: "Resources/MenuBarIcon@2x.png")

print("wrote \(iconset) and menu bar icons")
