import SwiftUI

struct APIKeySettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var openrouterKey: String = ""
    @State private var trustedtokensKey: String = ""
    @State private var localBaseURL: String = ""
    @State private var statusMessage: String = ""
    @State private var isError: Bool = false
    @State private var modelSearchText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            apiKeyFields
            Divider()
            modelSection
        }
    }

    // MARK: - API Keys

    private var apiKeyFields: some View {
        VStack(alignment: .leading, spacing: 10) {
            keyField("Anthropic", placeholder: "sk-ant-api03-…", text: $anthropicKey)
                .onAppear { anthropicKey = settingsStore.getAPIKey(for: .anthropic) ?? "" }

            keyField("OpenAI", placeholder: "sk-…", text: $openaiKey)
                .onAppear { openaiKey = settingsStore.getAPIKey(for: .openai) ?? "" }

            keyField("Google Gemini", placeholder: "AIza…", text: $geminiKey)
                .onAppear { geminiKey = settingsStore.getAPIKey(for: .gemini) ?? "" }

            VStack(alignment: .leading, spacing: 3) {
                keyField("OpenRouter", placeholder: "sk-or-v1-…", text: $openrouterKey)
                    .onAppear { openrouterKey = settingsStore.getAPIKey(for: .openrouter) ?? "" }
                Text("One key for every model on openrouter.ai")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                keyField("TrustedTokens", placeholder: "sk-bf…", text: $trustedtokensKey)
                    .onAppear { trustedtokensKey = settingsStore.getAPIKey(for: .trustedtokens) ?? "" }
                Text("EU-sovereign models at api.trustedtokens.eu")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }

            VStack(alignment: .leading, spacing: 3) {
                keyField("Local AI", placeholder: "http://localhost:1234", text: $localBaseURL)
                    .onAppear { localBaseURL = settingsStore.localAIBaseURL }
                Text("LM Studio or Ollama. Enter the server's base URL.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 2)
            }

            HStack(spacing: 8) {
                Button("Save Keys") { saveKeys() }
                    .controlSize(.small)
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(isError ? .red : .green)
                        .lineLimit(1)
                }
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func keyField(_ label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
        }
    }

    // MARK: - Model Selection

    private var isFetching: Bool {
        settingsStore.isFetchingAnthropic
            || settingsStore.isFetchingOpenAI
            || settingsStore.isFetchingGemini
            || settingsStore.isFetchingOpenRouter
            || settingsStore.isFetchingTrustedTokens
            || settingsStore.isFetchingLocal
    }

    @ViewBuilder
    private var modelSection: some View {
        if settingsStore.allModels.isEmpty && !isFetching {
            modelEmptyState
        } else {
            modelList
        }
    }

    private var modelEmptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No models available")
                .font(.subheadline)
                .fontWeight(.medium)
            Text("Save an API key above, then models will be fetched from the provider.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            fetchErrorLines
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Model")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                if isFetching {
                    ProgressView()
                        .controlSize(.small)
                }
                Button("Refresh") {
                    Task { await settingsStore.fetchAllModels() }
                }
                .controlSize(.small)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search models…", text: $modelSearchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !modelSearchText.isEmpty {
                    Button {
                        modelSearchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.primary.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .padding(.horizontal)
            .padding(.bottom, 8)

            List(selection: $settingsStore.selectedModelID) {
                ForEach(filteredGroupedModels, id: \.0) { provider, models in
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            modelRow(model).tag(model.id)
                        }
                    }
                }
            }
            .listStyle(.bordered)

            fetchErrorLines
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
    }

    private var filteredGroupedModels: [(AIProvider, [AIModel])] {
        guard !modelSearchText.isEmpty else {
            return settingsStore.sortedGroupedModels
        }
        let query = modelSearchText.lowercased()
        return settingsStore.sortedGroupedModels.compactMap { provider, models in
            let filtered = models.filter {
                $0.displayName.lowercased().contains(query)
                    || $0.id.lowercased().contains(query)
            }
            guard !filtered.isEmpty else { return nil }
            return (provider, filtered)
        }
    }

    private func modelRow(_ model: AIModel) -> some View {
        HStack {
            Text(model.displayName)
            Spacer()
            if model.id == settingsStore.selectedModelID {
                Image(systemName: "checkmark")
                    .foregroundStyle(.blue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            settingsStore.selectedModelID = model.id
        }
    }

    @ViewBuilder
    private var fetchErrorLines: some View {
        VStack(spacing: 2) {
            if let err = settingsStore.anthropicFetchError {
                Text("Anthropic: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.openaiFetchError {
                Text("OpenAI: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.geminiFetchError {
                Text("Gemini: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.openrouterFetchError {
                Text("OpenRouter: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.trustedtokensFetchError {
                Text("TrustedTokens: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.localFetchError {
                Text("Local AI: \(err)").font(.caption2).foregroundStyle(.red)
            }
        }
    }

    // MARK: - Save

    private func saveKeys() {
        let trimmedAnthropic = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAI = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGemini = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenRouter = openrouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTrustedTokens = trustedtokensKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocalURL = localBaseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        anthropicKey = trimmedAnthropic
        openaiKey = trimmedOpenAI
        geminiKey = trimmedGemini
        openrouterKey = trimmedOpenRouter
        trustedtokensKey = trimmedTrustedTokens
        localBaseURL = trimmedLocalURL

        do {
            try applyKey(trimmedAnthropic, for: .anthropic) { settingsStore.anthropicModels = [] }
            try applyKey(trimmedOpenAI, for: .openai) { settingsStore.openaiModels = [] }
            try applyKey(trimmedGemini, for: .gemini) { settingsStore.geminiModels = [] }
            try applyKey(trimmedOpenRouter, for: .openrouter) { settingsStore.openrouterModels = [] }
            try applyKey(trimmedTrustedTokens, for: .trustedtokens) { settingsStore.trustedtokensModels = [] }

            if trimmedLocalURL.isEmpty {
                settingsStore.localAIBaseURL = ""
                settingsStore.localModels = []
                settingsStore.localFetchError = nil
            } else {
                var sanitizedURL = trimmedLocalURL
                if !sanitizedURL.lowercased().hasPrefix("http://") && !sanitizedURL.lowercased().hasPrefix("https://") {
                    sanitizedURL = "http://" + sanitizedURL
                }
                while sanitizedURL.hasSuffix("/") {
                    sanitizedURL.removeLast()
                }
                settingsStore.localAIBaseURL = sanitizedURL
                localBaseURL = sanitizedURL
            }

            isError = false
            statusMessage = "Saved. Fetching models…"
            Task {
                await settingsStore.fetchAllModels()
                let errors = [
                    settingsStore.anthropicFetchError,
                    settingsStore.openaiFetchError,
                    settingsStore.geminiFetchError,
                    settingsStore.openrouterFetchError,
                    settingsStore.trustedtokensFetchError,
                    settingsStore.localFetchError,
                ].compactMap { $0 }
                if errors.isEmpty {
                    statusMessage = "Saved. \(settingsStore.allModels.count) models loaded."
                    isError = false
                } else {
                    statusMessage = errors.joined(separator: "; ")
                    isError = true
                }
            }
        } catch {
            statusMessage = error.localizedDescription
            isError = true
        }
    }

    private func applyKey(_ key: String, for provider: AIProvider, onDelete clearModels: () -> Void) throws {
        if key.isEmpty {
            settingsStore.deleteAPIKey(for: provider)
            clearModels()
        } else {
            try settingsStore.setAPIKey(key, for: provider)
        }
    }
}
