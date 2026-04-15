import Foundation
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    private let keychainService = KeychainService()

    @AppStorage("selectedModelID") var selectedModelID: String = ""
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false

    @Published var anthropicModels: [AIModel] = []
    @Published var openaiModels: [AIModel] = []
    @Published var geminiModels: [AIModel] = []
    @Published var openrouterModels: [AIModel] = []
    @Published var isFetchingAnthropic = false
    @Published var isFetchingOpenAI = false
    @Published var isFetchingGemini = false
    @Published var isFetchingOpenRouter = false
    @Published var anthropicFetchError: String?
    @Published var openaiFetchError: String?
    @Published var geminiFetchError: String?
    @Published var openrouterFetchError: String?

    var allModels: [AIModel] {
        anthropicModels + openaiModels + geminiModels + openrouterModels
    }

    /// Models grouped by provider. Within each group, sorted by release date
    /// descending (most recently released first), then by `tiebreakScore`.
    /// New flagship models land at the top without any hand-maintained list.
    var sortedGroupedModels: [(AIProvider, [AIModel])] {
        AIProvider.allCases.compactMap { provider in
            let models: [AIModel]
            switch provider {
            case .anthropic: models = anthropicModels
            case .openai: models = openaiModels
            case .gemini: models = geminiModels
            case .openrouter: models = openrouterModels
            }
            guard !models.isEmpty else { return nil }
            let sorted = models.sorted { lhs, rhs in
                let lk = lhs.sortKey
                let rk = rhs.sortKey
                if lk.0 != rk.0 { return lk.0 > rk.0 }
                return lk.1 > rk.1
            }
            return (provider, sorted)
        }
    }

    /// A handful of the newest flagship models across all providers. Used as
    /// the "Popular" section at the top of the picker.
    var popularModels: [AIModel] {
        // Take the top 3 newest from each provider, then re-sort by recency
        // so the absolute newest lead.
        var candidates: [AIModel] = []
        for (_, provider) in sortedGroupedModels.enumerated() {
            candidates.append(contentsOf: provider.1.prefix(3))
        }
        return candidates
            .sorted { lhs, rhs in
                let lk = lhs.sortKey
                let rk = rhs.sortKey
                if lk.0 != rk.0 { return lk.0 > rk.0 }
                return lk.1 > rk.1
            }
            .prefix(5)
            .map { $0 }
    }

    var selectedModel: AIModel? {
        allModels.first { $0.id == selectedModelID }
    }

    /// Pick a sensible default model when none is set or the stored one
    /// disappeared from the latest fetch.
    func ensureDefaultSelection() {
        if let current = selectedModel, allModels.contains(current) {
            return
        }
        if let best = popularModels.first {
            selectedModelID = best.id
        }
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
                ensureDefaultSelection()
            } catch {
                anthropicFetchError = error.localizedDescription
            }
            isFetchingAnthropic = false

        case .openai:
            isFetchingOpenAI = true
            openaiFetchError = nil
            do {
                openaiModels = try await ModelFetcher.fetchOpenAIModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                openaiFetchError = error.localizedDescription
            }
            isFetchingOpenAI = false

        case .gemini:
            isFetchingGemini = true
            geminiFetchError = nil
            do {
                geminiModels = try await ModelFetcher.fetchGeminiModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                geminiFetchError = error.localizedDescription
            }
            isFetchingGemini = false

        case .openrouter:
            isFetchingOpenRouter = true
            openrouterFetchError = nil
            do {
                openrouterModels = try await ModelFetcher.fetchOpenRouterModels(apiKey: apiKey)
                ensureDefaultSelection()
            } catch {
                openrouterFetchError = error.localizedDescription
            }
            isFetchingOpenRouter = false
        }
    }

    func fetchAllModels() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in AIProvider.allCases {
                if let key = getAPIKey(for: provider), !key.isEmpty {
                    group.addTask { await self.fetchModels(for: provider) }
                }
            }
        }
    }
}
