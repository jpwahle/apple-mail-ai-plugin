import AppKit

/// Checks and requests macOS Accessibility (AX) permission.
///
/// On macOS 15+ Mail's `outgoing messages` AppleScript collection is broken,
/// so the app needs AX access to read the compose window's fields directly.
enum AXPermissionChecker {

    /// True if the app is trusted for Accessibility access.
    static func isGranted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Trigger the system's one-time Accessibility permission prompt.
    /// Returns the new trusted state (the prompt may have just been shown).
    static func request() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Open System Settings → Privacy & Security → Accessibility.
    static func openSettings() {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
