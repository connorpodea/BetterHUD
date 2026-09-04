import CoreAudio
import Foundation

/// Reads and writes the system output volume, mirroring the semantics of the
/// hardware volume keys.
///
/// The default output device is resolved once and cached; CoreAudio notifies us
/// when it changes, so a key press never pays for a device lookup.
@MainActor
final class VolumeController {
    /// Apple's hardware keys move the volume in sixteenths.
    static let stepCount: Float = 16
    private static let step: Float = 1 / stepCount

    private var cachedDeviceID: AudioDeviceID?

    init() {
        observeDefaultDeviceChanges()
    }

    // No deinit unregisters the CoreAudio listener: the app owns a single
    // controller for its entire lifetime, so the listener is released with the
    // process. It captures `self` weakly, so it is inert rather than dangling
    // if this ever is deallocated.

    // MARK: - State

    /// Current output level in 0...1, or nil if the device exposes no volume
    /// control (some HDMI and Bluetooth outputs don't).
    var level: Float? {
        guard let device = deviceID else { return nil }
        if let main = scalarVolume(of: device, channel: kAudioObjectPropertyElementMain) {
            return main
        }
        // Fall back to the left/right channels, averaged.
        let channels = [1, 2].compactMap { scalarVolume(of: device, channel: UInt32($0)) }
        guard !channels.isEmpty else { return nil }
        return channels.reduce(0, +) / Float(channels.count)
    }

    var isMuted: Bool {
        guard let device = deviceID else { return false }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted) == noErr else {
            return false
        }
        return muted != 0
    }

    /// True when the output has no adjustable volume, so callers can show a
    /// disabled state rather than a level that never moves.
    var isAdjustable: Bool { level != nil }

    // MARK: - Actions

    /// Steps the volume up or down by one sixteenth, snapped to the step grid.
    ///
    /// Matches the native keys: raising the volume while muted unmutes, and
    /// lowering it to zero mutes.
    func adjust(increasing: Bool) {
        guard let current = level else { return }

        if increasing && isMuted {
            setMuted(false)
        }

        // Snap to the grid first so repeated presses land on clean stops even
        // if another app left the volume at an arbitrary value.
        let steps = (current * Self.stepCount).rounded(increasing ? .down : .up)
        let target = (steps + (increasing ? 1 : -1)) * Self.step
        let clamped = min(max(target, 0), 1)

        setLevel(clamped)

        if !increasing {
            // Reaching the bottom of the range mutes, as the hardware keys do.
            setMuted(clamped <= 0)
        }
    }

    func toggleMute() {
        setMuted(!isMuted)
    }

    func setLevel(_ newLevel: Float) {
        guard let device = deviceID else { return }
        let value = min(max(newLevel, 0), 1)

        if setScalarVolume(value, of: device, channel: kAudioObjectPropertyElementMain) {
            return
        }
        // Devices without a settable main element take per-channel writes.
        for channel in UInt32(1)...UInt32(2) {
            _ = setScalarVolume(value, of: device, channel: channel)
        }
    }

    func setMuted(_ muted: Bool) {
        guard let device = deviceID else { return }
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectHasProperty(device, &address) else { return }
        var value: UInt32 = muted ? 1 : 0
        AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<UInt32>.size), &value
        )
    }

    // MARK: - Device plumbing

    /// Computed and `nonisolated` so `deinit` can reach it: three integer
    /// assignments, so rebuilding it costs nothing versus stored state that
    /// would need actor isolation.
    private nonisolated static var defaultOutputDeviceAddress: AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }

    private var deviceID: AudioDeviceID? {
        if let cachedDeviceID { return cachedDeviceID }

        var address = Self.defaultOutputDeviceAddress
        var device = AudioDeviceID(kAudioObjectUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        ) == noErr, device != kAudioObjectUnknown else { return nil }

        cachedDeviceID = device
        return device
    }

    /// Drops the cached device when the user switches outputs, so we react to
    /// changes without polling.
    private func observeDefaultDeviceChanges() {
        var address = Self.defaultOutputDeviceAddress
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor in self?.cachedDeviceID = nil }
        }
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject), &address, nil, listener
        )
    }

    private func scalarVolume(of device: AudioDeviceID, channel: UInt32) -> Float? {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        guard AudioObjectHasProperty(device, &address) else { return nil }
        var volume: Float = 0
        var size = UInt32(MemoryLayout<Float>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &volume) == noErr else {
            return nil
        }
        return volume
    }

    private func setScalarVolume(_ volume: Float, of device: AudioDeviceID, channel: UInt32) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: channel
        )
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(device, &address),
              AudioObjectIsPropertySettable(device, &address, &settable) == noErr,
              settable.boolValue else { return false }

        var value = volume
        return AudioObjectSetPropertyData(
            device, &address, 0, nil, UInt32(MemoryLayout<Float>.size), &value
        ) == noErr
    }
}
