import Foundation

struct AIModel: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let provider: AIProvider
    /// Unix timestamp (seconds) of when the model was released, when the
    /// provider exposes it. Used as the primary sort key so "popular" means
    /// "most recently released" — new models are, in practice, what people
    /// want to use.
    let createdAt: TimeInterval?

    init(id: String, displayName: String, provider: AIProvider, createdAt: TimeInterval? = nil) {
        self.id = id
        self.displayName = displayName
        self.provider = provider
        self.createdAt = createdAt
    }
}

extension AIModel {
    /// Secondary sort score, used to break ties when two models have the same
    /// release date (or neither has one). Higher = more flagship-like.
    /// Prefers chat-tier models and de-prioritizes dated snapshots, -mini,
    /// embedding/audio/image endpoints, etc.
    var tiebreakScore: Int {
        let id = id.lowercased()
        var score = 0

        switch provider {
        case .anthropic:
            if id.contains("opus") { score += 30 }
            else if id.contains("sonnet") { score += 22 }
            else if id.contains("haiku") { score += 12 }
            if id.range(of: #"-\d{8}"#, options: .regularExpression) != nil { score -= 15 }

        case .openai:
            if id.hasPrefix("gpt-5") { score += 50 }
            else if id.hasPrefix("gpt-4.1") { score += 40 }
            else if id.hasPrefix("gpt-4o") { score += 35 }
            else if id.hasPrefix("o3") || id.hasPrefix("o4") { score += 45 }
            else if id.hasPrefix("o1") { score += 30 }
            else if id.hasPrefix("gpt-4") { score += 20 }
            else if id.hasPrefix("chatgpt") { score += 25 }
            if id.contains("mini") { score -= 8 }
            if id.contains("nano") { score -= 12 }
            if id.contains("audio") || id.contains("realtime") || id.contains("transcribe") || id.contains("tts") || id.contains("image") || id.contains("embedding") || id.contains("moderation") {
                score -= 60
            }
            if id.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil { score -= 30 }
            if id.range(of: #"-\d{4}$"#, options: .regularExpression) != nil { score -= 22 }
            if id.hasSuffix("-16k") { score -= 20 }

        case .gemini:
            if id.contains("pro") { score += 20 }
            else if id.contains("flash") { score += 15 }
            if id.contains("embedding") || id.contains("tts") || id.contains("image") { score -= 60 }
            if id.range(of: #"-\d{3,}"#, options: .regularExpression) != nil { score -= 20 }
            if id.contains("preview") || id.contains("exp") { score -= 5 }

        case .openrouter:
            // OpenRouter passes slugs like `anthropic/claude-sonnet-4`. Favour
            // flagship families, penalise free/preview/deprecated tags.
            if id.contains("opus") || id.contains("gpt-5") || id.contains("o4") || id.contains("2.5-pro") { score += 40 }
            else if id.contains("sonnet") || id.contains("gpt-4.1") || id.contains("gpt-4o") || id.contains("2.5-flash") || id.contains("o3") { score += 30 }
            else if id.contains("haiku") || id.contains("gpt-4-turbo") || id.contains("o1") { score += 20 }
            if id.contains(":free") { score -= 40 }
            if id.contains("preview") || id.contains("experimental") { score -= 10 }
            if id.contains("embedding") || id.contains("audio") { score -= 60 }
        }

        score -= min(id.count, 60) / 10
        return score
    }

    /// Sort key: most recently released first, then tiebreak on score.
    /// Returns a tuple comparable across models from the same provider.
    var sortKey: (TimeInterval, Int) {
        (createdAt ?? 0, tiebreakScore)
    }
}
