import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    private let keychainService = KeychainService()

    @AppStorage("selectedModelID") var selectedModelID: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    @Published var anthropicModels: [AIModel] = []
    @Published var openaiModels: [AIModel] = []
    @Published var isFetchingAnthropic = false
    @Published var isFetchingOpenAI = false
    @Published var anthropicFetchError: String?
    @Published var openaiFetchError: String?

    var allModels: [AIModel] {
        anthropicModels + openaiModels
    }

    var selectedModel: AIModel? {
        allModels.first { $0.id == selectedModelID }
    }

    func setAPIKey(_ key: String, for provider: AIProvider) throws {
        try keychainService.setKey(key, for: provider)
    }

    func getAPIKey(for provider: AIProvider) -> String? {
        keychainService.getKey(for: provider)
    }

    func deleteAPIKey(for provider: AIProvider) {
        keychainService.deleteKey(for: provider)
    }

    func makeAIClient() throws -> AIClient {
        guard let model = selectedModel else {
            throw AIClientError.requestFailed("No model selected. Open Settings and pick a model.")
        }
        return try AIClientFactory.client(for: model, keychainService: keychainService)
    }

    func fetchModels(for provider: AIProvider) async {
        guard let apiKey = getAPIKey(for: provider), !apiKey.isEmpty else { return }

        switch provider {
        case .anthropic:
            isFetchingAnthropic = true
            anthropicFetchError = nil
            do {
                anthropicModels = try await ModelFetcher.fetchAnthropicModels(apiKey: apiKey)
                if selectedModelID.isEmpty, let first = anthropicModels.first {
                    selectedModelID = first.id
                }
            } catch {
                anthropicFetchError = error.localizedDescription
            }
            isFetchingAnthropic = false

        case .openai:
            isFetchingOpenAI = true
            openaiFetchError = nil
            do {
                openaiModels = try await ModelFetcher.fetchOpenAIModels(apiKey: apiKey)
                if selectedModelID.isEmpty, let first = openaiModels.first {
                    selectedModelID = first.id
                }
            } catch {
                openaiFetchError = error.localizedDescription
            }
            isFetchingOpenAI = false
        }
    }

    func fetchAllModels() async {
        await withTaskGroup(of: Void.self) { group in
            if getAPIKey(for: .anthropic) != nil {
                group.addTask { await self.fetchModels(for: .anthropic) }
            }
            if getAPIKey(for: .openai) != nil {
                group.addTask { await self.fetchModels(for: .openai) }
            }
        }
    }
}
