import AppKit

/// The menu bar item: the app's only visible UI.
///
/// It exists mainly so a background app that needs a system permission has
/// somewhere to report its state and offer a way to quit.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    /// Queried when the menu opens so the status line is always current.
    private let isInterceptingKeys: () -> Bool
    private let openSettings: () -> Void

    init(isInterceptingKeys: @escaping () -> Bool, openSettings: @escaping () -> Void) {
        self.isInterceptingKeys = isInterceptingKeys
        self.openSettings = openSettings
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

        let settingsItem = NSMenuItem(
            title: "Settings…", action: #selector(handleOpenSettings), keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

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
        statusLine.title = isInterceptingKeys()
            ? "Replacing the system HUD"
            : "Needs Accessibility permission"
    }

    @objc private func handleOpenSettings() {
        openSettings()
    }
}
