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
        settingsStore.isFetchingAnthropic
            || settingsStore.isFetchingOpenAI
            || settingsStore.isFetchingGemini
            || settingsStore.isFetchingOpenRouter
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
            errorLines
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var errorLines: some View {
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
        }
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
                ForEach(settingsStore.sortedGroupedModels, id: \.0) { provider, models in
                    Section(provider.displayName) {
                        ForEach(models) { model in
                            modelRow(model).tag(model.id)
                        }
                    }
                }
            }
            .listStyle(.bordered)

            errorLines
                .padding(.horizontal)
                .padding(.bottom, 8)
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
