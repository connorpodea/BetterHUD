import AppKit

/// Plays the click macOS normally makes when the volume keys are pressed.
///
/// Because the app consumes the key event, the system never plays this itself,
/// which would otherwise be a silent regression from native behavior.
///
/// The audio file is read from the system rather than bundled, for the same
/// reason as the HUD artwork: no Apple asset is redistributed.
@MainActor
final class VolumeFeedbackSound {
    private static let soundPath =
        "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Media Keys.aif"

    /// The global preference behind System Settings → Sound → "Play feedback
    /// when volume is changed".
    private static let feedbackPreferenceKey = "com.apple.sound.beep.feedback"

    /// Loaded once and reused; `nil` if the system file is missing.
    private let sound = NSSound(contentsOfFile: soundPath, byReference: true)

    /// Whether the user has feedback enabled system-wide.
    private var isEnabledSystemWide: Bool {
        UserDefaults.standard.bool(forKey: Self.feedbackPreferenceKey)
    }

    /// Plays the click if `mode` calls for it.
    ///
    /// Holding Shift inverts the decision for that press, matching how the
    /// native keys behave.
    func play(shiftHeld: Bool, mode: Settings.FeedbackMode) {
        let wanted = switch mode {
        case .followSystem: isEnabledSystemWide
        case .always: true
        case .never: false
        }
        guard wanted != shiftHeld, let sound else { return }
        // Restart rather than overlap, so holding the key ticks once per step.
        if sound.isPlaying { sound.stop() }
        sound.play()
    }
}
