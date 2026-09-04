import AppKit

/// The app's full settings page, and its first launch experience.
///
/// One window serves both: on first launch it explains what the app does and
/// what permission it needs, and afterwards it's reachable from the menu as
/// settings. Keeping them unified means the permission state, the HUD options,
/// startup, and updates are all in one place.
///
/// The menu offers the same HUD options for quick changes. This window is the
/// complete picture, including what the menu deliberately leaves out.
@MainActor
final class SettingsWindowController: NSWindowController {
    private let settings: Settings
    private let permissions: PermissionManager
    private let updateChecker: UpdateChecker

    private let permissionIcon = NSImageView()
    private let permissionLabel = NSTextField(labelWithString: "")
    private let permissionButton = NSButton()

    private let placementControl = NSSegmentedControl()
    private let durationControl = NSSegmentedControl()
    private let opacityControl = NSSegmentedControl()
    private let volumeKeysCheckbox = NSButton()
    private let brightnessKeysCheckbox = NSButton()
    private let feedbackControl = NSSegmentedControl()
    private let launchAtLoginCheckbox = NSButton()

    private let updateLabel = NSTextField(labelWithString: "")
    private let updateButton = NSButton()

    private static let hasCompletedSetupKey = "hasCompletedSetup"

    /// True once the user has dismissed the window with permission granted, so
    /// it stops appearing on every launch.
    static var isSetupComplete: Bool {
        UserDefaults.standard.bool(forKey: hasCompletedSetupKey)
    }

