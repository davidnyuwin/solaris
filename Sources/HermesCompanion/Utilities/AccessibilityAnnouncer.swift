import Foundation
import AppKit

/// Posts VoiceOver / accessibility announcements on macOS using AppKit's
/// NSAccessibility announcement API.  All methods are safe no-ops if the
/// underlying API is unavailable or if VoiceOver is not active.
enum AccessibilityAnnouncer {

    /// Post an announcement string to the running accessibility client
    /// (e.g. VoiceOver).
    static func announce(_ message: String) {
        guard NSWorkspace.shared.isVoiceOverEnabled else { return }

        let element = NSApp.mainWindow ?? NSApp as Any
        let key = NSAccessibility.NotificationUserInfoKey(rawValue: "AXAnnouncement")
        NSAccessibility.post(element: element, notification: .announcementRequested, userInfo: [
            key: message
        ])
    }
}
