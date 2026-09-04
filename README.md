# BetterHUD

**Version 0.0.1 — September 4, 2026**

macOS 26 replaced the centered volume and brightness HUD with a small pill in
the corner. BetterHUD brings the old one back — and makes sure the new one
never appears while it's running.

<!-- Screenshot: capture the HUD with ⇧⌘5 (timed capture, since the HUD only
     stays up for 1.5s), save it as docs/screenshot.png, then uncomment:
![BetterHUD showing the volume HUD](docs/screenshot.png)
-->

## What it does

- Draws the classic 200pt centered panel, with a 16-segment level bar
- Uses macOS's own OSD artwork, so the glyphs are the real ones, not lookalikes
- Handles volume, mute, and built-in display brightness
- Plays the volume feedback click, honoring your system setting for it
- Lives in the menu bar; no Dock icon, no window
- Walks you through the one permission it needs on first launch

## Settings

Everything lives in the menu bar item, since each preference is a short list of
choices that a submenu expresses directly:

| Setting | Choices |
| --- | --- |
| Position | Upper, Middle, Lower |
| Duration | 1.0, 1.5, 2.0, or 3.0 seconds |
| Volume Click | Follow system setting, Always, Never |
| Take Over | Volume and mute, Brightness — independently |
| Open at Login | on/off, via `SMAppService` |

Turning off a key type genuinely hands those keys back to macOS: the event tap
only consumes a key when BetterHUD acted on it, so anything left off behaves
natively, native indicator included.

Holding Shift while pressing a volume key inverts the click setting for that
press, the way the native keys do.

## Requirements

- macOS 13 or later (developed and tested on macOS 26.6)
- A Mac with a built-in display, for brightness control
- Accessibility permission (see below)

## Install

Download the latest release, move `BetterHUD.app` to `/Applications` or
`~/Applications`, and launch it.

> **First launch will be blocked by Gatekeeper.** BetterHUD isn't notarized by
> Apple yet, so macOS will say it "cannot be opened because Apple cannot check
> it for malicious software". To open it anyway: **right-click the app → Open**,
> then confirm. Or clear the quarantine flag:
>
> ```sh
> xattr -d com.apple.quarantine /Applications/BetterHUD.app
> ```
>
> You only have to do this once. If you'd rather not, build from source instead
> — a locally built copy isn't quarantined.

Or build from source:

```sh
git clone https://github.com/<your-username>/BetterHUD.git
cd BetterHUD
./Scripts/build-app.sh      # -> ~/Applications/BetterHUD.app
open ~/Applications/BetterHUD.app
```

### Granting permission

BetterHUD needs **Accessibility** permission to see the media keys before macOS
does. On first launch it will ask; if you miss the prompt, use the menu bar item
or:

1. **System Settings → Privacy & Security → Accessibility**
2. Click **+**, add `BetterHUD.app`, and enable it

No relaunch needed — it starts working as soon as the toggle flips. Input
Monitoring is *not* required.

## How it works

macOS draws its own indicator in response to the hardware keys and offers no
API to turn that off. The only reliable approach is to make sure the process
that draws it never receives the key press:

1. A `CGEventTap` is installed for `NSSystemDefined` events at
   `.cghidEventTap` — the lowest point in the event pipeline, before
   WindowServer distributes events to session-level listeners — as an active
   tap.
2. The callback returns `nil` for the volume, mute, and brightness keys, which
   consumes them outright. Both key-down and key-up are swallowed.
3. Since the event is gone, BetterHUD performs the volume or brightness change
   itself and draws its own HUD.

The app is event-driven throughout and does no polling: the event tap, a
CoreAudio device listener, a display-reconfiguration notification, and the
accessibility-change notification are the only things that wake it. The
auto-hide timer is armed only while the HUD is visible, preferences are read at
key-press time rather than cached and observed, and the menu refreshes its
checkmarks only when it opens.

See [CLAUDE.md](CLAUDE.md) for the full architecture notes.

## Limitations

These are deliberate, not oversights:

- **Not sandboxed, so it can never ship on the Mac App Store.** Event taps
  aren't permitted under the App Sandbox. Distribution is direct download only.
- **Brightness uses a private framework.** macOS has no public API for the
  built-in panel's brightness, so `DisplayServicesGetBrightness` /
  `SetBrightness` are resolved with `dlsym`. If a future macOS removes them,
  brightness degrades to unsupported rather than breaking the app.
- **Built-in display only.** External monitors would need DDC/CI, which is out
  of scope.
- **Keyboard backlight keys (F5/F6) aren't handled yet.**

## Apple's artwork

The HUD glyphs are read at runtime from
`/System/Library/CoreServices/OSDUIHelper.app/Contents/Resources`. They are
deliberately **not** copied into the bundle or this repository, so no Apple
artwork is redistributed. If the files ever disappear, the HUD falls back to SF
Symbols.

## Building

```sh
swift build -c release      # binary only
./Scripts/build-app.sh      # assembles and signs the .app
swift Scripts/make-icons.swift   # regenerates the app icon
```

Signing with a certificate rather than ad-hoc matters more than it looks: an
ad-hoc signature's designated requirement is the binary's own cdhash, so every
rebuild looks like a different app to macOS and silently drops the Accessibility
grant. `Scripts/build-app.sh` uses a local code-signing certificate and falls
back to ad-hoc with a warning. CLAUDE.md has the commands to create one.

## Roadmap

- Keyboard backlight keys (F5/F6) — macOS still ships the artwork for them
- Precision mode (⇧⌥ for quarter steps)
- Scroll over the menu bar icon to change volume
- HUD size options
- Notarized DMG releases

## Version history

### 0.0.1 — September 4, 2026

First release.

- Intercepts the volume, mute, and brightness keys at the HID level and
  suppresses the macOS 26 indicator
- Centered HUD panel using macOS's own OSD artwork, with a 16-segment level bar
- Volume, mute, and built-in display brightness control in Apple's sixteenths
- Volume feedback click, honoring the system setting, invertible with Shift
- First-run setup that reports permission state live
- Menu bar settings: position, duration, which keys to take over, volume click,
  and open at login

## License

GPLv3. See [LICENSE](LICENSE).
