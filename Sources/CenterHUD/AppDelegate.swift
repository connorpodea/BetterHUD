import AppKit
import os

/// Owns the app's pieces and routes intercepted keys to the right controller.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let log = Logger(subsystem: "com.connorpodea.centerhud", category: "app")

    private let volumeController = VolumeController()
    private let brightnessController = BrightnessController()
    private let osdController = OSDController()
    private let feedbackSound = VolumeFeedbackSound()
    private let permissions = PermissionManager()

    private lazy var mediaKeyTap = MediaKeyTap { [weak self] event in
        self?.handle(event)
    }
    private var statusBar: StatusBarController?
    private var isIntercepting = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(
            isInterceptingKeys: { [weak self] in self?.isIntercepting ?? false },
            openSettings: { [weak self] in self?.permissions.openAccessibilitySettings() }
        )

        // Granting permission installs the tap immediately, so the app never
        // needs to be relaunched to start working.
        permissions.onTrustChanged = { [weak self] in self?.installTapIfPossible() }

        if !permissions.isTrusted {
            permissions.promptIfNeeded()
        }
        installTapIfPossible()
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

    private func handle(_ event: MediaKeyEvent) {
        guard event.isPressed else { return }

        switch event.key {
        case .soundUp, .soundDown:
            volumeController.adjust(increasing: event.key == .soundUp)
            // The system would normally click here, but it never sees the key.
            feedbackSound.play(shiftHeld: NSEvent.modifierFlags.contains(.shift))
            showVolumeHUD()

        case .mute:
            // Ignore auto-repeat so holding the key doesn't flap the mute state.
            guard !event.isRepeat else { return }
            volumeController.toggleMute()
            showVolumeHUD()

        case .brightnessUp, .brightnessDown:
            brightnessController.adjust(increasing: event.key == .brightnessUp)
            guard let level = brightnessController.level else { return }
            osdController.showBrightness(level: level)
        }
    }

    private func showVolumeHUD() {
        // Read the level back rather than predicting it, so the HUD reflects
        // what the hardware actually accepted.
        guard let level = volumeController.level else { return }
        osdController.showVolume(level: level, isMuted: volumeController.isMuted)
    }
}
