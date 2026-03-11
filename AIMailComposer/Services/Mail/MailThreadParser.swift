import Foundation

enum MailThreadParser {
    static func parse(_ raw: String) throws -> EmailThread {
        let messageBlocks = raw.components(separatedBy: "---END_MESSAGE---")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !messageBlocks.isEmpty else {
            throw MailBridgeError.parseError("No messages found in thread")
        }

        var messages: [EmailMessage] = []
        var threadSubject = ""

        for block in messageBlocks {
            let lines = block.components(separatedBy: "\n")

            var sender = ""
            var recipients: [String] = []
            var subject = ""
            var dateString = ""
            var body = ""
            var inBody = false

            for line in lines {
                if line.hasPrefix("FROM:") {
                    sender = String(line.dropFirst(5))
                } else if line.hasPrefix("TO:") {
                    recipients = String(line.dropFirst(3))
                        .components(separatedBy: ", ")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                } else if line.hasPrefix("SUBJECT:") {
                    subject = String(line.dropFirst(8))
                    if threadSubject.isEmpty {
                        threadSubject = subject
                    }
                } else if line.hasPrefix("DATE:") {
                    dateString = String(line.dropFirst(5))
                } else if line == "BODY_START" {
                    inBody = true
                } else if line == "BODY_END" {
                    inBody = false
                } else if inBody {
                    if !body.isEmpty { body += "\n" }
                    body += line
                }
            }

            let date = parseDate(dateString)

            messages.append(EmailMessage(
                sender: sender,
                recipients: recipients,
                subject: subject,
                dateSent: date,
                body: body
            ))
        }

        // Sort by date, oldest first
        messages.sort { ($0.dateSent ?? .distantPast) < ($1.dateSent ?? .distantPast) }

        return EmailThread(subject: threadSubject, messages: messages)
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = DateFormatter()
        // AppleScript date format varies by locale; try common patterns
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
