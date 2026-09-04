# BetterHUD

**Version 0.0.1 (September 4, 2026)**

macOS 26 replaced the centered volume and brightness HUD with a small indicator
in the corner of the screen. BetterHUD brings the centered panel back, and stops
the new indicator from appearing while it runs.

<p align="center">
  <img src="docs/volume.png" width="46%" alt="The volume HUD">
  <img src="docs/brightness.png" width="46%" alt="The brightness HUD">
</p>

## Features

* Centered 200pt panel with a 16 segment level bar, matching the old design
* Uses the OSD artwork that ships with macOS, so the glyphs are the real ones
* Controls volume, mute, and built in display brightness in steps of 1/16, the
  same increment the hardware keys use
* Plays the volume click that macOS normally makes, following your system
  setting for it
* Lives in the menu bar with no Dock icon and no windows
* Guides you through the one permission it needs the first time you launch it

## Requirements

* macOS 13 or later, developed and tested on macOS 26.6
* A Mac with a built in display, for brightness control
* Accessibility permission, described below

## Install

1. Download the latest release and move `BetterHUD.app` to `/Applications` or
   `~/Applications`.
2. Open it. The first launch is blocked by Gatekeeper, since the app is not
   notarized by Apple yet. Right click the app, choose **Open**, then confirm.
   If you would rather do it from the terminal:

   ```sh
   xattr -d com.apple.quarantine /Applications/BetterHUD.app
   ```

   You only need this once. A copy you build yourself is not quarantined.
3. A setup window explains what the app does and walks you through the
   permission below.

### Granting Accessibility permission

BetterHUD needs Accessibility permission so it can see the media keys before
macOS does.

1. Open **System Settings > Privacy & Security > Accessibility**
2. Click **+**, add `BetterHUD.app`, and turn it on

There is nothing to restart. The app notices the change and starts working
within about a second. Input Monitoring is not required.

## Settings

Everything is in the menu bar item, since each setting is a short list of
choices. Opening at login is set during first launch setup, and afterwards from
System Settings > General > Login Items.

| Setting | Choices |
| --- | --- |
| Position | Upper, Middle, Lower |
| Show for | 1.0, 1.5, or 2.0 seconds |
| Opacity | Panel background at 0, 25, 50, 75, or 100 percent |
| Take over | Volume and mute, Brightness, independently |
| Volume click | System, Always, Never |

Turning off a key type hands those keys back to macOS. The app only swallows a
key press it actually acted on, so anything you turn off behaves normally,
including the system indicator.

Holding Shift while pressing a volume key flips the click setting for that press,
which is how the hardware keys behave.

## How it works

macOS draws its own indicator when you press the hardware keys, and there is no
API to turn that off. The only reliable approach is to make sure the process
that draws it never receives the key press.

1. A `CGEventTap` listens for `NSSystemDefined` events at `.cghidEventTap`, the
   lowest point in the event pipeline, before WindowServer hands events to
   session level listeners. The tap is active rather than passive.
2. The callback returns `nil` for the volume, mute, and brightness keys, which
   consumes them. Both key down and key up are swallowed, so no part of the
   press gets through.
3. Since the event is gone, BetterHUD changes the volume or brightness itself
   and draws its own HUD.

Nothing polls. The event tap, a CoreAudio device listener, a display
reconfiguration notification, and the accessibility change notification are the
only things that wake the app. The auto hide timer is armed only while the HUD
is visible, settings are read when a key is pressed rather than cached, and the
menu updates its checkmarks only when it opens.

## Limitations

These are design decisions, not oversights.

* **Not sandboxed, so it cannot ship on the Mac App Store.** Event taps are not
  allowed under the App Sandbox, so distribution is by direct download.
* **Brightness relies on a private framework.** macOS has no public API for the
  built in display's brightness, so `DisplayServicesGetBrightness` and
  `DisplayServicesSetBrightness` are looked up with `dlsym`. If a future version
  of macOS removes them, brightness stops working and the rest of the app
  carries on.
* **Built in display only.** External monitors need DDC/CI, which is out of
  scope.
* **Keyboard backlight keys are not handled yet.**

## Artwork from macOS

The HUD glyphs are read at runtime from
`/System/Library/CoreServices/OSDUIHelper.app/Contents/Resources`. They are not
copied into the app bundle or this repository, so no Apple artwork is
redistributed. If those files ever disappear, the HUD falls back to SF Symbols.

## Building from source

```sh
swift build -c release          # binary only
./Scripts/build-app.sh          # assembles and signs BetterHUD.app
swift Scripts/make-icons.swift  # regenerates the app icon
```

The build script signs with a code signing certificate if it finds one, and
falls back to ad hoc signing with a warning. This matters more than it sounds:
an ad hoc signature ties the app's identity to the binary's hash, so every
rebuild looks like a different app to macOS and quietly drops the Accessibility
permission you granted. Point it at your own identity with
`BETTERHUD_SIGN_IDENTITY="Your Certificate Name"`, and choose where the app is
built with `BETTERHUD_INSTALL_DIR`.

## Version history

### 0.0.1 (September 4, 2026)

First release.

* Intercepts the volume, mute, and brightness keys at the HID level and
  suppresses the macOS 26 indicator
* Centered HUD panel using the OSD artwork from macOS, with a 16 segment bar
* Volume, mute, and built in display brightness control
* Volume click, following the system setting, flippable with Shift
* First launch setup that reports permission state as it changes
* Menu bar settings for position, duration, which keys to take over, volume
  click, and opening at login

## Author

**Connor Podea**, CS student at Arizona State University.

## License

GPLv3. See [LICENSE](LICENSE).