    init(settings: Settings, permissions: PermissionManager, updateChecker: UpdateChecker) {
        self.settings = settings
        self.permissions = permissions
        self.updateChecker = updateChecker

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "BetterHUD"
        // The controller outlives the window being closed and reopened.
        window.isReleasedWhenClosed = false

        super.init(window: window)
        window.contentView = makeContentView()

        updateChecker.onCheckCompleted = { [weak self] outcome in
            self?.report(outcome)
        }

        // Refresh before sizing: it hides the permission button when access is
        // already granted, and a window sized before that is left with the
        // button's height as empty space at the bottom.
        refresh()
        window.center()
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

    /// Pulls current values into the controls, so the window always shows the
    /// truth. Also called when permission changes underneath it.
    func refresh() {
        let trusted = permissions.isTrusted
        permissionIcon.image = NSImage(
            systemSymbolName: trusted ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
            accessibilityDescription: nil
        )
        permissionIcon.contentTintColor = trusted ? .systemGreen : .systemOrange
        permissionLabel.stringValue = trusted
            ? "Accessibility access granted. BetterHUD is replacing the system HUD."
            : "BetterHUD needs Accessibility access to replace the system HUD."
        permissionButton.isHidden = trusted

        placementControl.selectedSegment =
            Settings.Placement.allCases.firstIndex(of: settings.placement) ?? 1
        durationControl.selectedSegment =
            Settings.durationChoices.firstIndex(of: settings.visibleDuration) ?? 1
        opacityControl.selectedSegment =
            Settings.opacityChoices.firstIndex(of: settings.backdropOpacity)
                ?? Settings.opacityChoices.count - 1
        volumeKeysCheckbox.state = settings.handlesVolumeKeys ? .on : .off
        brightnessKeysCheckbox.state = settings.handlesBrightnessKeys ? .on : .off
        feedbackControl.selectedSegment =
            Settings.FeedbackMode.allCases.firstIndex(of: settings.feedbackMode) ?? 0
        launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off

        if let release = updateChecker.newerRelease {
            updateLabel.stringValue = "Version \(release.version) is available."
            updateButton.title = "Open Release Page"
        } else {
            updateLabel.stringValue = "Version \(Self.currentVersion)"
            updateButton.title = "Check for Updates"
        }

        fitWindow()
    }

    /// Resizes to fit, so hiding or showing a row never leaves a gap.
    private func fitWindow() {
        guard let content = window?.contentView else { return }
        window?.setContentSize(content.fittingSize)
    }

    /// Says what a finished check found. Silence would leave the button's
    /// "Checking…" text on screen with no resolution.
    private func report(_ outcome: UpdateChecker.Outcome) {
        switch outcome {
        case .upToDate:
            updateLabel.stringValue = "Version \(Self.currentVersion) is the latest."
            updateButton.title = "Check for Updates"
        case .updateAvailable(let release):
            updateLabel.stringValue = "Version \(release.version) is available."
            updateButton.title = "Open Release Page"
        case .failed:
            updateLabel.stringValue = "Couldn't check for updates."
            updateButton.title = "Check for Updates"
        }
        fitWindow()
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    // MARK: - Layout

    /// Width every control is pinned to. Uniform width, with uniform segments
    /// inside it, is what puts each control's middle segment exactly on the
    /// window's centerline. Left to size themselves, "0%" is narrower than
    /// "100%" and the middle segment drifts off center.
    private static let controlWidth: CGFloat = 250
    private static let contentInset: CGFloat = 24
    private static let contentWidth: CGFloat = 500

    private func makeContentView() -> NSView {
        let icon = NSImageView()
        icon.image = NSApp.applicationIconImage
        icon.imageScaling = .scaleProportionallyUpOrDown

        let name = NSTextField(labelWithString: "BetterHUD")
        name.font = .systemFont(ofSize: 20, weight: .semibold)

        let blurb = NSTextField(wrappingLabelWithString: """
            Restores the centered volume and brightness HUD that macOS 26 \
            replaced, and keeps the new indicator from appearing.
            """)
        blurb.textColor = .secondaryLabelColor
        blurb.font = .systemFont(ofSize: 11)

        let titleStack = NSStackView(views: [name, blurb])
        titleStack.orientation = .vertical
        titleStack.alignment = .leading
        titleStack.spacing = 2

        let header = NSStackView(views: [icon, titleStack])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 12

        permissionIcon.symbolConfiguration = .init(pointSize: 14, weight: .regular)
        permissionLabel.font = .systemFont(ofSize: 11)
        permissionLabel.lineBreakMode = .byWordWrapping
        permissionLabel.maximumNumberOfLines = 2
        configureButton(permissionButton, title: "Open Accessibility Settings…",
                        action: #selector(openAccessibilitySettings))

        let permissionRow = NSStackView(views: [permissionIcon, permissionLabel])
        permissionRow.orientation = .horizontal
        permissionRow.alignment = .firstBaseline
        permissionRow.spacing = 6

        configure(placementControl, labels: Settings.Placement.allCases.map(\.title),
                  action: #selector(changePlacement))
        configure(durationControl,
                  labels: Settings.durationChoices.map { String(format: "%.1fs", $0) },
                  action: #selector(changeDuration))
        configure(opacityControl,
                  labels: Settings.opacityChoices.map { "\(Int($0 * 100))%" },
                  action: #selector(changeOpacity))
        configure(feedbackControl, labels: Settings.FeedbackMode.allCases.map(\.menuTitle),
                  action: #selector(changeFeedbackMode))

        configureCheckbox(volumeKeysCheckbox, title: "Volume and Mute",
                          action: #selector(toggleVolumeKeys))
        configureCheckbox(brightnessKeysCheckbox, title: "Brightness",
                          action: #selector(toggleBrightnessKeys))
        configureCheckbox(launchAtLoginCheckbox, title: "Open BetterHUD at Login",
                          action: #selector(toggleLaunchAtLogin))

        let keysStack = NSStackView(views: [volumeKeysCheckbox, brightnessKeysCheckbox])
        keysStack.orientation = .horizontal
        keysStack.spacing = 16

        updateLabel.font = .systemFont(ofSize: 11)
        updateLabel.textColor = .secondaryLabelColor
        configureButton(updateButton, title: "Check for Updates",
                        action: #selector(checkForUpdates))

        let done = NSButton(title: "Done", target: self, action: #selector(finish))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"

        // The spacer carries the slack, so the update button stays left and
        // Done stays right.
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        updateButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        done.setContentHuggingPriority(.defaultHigh, for: .horizontal)

        let footer = NSStackView(views: [updateButton, spacer, done])
        footer.orientation = .horizontal

        let stack = NSStackView(views: [
            header,
            separator(),
            sectionLabel("Permission"), permissionRow, permissionButton,
            separator(),
            sectionLabel("HUD"),
            row("Position:", placementControl),
            row("Show For:", durationControl),
            row("Opacity:", opacityControl),
            row("Volume Click:", feedbackControl),
            row("Take Over:", keysStack),
            separator(),
            sectionLabel("Startup"), launchAtLoginCheckbox,
            separator(),
            updateLabel,
            footer,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        // Even on all four sides.
        stack.edgeInsets = NSEdgeInsets(
            top: Self.contentInset,
            left: Self.contentInset,
            bottom: Self.contentInset,
            right: Self.contentInset
        )
        stack.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            icon.widthAnchor.constraint(equalToConstant: 52),
            icon.heightAnchor.constraint(equalToConstant: 52),
            blurb.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
            permissionLabel.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
            footer.widthAnchor.constraint(equalToConstant: Self.contentWidth),
        ])
        return container
    }

    /// A label on the left with its control centered on the window's
    /// centerline, so every control lines up with every other one.
    private func row(_ text: String, _ control: NSView) -> NSView {
        let label = NSTextField(labelWithString: text)
        let container = NSView()
        container.addSubview(label)
        container.addSubview(control)

        label.translatesAutoresizingMaskIntoConstraints = false
        control.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: Self.contentWidth),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            control.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            control.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalTo: control.heightAnchor),
        ])
        return container
    }

    private func configure(_ control: NSSegmentedControl, labels: [String], action: Selector) {
        control.segmentCount = labels.count
        control.segmentStyle = .automatic
        control.trackingMode = .selectOne

        // Every segment the same width, so the middle one is centered.
        let segmentWidth = Self.controlWidth / CGFloat(labels.count)
        for (index, title) in labels.enumerated() {
            control.setLabel(title, forSegment: index)
            control.setWidth(segmentWidth, forSegment: index)
        }
        control.target = self
        control.action = action
    }

    private func configureButton(_ button: NSButton, title: String, action: Selector) {
        button.bezelStyle = .rounded
        button.title = title
        button.target = self
        button.action = action
    }

    private func configureCheckbox(_ checkbox: NSButton, title: String, action: Selector) {
        checkbox.setButtonType(.switch)
        checkbox.title = title
        checkbox.target = self
        checkbox.action = action
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let field = NSTextField(labelWithString: text.uppercased())
        field.font = .systemFont(ofSize: 10, weight: .semibold)
        field.textColor = .secondaryLabelColor
        return field
    }

    private func separator() -> NSBox {
        let box = NSBox()
        box.boxType = .separator
        box.widthAnchor.constraint(equalToConstant: Self.contentWidth).isActive = true
        return box
    }

    // MARK: - Actions

    @objc private func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    @objc private func changePlacement() {
        settings.placement = Settings.Placement.allCases[placementControl.selectedSegment]
    }

    @objc private func changeDuration() {
        settings.visibleDuration = Settings.durationChoices[durationControl.selectedSegment]
    }

    @objc private func changeOpacity() {
        settings.backdropOpacity = Settings.opacityChoices[opacityControl.selectedSegment]
    }

    @objc private func changeFeedbackMode() {
        settings.feedbackMode = Settings.FeedbackMode.allCases[feedbackControl.selectedSegment]
    }

    @objc private func toggleVolumeKeys() {
        settings.handlesVolumeKeys = volumeKeysCheckbox.state == .on
    }

    @objc private func toggleBrightnessKeys() {
        settings.handlesBrightnessKeys = brightnessKeysCheckbox.state == .on
    }

    @objc private func toggleLaunchAtLogin() {
        if !LaunchAtLogin.setEnabled(launchAtLoginCheckbox.state == .on) {
            // macOS refused, so don't leave the checkbox lying about the state.
            launchAtLoginCheckbox.state = LaunchAtLogin.isEnabled ? .on : .off
        }
    }

    @objc private func checkForUpdates() {
        if let release = updateChecker.newerRelease {
            NSWorkspace.shared.open(release.page)
            return
        }
        updateLabel.stringValue = "Checking…"
        updateChecker.check()
    }

    @objc private func finish() {
        // Only remember completion once permission is actually in place, so an
        // unconfigured app still explains itself on the next launch.
        if permissions.isTrusted {
            UserDefaults.standard.set(true, forKey: Self.hasCompletedSetupKey)
        }
        window?.close()
    }
}
