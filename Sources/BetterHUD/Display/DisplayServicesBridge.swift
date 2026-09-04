import CoreGraphics
import Foundation

/// Thin wrapper over the private DisplayServices framework.
///
/// macOS exposes no public API for setting the built-in display's brightness:
/// the old CoreGraphics brightness calls are long gone, and IOKit's display
/// parameters don't reach Apple Silicon internal panels. Every tool in this
/// space (Lunar, MonitorControl, nriley/brightness) uses these same private
/// symbols.
///
/// They're resolved with `dlsym` rather than linked, so a renamed or removed
/// symbol on a future macOS degrades to "brightness unsupported" instead of
/// preventing the app from launching. This is also why the app can't be
/// sandboxed or shipped on the Mac App Store.
struct DisplayServicesBridge {
    private typealias GetBrightness =
        @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightness =
        @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let getBrightnessFunction: GetBrightness
    private let setBrightnessFunction: SetBrightness
    /// Optional: ramps to the new value instead of jumping to it, which is
    /// what stops a held key from visibly stepping the display.
    private let setBrightnessSmoothFunction: SetBrightness?

    private static let frameworkPath =
        "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"

    /// Fails if the framework or either symbol is unavailable.
    init?() {
        // The handle is deliberately never dlclose'd: the resolved function
        // pointers must stay valid for the lifetime of the process.
        guard let handle = dlopen(Self.frameworkPath, RTLD_LAZY),
              let get = dlsym(handle, "DisplayServicesGetBrightness"),
              let set = dlsym(handle, "DisplayServicesSetBrightness") else { return nil }

        getBrightnessFunction = unsafeBitCast(get, to: GetBrightness.self)
        setBrightnessFunction = unsafeBitCast(set, to: SetBrightness.self)
        setBrightnessSmoothFunction = dlsym(handle, "DisplayServicesSetBrightnessSmooth")
            .map { unsafeBitCast($0, to: SetBrightness.self) }
    }

    /// Current brightness in 0...1, or nil if the display doesn't report one.
    func brightness(of display: CGDirectDisplayID) -> Float? {
        var value: Float = 0
        guard getBrightnessFunction(display, &value) == 0 else { return nil }
        return value
    }

    /// Sets brightness, ramping where the system supports it.
    ///
    /// The plain setter applies each step instantly, so a held key produces
    /// visible stepping. The smooth variant animates, which is what the
    /// hardware keys do natively. Falls back if it's unavailable or fails.
    @discardableResult
    func setBrightness(_ value: Float, of display: CGDirectDisplayID) -> Bool {
        if let smooth = setBrightnessSmoothFunction, smooth(display, value) == 0 {
            return true
        }
        return setBrightnessFunction(display, value) == 0
    }
}
