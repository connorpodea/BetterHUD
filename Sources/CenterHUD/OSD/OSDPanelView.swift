import AppKit

/// The contents of the HUD: Apple's OSD glyph over a 16-segment level bar, on a
/// translucent rounded square — the design macOS 26 replaced.
///
/// Geometry follows Apple's shipped artwork: the glyph PDFs are drawn on a
/// 170pt canvas whose lower third is empty, and the level bar sits in that gap.
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
        /// Cells are square; only the bar's outer ends are rounded, which the
        /// container's corner radius takes care of by clipping.
        static let segmentCornerRadius: CGFloat = 0
        static let barCornerRadius: CGFloat = 2.5
        static let barBottomInset: CGFloat = 34

        static var barWidth: CGFloat {
            CGFloat(segmentCount) * segmentWidth + CGFloat(segmentCount - 1) * segmentGap
        }
    }

    private let backdrop = NSVisualEffectView()
    private let iconView = NSImageView()
    /// The segments live in their own subview rather than in this view's layer:
    /// a view's own sublayers draw *behind* its subviews, so segments added to
    /// `self.layer` would be hidden underneath the backdrop.
    private let levelBarView = NSView()
    private var segments: [CALayer] = []

    /// Tracks the last rendered fill count so a repeated key press that lands
    /// on the same step touches no layers at all.
    private var filledSegmentCount = -1

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: frameRect.origin, size: Self.size))
        wantsLayer = true
        setUpBackdrop()
        setUpIcon()
        setUpLevelBar()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    // MARK: - Content

    /// Updates the glyph and bar in place. The panel is built once and reused,
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
                ? NSColor.white.cgColor
                : NSColor.white.withAlphaComponent(0.25).cgColor
        }
        CATransaction.commit()
    }

    // MARK: - Setup

    private func setUpBackdrop() {
        backdrop.material = .hudWindow
        backdrop.blendingMode = .behindWindow
        backdrop.state = .active
        backdrop.wantsLayer = true
        backdrop.layer?.cornerRadius = Metrics.cornerRadius
        backdrop.layer?.cornerCurve = .continuous
        backdrop.layer?.masksToBounds = true
        backdrop.frame = bounds
        backdrop.autoresizingMask = [.width, .height]
        addSubview(backdrop)
    }

    private func setUpIcon() {
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.contentTintColor = .white
        iconView.frame = NSRect(
            x: Metrics.canvasInset,
            y: Metrics.canvasInset,
            width: OSDGlyphProvider.canvasSize,
            height: OSDGlyphProvider.canvasSize
        )
        addSubview(iconView)
    }

    private func setUpLevelBar() {
        levelBarView.wantsLayer = true
        // Clipping rounds the bar's outer ends while leaving the interior cell
        // edges square.
        levelBarView.layer?.cornerRadius = Metrics.barCornerRadius
        levelBarView.layer?.masksToBounds = true
        levelBarView.frame = NSRect(
            x: (Self.size.width - Metrics.barWidth) / 2,
            y: Metrics.barBottomInset,
            width: Metrics.barWidth,
            height: Metrics.segmentHeight
        )
        addSubview(levelBarView)

        segments = (0..<Metrics.segmentCount).map { index in
            let segment = CALayer()
            segment.frame = CGRect(
                x: CGFloat(index) * (Metrics.segmentWidth + Metrics.segmentGap),
                y: 0,
                width: Metrics.segmentWidth,
                height: Metrics.segmentHeight
            )
            segment.cornerRadius = Metrics.segmentCornerRadius
            segment.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
            levelBarView.layer?.addSublayer(segment)
            return segment
        }
    }
}
