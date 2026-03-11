import SwiftUI

struct ComposerView: View {
    @ObservedObject var viewModel: ComposerViewModel
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            contentArea
            Divider()
            footerBar
        }
        .frame(minWidth: 480, minHeight: 400)
    }

    private var headerBar: some View {
        HStack {
            if !viewModel.threadSubject.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.threadSubject)
                        .font(.headline)
                        .lineLimit(1)
                    Text("\(viewModel.messageCount) message\(viewModel.messageCount == 1 ? "" : "s") in thread")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("AI Mail Composer")
                    .font(.headline)
            }
            Spacer()
            if !settingsStore.allModels.isEmpty {
                Picker("Model", selection: $settingsStore.selectedModelID) {
                    ForEach(settingsStore.allModels) { model in
                        Text(model.displayName).tag(model.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.state {
        case .idle, .fetchingThread:
            VStack {
                Spacer()
                ProgressView("Loading email thread…")
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .composing:
            VStack(alignment: .leading, spacing: 12) {
                Text("Your thoughts:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.userThoughts)
                    .font(.body)
                    .frame(maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()

        case .generating:
            VStack(spacing: 16) {
                thoughtsSummary
                Spacer()
                ProgressView("Generating reply…")
                    .controlSize(.large)
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .complete:
            VStack(alignment: .leading, spacing: 12) {
                thoughtsSummary
                Text("Generated reply:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.generatedReply)
                    .font(.body)
                    .frame(maxHeight: .infinity)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding()

        case .error(let message):
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.yellow)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                if viewModel.hasThread {
                    Button("Try Again") {
                        viewModel.state = .composing
                    }
                } else {
                    Button("Retry") {
                        Task { await viewModel.activate() }
                    }
                }
                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var thoughtsSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Your thoughts:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(viewModel.userThoughts)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }

    private var footerBar: some View {
        HStack {
            Button("Cancel") {
                viewModel.cancel()
            }
            .keyboardShortcut(.cancelAction)

            Spacer()

            if viewModel.state == .complete {
                Button("Regenerate") {
                    Task { await viewModel.generate() }
                }

                Button("Copy & Switch to Mail") {
                    viewModel.insertIntoMail()
                }
                .keyboardShortcut(.defaultAction)
            }

            if viewModel.state == .composing {
                Button("Generate Reply") {
                    Task { await viewModel.generate() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(viewModel.userThoughts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
}
