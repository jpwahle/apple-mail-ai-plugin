import Foundation

enum AIProvider: String, CaseIterable, Codable, Identifiable {
    case anthropic
    case openai
    case gemini
    case openrouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .anthropic: return "Anthropic"
        case .openai: return "OpenAI"
        case .gemini: return "Google Gemini"
        case .openrouter: return "OpenRouter"
        }
    }

    /// One-letter badge shown in the model picker.
    var badgeLetter: String {
        switch self {
        case .anthropic: return "A"
        case .openai: return "O"
        case .gemini: return "G"
        case .openrouter: return "R"
        }
    }
}
