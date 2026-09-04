import AppKit

/// Shows the HUD and takes it away again, reproducing the timing and glyphs of
/// the HUD macOS 26 replaced.
///
/// One window and one panel view are built at launch and reused for every
/// press, so showing the HUD costs a layer update rather than any allocation
/// or view construction.
@MainActor
final class OSDController {
    private enum Timing {
        static let fadeIn: TimeInterval = 0.08
        static let fadeOut: TimeInterval = 0.4
    }

    private let window = OSDWindow()
    private let glyphs = OSDGlyphProvider()
    private let settings: Settings
    private var hideTimer: Timer?

    init(settings: Settings) {
        self.settings = settings
    }

    func showVolume(level: Float, isMuted: Bool) {
        // A muted output shows the crossed-out speaker and an empty bar, as the
        // native HUD does. Apple's speaker glyph is a single fixed image, so it
        // doesn't change with the level.
        if isMuted {
            show(icon: glyphs.image(for: .mute), level: 0)
        } else {
            show(icon: glyphs.image(for: .volume), level: level)
        }
    }

    func showBrightness(level: Float) {
        show(icon: glyphs.image(for: .brightness), level: level)
    }

    // MARK: - Presentation

    private func show(icon: NSImage?, level: Float) {
        window.panel.apply(style: settings.style)
        window.panel.update(icon: icon, level: level)

        if !window.isVisible {
            window.position(for: settings.placement)
            window.orderFrontRegardless()
        }

        // Already fully visible on a repeat press: skip the animation entirely
        // and just extend the on-screen time.
        if window.alphaValue < 1 {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = Timing.fadeIn
                window.animator().alphaValue = 1
            }
        }

        scheduleHide()
    }

    private func scheduleHide() {
        hideTimer?.invalidate()

        // A one-shot timer, armed only while the HUD is up, so an idle app has
        // nothing scheduled at all.
        let timer = Timer(timeInterval: settings.visibleDuration, repeats: false) { _ in
            MainActor.assumeIsolated { [weak self] in self?.hide() }
        }
        // Common modes, not the default mode: while a menu is open the run loop
        // is tracking events, and a default-mode timer wouldn't fire until the
        // menu closed — leaving the HUD stuck on screen.
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }

    private func hide() {
        hideTimer = nil
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Timing.fadeOut
            window.animator().alphaValue = 0
        }, completionHandler: {
            MainActor.assumeIsolated { [weak self] in
                guard let self, window.alphaValue == 0 else { return }
                // Ordering out once faded keeps the window off the compositor
                // while idle.
                window.orderOut(nil)
            }
        })
    }
}
