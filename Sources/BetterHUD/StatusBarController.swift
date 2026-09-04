import AppKit

/// The menu bar item, which is both the app's status display and its entire
/// settings UI.
///
/// Everything lives here rather than in a settings window: each preference is a
/// short list of choices, so the menu lays them out as flat labelled sections
/// with checkmarks — every option visible at a glance, nothing to place, size,
/// or manage.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let settings: Settings
    /// Queried when the menu opens, so the status line is always current.
    private let isInterceptingKeys: () -> Bool

    private let statusItem: NSStatusItem
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let headerView = MenuHeaderView()
    private let launchAtLoginItem = NSMenuItem(title: "Open at Login", action: nil, keyEquivalent: "")

    private var placementItems: [NSMenuItem] = []
    private var durationItems: [NSMenuItem] = []
    private var feedbackItems: [NSMenuItem] = []
    private let volumeKeysItem = NSMenuItem(title: "Volume and Mute", action: nil, keyEquivalent: "")
    private let brightnessKeysItem = NSMenuItem(title: "Brightness", action: nil, keyEquivalent: "")

    init(settings: Settings, isInterceptingKeys: @escaping () -> Bool) {
        self.settings = settings
        self.isInterceptingKeys = isInterceptingKeys
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        // Drawn as text rather than as an image: it stays crisp at any scale
        // factor, and `labelColor` is dynamic, so it tracks light, dark, and
        // highlighted menu bars.
        button.attributedTitle = NSAttributedString(
            string: "HUD",
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .bold),
                .foregroundColor: NSColor.labelColor,
            ]
        )
        button.setAccessibilityLabel("BetterHUD")
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self
        // Items keep whatever `isEnabled` they're given. Without this, AppKit
        // disables anything with no action and draws it dimmed, which would
        // gray out the title.
        menu.autoenablesItems = false

        // A view, not a title: a menu item can only draw its image on the
        // leading side, and the app icon belongs on the trailing side of the
        // header.
        statusLine.isEnabled = true
        statusLine.view = headerView
        menu.addItem(statusLine)

        // One selectable option per section, except Take Over, where any
        // combination is valid.
        addSection(to: menu, titled: "Position")
        placementItems = Settings.Placement.allCases.enumerated().map { index, placement in
            item(title: placement.title, tag: index, action: #selector(changePlacement(_:)))
        }
        placementItems.forEach(menu.addItem)

        addSection(to: menu, titled: "Show For")
        durationItems = Settings.durationChoices.enumerated().map { index, duration in
            item(
                title: String(format: "%.1f seconds", duration),
                tag: index,
                action: #selector(changeDuration(_:))
            )
        }
        durationItems.forEach(menu.addItem)

        addSection(to: menu, titled: "Take Over")
        for (item, action) in [
            (volumeKeysItem, #selector(toggleVolumeKeys)),
            (brightnessKeysItem, #selector(toggleBrightnessKeys)),
        ] {
            item.target = self
            item.action = action
            item.attributedTitle = Self.optionTitle(item.title)
            menu.addItem(item)
        }

        addSection(to: menu, titled: "Volume Click")
        feedbackItems = Settings.FeedbackMode.allCases.enumerated().map { index, mode in
            item(title: mode.menuTitle, tag: index, action: #selector(changeFeedbackMode(_:)))
        }
        feedbackItems.forEach(menu.addItem)

        addSection(to: menu, titled: "Startup")
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        launchAtLoginItem.attributedTitle = Self.optionTitle(launchAtLoginItem.title)
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        // Deliberately not `NSApplication.terminate(_:)`: macOS decorates that
        // standard action with a symbol, which shifts the title into a
        // different column from every other row.
        let quit = NSMenuItem(title: "Quit BetterHUD", action: #selector(quit), keyEquivalent: "q")
        quit.attributedTitle = Self.optionTitle(quit.title)
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// Refreshing when the menu opens keeps every checkmark honest without any
    /// observers running while nobody is looking.
    func menuWillOpen(_ menu: NSMenu) {
        headerView.update(
            status: isInterceptingKeys() ? "Replacing HUD" : "Needs Permission"
        )

        check(placementItems, at: Settings.Placement.allCases.firstIndex(of: settings.placement))
        check(durationItems, at: Settings.durationChoices.firstIndex(of: settings.visibleDuration))
        check(feedbackItems, at: Settings.FeedbackMode.allCases.firstIndex(of: settings.feedbackMode))

        volumeKeysItem.state = settings.handlesVolumeKeys ? .on : .off
        brightnessKeysItem.state = settings.handlesBrightnessKeys ? .on : .off
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    // MARK: - Menu building

    private func item(title: String, tag: Int, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.attributedTitle = Self.optionTitle(title)
        item.tag = tag
        item.target = self
        return item
    }

    /// Options are dimmer than the headings above them, so a section reads as
    /// a label followed by its choices.
    ///
    /// One tradeoff: an explicit color is kept even while a row is highlighted,
    /// where AppKit would normally switch the text to white.
    static func optionTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.menuFont(ofSize: 0),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
    }

    /// A divider plus a heading, so the groups read as groups.
    ///
    /// The heading is a view rather than a title, which is the only way to get
    /// all three of: full contrast, no hover highlight, and no click. A
    /// disabled title row is grayed out by AppKit, and an enabled one
    /// highlights and takes clicks. AppKit neither dims nor highlights a view
    /// it doesn't draw, so a disabled item with a view gets every part right.
    ///
    /// It also isn't `NSMenuItem.sectionHeader(title:)`, which carries Apple's
    /// styling but fixes the font size smaller than wanted here.
    private func addSection(to menu: NSMenu, titled title: String) {
        menu.addItem(.separator())

        let header = NSMenuItem()
        header.view = SectionHeaderView(title: title.uppercased())
        header.isEnabled = false
        menu.addItem(header)
    }

    /// Marks one item in a mutually exclusive group.
    ///
    /// Uses AppKit's own state column. Right aligning the checkmarks instead
    /// means a tab stop, and tab stops are measured inside the title's text
    /// area, which is narrower than the menu and inset from its left edge, so
    /// a stop near the menu's right edge overshoots and AppKit clamps it
    /// differently per row. Doing it properly would mean custom drawn rows and
    /// giving up the system's menu styling.
    private func check(_ items: [NSMenuItem], at index: Int?) {
        for (offset, item) in items.enumerated() {
            item.state = offset == index ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func changePlacement(_ sender: NSMenuItem) {
        settings.placement = Settings.Placement.allCases[sender.tag]
    }

    @objc private func changeDuration(_ sender: NSMenuItem) {
        settings.visibleDuration = Settings.durationChoices[sender.tag]
    }

    @objc private func changeFeedbackMode(_ sender: NSMenuItem) {
        settings.feedbackMode = Settings.FeedbackMode.allCases[sender.tag]
    }

    @objc private func toggleVolumeKeys() {
        settings.handlesVolumeKeys.toggle()
    }

    @objc private func toggleBrightnessKeys() {
        settings.handlesBrightnessKeys.toggle()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// The menu's header: the app name over its current state, with the app icon on
/// the trailing side.
///
/// Laid out by hand against `bounds`, because AppKit stretches a menu item's
/// view to the menu's width and the icon has to follow that edge.
@MainActor
private final class MenuHeaderView: NSView {
    private let titleLabel = NSTextField(labelWithString: "BetterHUD")
    private let statusLabel = NSTextField(labelWithString: "")
    private let iconView = NSImageView()

    private enum Metrics {
        /// Matches the inset AppKit gives a menu item's title, so the header
        /// lines up with the rows below it.
        static let leadingInset: CGFloat = 21
        static let trailingInset: CGFloat = 8
        static let verticalPadding: CGFloat = 7
        /// Space between the two lines of text.
        static let lineSpacing: CGFloat = 4
        /// Minimum space between the text and the icon.
        static let iconGap: CGFloat = 11
    }

    init() {
        super.init(frame: .zero)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .labelColor
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        // Placeholder text so the frame below is right from the start; a menu
        // item view with a zero frame draws nothing.
        statusLabel.stringValue = "Replacing HUD"

        iconView.image = NSApp.applicationIconImage
        iconView.imageScaling = .scaleProportionallyUpOrDown

        addSubview(titleLabel)
        addSubview(statusLabel)
        addSubview(iconView)
        autoresizingMask = [.width]
        frame = NSRect(origin: .zero, size: intrinsicContentSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    func update(status: String) {
        statusLabel.stringValue = status
        // Width is AppKit's to set; only the height is ours.
        setFrameSize(NSSize(width: frame.width, height: intrinsicContentSize.height))
        needsLayout = true
    }

    /// Width of the wider of the two lines.
    private var textWidth: CGFloat {
        max(titleLabel.fittingSize.width, statusLabel.fittingSize.width)
    }

    /// Height of both lines together.
    private var textHeight: CGFloat {
        titleLabel.fittingSize.height + Metrics.lineSpacing + statusLabel.fittingSize.height
    }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: Metrics.leadingInset + textWidth + Metrics.iconGap + textHeight
                + Metrics.verticalPadding,
            height: textHeight + Metrics.verticalPadding * 2
        )
    }

    override func layout() {
        super.layout()

        var y = bounds.maxY - Metrics.verticalPadding
        for label in [titleLabel, statusLabel] {
            let size = label.fittingSize
            y -= size.height
            label.frame = NSRect(
                x: Metrics.leadingInset, y: y, width: size.width, height: size.height
            )
            y -= Metrics.lineSpacing
        }

        // Fills the square to the right of the text, with the same margin
        // above, below, and to its right: as tall as the text block, and
        // reaching the trailing edge.
        let margin = Metrics.verticalPadding
        let size = bounds.height - margin * 2
        iconView.frame = NSRect(
            x: bounds.maxX - margin - size, y: margin, width: size, height: size
        )
    }
}

/// A section heading. A view rather than a menu item title, so it keeps full
/// contrast without becoming hoverable or clickable.
@MainActor
private final class SectionHeaderView: NSView {
    private let label = NSTextField(labelWithString: "")

    private enum Metrics {
        /// Matches the inset AppKit gives a menu item's title, so headings line
        /// up with the rows under them.
        static let leadingInset: CGFloat = 21
        static let topPadding: CGFloat = 5
        static let bottomPadding: CGFloat = 3
    }

    init(title: String) {
        super.init(frame: .zero)
        label.stringValue = title
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        addSubview(label)
        autoresizingMask = [.width]
        frame = NSRect(origin: .zero, size: intrinsicContentSize)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    override var intrinsicContentSize: NSSize {
        NSSize(
            width: Metrics.leadingInset + label.fittingSize.width,
            height: label.fittingSize.height + Metrics.topPadding + Metrics.bottomPadding
        )
    }

    override func layout() {
        super.layout()
        let size = label.fittingSize
        label.frame = NSRect(
            x: Metrics.leadingInset,
            y: Metrics.bottomPadding,
            width: size.width,
            height: size.height
        )
    }
}
