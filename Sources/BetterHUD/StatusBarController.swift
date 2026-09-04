import AppKit

/// The menu bar item: the app's only visible UI.
///
/// It exists mainly so a background app that needs a system permission has
/// somewhere to report its state and offer a way to quit.
@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let statusLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Open at Login", action: nil, keyEquivalent: "")

    /// Queried when the menu opens so the status line is always current.
    private let isInterceptingKeys: () -> Bool
    private let openSetup: () -> Void

    init(isInterceptingKeys: @escaping () -> Bool, openSetup: @escaping () -> Void) {
        self.isInterceptingKeys = isInterceptingKeys
        self.openSetup = openSetup
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        configureButton()
        configureMenu()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        // The same wordmark as the app icon. It's a template image, so macOS
        // tints it for light, dark, and highlighted menu bars.
        let icon = Bundle.main.image(forResource: "MenuBarIcon")
        icon?.isTemplate = true
        button.image = icon
        button.setAccessibilityLabel("BetterHUD")
    }

    private func configureMenu() {
        let menu = NSMenu()
        menu.delegate = self

        statusLine.isEnabled = false
        menu.addItem(statusLine)

        menu.addItem(.separator())

        let setupItem = NSMenuItem(
            title: "Setup…", action: #selector(handleOpenSetup), keyEquivalent: ""
        )
        setupItem.target = self
        menu.addItem(setupItem)

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

    /// Refreshing on open avoids keeping any timer or observer alive just to
    /// maintain a label nobody is looking at.
    func menuWillOpen(_ menu: NSMenu) {
        statusLine.title = isInterceptingKeys()
            ? "Replacing the system HUD"
            : "Needs Accessibility permission"
        launchAtLoginItem.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    @objc private func handleOpenSetup() {
        openSetup()
    }

    @objc private func toggleLaunchAtLogin() {
        LaunchAtLogin.setEnabled(!LaunchAtLogin.isEnabled)
    }
}
