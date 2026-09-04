import AppKit
import ApplicationServices
import os

let log = Logger(subsystem: "com.connorpodea.centerhud", category: "mediakeys")

let app = NSApplication.shared
app.setActivationPolicy(.accessory)

// The key is spelled out rather than using `kAXTrustedCheckOptionPrompt`: that
// constant imports as a mutable global, which Swift 6 rejects as not
// concurrency-safe.
let isTrusted = AXIsProcessTrustedWithOptions(
    ["AXTrustedCheckOptionPrompt": true] as CFDictionary
)

let volumeController = VolumeController()
let brightnessController = BrightnessController()
let osdController = OSDController()

log.notice("""
    startup: volume=\(volumeController.level.map { "\($0)" } ?? "unavailable", privacy: .public) \
    brightness=\(brightnessController.level.map { "\($0)" } ?? "unsupported", privacy: .public)
    """)

let mediaKeyTap = MediaKeyTap { event in
    guard event.isPressed else { return }

    switch event.key {
    case .soundUp, .soundDown:
        volumeController.adjust(increasing: event.key == .soundUp)
        // Read the level back rather than predicting it, so the HUD reflects
        // what the hardware actually accepted.
        guard let level = volumeController.level else { return }
        osdController.showVolume(level: level, isMuted: volumeController.isMuted)

    case .mute:
        // Ignore auto-repeat so holding the key doesn't flap the mute state.
        guard !event.isRepeat else { return }
        volumeController.toggleMute()
        guard let level = volumeController.level else { return }
        osdController.showVolume(level: level, isMuted: volumeController.isMuted)

    case .brightnessUp, .brightnessDown:
        brightnessController.adjust(increasing: event.key == .brightnessUp)
        guard let level = brightnessController.level else { return }
        osdController.showBrightness(level: level)
    }
}

if mediaKeyTap.start() {
    log.notice("event tap active (trusted=\(isTrusted, privacy: .public)); media keys are being swallowed")
} else {
    log.error("""
        event tap could not be created (trusted=\(isTrusted, privacy: .public)); \
        grant Accessibility to CenterHUD.app
        """)
}

app.run()
