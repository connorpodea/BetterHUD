import Testing

@testable import BetterHUD

/// The `data1` layout these assert is documented nowhere in Apple's headers
/// beyond the key codes themselves, so it was arrived at by reading the bits
/// off real presses. That makes it exactly the kind of thing that should be
/// pinned down: a wrong shift or mask still compiles, still runs, and shows up
/// as a key that quietly does nothing.
struct MediaKeyEventTests {
    /// Builds the payload the way the window server does: key code in the high
    /// half, flags in the low half.
    private static func data1(key: Int, flags: Int) -> Int {
        (key << 16) | flags
    }

    private static let keyDown = 0x0A00
    private static let keyUp = 0x0B00
    private static let keyDownRepeating = 0x0A01

    @Test("Every key code we claim decodes to the key we expect")
    func decodesKnownKeyCodes() {
        let expected: [(code: Int, key: MediaKey)] = [
            (0, .soundUp),
            (1, .soundDown),
            (2, .brightnessUp),
            (3, .brightnessDown),
            (7, .mute),
        ]

        for (code, key) in expected {
            let event = MediaKeyEvent(data1: Self.data1(key: code, flags: Self.keyDown))
            #expect(event?.key == key, "key code \(code)")
        }
    }

    @Test("A key we don't handle decodes to nil rather than to the wrong key")
    func rejectsUnhandledKeyCodes() {
        // 21 and 22 are the keyboard backlight keys. They arrive as the same
        // kind of event as ours and must fall through untouched, which is why
        // they still show the macOS indicator.
        #expect(MediaKeyEvent(data1: Self.data1(key: 21, flags: Self.keyDown)) == nil)
        #expect(MediaKeyEvent(data1: Self.data1(key: 22, flags: Self.keyDown)) == nil)
        // Play/pause, and a value well past anything defined.
        #expect(MediaKeyEvent(data1: Self.data1(key: 16, flags: Self.keyDown)) == nil)
        #expect(MediaKeyEvent(data1: Self.data1(key: 999, flags: Self.keyDown)) == nil)
    }

    @Test("Key down and key up are told apart by the high byte of the flags")
    func decodesPressState() {
        let down = MediaKeyEvent(data1: Self.data1(key: 0, flags: Self.keyDown))
        #expect(down?.isPressed == true)

        let up = MediaKeyEvent(data1: Self.data1(key: 0, flags: Self.keyUp))
        #expect(up?.isPressed == false)
    }

    @Test("Auto-repeat is read from the low bit, independently of press state")
    func decodesRepeatFlag() {
        let firstPress = MediaKeyEvent(data1: Self.data1(key: 7, flags: Self.keyDown))
        #expect(firstPress?.isRepeat == false)
        #expect(firstPress?.isPressed == true)

        let held = MediaKeyEvent(data1: Self.data1(key: 7, flags: Self.keyDownRepeating))
        #expect(held?.isRepeat == true)
        #expect(held?.isPressed == true)
    }

    @Test("The key code is read from the high half only, whatever the flags say")
    func flagsDoNotLeakIntoTheKeyCode() {
        // Every flag bit set. If the mask were wrong, the key code would come
        // back as something other than mute — or as nil.
        let event = MediaKeyEvent(data1: Self.data1(key: 7, flags: 0xFFFF))
        #expect(event?.key == .mute)
        #expect(event?.isPressed == false)
        #expect(event?.isRepeat == true)
    }
}
