import Foundation

/// User preferences, stored in `UserDefaults`.
///
/// Values are read on demand — at key-press time, which happens at human rates
/// — so there's nothing to cache, no observers to keep alive, and no way for a
/// cached copy to go stale after the user changes something.
@MainActor
final class Settings {
    /// Where the HUD is drawn. All three are horizontally centered; they
    /// differ only in height.
    ///
    /// Ordered bottom to top, which is how the choices are presented.
    enum Placement: String, CaseIterable {
        /// Low and centered, where macOS used to put it.
        case lower
        /// Dead center, the default.
        case center
        case upper

        var title: String {
            switch self {
            case .lower: "Lower"
            case .center: "Middle"
            case .upper: "Upper"
            }
        }
    }

    /// Whether to play the click that macOS normally makes on a volume change.
    /// Ordered least to most, which is how the choices are presented.
    enum FeedbackMode: String, CaseIterable {
        case never
        /// Honor System Settings → Sound → "Play feedback when volume is changed".
        case followSystem
        case always

        /// Kept short: a menu is only as narrow as its longest row, and the
        /// section heading already supplies the context.
        var menuTitle: String {
            switch self {
            case .never: "Never"
            case .followSystem: "System"
            case .always: "Always"
            }
        }
    }

    private enum Key {
        static let placement = "hudPlacement"
        static let opacity = "hudBackdropOpacity"
        static let visibleDuration = "hudVisibleDuration"
        static let handlesVolumeKeys = "handlesVolumeKeys"
        static let handlesBrightnessKeys = "handlesBrightnessKeys"
        static let feedbackMode = "volumeFeedbackMode"
    }

    /// Durations offered in the menu.
    static let durationChoices: [TimeInterval] = [1.0, 1.5, 2.0]

    /// Opacities the slider snaps to.
    static let opacityChoices: [Double] = [0, 0.25, 0.5, 0.75, 1.0]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Registered rather than written, so an untouched preference stays
        // absent from the plist and can be changed later without migration.
        defaults.register(defaults: [
            Key.placement: Placement.center.rawValue,
            Key.visibleDuration: 1.5,
            Key.opacity: 1.0,
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
        get {
            // A previously chosen duration may no longer be offered, so fall
            // back to the closest one still available rather than leaving no
            // option selected.
            let stored = defaults.double(forKey: Key.visibleDuration)
            return Self.durationChoices.min {
                abs($0 - stored) < abs($1 - stored)
            } ?? 1.5
        }
        set { defaults.set(newValue, forKey: Key.visibleDuration) }
    }

    /// Opacity of the HUD's panel background, 0 through 1. The glyph and level
    /// bar are unaffected.
    var backdropOpacity: Double {
        get { defaults.double(forKey: Key.opacity) }
        set { defaults.set(min(max(newValue, 0), 1), forKey: Key.opacity) }
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
