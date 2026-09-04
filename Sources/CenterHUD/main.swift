import AppKit
import ApplicationServices
import os

// Step 3 spike: intercept the keys and log them, without changing volume or
// brightness yet. This isolates the one risky question — does consuming the
// event actually suppress the native macOS HUD?
let log = Logger(subsystem: "com.connorpodea.centerhud", category: "mediakeys")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// The tap cannot be created without Accessibility trust. Prompting here is
// temporary; this moves into PermissionManager once the app has a menu bar UI.
// The key is spelled out rather than using `kAXTrustedCheckOptionPrompt`: that
// constant imports as a mutable global, which Swift 6 rejects as not
// concurrency-safe.
let isTrusted = AXIsProcessTrustedWithOptions(
    ["AXTrustedCheckOptionPrompt": true] as CFDictionary
)

let mediaKeyTap = MediaKeyTap { event in
    log.notice("""
        intercepted \(String(describing: event.key), privacy: .public) \
        pressed=\(event.isPressed, privacy: .public) \
        repeat=\(event.isRepeat, privacy: .public)
        """)
}

if mediaKeyTap.start() {
    log.notice("event tap active (trusted=\(isTrusted, privacy: .public)); media keys are being swallowed")
} else {
    log.error("""
        event tap could not be created (trusted=\(isTrusted, privacy: .public)); \
        grant Accessibility and Input Monitoring to CenterHUD.app
        """)
}

app.run()
