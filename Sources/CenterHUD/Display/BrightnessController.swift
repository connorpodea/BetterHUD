import AppKit
import CoreGraphics

/// Reads and writes the built-in display's brightness, mirroring the semantics
/// of the hardware brightness keys.
///
/// Only the built-in panel is supported by design; external monitors would need
/// DDC/CI, which is deliberately out of scope.
@MainActor
final class BrightnessController {
    /// Matches the volume keys' granularity so both HUDs read the same.
    static let stepCount: Float = 16
    private static let step: Float = 1 / stepCount

    private let bridge: DisplayServicesBridge?
    private var cachedDisplayID: CGDirectDisplayID?

    init() {
        bridge = DisplayServicesBridge()
        // Displays coming and going (docking, clamshell) can change which ID is
        // the built-in one. Observing beats re-scanning on every key press.
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.cachedDisplayID = nil }
        }
    }

    /// False when the private framework is unavailable or there's no built-in
    /// panel, so callers can leave the brightness keys alone rather than
    /// swallowing them to no effect.
    var isSupported: Bool { level != nil }

    /// Current brightness in 0...1, or nil if unsupported.
    var level: Float? {
        guard let bridge, let display = builtInDisplayID else { return nil }
        return bridge.brightness(of: display)
    }

    /// Steps brightness by one sixteenth, snapped to the step grid so repeated
    /// presses land on clean stops.
    func adjust(increasing: Bool) {
        guard let current = level else { return }
        let steps = (current * Self.stepCount).rounded(increasing ? .down : .up)
        let target = (steps + (increasing ? 1 : -1)) * Self.step
        setLevel(target)
    }

    func setLevel(_ newLevel: Float) {
        guard let bridge, let display = builtInDisplayID else { return }
        bridge.setBrightness(min(max(newLevel, 0), 1), of: display)
    }

    /// The built-in panel's display ID, resolved once and cached until the
    /// screen layout changes.
    private var builtInDisplayID: CGDirectDisplayID? {
        if let cachedDisplayID { return cachedDisplayID }

        var displayCount: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &displayCount) == .success, displayCount > 0 else {
            return nil
        }
        var displays = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        guard CGGetActiveDisplayList(displayCount, &displays, &displayCount) == .success else {
            return nil
        }

        guard let builtIn = displays.first(where: { CGDisplayIsBuiltin($0) != 0 }) else {
            return nil
        }
        cachedDisplayID = builtIn
        return builtIn
    }
}
