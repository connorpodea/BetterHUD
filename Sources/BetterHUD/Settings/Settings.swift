import Foundation

/// User preferences, stored in `UserDefaults`.
///
/// Values are read on demand — at key-press time, which happens at human rates
/// — so there's nothing to cache, no observers to keep alive, and no way for a
/// cached copy to go stale after the user changes something.
@MainActor
final class Settings {
    /// Where the HUD is drawn.
    enum Placement: String, CaseIterable {
        /// Dead center, which is where this app puts it by default.
        case center
        /// Low and centered, where macOS used to put it.
        case lower

        var title: String {
            switch self {
            case .center: "Center of screen"
            case .lower: "Lower center (like macOS)"
            }
        }
    }

    /// Whether to play the click that macOS normally makes on a volume change.
    enum FeedbackMode: String, CaseIterable {
        /// Honor System Settings → Sound → "Play feedback when volume is changed".
        case followSystem
        case always
        case never

        var title: String {
            switch self {
            case .followSystem: "Follow system setting"
            case .always: "Always"
            case .never: "Never"
            }
        }
    }

    private enum Key {
        static let placement = "hudPlacement"
        static let visibleDuration = "hudVisibleDuration"
        static let handlesVolumeKeys = "handlesVolumeKeys"
        static let handlesBrightnessKeys = "handlesBrightnessKeys"
        static let feedbackMode = "volumeFeedbackMode"
    }

    /// Durations offered in the settings window.
    static let durationChoices: [TimeInterval] = [1.0, 1.5, 2.0, 3.0]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Registered rather than written, so an untouched preference stays
        // absent from the plist and can be changed later without migration.
        defaults.register(defaults: [
            Key.placement: Placement.center.rawValue,
            Key.visibleDuration: 1.5,
            Key.handlesVolumeKeys: true,
            Key.handlesBrightnessKeys: true,
            Key.feedbackMode: FeedbackMode.followSystem.rawValue,
        ])
    }

    var placement: Placement {
        get { Placement(rawValue: defaults.string(forKey: Key.placement) ?? "") ?? .center }
        set { defaults.set(newValue.rawValue, forKey: Key.placement) }
    }

    var visibleDuration: TimeInterval {
        get { defaults.double(forKey: Key.visibleDuration) }
        set { defaults.set(newValue, forKey: Key.visibleDuration) }
    }

    var handlesVolumeKeys: Bool {
        get { defaults.bool(forKey: Key.handlesVolumeKeys) }
        set { defaults.set(newValue, forKey: Key.handlesVolumeKeys) }
    }

    var handlesBrightnessKeys: Bool {
        get { defaults.bool(forKey: Key.handlesBrightnessKeys) }
        set { defaults.set(newValue, forKey: Key.handlesBrightnessKeys) }
    }

    var feedbackMode: FeedbackMode {
        get { FeedbackMode(rawValue: defaults.string(forKey: Key.feedbackMode) ?? "") ?? .followSystem }
        set { defaults.set(newValue.rawValue, forKey: Key.feedbackMode) }
    }
}
