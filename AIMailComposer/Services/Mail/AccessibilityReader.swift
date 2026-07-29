import Foundation
import AppKit

/// Reads the Mail compose window's fields via the Accessibility (AX) API.
///
/// macOS 15 (Sequoia) and later broke Mail's `outgoing messages` AppleScript
/// collection — it returns 0 even with a compose window open. This reader
/// traverses Mail's AX tree to recover the subject, recipients, and draft
/// content directly from the window's text fields.
///
/// Read-only: never sends keystrokes or modifies the compose window.
enum AccessibilityReader {

    struct ComposeContext {
        let subject: String
        let recipients: [String]
        let draftContent: String
    }

    /// Traverse all Mail windows and return the context of the first one that
    /// looks like a compose window (has a `Mail.subjectField` or a
    /// `message body` web area). Returns `nil` if no compose window is found
    /// or if the app lacks Accessibility permission.
    static func readComposeWindow() -> ComposeContext? {
        guard AXIsProcessTrusted() else { return nil }

        guard let mailApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first else {
            return nil
        }
        let app = AXUIElementCreateApplication(mailApp.processIdentifier)

        var windowsRef: CFTypeRef?
        AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        guard let windows = windowsRef as? [AXUIElement] else { return nil }

        for window in windows {
            if let ctx = readWindow(window) {
                return ctx
            }
        }
        return nil
    }

    // MARK: - Per-window

    /// Returns context if the given AX window is a Mail compose window.
    private static func readWindow(_ window: AXUIElement) -> ComposeContext? {
        // Compose windows contain a `Mail.subjectField` or a `message body` web area.
        // Viewer windows have `Mail.messageViewer.window` ids and contain AXSplitGroup.
        guard hasComposeMarker(window) else { return nil }

        let subject = fieldValue(window, identifier: "Mail.subjectField") ?? ""
        let recipients = collectRecipients(window)
        let draft = readDraftBody(window)

        return ComposeContext(
            subject: subject,
            recipients: recipients,
            draftContent: draft
        )
    }

    /// True if the window contains a compose-specific field id.
    private static func hasComposeMarker(_ window: AXUIElement) -> Bool {
        for id in ["Mail.subjectField", "Mail.toField"] {
            if findFirst(window, identifier: id) != nil {
                return true
            }
        }
        return false
    }

    // MARK: - Recipients

    /// Read all recipient fields (To, CC, BCC, Reply-To) and extract addresses.
    private static func collectRecipients(_ window: AXUIElement) -> [String] {
        var recipients: [String] = []
        for id in ["Mail.toField", "Mail.ccField", "Mail.bccField"] {
            if let field = findFirst(window, identifier: id) {
                if let addr = extractAddress(from: field), !addr.isEmpty {
                    recipients.append(addr)
                }
            }
        }
        return recipients
    }

    /// Recipient fields contain a child `AXStaticText` with the formatted
    /// "Name <email>" string; the field's own value is just an attachment
    /// placeholder. Walk children to find the static text.
    private static func extractAddress(from field: AXUIElement) -> String? {
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(field, kAXChildrenAttribute as CFString, &childrenRef)
        guard let children = childrenRef as? [AXUIElement] else { return nil }

        var parts: [String] = []
        for child in children {
            if let role = axRole(child), role == "AXStaticText" {
                if let val = axValue(child), !val.isEmpty {
                    parts.append(val)
                }
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    // MARK: - Draft body

    /// Find the `AXWebArea` with description "message body" and concatenate
    /// all `AXStaticText` children to recover the draft content.
    private static func readDraftBody(_ window: AXUIElement) -> String {
        guard let bodyArea = findFirst(window, role: "AXWebArea", description: "message body") else {
            return ""
        }
        var lines: [String] = []
        collectText(into: &lines, from: bodyArea)
        return lines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Depth-first walk collecting `AXStaticText` / `AXTextArea` values.
    private static func collectText(into lines: inout [String], from element: AXUIElement) {
        if let role = axRole(element) {
            if role == "AXStaticText" || role == "AXTextArea" {
                if let val = axValue(element), !val.isEmpty {
                    lines.append(val)
                }
            }
        }
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                collectText(into: &lines, from: child)
            }
        }
    }

    // MARK: - AX helpers

    /// Find the first descendant matching an AXIdentifier.
    private static func findFirst(_ element: AXUIElement, identifier: String) -> AXUIElement? {
        if let id = axIdentifier(element), id == identifier {
            return element
        }
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFirst(child, identifier: identifier) {
                    return found
                }
            }
        }
        return nil
    }

    /// Find the first descendant matching role + description.
    private static func findFirst(_ element: AXUIElement, role: String, description: String) -> AXUIElement? {
        if let r = axRole(element), r == role {
            if let d = axDescription(element), d == description {
                return element
            }
        }
        var childrenRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef)
        if let children = childrenRef as? [AXUIElement] {
            for child in children {
                if let found = findFirst(child, role: role, description: description) {
                    return found
                }
            }
        }
        return nil
    }

    /// Read the `AXValue` of an element identified by `identifier`.
    private static func fieldValue(_ element: AXUIElement, identifier: String) -> String? {
        guard let target = findFirst(element, identifier: identifier) else { return nil }
        return axValue(target)
    }

    private static func axRole(_ el: AXUIElement) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXRoleAttribute as CFString, &ref)
        return ref as? String
    }

    private static func axDescription(_ el: AXUIElement) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXDescriptionAttribute as CFString, &ref)
        return ref as? String
    }

    private static func axValue(_ el: AXUIElement) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXValueAttribute as CFString, &ref)
        return ref as? String
    }

    private static func axIdentifier(_ el: AXUIElement) -> String? {
        var ref: CFTypeRef?
        AXUIElementCopyAttributeValue(el, kAXIdentifierAttribute as CFString, &ref)
        return ref as? String
    }
}
