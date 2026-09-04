import AppKit

/// The menu bar item, which is both the app's status display and its entire
/// settings UI.
///
/// Everything lives here rather than in a settings window: each preference is a
/// short list of choices, which a submenu of checkmarked items expresses
/// directly, with no window to place, size, or manage.
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
        menu.addItem(.separator())

        placementItems = Settings.Placement.allCases.enumerated().map { index, placement in
            item(title: placement.title, tag: index, action: #selector(changePlacement(_:)))
        }
        menu.addItem(submenu(titled: "Position", items: placementItems))

        durationItems = Settings.durationChoices.enumerated().map { index, duration in
            item(
                title: String(format: "%.1f seconds", duration),
                tag: index,
                action: #selector(changeDuration(_:))
            )
        }
        menu.addItem(submenu(titled: "Duration", items: durationItems))

        feedbackItems = Settings.FeedbackMode.allCases.enumerated().map { index, mode in
            item(title: mode.menuTitle, tag: index, action: #selector(changeFeedbackMode(_:)))
        }
        menu.addItem(submenu(titled: "Volume Click", items: feedbackItems))

        volumeKeysItem.target = self
        volumeKeysItem.action = #selector(toggleVolumeKeys)
        brightnessKeysItem.target = self
        brightnessKeysItem.action = #selector(toggleBrightnessKeys)
        let footnote = NSMenuItem(
            title: "Keys turned off are left to macOS", action: nil, keyEquivalent: ""
        )
        footnote.isEnabled = false
        menu.addItem(submenu(
            titled: "Take Over",
            items: [volumeKeysItem, brightnessKeysItem, .separator(), footnote]
        ))

        menu.addItem(.separator())
        launchAtLoginItem.target = self
        launchAtLoginItem.action = #selector(toggleLaunchAtLogin)
        menu.addItem(launchAtLoginItem)

        menu.addItem(.separator())
        let quit = NSMenuItem(
            title: "Quit BetterHUD",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        menu.addItem(quit)

        statusItem.menu = menu
    }

    /// Refreshing when the menu opens keeps every checkmark honest without any
    /// observers running while nobody is looking.
    func menuWillOpen(_ menu: NSMenu) {
        statusLine.title = isInterceptingKeys()
            ? "Replacing the system HUD"
            : "Needs Accessibility permission"

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
        item.tag = tag
        item.target = self
        return item
    }

    private func submenu(titled title: String, items: [NSMenuItem]) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        items.forEach(submenu.addItem)
        parent.submenu = submenu
        return parent
    }

    /// Marks one item in a mutually exclusive group.
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
}
