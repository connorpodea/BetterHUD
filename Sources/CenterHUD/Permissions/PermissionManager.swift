import AppKit
import ApplicationServices

/// Tracks whether the app is trusted for Accessibility, which is what the event
/// tap requires.
///
/// Rather than polling, it listens for the system's accessibility-change
/// notification, so granting the permission takes effect immediately instead of
/// requiring a relaunch.
@MainActor
final class PermissionManager {
    /// Called when trust status changes, so the app can install the tap without
    /// being restarted.
    var onTrustChanged: (() -> Void)?

    /// Posted by the system when any app's accessibility trust changes.
    private static let trustChangeNotification = Notification.Name("com.apple.accessibility.api")

    var isTrusted: Bool { AXIsProcessTrusted() }

    init() {
        DistributedNotificationCenter.default().addObserver(
            forName: Self.trustChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // AXIsProcessTrusted briefly lags the notification, so re-check
            // after a short delay rather than trusting it immediately.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                MainActor.assumeIsolated { self?.onTrustChanged?() }
            }
        }
    }

    /// Shows the system's permission prompt if the app isn't trusted yet.
    @discardableResult
    func promptIfNeeded() -> Bool {
        // The option key is spelled out because `kAXTrustedCheckOptionPrompt`
        // imports as a mutable global, which Swift 6 rejects as not
        // concurrency-safe.
        AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
    }

    /// Opens the exact settings pane the user needs, since the prompt's own
    /// button only appears the first time.
    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }
}
