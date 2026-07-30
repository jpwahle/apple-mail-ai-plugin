import Foundation
import ServiceManagement
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    private let keychainService = KeychainService()

    @AppStorage("selectedModelID") var selectedModelID: String = ""
    @AppStorage("customWritingInstructions") var customWritingInstructions: String = ""
    @AppStorage("hotkeyKeyCode") var hotkeyKeyCode: Int = 0x04    // kVK_ANSI_H
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0x0800 // optionKey

    static let hotkeyDidChange = Notification.Name("hotkeyDidChange")

    func setHotkey(keyCode: Int, modifiers: Int) {
        hotkeyKeyCode = keyCode
        hotkeyModifiers = modifiers
        NotificationCenter.default.post(name: Self.hotkeyDidChange, object: nil)
    }

    // MARK: - Launch at Login

    @Published var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Failed to update launch at login: \(error.localizedDescription)")
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    @AppStorage("localAIBaseURL") var localAIBaseURL: String = ""

    @Published var anthropicModels: [AIModel] = []
    @Published var openaiModels: [AIModel] = []
    @Published var geminiModels: [AIModel] = []
    @Published var openrouterModels: [AIModel] = []
    @Published var trustedtokensModels: [AIModel] = []
    @Published var localModels: [AIModel] = []
    @Published var isFetchingAnthropic = false
    @Published var isFetchingOpenAI = false
    @Published var isFetchingGemini = false
    @Published var isFetchingOpenRouter = false
    @Published var isFetchingTrustedTokens = false
    @Published var isFetchingLocal = false
    @Published var anthropicFetchError: String?
    @Published var openaiFetchError: String?
    @Published var geminiFetchError: String?
    @Published var openrouterFetchError: String?
    @Published var trustedtokensFetchError: String?
    @Published var localFetchError: String?
    @Published var trendingModels: [TrendingModel] = []

    var allModels: [AIModel] {
        anthropicModels + openaiModels + geminiModels + openrouterModels + trustedtokensModels + localModels
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
            case .trustedtokens: models = trustedtokensModels
            case .local: models = localModels
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

    /// The most popular models across all providers. Uses trending data from
    /// OpenRouter's public API so the list stays current without hardcoded
    /// model names. Falls back to a recency-based heuristic when trending
    /// data isn't available.
    var popularModels: [AIModel] {
        if !trendingModels.isEmpty {
            var popular: [AIModel] = []
            for entry in trendingModels {
                var match: AIModel?

                // Try direct-API models for the entry's provider first
                if let provider = entry.provider {
                    let providerModels: [AIModel]
                    switch provider {
                    case .anthropic:     providerModels = anthropicModels
                    case .openai:        providerModels = openaiModels
                    case .gemini:        providerModels = geminiModels
                    case .openrouter:    providerModels = openrouterModels
                    case .trustedtokens: providerModels = trustedtokensModels
                    case .local:         providerModels = localModels
                    }
                    match = providerModels.first {
                        ModelFetcher.modelIDMatchesSlug($0.id, slug: entry.slug)
                    }
                }

                // Fall back to OpenRouter models by full ID
                if match == nil {
                    match = openrouterModels.first {
                        $0.id.lowercased() == entry.openRouterId.lowercased()
                    }
                }

                if let match, !popular.contains(match) {
                    popular.append(match)
                }
                if popular.count >= 5 { break }
            }
            if !popular.isEmpty { return popular }
        }

        // Fallback: top 3 newest from each provider, re-sorted.
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
        return try AIClientFactory.client(for: model, keychainService: keychainService, localAIBaseURL: localAIBaseURL)
    }

    func fetchModels(for provider: AIProvider) async {
        switch provider {
        case .local:
            isFetchingLocal = true
            localFetchError = nil
            do {
                localModels = try await ModelFetcher.fetchLocalAIModels(baseURL: localAIBaseURL)
                ensureDefaultSelection()
            } catch {
                localFetchError = error.localizedDescription
            }
            isFetchingLocal = false

        default:
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

            case .trustedtokens:
                isFetchingTrustedTokens = true
                trustedtokensFetchError = nil
                do {
                    trustedtokensModels = try await ModelFetcher.fetchTrustedTokensModels(apiKey: apiKey)
                    ensureDefaultSelection()
                } catch {
                    trustedtokensFetchError = error.localizedDescription
                }
                isFetchingTrustedTokens = false

            case .local:
                break // handled above
            }
        }
    }

    func fetchAllModels() async {
        // Fetch trending/popular rankings from OpenRouter (public, no auth)
        // in parallel with provider model lists.
        async let trending = ModelFetcher.fetchTrendingModels()

        await withTaskGroup(of: Void.self) { group in
            for provider in AIProvider.allCases {
                if provider == .local {
                    // Local AI needs no API key — always attempt if a URL is set.
                    if !localAIBaseURL.isEmpty {
                        group.addTask { await self.fetchModels(for: .local) }
                    }
                } else if let key = getAPIKey(for: provider), !key.isEmpty {
                    group.addTask { await self.fetchModels(for: provider) }
                }
            }
        }

        trendingModels = await trending
    }
}
