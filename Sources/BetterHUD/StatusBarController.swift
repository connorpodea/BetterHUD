import AppKit

/// The menu bar item.
///
/// Deliberately short: the settings themselves live in the settings window, so
/// this is just a way in, plus quit. Presenting the settings here as well meant
/// maintaining every one of them twice, and a menu is the worse of the two
/// surfaces for it — checkmark columns, type-select, and a width set by the
/// longest label are all problems a window doesn't have.
@MainActor
final class StatusBarController: NSObject {
    private let openSettings: () -> Void
    private let checkForUpdates: () -> Void

    private let statusItem: NSStatusItem
    /// Inserted at the top only when a newer release exists.
    private var updateItem: NSMenuItem?
    private var updatePage: URL?

    init(openSettings: @escaping () -> Void, checkForUpdates: @escaping () -> Void) {
        self.openSettings = openSettings
        self.checkForUpdates = checkForUpdates
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

        menu.addItem(item(title: "Settings…", action: #selector(handleOpenSettings)))
        menu.addItem(item(title: "Check for Updates", action: #selector(handleCheckForUpdates)))
        menu.addItem(.separator())
        // Deliberately not `NSApplication.terminate(_:)`: macOS decorates that
        // standard action with a symbol, which shifts the title out of line
        // with the other rows.
        menu.addItem(item(title: "Quit BetterHUD", action: #selector(handleQuit)))

        statusItem.menu = menu
    }

    /// Shows a row linking to a newer release. Nothing appears unless one
    /// exists, so the menu is unchanged for anyone up to date.
    func showUpdate(version: String, page: URL) {
        guard updateItem == nil, let menu = statusItem.menu else { return }
        updatePage = page

        let row = item(title: "Update Available: \(version)", action: #selector(openUpdatePage))
        menu.insertItem(row, at: 0)
        menu.insertItem(.separator(), at: 1)
        updateItem = row
    }

    private func item(title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    // MARK: - Actions

    @objc private func handleOpenSettings() {
        openSettings()
    }

    @objc private func handleCheckForUpdates() {
        checkForUpdates()
    }

    @objc private func openUpdatePage() {
        guard let updatePage else { return }
        NSWorkspace.shared.open(updatePage)
    }

    @objc private func handleQuit() {
        NSApp.terminate(nil)
    }
}
