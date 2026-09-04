import AppKit

/// The contents of the HUD: an OSD glyph over a 16 segment level bar, on a
/// rounded panel.
///
/// Geometry follows the artwork that ships with macOS: the glyph PDFs are drawn
/// on a 170pt canvas whose lower third is empty, and the level bar sits in that
/// gap.
final class OSDPanelView: NSView {
    static let size = NSSize(width: 200, height: 200)

    private enum Metrics {
        static let cornerRadius: CGFloat = 18
        /// Inset of the glyph canvas within the panel.
        static let canvasInset: CGFloat = 15
        static let segmentCount = 16
        static let segmentWidth: CGFloat = 8
        static let segmentHeight: CGFloat = 8
        /// A hairline gap, so the cells read as one divided bar rather than a
        /// row of floating pills. The gap shows the backdrop through as a
        /// separator line.
        static let segmentGap: CGFloat = 1
        static let barBottomInset: CGFloat = 34

        static var barWidth: CGFloat {
            CGFloat(segmentCount) * segmentWidth + CGFloat(segmentCount - 1) * segmentGap
        }
    }

    /// Holds the glyph and the bar. Kept separate from the background so it can
    /// be handed to whichever backdrop the current style uses. For Liquid
    /// Glass that matters: `NSGlassEffectView` only guarantees the effect for
    /// its `contentView`, and gives no defined z-order to sibling subviews.
    private let content = NSView()
    private let iconView = NSImageView()
    /// The segments live in their own view rather than in a layer of `content`:
    /// a view's own sublayers draw behind its subviews.
    private let levelBarView = NSView()
    private var segments: [CALayer] = []

    private var backdrop: NSView?
    private var appliedStyle: Settings.Style?

    /// Tracks the last rendered fill count, so a repeated key press landing on
    /// the same step touches no layers at all.
    private var filledSegmentCount = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: frameRect.origin, size: Self.size))
        wantsLayer = true

        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        setUpIcon()
        setUpLevelBar()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Content

    /// Updates the glyph and bar in place. The views are built once and reused,
    /// so showing the HUD allocates nothing.
    func update(icon: NSImage?, level: Float) {
        if iconView.image !== icon { iconView.image = icon }

        let clamped = min(max(level, 0), 1)
        let filled = Int((clamped * Float(Metrics.segmentCount)).rounded())
        guard filled != filledSegmentCount else { return }
        filledSegmentCount = filled

        // Segment fill must not animate: successive presses should snap, the
        // way the native HUD does.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for (index, segment) in segments.enumerated() {
            segment.backgroundColor = index < filled
                ? tint.cgColor
                : tint.withAlphaComponent(0.25).cgColor
        }
        CATransaction.commit()
    }

    /// Installs the background for `style`, replacing whatever was there. Does
    /// nothing when the style hasn't changed, so showing the HUD stays free of
    /// view work.
    func apply(style: Settings.Style) {
        guard appliedStyle != style else { return }
        appliedStyle = style

        backdrop?.removeFromSuperview()
        content.removeFromSuperview()

        if style == .liquidGlass, #available(macOS 26.0, *) {
            let glass = NSGlassEffectView()
            glass.cornerRadius = Metrics.cornerRadius
            glass.frame = bounds
            glass.autoresizingMask = [.width, .height]
            // The glyph and bar have to be the glass view's content to sit
            // inside the effect.
            glass.contentView = content
            addSubview(glass)
            backdrop = glass
        } else {
            let effect = NSVisualEffectView()
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .active
            effect.wantsLayer = true
            effect.layer?.cornerRadius = Metrics.cornerRadius
            effect.layer?.cornerCurve = .continuous
            effect.layer?.masksToBounds = true
            effect.frame = bounds
            effect.autoresizingMask = [.width, .height]
            addSubview(effect)
            addSubview(content)
            backdrop = effect
        }

        content.frame = bounds
        iconView.contentTintColor = tint
        // Force the segments to be recolored for the new tint.
        filledSegmentCount = -1
    }

    /// White on the dark classic panel; the dynamic label color on glass, which
    /// is light in light appearance and would swallow white.
    private var tint: NSColor {
        appliedStyle == .liquidGlass ? .labelColor : .white
    }

    // MARK: - Setup

    private func setUpIcon() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = tint
        iconView.frame = NSRect(
            x: Metrics.canvasInset,
            y: Metrics.canvasInset,
            width: OSDGlyphProvider.canvasSize,
            height: OSDGlyphProvider.canvasSize
        )
        content.addSubview(iconView)
    }

    private func setUpLevelBar() {
        levelBarView.wantsLayer = true
        levelBarView.frame = NSRect(
            x: (Self.size.width - Metrics.barWidth) / 2,
            y: Metrics.barBottomInset,
            width: Metrics.barWidth,
            height: Metrics.segmentHeight
        )
        content.addSubview(levelBarView)

        segments = (0..<Metrics.segmentCount).map { index in
            let segment = CALayer()
            segment.frame = CGRect(
                x: CGFloat(index) * (Metrics.segmentWidth + Metrics.segmentGap),
                y: 0,
                width: Metrics.segmentWidth,
                height: Metrics.segmentHeight
            )
            segment.backgroundColor = tint.withAlphaComponent(0.25).cgColor
            levelBarView.layer?.addSublayer(segment)
            return segment
        }
    }
}
