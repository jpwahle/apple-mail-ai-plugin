import SwiftUI

struct APIKeySettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @State private var anthropicKey: String = ""
    @State private var openaiKey: String = ""
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
        anthropicKey = trimmedAnthropic
        openaiKey = trimmedOpenAI

        do {
            if !trimmedAnthropic.isEmpty {
                try settingsStore.setAPIKey(trimmedAnthropic, for: .anthropic)
            } else {
                settingsStore.deleteAPIKey(for: .anthropic)
                settingsStore.anthropicModels = []
            }
            if !trimmedOpenAI.isEmpty {
                try settingsStore.setAPIKey(trimmedOpenAI, for: .openai)
            } else {
                settingsStore.deleteAPIKey(for: .openai)
                settingsStore.openaiModels = []
            }
            isError = false
            statusMessage = "Saved. Fetching models…"
            Task {
                await settingsStore.fetchAllModels()
                let errors = [settingsStore.anthropicFetchError, settingsStore.openaiFetchError].compactMap { $0 }
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
}
