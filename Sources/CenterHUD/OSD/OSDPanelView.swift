import AppKit

/// The contents of the HUD: a large glyph over a level bar, on a translucent
/// rounded square — the pre-macOS-26 design this app restores.
final class OSDPanelView: NSView {
    static let size = NSSize(width: 200, height: 200)

    private enum Metrics {
        static let cornerRadius: CGFloat = 18
        static let iconSize: CGFloat = 88
        static let iconCenterY: CGFloat = 118
        static let barWidth: CGFloat = 152
        static let barHeight: CGFloat = 8
        static let barBottomInset: CGFloat = 34
    }

    private let backdrop = NSVisualEffectView()
    private let iconView = NSImageView()
    private let barTrack = CALayer()
    private let barFill = CALayer()

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
    /// so showing the HUD never allocates views.
    func update(icon: NSImage?, level: Float) {
        iconView.image = icon
        let clamped = CGFloat(min(max(level, 0), 1))

        // Geometry changes must not animate: successive key presses should snap
        // to the new level the way the native HUD does.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        barFill.frame = CGRect(
            x: 0, y: 0,
            width: Metrics.barWidth * clamped,
            height: Metrics.barHeight
        )
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
            x: (Self.size.width - Metrics.iconSize) / 2,
            y: Metrics.iconCenterY - Metrics.iconSize / 2,
            width: Metrics.iconSize,
            height: Metrics.iconSize
        )
        addSubview(iconView)
    }

    private func setUpLevelBar() {
        let barFrame = CGRect(
            x: (Self.size.width - Metrics.barWidth) / 2,
            y: Metrics.barBottomInset,
            width: Metrics.barWidth,
            height: Metrics.barHeight
        )

        barTrack.frame = barFrame
        barTrack.backgroundColor = NSColor.white.withAlphaComponent(0.25).cgColor
        barTrack.cornerRadius = Metrics.barHeight / 2
        barTrack.masksToBounds = true

        barFill.frame = CGRect(x: 0, y: 0, width: 0, height: Metrics.barHeight)
        barFill.backgroundColor = NSColor.white.cgColor
        barFill.cornerRadius = Metrics.barHeight / 2
        barFill.anchorPoint = .zero
        barTrack.addSublayer(barFill)

        layer?.addSublayer(barTrack)
    }
}
