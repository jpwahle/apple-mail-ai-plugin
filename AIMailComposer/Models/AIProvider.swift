import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case anthropic
    case openai
    case gemini
    case openrouter
    case trustedtokens
    case local

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .openrouter: return "OpenRouter"
        case .trustedtokens: return "TrustedTokens"
        case .local: return "Local AI"
        }
    }

    /// One-letter badge shown in the model picker.
    var badgeLetter: String {
        switch self {
        case .anthropic: return "A"
        case .openai: return "O"
        case .gemini: return "G"
        case .openrouter: return "R"
        case .trustedtokens: return "T"
        case .local: return "L"
        }
    }
}
