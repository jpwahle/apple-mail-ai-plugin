import Foundation

protocol AIClient {
    var provider: AIProvider { get }
    func complete(systemPrompt: String, userMessage: String) async throws -> String
}

enum AIClientError: LocalizedError {
    case missingAPIKey(AIProvider)
    case requestFailed(String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "No API key configured for \(provider.displayName). Add one in Settings."
        case .requestFailed(let msg):
            return "API request failed: \(msg)"
        case .invalidResponse(let msg):
            return "Invalid API response: \(msg)"
        }
    }
}
