import AppKit

/// The settings window: the only place these preferences can be changed, since
/// the menu bar item is deliberately kept to status and Quit.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: Settings

    private let launchAtLoginCheckbox = NSButton()
    private let placementPopUp = NSPopUpButton()
    private let durationPopUp = NSPopUpButton()
    private let volumeKeysCheckbox = NSButton()
    private let brightnessKeysCheckbox = NSButton()
    private let feedbackPopUp = NSPopUpButton()

    init(settings: Settings) {
        self.settings = settings

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 260),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BetterHUD Settings"
        // The controller outlives the window being closed and reopened.
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.contentView = makeContentView()
        window.center()
        refresh()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// The app is an accessory, so it has to activate itself for the window to
    /// come to the front.
    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        refresh()
    }

    /// Pulls the current values into the controls, so the window always opens
    /// showing the truth.
    private func refresh() {
        launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        placementPopUp.selectItem(at: Settings.Placement.allCases.firstIndex(of: settings.placement) ?? 0)
        durationPopUp.selectItem(at: Settings.durationChoices.firstIndex(of: settings.visibleDuration) ?? 1)
        volumeKeysCheckbox.state = settings.handlesVolumeKeys ? .on : .off
        brightnessKeysCheckbox.state = settings.handlesBrightnessKeys ? .on : .off
        feedbackPopUp.selectItem(at: Settings.FeedbackMode.allCases.firstIndex(of: settings.feedbackMode) ?? 0)
    }

    // MARK: - Layout

    private func makeContentView() -> NSView {
        launchAtLoginCheckbox.setButtonType(.switch)
        launchAtLoginCheckbox.title = "Open BetterHUD at login"
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.action = #selector(toggleLaunchAtLogin)

        placementPopUp.addItems(withTitles: Settings.Placement.allCases.map(\.title))
        placementPopUp.target = self
        placementPopUp.action = #selector(changePlacement)

        durationPopUp.addItems(
            withTitles: Settings.durationChoices.map { String(format: "%.1f seconds", $0) }
        )
        durationPopUp.target = self
        durationPopUp.action = #selector(changeDuration)

        volumeKeysCheckbox.setButtonType(.switch)
        volumeKeysCheckbox.title = "Volume and mute"
        volumeKeysCheckbox.target = self
        volumeKeysCheckbox.action = #selector(toggleVolumeKeys)

        brightnessKeysCheckbox.setButtonType(.switch)
        brightnessKeysCheckbox.title = "Brightness"
        brightnessKeysCheckbox.target = self
        brightnessKeysCheckbox.action = #selector(toggleBrightnessKeys)

        feedbackPopUp.addItems(withTitles: Settings.FeedbackMode.allCases.map(\.title))
        feedbackPopUp.target = self
        feedbackPopUp.action = #selector(changeFeedbackMode)

        let keysStack = NSStackView(views: [volumeKeysCheckbox, brightnessKeysCheckbox])
        keysStack.orientation = .vertical
        keysStack.alignment = .leading
        keysStack.spacing = 4

        let note = NSTextField(wrappingLabelWithString:
            "Keys that are turned off are left to macOS, which will show its own indicator for them."
        )
        note.font = .systemFont(ofSize: 11)
        note.textColor = .secondaryLabelColor

        let grid = NSGridView(views: [
            [label("Show HUD:"), placementPopUp],
            [label("Show for:"), durationPopUp],
            [label("Take over:"), keysStack],
            [label("Volume click:"), feedbackPopUp],
            [NSGridCell.emptyContentView, launchAtLoginCheckbox],
            [NSGridCell.emptyContentView, note],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.row(at: 2).yPlacement = .top
        grid.row(at: 4).topPadding = 8
        grid.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 20),
            grid.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -20),
            grid.topAnchor.constraint(equalTo: container.topAnchor, constant: 20),
            note.widthAnchor.constraint(lessThanOrEqualToConstant: 300),
        ])
        return container
    }

    private func label(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text)
        field.alignment = .right
        return field
    }

    // MARK: - Actions

    @objc private func toggleLaunchAtLogin() {
        if !LaunchAtLogin.setEnabled(launchAtLoginCheckbox.state == .on) {
            // macOS refused, so don't leave the checkbox lying about the state.
            launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    @objc private func changePlacement() {
        settings.placement = Settings.Placement.allCases[placementPopUp.indexOfSelectedItem]
    }

    @objc private func changeDuration() {
        settings.visibleDuration = Settings.durationChoices[durationPopUp.indexOfSelectedItem]
    }

    @objc private func toggleVolumeKeys() {
        settings.handlesVolumeKeys = volumeKeysCheckbox.state == .on
    }

    @objc private func toggleBrightnessKeys() {
        settings.handlesBrightnessKeys = brightnessKeysCheckbox.state == .on
    }

    @objc private func changeFeedbackMode() {
        settings.feedbackMode = Settings.FeedbackMode.allCases[feedbackPopUp.indexOfSelectedItem]
    }
}
