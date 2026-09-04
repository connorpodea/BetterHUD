#!/usr/bin/env swift
//
// Generates the app icon: the wordmark "HUD" over the same 16-cell level bar
// the app draws on screen.
//
// The artwork is drawn in code rather than checked in as an opaque binary, so
// it can be adjusted and regenerated. The menu bar uses an SF Symbol instead:
// Apple's glyphs are built for that size and custom artwork looked muddy at
// 18pt.
//
// Usage: swift Scripts/make-icons.swift

import AppKit

// MARK: - Drawing helpers

/// Draws `text` scaled so it spans exactly `fittingWidth`, centered on
/// `centerX`, sitting on `baselineY`.
func drawWordmark(
    _ text: String,
    fittingWidth: CGFloat,
    centerX: CGFloat,
    baselineY: CGFloat,
    color: NSColor
) {
    // Measure at an arbitrary size, then scale to the width we want, so the
    // wordmark always lines up with the bar beneath it.
    let probeSize: CGFloat = 100
    let probeFont = NSFont.systemFont(ofSize: probeSize, weight: .bold)
    let probeWidth = (text as NSString).size(withAttributes: [.font: probeFont]).width
    let fontSize = probeSize * fittingWidth / probeWidth

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
        .foregroundColor: color,
    ]
    let size = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(
        at: NSPoint(x: centerX - size.width / 2, y: baselineY),
        withAttributes: attributes
    )
}

/// Draws the 16-cell level bar: square cells with hairline separators, matching
/// the HUD itself.
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

    // Dark backing, echoing the HUD panel the app draws.
    let gradient = NSGradient(
        colors: [
            NSColor(calibratedWhite: 0.24, alpha: 1),
            NSColor(calibratedWhite: 0.10, alpha: 1),
        ]
    )
    shape.addClip()
    gradient?.draw(in: body, angle: -90)

    let barWidth: CGFloat = 524
    drawWordmark(
        "HUD",
        fittingWidth: barWidth * scale,
        centerX: 512 * scale,
        baselineY: 420 * scale,
        color: .white
    )
    drawLevelBar(
        in: NSRect(x: 250 * scale, y: 320 * scale, width: barWidth * scale, height: 46 * scale),
        filled: 11,
        color: .white
    )

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

print("wrote \(iconset)")
