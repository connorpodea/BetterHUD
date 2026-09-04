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
        /// How long the HUD stays at full opacity after the last key press.
        static let visibleDuration: TimeInterval = 1.5
        static let fadeIn: TimeInterval = 0.08
        static let fadeOut: TimeInterval = 0.4
    }

    private enum Glyph {
        static let pointSize: CGFloat = 76
        static let volume = "speaker.wave.3.fill"
        static let muted = "speaker.slash.fill"
        static let brightness = "sun.max.fill"
    }

    private let window = OSDWindow()
    private var hideTimer: Timer?

    /// Symbol images are cached because the volume glyph varies with level:
    /// rebuilding it on every press would allocate for no reason.
    private var glyphCache: [String: NSImage] = [:]

    func showVolume(level: Float, isMuted: Bool) {
        // A muted output shows the crossed-out speaker and an empty bar.
        if isMuted {
            show(icon: glyph(named: Glyph.muted), level: 0)
        } else {
            show(icon: glyph(named: Glyph.volume, variableValue: Double(level)), level: level)
        }
    }

    func showBrightness(level: Float) {
        show(icon: glyph(named: Glyph.brightness), level: level)
    }

    // MARK: - Presentation

    private func show(icon: NSImage?, level: Float) {
        window.panel.update(icon: icon, level: level)

        if !window.isVisible {
            window.positionOnActiveScreen()
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
        hideTimer = Timer.scheduledTimer(
            withTimeInterval: Timing.visibleDuration, repeats: false
        ) { _ in
            MainActor.assumeIsolated { [weak self] in self?.hide() }
        }
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

    // MARK: - Glyphs

    private func glyph(named name: String, variableValue: Double? = nil) -> NSImage? {
        // Quantize the variable value to the 16 steps the keys produce, so the
        // cache has a small fixed number of entries.
        let step = variableValue.map { Int(($0 * 16).rounded()) }
        let key = step.map { "\(name)#\($0)" } ?? name
        if let cached = glyphCache[key] { return cached }

        let image: NSImage? = if let step {
            NSImage(
                systemSymbolName: name,
                variableValue: Double(step) / 16,
                accessibilityDescription: nil
            )
        } else {
            NSImage(systemSymbolName: name, accessibilityDescription: nil)
        }

        guard let configured = image?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: Glyph.pointSize, weight: .regular)
        ) else { return nil }

        configured.isTemplate = true
        glyphCache[key] = configured
        return configured
    }
}
