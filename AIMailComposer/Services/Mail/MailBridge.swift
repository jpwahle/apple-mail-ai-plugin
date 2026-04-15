import Foundation
import AppKit

enum MailBridgeError: LocalizedError {
    case scriptFailed(String)
    case noComposer
    case mailNotRunning
    case parseError(String)

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
