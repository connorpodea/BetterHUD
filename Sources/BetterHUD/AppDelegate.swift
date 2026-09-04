import AppKit
import os

/// Owns the app's pieces and routes intercepted keys to the right controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.connorpodea.betterhud", category: "app")

    private let settings = Settings()
    private let volumeController = VolumeController()
    private let brightnessController = BrightnessController()
    private let feedbackSound = VolumeFeedbackSound()
    private let permissions = PermissionManager()
    private lazy var osdController = OSDController(settings: settings)

    private lazy var mediaKeyTap = MediaKeyTap { [weak self] event in
        // No delegate means nothing can act on the key, so let macOS have it.
        self?.handle(event) ?? false
    }
    private var statusBar: StatusBarController?
    private lazy var setupWindowController = SetupWindowController(permissions: permissions)
    private var isIntercepting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(settings: settings)

        // Granting permission installs the tap immediately, so the app never
        // needs to be relaunched to start working.
        permissions.onTrustChanged = { [weak self] in
            self?.installTapIfPossible()
            self?.setupWindowController.refresh()
        }

        installTapIfPossible()

        // A background app that does nothing until a permission is granted is
        // baffling, so explain itself until setup is actually done.
        if !isIntercepting || !SetupWindowController.isSetupComplete {
            setupWindowController.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Releasing the tap hands the keys straight back to the system.
        mediaKeyTap.stop()
    }

    private func installTapIfPossible() {
        guard !isIntercepting else { return }
        isIntercepting = mediaKeyTap.start()

        if isIntercepting {
            log.notice("event tap active; replacing the system HUD")
        } else {
            // Distinguishing these cases matters: untrusted means permission is
            // still missing, while trusted-but-refused means the tap itself was
            // rejected and something else is wrong.
            log.error("event tap unavailable; accessibility trusted=\(self.permissions.isTrusted, privacy: .public)")
        }
    }

    /// Returns true if the key was handled, which consumes it. Returning false
    /// leaves the key to macOS, so a key type the user turned off behaves
    /// natively, native indicator included.
    private func handle(_ event: MediaKeyEvent) -> Bool {
        switch event.key {
        case .soundUp, .soundDown, .mute:
            guard settings.handlesVolumeKeys else { return false }
            // Key-up is consumed without acting, so no fragment of the press
            // reaches the native HUD.
            guard event.isPressed else { return true }

            if event.key == .mute {
                // Ignore auto-repeat so holding the key doesn't flap the state.
                guard !event.isRepeat else { return true }
                volumeController.toggleMute()
            } else {
                volumeController.adjust(increasing: event.key == .soundUp)
                // The system would normally click here, but it never sees the key.
                feedbackSound.play(
                    shiftHeld: NSEvent.modifierFlags.contains(.shift),
                    mode: settings.feedbackMode
                )
            }
            showVolumeHUD()
            return true

        case .brightnessUp, .brightnessDown:
            guard settings.handlesBrightnessKeys else { return false }
            guard event.isPressed else { return true }

            brightnessController.adjust(increasing: event.key == .brightnessUp)
            if let level = brightnessController.level {
                osdController.showBrightness(level: level)
            }
            return true
        }
    }

    private func showVolumeHUD() {
        // Read the level back rather than predicting it, so the HUD reflects
        // what the hardware actually accepted.
        guard let level = volumeController.level else { return }
        osdController.showVolume(level: level, isMuted: volumeController.isMuted)
    }
}
