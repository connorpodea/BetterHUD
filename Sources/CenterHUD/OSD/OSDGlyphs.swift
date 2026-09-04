import AppKit

/// The three glyphs the HUD can show.
enum OSDGlyph: CaseIterable {
    case volume
    case mute
    case brightness

    /// The filename macOS uses for this glyph in OSDUIHelper's resources.
    fileprivate var systemAssetName: String {
        switch self {
        case .volume: "Volume"
        case .mute: "Mute"
        case .brightness: "Brightness"
        }
    }

    /// Used only if the system artwork can't be found.
    fileprivate var fallbackSymbolName: String {
        switch self {
        case .volume: "speaker.wave.3.fill"
        case .mute: "speaker.slash.fill"
        case .brightness: "sun.max.fill"
        }
    }
}

/// Supplies the HUD artwork.
///
/// macOS still ships the original OSD glyphs as PDFs inside OSDUIHelper.app, so
/// the HUD draws those exact files instead of an SF Symbol lookalike. They are
/// read from the system at runtime and never copied into this bundle, so none
/// of Apple's artwork is redistributed. If a future macOS stops shipping them,
/// each glyph degrades to the closest SF Symbol.
///
/// Images are vector PDFs loaded once and cached, so showing the HUD costs no
/// file I/O.
@MainActor
final class OSDGlyphProvider {
    /// Apple draws these on a 170pt canvas whose lower third is left empty for
    /// the level bar.
    static let canvasSize: CGFloat = 170

    private static let resourcesPath =
        "/System/Library/CoreServices/OSDUIHelper.app/Contents/Resources"

    private var cache: [OSDGlyph: NSImage] = [:]

    func image(for glyph: OSDGlyph) -> NSImage? {
        if let cached = cache[glyph] { return cached }

        let image = systemImage(for: glyph) ?? fallbackImage(for: glyph)
        // Template rendering lets the panel tint the artwork white.
        image?.isTemplate = true
        image?.size = NSSize(width: Self.canvasSize, height: Self.canvasSize)
        cache[glyph] = image
        return image
    }

    private func systemImage(for glyph: OSDGlyph) -> NSImage? {
        let path = "\(Self.resourcesPath)/\(glyph.systemAssetName).pdf"
        return NSImage(contentsOfFile: path)
    }

    private func fallbackImage(for glyph: OSDGlyph) -> NSImage? {
        NSImage(systemSymbolName: glyph.fallbackSymbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(
                NSImage.SymbolConfiguration(pointSize: 96, weight: .regular)
            )
    }
}
