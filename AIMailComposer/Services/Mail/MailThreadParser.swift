import Foundation
import CoreGraphics

enum MailThreadParser {
    static func parseComposerContext(_ raw: String) throws -> ComposerContext {
        let parts = raw.components(separatedBy: "---END_COMPOSER---")
        guard parts.count >= 1 else {
            throw MailBridgeError.parseError("Missing composer header")
        }

        let composerBlock = parts[0]
        let parsed = parseComposerBlock(composerBlock)

        let rest = parts.count > 1 ? parts[1] : ""
        let messages = parseThreadMessages(rest)

        let thread: EmailThread?
        if messages.isEmpty {
            thread = nil
        } else {
            let displaySubject = parsed.subject.isEmpty
                ? (messages.first?.subject ?? "")
                : parsed.subject
            thread = EmailThread(subject: displaySubject, messages: messages)
        }

        return ComposerContext(
            recipients: parsed.recipients,
            subject: parsed.subject,
            currentDraft: parsed.draft,
            thread: thread,
            composeWindowFrame: parsed.frame
        )
    }

    // MARK: - Composer block

    private static func parseComposerBlock(_ block: String) -> (subject: String, recipients: [String], draft: String, frame: CGRect?) {
        var subject = ""
        var recipients: [String] = []
        var draftLines: [String] = []
        var frame: CGRect?
        var inDraft = false

        for rawLine in block.components(separatedBy: "\n") {
            let line = rawLine
            if line.hasPrefix("SUBJECT:") {
                subject = String(line.dropFirst("SUBJECT:".count))
                    .trimmingCharacters(in: .whitespaces)
            } else if line.hasPrefix("TO:") {
                recipients = String(line.dropFirst("TO:".count))
                    .components(separatedBy: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
            } else if line.hasPrefix("FRAME:") {
                let value = String(line.dropFirst("FRAME:".count))
                frame = parseFrame(value)
            } else if line == "DRAFT_START" {
                inDraft = true
            } else if line == "DRAFT_END" {
                inDraft = false
            } else if inDraft {
                draftLines.append(line)
            }
        }

        let draft = draftLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (subject, recipients, draft, frame)
    }

    /// AppleScript's `bounds` returns `{left, top, right, bottom}` in AX
    /// coordinates (origin at top-left of the primary display, y grows down).
    /// Convert to a top-left-origin CGRect with width/height.
    private static func parseFrame(_ value: String) -> CGRect? {
        let parts = value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 4 else { return nil }
        let doubles = parts.compactMap { Double($0) }
        guard doubles.count == 4 else { return nil }
        let left = doubles[0]
        let top = doubles[1]
        let right = doubles[2]
        let bottom = doubles[3]
        let width = max(0, right - left)
        let height = max(0, bottom - top)
        guard width > 0, height > 0 else { return nil }
        return CGRect(x: left, y: top, width: width, height: height)
    }

    // MARK: - Thread messages

    private static func parseThreadMessages(_ raw: String) -> [EmailMessage] {
        let blocks = raw
            .components(separatedBy: "---END_MESSAGE---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var messages: [EmailMessage] = []
        for block in blocks {
            var sender = ""
            var recipients: [String] = []
            var subject = ""
            var dateString = ""
            var bodyLines: [String] = []
            var inBody = false

            for line in block.components(separatedBy: "\n") {
                if line.hasPrefix("FROM:") {
                    sender = String(line.dropFirst(5))
                } else if line.hasPrefix("TO:") {
                    recipients = String(line.dropFirst(3))
                        .components(separatedBy: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                } else if line.hasPrefix("SUBJECT:") {
                    subject = String(line.dropFirst(8))
                } else if line.hasPrefix("DATE:") {
                    dateString = String(line.dropFirst(5))
                } else if line == "BODY_START" {
                    inBody = true
                } else if line == "BODY_END" {
                    inBody = false
                } else if inBody {
                    bodyLines.append(line)
                }
            }

            messages.append(EmailMessage(
                sender: sender,
                recipients: recipients,
                subject: subject,
                dateSent: parseDate(dateString),
                body: bodyLines.joined(separator: "\n")
            ))
        }

        messages.sort { ($0.dateSent ?? .distantPast) < ($1.dateSent ?? .distantPast) }
        return messages
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        let formats = [
            "EEEE, MMMM d, yyyy 'at' h:mm:ss a",
            "EEEE d MMMM yyyy HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss Z",
        ]
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: string) {
                return date
            }
        }
        return nil
    }
}
