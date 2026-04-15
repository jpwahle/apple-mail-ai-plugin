import SwiftUI

struct APIKeySettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
    @State private var geminiKey: String = ""
    @State private var openrouterKey: String = ""
    @State private var statusMessage: String = ""
    @State private var isError: Bool = false

    var body: some View {
        Form {
            Section("Anthropic") {
                TextField("sk-ant-api03-…", text: $anthropicKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onAppear {
                        anthropicKey = settingsStore.getAPIKey(for: .anthropic) ?? ""
                    }
            }
            Section("OpenAI") {
                TextField("sk-…", text: $openaiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onAppear {
                        openaiKey = settingsStore.getAPIKey(for: .openai) ?? ""
                    }
            }
            Section("Google Gemini") {
                TextField("AIza…", text: $geminiKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onAppear {
                        geminiKey = settingsStore.getAPIKey(for: .gemini) ?? ""
                    }
            }
            Section {
                TextField("sk-or-v1-…", text: $openrouterKey)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                    .onAppear {
                        openrouterKey = settingsStore.getAPIKey(for: .openrouter) ?? ""
                    }
            } header: {
                Text("OpenRouter")
            } footer: {
                Text("One key, access to every model on openrouter.ai — Claude, GPT, Gemini, Llama, Mistral, and more. Get a key at openrouter.ai/keys.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Save Keys") {
                    saveKeys()
                }
                if !statusMessage.isEmpty {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(isError ? .red : .green)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func saveKeys() {
        let trimmedAnthropic = anthropicKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAI = openaiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGemini = geminiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenRouter = openrouterKey.trimmingCharacters(in: .whitespacesAndNewlines)
        anthropicKey = trimmedAnthropic
        openaiKey = trimmedOpenAI
        geminiKey = trimmedGemini
        openrouterKey = trimmedOpenRouter

        do {
            try applyKey(trimmedAnthropic, for: .anthropic) { settingsStore.anthropicModels = [] }
            try applyKey(trimmedOpenAI, for: .openai) { settingsStore.openaiModels = [] }
            try applyKey(trimmedGemini, for: .gemini) { settingsStore.geminiModels = [] }
            try applyKey(trimmedOpenRouter, for: .openrouter) { settingsStore.openrouterModels = [] }

            isError = false
            statusMessage = "Saved. Fetching models…"
            Task {
                await settingsStore.fetchAllModels()
                let errors = [
                    settingsStore.anthropicFetchError,
                    settingsStore.openaiFetchError,
                    settingsStore.geminiFetchError,
                    settingsStore.openrouterFetchError,
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
