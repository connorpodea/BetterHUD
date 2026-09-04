import AppKit

/// First-run setup: explains what the app does and walks the user through the
/// one permission it needs.
///
/// A background app that silently does nothing until a permission is granted is
/// baffling, so this window exists to make the requirement and its current
/// state obvious. It reappears on launch until the permission is in place.
@MainActor
final class SetupWindowController: NSWindowController {
    private let permissions: PermissionManager

    private let statusIcon = NSImageView()
    private let statusLabel = NSTextField(labelWithString: "")
    private let grantButton = NSButton()
    private let loginCheckbox = NSButton()

    private static let hasCompletedSetupKey = "hasCompletedSetup"

    /// True once the user has dismissed setup with the permission granted, so
    /// it stops appearing on every launch.
    static var isSetupComplete: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }

    init(permissions: PermissionManager) {
        self.permissions = permissions

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BetterHUD Setup"
        // The controller outlives the window being closed and reopened.
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.contentView = makeContentView()
        window.center()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Brings the window up. The app is an accessory, so it has to activate
    /// itself for the window to come to the front.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        refresh()
    }

    /// Called when permission changes, so the status flips without the user
    /// having to close and reopen the window.
    func refresh() {
        let trusted = permissions.isTrusted

        statusIcon.image = NSImage(
            systemSymbolName: trusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
            accessibilityDescription: nil
        )
        statusIcon.contentTintColor = trusted ? .systemGreen : .systemOrange
        statusLabel.stringValue = trusted
            ? "Accessibility access granted — BetterHUD is active."
            : "BetterHUD needs Accessibility access to replace the HUD."
        grantButton.isHidden = trusted
        loginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
    }

    // MARK: - Layout

    private func makeContentView() -> NSView {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let title = NSTextField(labelWithString: "BetterHUD")
        title.font = .systemFont(ofSize: 22, weight: .bold)

        let blurb = NSTextField(wrappingLabelWithString: """
            Restores the centered volume and brightness HUD that macOS 26 \
            replaced with a small indicator — and keeps the new one from \
            appearing while BetterHUD is running.
            """)
        blurb.textColor = .secondaryLabelColor

        statusIcon.symbolConfiguration = .init(pointSize: 15, weight: .regular)

        grantButton.title = "Open Accessibility Settings…"
        grantButton.bezelStyle = .rounded
        grantButton.target = self
        grantButton.action = #selector(openSettings)

        let statusRow = NSStackView(views: [statusIcon, statusLabel])
        statusRow.orientation = .horizontal
        statusRow.spacing = 8
        statusRow.alignment = .firstBaseline

        let steps = NSTextField(wrappingLabelWithString: """
            1.  Open System Settings → Privacy & Security → Accessibility
            2.  Add BetterHUD and turn it on

            No restart needed — BetterHUD starts working the moment you \
            enable it.
            """)
        steps.font = .systemFont(ofSize: 12)
        steps.textColor = .secondaryLabelColor

        loginCheckbox.setButtonType(.switch)
        loginCheckbox.title = "Open BetterHUD at login"
        loginCheckbox.target = self
        loginCheckbox.action = #selector(toggleLaunchAtLogin)

        let done = NSButton(title: "Done", target: self, action: #selector(finish))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        let footer = NSStackView(views: [NSView(), done])
        footer.orientation = .horizontal

        let separator = NSBox()
        separator.boxType = .separator

        let stack = NSStackView(views: [
            icon, title, blurb, separator, statusRow, grantButton, steps,
            loginCheckbox, footer,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 20, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 64),
            icon.heightAnchor.constraint(equalToConstant: 64),
            footer.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -48),
        ])
        return container
    }

    // MARK: - Actions

    @objc private func openSettings() {
        permissions.openAccessibilitySettings()
    }

    @objc private func toggleLaunchAtLogin() {
        let wantsEnabled = loginCheckbox.state == .on
        if !LaunchAtLogin.setEnabled(wantsEnabled) {
            // macOS refused, so don't leave the checkbox lying about the state.
            loginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    @objc private func finish() {
        // Only remember completion once the permission is actually in place,
        // so an unconfigured app still explains itself on the next launch.
        if permissions.isTrusted {
            UserDefaults.standard.set(true, forKey: Self.hasCompletedSetupKey)
        }
        window?.close()
    }
}
