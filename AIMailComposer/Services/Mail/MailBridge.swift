import Foundation
import AppKit

enum MailBridgeError: LocalizedError {
    case scriptFailed(String)
    case noSelection(String)
    case mailNotRunning
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .scriptFailed(let msg): return "AppleScript error: \(msg)"
        case .noSelection(let debug):
            if debug.isEmpty {
                return "No email selected in Mail. Select a message and try again."
            }
            return "Could not find email thread. Debug: \(debug)"
        case .mailNotRunning: return "Mail is not running. Open Mail and try again."
        case .parseError(let msg): return "Failed to parse email thread: \(msg)"
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

    static func fetchEmailThread() async throws -> EmailThread {
        guard await isMailRunning() else {
            throw MailBridgeError.mailNotRunning
        }

        let raw = try await executeAppleScript(MailScripts.fetchThread)

        if raw.hasPrefix("ERROR:NO_SELECTION") {
            let debug = raw.replacingOccurrences(of: "ERROR:NO_SELECTION|", with: "")
                .replacingOccurrences(of: "ERROR:NO_SELECTION", with: "")
            throw MailBridgeError.noSelection(debug)
        }

        return try MailThreadParser.parse(raw)
    }

    @MainActor
    static func insertReply(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Bring Mail to front
        if let mailApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.mail").first {
            mailApp.activate(options: .activateIgnoringOtherApps)
        }
    }
}
