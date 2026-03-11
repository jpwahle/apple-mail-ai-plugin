import Foundation

enum AIClientFactory {
    static func client(for model: AIModel, keychainService: KeychainService) throws -> AIClient {
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
        }
    }
}
