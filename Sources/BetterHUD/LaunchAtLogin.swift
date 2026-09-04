import ServiceManagement

/// The "open at login" toggle, backed by `SMAppService`.
///
/// macOS owns this state — it appears under System Settings → General → Login
/// Items — so there's nothing to persist ourselves; we just read and write it.
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Returns false if macOS refused the change, which happens if the user has
    /// disallowed the login item in System Settings.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}
