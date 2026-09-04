import AppKit

/// Takes over the volume/brightness keys with a HID-level event tap.
///
/// The tap configuration is load-bearing for suppressing macOS's own
/// volume/brightness HUD:
///
/// - `.cghidEventTap` places us at the lowest point of the event pipeline,
///   before WindowServer fans events out to session-level listeners.
/// - `.headInsertEventTap` puts us ahead of any taps already installed.
/// - `.defaultTap` (rather than `.listenOnly`) makes the tap *active*, so
///   returning nil from the callback consumes the event outright.
///
/// Consuming the event is the whole mechanism: the process that draws the
/// native HUD never learns the key was pressed. Passing the event through, or
/// using a listen-only tap, would make the native HUD appear alongside ours.
@MainActor
final class MediaKeyTap {
    typealias Handler = (MediaKeyEvent) -> Void

    private let handler: Handler
    private var tapPort: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(handler: @escaping Handler) {
        self.handler = handler
    }

    /// Installs the tap. Returns false if the tap could not be created, which
    /// in practice means Accessibility / Input Monitoring permission is missing.
    func start() -> Bool {
        guard tapPort == nil else { return true }

        // Media keys arrive exclusively as NSSystemDefined (event type 14).
        let systemDefinedMask: CGEventMask = 1 << 14

        guard let port = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: systemDefinedMask,
            callback: mediaKeyTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)

        tapPort = port
        runLoopSource = source
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port = tapPort {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        runLoopSource = nil
        tapPort = nil
    }

    /// The system disables a tap whose callback ran too slowly, or when input
    /// permissions change. Re-arming keeps our key handling alive rather than
    /// silently letting the native HUD come back.
    fileprivate func reenable() {
        guard let port = tapPort else { return }
        CGEvent.tapEnable(tap: port, enable: true)
    }

    fileprivate func handle(_ event: MediaKeyEvent) {
        handler(event)
    }
}

/// Runs on the main run loop, so main-actor state is safe to touch via
/// `assumeIsolated`. Kept deliberately small — the system revokes taps whose
/// callbacks are slow.
private let mediaKeyTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<MediaKeyTap>.fromOpaque(userInfo).takeUnretainedValue()

    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        MainActor.assumeIsolated { tap.reenable() }
        return Unmanaged.passUnretained(event)
    }

    guard let mediaKeyEvent = MediaKeyEvent(cgEvent: event) else {
        return Unmanaged.passUnretained(event)
    }

    MainActor.assumeIsolated { tap.handle(mediaKeyEvent) }

    // Swallow key down *and* key up for keys we own, so no fragment of the
    // press reaches the native HUD.
    return nil
}
