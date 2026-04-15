import Foundation
import SwiftUI

@MainActor
final class ComposerViewModel: ObservableObject {
    enum State: Equatable {
        case loadingContext
        case ready
        case generating   // request sent, no chunks received yet
        case complete     // have content (may still be streaming — see isStreaming)
        case error(String)
    }

    @Published var state: State = .loadingContext
    @Published var userThoughts: String = ""
    @Published var generatedReply: String = ""
    /// True while bytes are still arriving from the model. Used by the view
    /// to show a caret animation and to gate the "Copy message" action.
    @Published var isStreaming: Bool = false
    @Published private(set) var context: ComposerContext?

    private let settingsStore: SettingsStore
    private let onDismiss: () -> Void
    private var streamTask: Task<Void, Never>?

    init(settingsStore: SettingsStore, onDismiss: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.onDismiss = onDismiss
    }

    var canSend: Bool {
        guard context != nil else { return false }
        guard settingsStore.selectedModel != nil else { return false }
        return !userThoughts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isBusy: Bool {
        switch state {
        case .loadingContext, .generating: return true
        default: return isStreaming
        }
    }

    func activate() async {
        state = .loadingContext
        do {
            let context = try await MailBridge.fetchComposerContext()
            self.context = context
            state = .ready
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func generate() async {
        guard let context else {
            state = .error("No compose window detected.")
            return
        }
        let trimmed = userThoughts.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        streamTask?.cancel()
        generatedReply = ""
        state = .generating
        isStreaming = true

        let client: AIClient
        do {
            client = try settingsStore.makeAIClient()
        } catch {
            isStreaming = false
            state = .error(error.localizedDescription)
            return
        }

        let (systemPrompt, userMessage) = SystemPrompt.compose(
            context: context,
            userThoughts: trimmed
        )

        streamTask = Task { [weak self] in
            await self?.consumeStream(client.stream(systemPrompt: systemPrompt, userMessage: userMessage))
        }
        await streamTask?.value
    }

    private func consumeStream(_ stream: AsyncThrowingStream<String, Error>) async {
        do {
            for try await chunk in stream {
                if Task.isCancelled { return }
                if state != .complete {
                    state = .complete
                }
                generatedReply += chunk
            }
            isStreaming = false
            if generatedReply.isEmpty {
                state = .error("No response from model.")
            }
        } catch is CancellationError {
            isStreaming = false
        } catch {
            isStreaming = false
            // Preserve any partial output — but only surface the error if we
            // got nothing back at all, otherwise the partial is still useful.
            if generatedReply.isEmpty {
                state = .error(error.localizedDescription)
            }
        }
    }

    func insertIntoMail() async {
        guard !generatedReply.isEmpty else { return }
        await MailBridge.insertReply(generatedReply)
        onDismiss()
    }

    func copyToClipboard() {
        guard !generatedReply.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedReply, forType: .string)
    }

    func backToEditing() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
        state = .ready
    }

    func retry() async {
        await activate()
    }

    func cancel() {
        streamTask?.cancel()
        onDismiss()
    }
}
