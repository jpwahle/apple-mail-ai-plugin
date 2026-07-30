import Foundation
import AppKit

enum MailBridgeError: LocalizedError {
    case scriptFailed(String)
    case noComposer
    case mailNotRunning
    case parseError(String)
    case accessibilityDenied

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg):
            return "AppleScript error: \(msg)"
        case .noComposer:
            return "Open a compose window in Mail first, then try again."
        case .mailNotRunning:
            return "Mail is not running. Open Mail and try again."
        case .parseError(let msg):
            return "Failed to parse Mail context: \(msg)"
        case .accessibilityDenied:
            return "Accessibility permission is needed to read your Mail compose window."
        }
    }
}

final class MailBridge {
    static func executeAppleScript(_ source: String) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                guard let script = NSAppleScript(source: source) else {
                    continuation.resume(throwing: MailBridgeError.scriptFailed("Failed to create script"))
                    return
                }
                let result = script.executeAndReturnError(&error)
                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
                    continuation.resume(throwing: MailBridgeError.scriptFailed(message))
                } else {
                    continuation.resume(returning: result.stringValue ?? "")
                }
            }
        }
    }

    static func isMailRunning() async -> Bool {
        do {
            let result = try await executeAppleScript(MailScripts.checkMailRunning)
            return result.lowercased() == "true"
        } catch {
            return false
        }
    }

    /// Pull context from the currently open Mail compose window.
    /// Never reads from the message list — the compose window is the source of truth.
    static func fetchComposerContext() async throws -> ComposerContext {
        guard await isMailRunning() else {
            throw MailBridgeError.mailNotRunning
        }

        let raw = try await executeAppleScript(MailScripts.fetchComposerContext)

        if raw.hasPrefix("ERROR:NO_COMPOSER") {
            throw MailBridgeError.noComposer
        }

        return try MailThreadParser.parseComposerContext(raw)
    }

    /// Pull context, falling back to the Accessibility reader when Mail's
    /// `outgoing messages` AppleScript collection is empty (macOS 15+).
    /// Throws `accessibilityDenied` if the AX fallback is required but
    /// permission hasn't been granted.
    static func fetchComposerContextWithAXFallback() async throws -> ComposerContext {
        guard await isMailRunning() else {
            throw MailBridgeError.mailNotRunning
        }

        let raw = try await executeAppleScript(MailScripts.fetchComposerContext)

        if raw.hasPrefix("ERROR:NO_COMPOSER") {
            throw MailBridgeError.noComposer
        }

        let context = try MailThreadParser.parseComposerContext(raw)

        // If Pass 1 (outgoing messages) found nothing but Pass 2 identified
        // a compose window by name, the AppleScript path is broken (macOS
        // 15+). Fall back to the Accessibility reader.
        if context.recipients.isEmpty && context.currentDraft.isEmpty {
            return try fetchViaAccessibility(context: context)
        }

        return context
    }

    /// Use the AX reader to populate recipients/subject/draft. If AX isn't
    /// trusted, throw so the UI can guide the user to grant permission.
    private static func fetchViaAccessibility(context: ComposerContext) throws -> ComposerContext {
        guard AXPermissionChecker.isGranted() else {
            throw MailBridgeError.accessibilityDenied
        }

        guard let ax = AccessibilityReader.readComposeWindow() else {
            // AX is granted but no compose window was found — return the
            // original (possibly empty) context rather than failing.
            return context
        }

        let thread = context.thread
        let subject = ax.subject.isEmpty ? context.subject : ax.subject

        return ComposerContext(
            recipients: ax.recipients,
            subject: subject,
            currentDraft: ax.draftContent,
            thread: thread,
            composeWindowFrame: context.composeWindowFrame
        )
    }

    /// Write the reply directly into the current Mail compose window.
    /// Falls back to the clipboard if the AppleScript insert fails.
    @MainActor
    static func insertReply(_ text: String) async {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        _ = try? await executeAppleScript(MailScripts.insertReply(text))
        activateMail()
    }

    @MainActor
    private static func activateMail() {
        if let mailApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first {
            mailApp.activate()
        }
    }
}
