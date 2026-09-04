import AppKit
import ApplicationServices
import os

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

let volumeController = VolumeController()

// Brightness keys are still inert until the DisplayServices bridge lands.
let mediaKeyTap = MediaKeyTap { event in
    guard event.isPressed else { return }

    switch event.key {
    case .soundUp:
        volumeController.adjust(increasing: true)
    case .soundDown:
        volumeController.adjust(increasing: false)
    case .mute:
        // Ignore auto-repeat so holding the key doesn't flap the mute state.
        if !event.isRepeat { volumeController.toggleMute() }
    case .brightnessUp, .brightnessDown:
        break
    }
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
