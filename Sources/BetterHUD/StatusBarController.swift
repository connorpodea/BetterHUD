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

        statusLine.isEnabled = false
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
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        // Deliberately not `NSApplication.terminate(_:)`: macOS decorates that
        // standard action with a symbol, which shifts the title into a
        // different column from every other row.
        let quit = NSMenuItem(title: "Quit BetterHUD", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// Refreshing when the menu opens keeps every checkmark honest without any
    /// observers running while nobody is looking.
    func menuWillOpen(_ menu: NSMenu) {
        statusLine.attributedTitle = titleBlock(
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

    /// The app name over its current state. Left aligned as a plain title, so
    /// AppKit applies the same text inset as every other row and the header
    /// lines up with them.
    private func titleBlock(status: String) -> NSAttributedString {
        let title = NSMutableAttributedString(
            string: "BetterHUD\n",
            attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold)]
        )
        title.append(NSAttributedString(
            string: status,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        ))
        return title
    }

    private func item(title: String, tag: Int, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.tag = tag
        item.target = self
        return item
    }

    /// Groups the rows under a heading.
    ///
    /// AppKit's own section headers carry Apple's styling and are meant to be
    /// used without separators, which is both tidier and shorter than a
    /// separator plus a hand-styled row. Older systems get the hand-styled
    /// version.
    private func addSection(to menu: NSMenu, titled title: String) {
        if #available(macOS 14.0, *) {
            menu.addItem(.sectionHeader(title: title))
            return
        }

        menu.addItem(.separator())
        let header = NSMenuItem()
        header.attributedTitle = NSAttributedString(
            string: title.uppercased(),
            attributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ]
        )
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
