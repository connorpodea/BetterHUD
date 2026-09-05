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

        guard let artwork = systemImage(for: glyph) ?? fallbackImage(for: glyph) else {
            return nil
        }
        artwork.size = NSSize(width: Self.canvasSize, height: Self.canvasSize)

        let white = Self.whitened(artwork)
        cache[glyph] = white
        return white
    }

    /// Bakes white into the artwork instead of leaving it as a template image
    /// for the view to tint.
    ///
    /// A template image is black pixels plus alpha, and AppKit applies the tint
    /// when drawing. If a frame is composited before that happens, which is
    /// most likely on the first frame while the window fades in, the glyph
    /// draws black on a dark panel and looks like it disappeared. Pre-tinting
    /// removes that possibility, and saves a tint pass on every draw.
    private static func whitened(_ artwork: NSImage) -> NSImage {
        let size = artwork.size
        let image = NSImage(size: size)
        image.lockFocus()
        artwork.draw(in: NSRect(origin: .zero, size: size))
        NSColor.white.set()
        NSRect(origin: .zero, size: size).fill(using: .sourceAtop)
        image.unlockFocus()
        image.isTemplate = false
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
