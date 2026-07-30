import Foundation

enum AIClientFactory {
    static func client(
        for model: AIModel,
        keychainService: KeychainService,
        localAIBaseURL: String = "http://localhost:1234"
    ) throws -> AIClient {
        switch model.provider {
        case .anthropic:
            guard let key = keychainService.getKey(for: .anthropic), !key.isEmpty else {
                throw AIClientError.missingAPIKey(.anthropic)
            }
            return AnthropicClient(apiKey: key, model: model.id)
        case .openai:
            guard let key = keychainService.getKey(for: .openai), !key.isEmpty else {
                throw AIClientError.missingAPIKey(.openai)
            }
            return OpenAIClient(apiKey: key, model: model.id)
        case .gemini:
            guard let key = keychainService.getKey(for: .gemini), !key.isEmpty else {
                throw AIClientError.missingAPIKey(.gemini)
            }
            return GeminiClient(apiKey: key, model: model.id)
        case .openrouter:
            guard let key = keychainService.getKey(for: .openrouter), !key.isEmpty else {
                throw AIClientError.missingAPIKey(.openrouter)
            }
            return OpenRouterClient(apiKey: key, model: model.id)
        case .trustedtokens:
            guard let key = keychainService.getKey(for: .trustedtokens), !key.isEmpty else {
                throw AIClientError.missingAPIKey(.trustedtokens)
            }
            return TrustedTokensClient(apiKey: key, model: model.id)
        case .local:
            return LocalAIClient(baseURL: localAIBaseURL, model: model.id)
        }
    }
}
