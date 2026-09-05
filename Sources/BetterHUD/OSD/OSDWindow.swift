import AppKit

/// The floating window the HUD is drawn in.
///
/// A non-activating panel is essential: pressing a volume key must never pull
/// focus away from whatever app you're working in.
final class OSDWindow: NSPanel {
    let panel = OSDPanelView(frame: .zero)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: OSDPanelView.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        // Above full-screen apps and the menu bar, matching the native HUD.
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]

        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        // Clicks pass straight through to whatever is underneath.
        ignoresMouseEvents = true
        // Keep it out of Mission Control, screenshots of window lists, etc.
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        alphaValue = 0

        contentView = panel
    }

    /// The HUD must never become key or main, or it would steal focus.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// Brings the HUD up on whichever desktop is in front.
    ///
    /// The collection behavior is reapplied rather than trusted from `init`,
    /// and the window is ordered front on every show, not just when it's
    /// hidden. Skipping the order when it was already on screen left it
    /// asserted on the desktop where it last appeared, so switching spaces
    /// meant the keys still worked while the HUD stayed behind.
    func presentOnActiveSpace() {
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        orderFrontRegardless()
    }

    /// Inset used by the upper and lower placements. The lower one matches
    /// where macOS used to draw its own HUD.
    private static let edgeOffset: CGFloat = 140

    /// Positions on the screen containing the pointer, so on a multi-display
    /// setup the HUD appears where the user is looking.
    func position(for placement: Settings.Placement) {
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.frame else { return }

        let y = switch placement {
        case .upper: frame.maxY - Self.edgeOffset - OSDPanelView.size.height
        case .center: frame.midY - OSDPanelView.size.height / 2
        case .lower: frame.minY + Self.edgeOffset
        }
        setFrameOrigin(NSPoint(x: frame.midX - OSDPanelView.size.width / 2, y: y))
    }
}
