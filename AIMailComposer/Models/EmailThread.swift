import Foundation

struct EmailThread {
    let subject: String
    let messages: [EmailMessage]

    func formatted() -> String {
        messages.map { msg in
            """
            From: \(msg.sender)
            Date: \(msg.formattedDate)

            \(msg.body)
            """
        }.joined(separator: "\n---\n")
    }
}
