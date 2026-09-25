import AppKit

/// The hardware keys we take over, identified by their `NX_KEYTYPE_*` codes
/// from IOKit's `ev_keymap.h`.
enum MediaKey: Int {
    case soundUp = 0        // NX_KEYTYPE_SOUND_UP
    case soundDown = 1      // NX_KEYTYPE_SOUND_DOWN
    case brightnessUp = 2   // NX_KEYTYPE_BRIGHTNESS_UP
    case brightnessDown = 3 // NX_KEYTYPE_BRIGHTNESS_DOWN
    case mute = 7           // NX_KEYTYPE_MUTE
}

/// A decoded volume/brightness key press.
struct MediaKeyEvent {
    let key: MediaKey
    /// True on key down, false on key up.
    let isPressed: Bool
    /// True while the key is being held down and auto-repeating.
    let isRepeat: Bool
}

extension MediaKeyEvent {
    /// Subtype 8 of an `NSSystemDefined` event is `NX_SUBTYPE_AUX_CONTROL_BUTTONS`
    /// — the hardware keys. AppKit's `NSEvent.EventSubtype` names 8 `.screenChanged`,
    /// which is its meaning for `appKitDefined` events only, so we compare the raw
    /// value rather than the misleading case name.
    private static let auxControlButtonsSubtype: Int16 = 8

    /// Decodes a system-defined `CGEvent`, returning nil if it isn't one of the
    /// keys we handle.
    ///
    /// Bridging to `NSEvent` allocates, but these events only arrive at
    /// human keypress rates, so it costs nothing measurable and is the only
    /// documented way to read `subtype` and `data1`.
    init?(cgEvent: CGEvent) {
        guard let event = NSEvent(cgEvent: cgEvent),
              event.subtype.rawValue == Self.auxControlButtonsSubtype else { return nil }
        self.init(data1: event.data1)
    }

    /// Decodes the payload an aux-control event packs into `data1`: the key
    /// code in the high 16 bits, and the key's flags in the low 16.
    ///
    /// ```
    /// bits 31-16   which key (NX_KEYTYPE_SOUND_UP = 0, MUTE = 7, ...)
    /// bits 15-8    0x0A means key down; anything else is key up
    /// bit 0        set while the key is auto-repeating
    /// ```
    ///
    /// Split out from the initializer above so the layout — the part that is
    /// documented nowhere and has every opportunity to be subtly wrong — can be
    /// tested without conjuring a real system event.
    init?(data1: Int) {
        guard let key = MediaKey(rawValue: (data1 & 0xFFFF_0000) >> 16) else { return nil }

        let keyFlags = data1 & 0x0000_FFFF
        self.key = key
        self.isPressed = ((keyFlags & 0xFF00) >> 8) == 0x0A
        self.isRepeat = (keyFlags & 0x1) == 0x1
    }
}
