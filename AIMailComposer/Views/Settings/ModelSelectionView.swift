import SwiftUI

struct ModelSelectionView: View {
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if settingsStore.allModels.isEmpty && !isFetching {
                emptyState
            } else {
                modelList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if settingsStore.allModels.isEmpty {
                await settingsStore.fetchAllModels()
            }
        }
    }

    private var isFetching: Bool {
        settingsStore.isFetchingAnthropic || settingsStore.isFetchingOpenAI
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "cpu")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No models available")
                .font(.headline)
            Text("Add an API key in the API Keys tab, then models will be fetched from the provider.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let err = settingsStore.anthropicFetchError {
                Text("Anthropic: \(err)").font(.caption2).foregroundStyle(.red)
            }
            if let err = settingsStore.openaiFetchError {
                Text("OpenAI: \(err)").font(.caption2).foregroundStyle(.red)
            }
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    private var modelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Select a model")
                    .font(.headline)
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
            .padding()

            List(selection: $settingsStore.selectedModelID) {
                if !settingsStore.anthropicModels.isEmpty {
                    Section("Anthropic") {
                        ForEach(settingsStore.anthropicModels) { model in
                            modelRow(model)
                                .tag(model.id)
                        }
                    }
                }
                if !settingsStore.openaiModels.isEmpty {
                    Section("OpenAI") {
                        ForEach(settingsStore.openaiModels) { model in
                            modelRow(model)
                                .tag(model.id)
                        }
                    }
                }
            }
            .listStyle(.bordered)

            if let err = settingsStore.anthropicFetchError {
                Text("Anthropic error: \(err)")
                    .font(.caption2).foregroundStyle(.red).padding(.horizontal)
            }
            if let err = settingsStore.openaiFetchError {
                Text("OpenAI error: \(err)")
                    .font(.caption2).foregroundStyle(.red).padding(.horizontal)
            }
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
}
