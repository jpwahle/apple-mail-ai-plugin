import Foundation

struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let provider: AIProvider
}
