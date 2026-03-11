import Foundation
import SwiftUI

@MainActor
final class ComposerViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case fetchingThread
        case composing
        case generating
        case complete
        case error(String)
    }

    @Published var state: State = .idle
    @Published var userThoughts: String = ""
    @Published var generatedReply: String = ""
    @Published var threadSubject: String = ""
    @Published var messageCount: Int = 0

    private let settingsStore: SettingsStore
    private let onDismiss: () -> Void
    private(set) var hasThread: Bool = false
    private var emailThread: EmailThread?

    init(settingsStore: SettingsStore, onDismiss: @escaping () -> Void) {
        self.settingsStore = settingsStore
        self.onDismiss = onDismiss
    }

    func activate() async {
        state = .fetchingThread
        do {
            let thread = try await MailBridge.fetchEmailThread()
            emailThread = thread
            hasThread = true
            threadSubject = thread.subject
            messageCount = thread.messages.count
            state = .composing
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func generate() async {
        guard let thread = emailThread else {
            state = .error("No email thread loaded.")
            return
        }
        guard !userThoughts.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            state = .error("Type your thoughts about the reply first.")
            return
        }

        state = .generating
        do {
            let client = try settingsStore.makeAIClient()
            let (systemPrompt, userMessage) = SystemPrompt.compose(
                thread: thread,
                userThoughts: userThoughts
            )
            generatedReply = try await client.complete(
                systemPrompt: systemPrompt,
                userMessage: userMessage
            )
            state = .complete
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func insertIntoMail() {
        guard !generatedReply.isEmpty else { return }
        MailBridge.insertReply(generatedReply)
        onDismiss()
    }

    func cancel() {
        onDismiss()
    }
}
