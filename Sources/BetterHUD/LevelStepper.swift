import Foundation

/// The step arithmetic behind the volume and brightness keys.
///
/// Both move their level in sixteenths, and both read that level back from
/// hardware that doesn't hand back clean fractions, so both need the same
/// correction — it was written twice, identically, before it lived here.
///
/// Keeping it in one place also makes it reachable from tests. The controllers
/// themselves aren't: neither can be exercised without a real audio device or a
/// real display behind it.
enum LevelStepper {
    /// How many steps the hardware keys divide the range into. Apple's keys
    /// move in sixteenths, so ours do too.
    static let stepCount: Float = 16

    /// Snaps `current` to the nearest step, then moves one step in the given
    /// direction.
    ///
    /// Snapping first is the whole point, and the reason this isn't simply
    /// `current ± 1/16`. The hardware reads a level back as 8.999999 sixteenths
    /// rather than 9, so rounding toward the direction of travel recomputes the
    /// step that was just set and the level never advances.
    ///
    /// The result is deliberately unclamped: callers clamp against whatever
    /// their own range requires, and the volume keys additionally read the
    /// unclamped result to decide whether the bottom of the range was hit.
    static func step(from current: Float, increasing: Bool) -> Float {
        let steps = (current * stepCount).rounded()
        return (steps + (increasing ? 1 : -1)) / stepCount
    }
}
