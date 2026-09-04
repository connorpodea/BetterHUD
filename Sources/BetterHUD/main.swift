import AppKit

let app = NSApplication.shared
// Menu-bar-only: no Dock icon, no app menu.
app.setActivationPolicy(.accessory)

// Held for the process lifetime; NSApplication keeps only a weak delegate.
let delegate = AppDelegate()
app.delegate = delegate

app.run()
