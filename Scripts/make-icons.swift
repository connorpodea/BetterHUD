#!/usr/bin/env swift
//
// Generates the app icon and the menu bar icon: the wordmark "Better" set over
// "HUD".
//
// The artwork is drawn in code rather than checked in as an opaque binary, so
// it can be adjusted and regenerated. The menu bar uses a smaller version of
// the same wordmark and bar.
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
    weight: NSFont.Weight = .bold,
    color: NSColor
) {
    // Measure at an arbitrary size, then scale to the width we want, so the
    // wordmark always lines up with the bar beneath it.
    let probeSize: CGFloat = 100
    let probeFont = NSFont.systemFont(ofSize: probeSize, weight: weight)
    let probeWidth = (text as NSString).size(withAttributes: [.font: probeFont]).width
    let fontSize = probeSize * fittingWidth / probeWidth

    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: weight),
        .foregroundColor: color,
    ]
    let size = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(
        at: NSPoint(x: centerX - size.width / 2, y: baselineY),
        withAttributes: attributes
    )
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

    drawWordmark(
        "Better",
        fittingWidth: 400 * scale,
        centerX: 512 * scale,
        baselineY: 560 * scale,
        weight: .semibold,
        color: .white
    )
    drawWordmark(
        "HUD",
        fittingWidth: 560 * scale,
        centerX: 512 * scale,
        baselineY: 340 * scale,
        color: .white
    )

    return image
}

// MARK: - Menu bar icon

/// The same wordmark, sized for the menu bar.
///
/// A template image — black with alpha — so macOS tints it for light, dark, and
/// highlighted menu bars. Laid out bottom-up from the height: cap height runs
/// about 0.7 of the font size, and each font size follows from the width it has
/// to fill, so the two lines never collide.
func makeMenuBarIcon(pointSize: CGFloat) -> NSImage {
    let unit = pointSize / 18
    let width = 30 * unit

    let image = NSImage(size: NSSize(width: width, height: pointSize))
    image.lockFocus()
    let centerX = width / 2

    drawWordmark("HUD", fittingWidth: 21 * unit, centerX: centerX,
                 baselineY: 2.5 * unit, color: .black)
    drawWordmark("Better", fittingWidth: 17 * unit, centerX: centerX,
                 baselineY: 11 * unit, weight: .semibold, color: .black)

    image.unlockFocus()
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

// 1x and 2x renderings; NSImage picks the right one per display.
writePNG(makeMenuBarIcon(pointSize: 18), to: "Resources/MenuBarIcon.png")
writePNG(makeMenuBarIcon(pointSize: 36), to: "Resources/MenuBarIcon@2x.png")

print("wrote \(iconset) and menu bar icons")
