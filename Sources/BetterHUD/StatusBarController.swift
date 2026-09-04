import AppKit

/// The menu bar item: the app's only visible UI.
///
/// It exists mainly so a background app that needs a system permission has
/// somewhere to report its state and offer a way to quit.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let openSettingsItem: NSMenuItem

    /// Queried when the menu opens so the status line is always current.
    private let isInterceptingKeys: () -> Bool
    private let openSettings: () -> Void

    init(isInterceptingKeys: @escaping () -> Bool, openSettings: @escaping () -> Void) {
        self.isInterceptingKeys = isInterceptingKeys
        self.openSettings = openSettings
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        openSettingsItem = NSMenuItem(
            title: "Open Accessibility Settings…",
            action: nil,
            keyEquivalent: ""
        )
        super.init()

        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        // An SF Symbol rather than custom artwork: Apple's glyphs are drawn
        // for menu bar sizes and stay legible at 18pt, and a rectangle with a
        // centered inset reads as "a panel in the middle of the screen".
        let icon = NSImage(
            systemSymbolName: "rectangle.center.inset.filled",
            accessibilityDescription: "BetterHUD"
        )
        icon?.isTemplate = true
        button.image = icon
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        statusLine.isEnabled = false
        menu.addItem(statusLine)

        openSettingsItem.target = self
        openSettingsItem.action = #selector(handleOpenSettings)
        menu.addItem(openSettingsItem)

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

    /// Refreshing on open avoids keeping any timer or observer alive just to
    /// maintain a label nobody is looking at.
    func menuWillOpen(_ menu: NSMenu) {
        let active = isInterceptingKeys()
        statusLine.title = active
            ? "Replacing the system HUD"
            : "Needs Accessibility permission"
        // The settings shortcut is only useful while permission is missing.
        openSettingsItem.isHidden = active
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }
}
