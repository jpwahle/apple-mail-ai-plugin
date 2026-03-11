import Foundation

struct EmailMessage {
    let sender: String
    let recipients: [String]
    let subject: String
    let dateSent: Date?
    let body: String

    var formattedDate: String {
        guard let date = dateSent else { return "Unknown" }
        return DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
}
