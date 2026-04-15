import SwiftUI
import AppKit

struct ComposerView: View {
    @ObservedObject var viewModel: ComposerViewModel
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        VStack(spacing: 0) {
            ComposerHeader(
                title: headerTitle,
                subtitle: headerSubtitle,
                statusColor: statusColor
            )

            Divider()
                .opacity(0.4)

            contentArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            ComposerInputBar(
                userThoughts: $viewModel.userThoughts,
                isEditable: isInputEditable,
                isGenerating: viewModel.isBusy,
                canSend: viewModel.canSend,
                placeholder: inputPlaceholder,
                settingsStore: settingsStore,
                shouldFocus: viewModel.state == .ready || viewModel.state == .complete,
                claimsReturnShortcut: viewModel.state != .complete,
                onSend: { Task { await viewModel.generate() } }
            )
        }
        .frame(minWidth: 500, minHeight: 500)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()
        )
        .background(
            // Preserve Esc-to-close. The visible close affordance is now the
            // standard red traffic-light button on the panel.
            Button(action: { viewModel.cancel() }) { EmptyView() }
                .buttonStyle(.plain)
                .keyboardShortcut(.cancelAction)
                .frame(width: 0, height: 0)
                .opacity(0)
                .accessibilityHidden(true)
        )
    }

    // MARK: Content area

    @ViewBuilder
    private var contentArea: some View {
        switch viewModel.state {
        case .loadingContext:
            LoadingState(label: "Reading your compose window…")

        case .ready:
            ReadyState(context: viewModel.context)

        case .generating:
            GeneratingState(thoughts: viewModel.userThoughts)

        case .complete:
            ReplyResultView(
                reply: $viewModel.generatedReply,
                userThoughts: viewModel.userThoughts,
                isStreaming: viewModel.isStreaming,
                onCopy: { viewModel.copyToClipboard() },
                onInsert: { Task { await viewModel.insertIntoMail() } },
                onRegenerate: { Task { await viewModel.generate() } },
                onEdit: { viewModel.backToEditing() }
            )

        case .error(let message):
            ErrorState(
                message: message,
                onRetry: { Task { await viewModel.retry() } }
            )
        }
    }

    // MARK: Derived state

    private var isInputEditable: Bool {
        switch viewModel.state {
        case .ready, .complete: return true
        default: return false
        }
    }

    private var inputPlaceholder: String {
        guard let ctx = viewModel.context else {
            return "Describe the reply you want…"
        }
        if ctx.isNewEmail {
            return "What should this email say?"
        }
        return "Tell me how to reply…"
    }

    private var headerTitle: String {
        if case .loadingContext = viewModel.state { return "Reading Mail…" }
        guard let ctx = viewModel.context else { return "AI Mail Composer" }
        return ctx.displaySubject
    }

    private var headerSubtitle: String? {
        guard let ctx = viewModel.context else { return nil }
        if ctx.isNewEmail {
            if ctx.hasRecipients {
                return "New email · \(ctx.recipientSummary)"
            }
            return "New email · no recipients yet"
        }
        let count = ctx.messageCount
        let label = count == 1 ? "message" : "messages"
        if ctx.hasRecipients {
            return "\(count) \(label) · \(ctx.recipientSummary)"
        }
        return "\(count) \(label) in thread"
    }

    private var statusColor: Color {
        if case .error = viewModel.state { return .red }
        if viewModel.isBusy { return .orange }
        if viewModel.state == .complete { return .green }
        if viewModel.context?.isNewEmail == true { return .blue }
        return .green
    }
}

// MARK: - Header

private struct ComposerHeader: View {
    let title: String
    let subtitle: String?
    let statusColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
                .shadow(color: statusColor.opacity(0.5), radius: 3)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        // Leave room on the leading edge for the standard macOS traffic-light
        // buttons (close/minimize/zoom) which sit inside the transparent
        // titlebar overlaid on top of this content via .fullSizeContentView.
        .padding(.leading, 80)
        .padding(.trailing, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - States

private struct LoadingState: View {
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            ProgressView()
                .controlSize(.small)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ReadyState: View {
    let context: ComposerContext?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let context {
                    ContextSummaryCard(context: context)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct ContextSummaryCard: View {
    let context: ComposerContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: context.isNewEmail ? "square.and.pencil" : "bubble.left.and.bubble.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(context.isNewEmail ? "New email" : "Reply context")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                Spacer()
            }

            if context.isNewEmail {
                Text(context.hasRecipients
                     ? "Drafting to \(context.recipients.joined(separator: ", "))"
                     : "Drafting a new message. Add recipients in Mail when you're ready.")
                    .font(.system(size: 12))
                    .foregroundStyle(.primary.opacity(0.85))
            } else if let thread = context.thread {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(thread.messages.suffix(3).enumerated()), id: \.offset) { _, message in
                        ThreadMessageRow(message: message)
                    }
                    if thread.messages.count > 3 {
                        Text("+ \(thread.messages.count - 3) earlier")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.leading, 14)
                    }
                }
            }

            if !context.currentDraft.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "doc.text")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                    Text("Existing draft will be kept and the reply added above it")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct ThreadMessageRow: View {
    let message: EmailMessage

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(Color.accentColor.opacity(0.18))
                .frame(width: 6, height: 6)
                .padding(.top, 5)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(senderShort)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                    Text(message.formattedDate)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Text(bodyPreview)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var senderShort: String {
        // Trim "Name <email>" to just the name or first part of email
        let raw = message.sender
        if let open = raw.firstIndex(of: "<") {
            return raw[..<open].trimmingCharacters(in: .whitespaces)
        }
        if let at = raw.firstIndex(of: "@") {
            return String(raw[..<at])
        }
        return raw
    }

    private var bodyPreview: String {
        message.body
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}

private struct GeneratingState: View {
    let thoughts: String
    @State private var pulse = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            UserBubble(text: thoughts)
                .padding(.horizontal, 16)
                .padding(.top, 16)

            HStack(spacing: 10) {
                ShimmerDot(delay: 0.0)
                ShimmerDot(delay: 0.15)
                ShimmerDot(delay: 0.30)
                Text("Drafting reply…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ShimmerDot: View {
    let delay: Double
    @State private var active = false

    var body: some View {
        Circle()
            .fill(Color.accentColor)
            .frame(width: 6, height: 6)
            .opacity(active ? 1.0 : 0.25)
            .animation(
                .easeInOut(duration: 0.6).repeatForever().delay(delay),
                value: active
            )
            .onAppear { active = true }
    }
}

private struct UserBubble: View {
    let text: String

    var body: some View {
        HStack(spacing: 0) {
            Spacer(minLength: 40)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.accentColor)
                )
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}

private struct ReplyResultView: View {
    @Binding var reply: String
    let userThoughts: String
    let isStreaming: Bool
    let onCopy: () -> Void
    let onInsert: () -> Void
    let onRegenerate: () -> Void
    let onEdit: () -> Void

    @State private var didCopy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                UserBubble(text: userThoughts)

                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.6)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                        .overlay(
                            Image(systemName: "sparkles")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.white)
                        )
                        .frame(width: 22, height: 22)

                    VStack(alignment: .leading, spacing: 8) {
                        StreamingTextView(
                            text: $reply,
                            isStreaming: isStreaming,
                            minHeight: 44
                        )

                        HStack(spacing: 6) {
                            ActionChip(
                                icon: didCopy ? "checkmark" : "doc.on.doc",
                                label: didCopy ? "Copied" : "Copy",
                                action: {
                                    onCopy()
                                    didCopy = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                        didCopy = false
                                    }
                                }
                            )
                            .disabled(isStreaming)
                            ActionChip(icon: "arrow.uturn.backward", label: "Edit", action: onEdit)
                                .disabled(isStreaming)
                            ActionChip(icon: "arrow.clockwise", label: "Regenerate", action: onRegenerate)
                                .disabled(isStreaming)
                            Spacer()
                            PrimaryActionButton(
                                icon: "doc.on.doc",
                                label: "Copy message",
                                action: onInsert
                            )
                            .keyboardShortcut(.return, modifiers: .command)
                            .disabled(isStreaming)
                        }
                        .opacity(isStreaming ? 0.55 : 1.0)
                        .animation(.easeOut(duration: 0.15), value: isStreaming)
                    }
                }
            }
            .padding(16)
        }
    }
}

/// Shows the AI reply sized exactly to its content.
///
/// During streaming we render a `Text` with a blinking caret concatenated at
/// the end. When streaming finishes we drop the caret and keep the same
/// `Text` — selectable, so the user can still click to copy, but no
/// `TextEditor` involved. `TextEditor` and `Text` use different line metrics
/// on macOS, which made the previous "auto-height editor" under-report its
/// required height and the content spilled out above and below the box.
///
/// The user's "Edit" chip means "go back and rewrite the prompt", so we never
/// actually need inline editing of the reply — dropping `TextEditor` here
/// trades a rarely-used feature for correct sizing in all cases.
private struct StreamingTextView: View {
    @Binding var text: String
    let isStreaming: Bool
    let minHeight: CGFloat

    var body: some View {
        Group {
            if isStreaming {
                StreamingCaretText(text: text)
            } else {
                Text(text)
                    .font(.system(size: 13))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
        }
        .padding(10)
        .frame(minHeight: minHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
    }
}

/// Text plus a blinking caret concatenated at the end, so the caret flows
/// with the final character instead of floating at the frame edge.
private struct StreamingCaretText: View {
    let text: String

    @State private var caretOn = true

    private let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()

    var body: some View {
        (Text(text) + Text("▎").foregroundColor(caretOn ? Color.accentColor : .clear))
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textSelection(.enabled)
            .onReceive(timer) { _ in caretOn.toggle() }
    }
}

private struct ActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .medium))
                Text(label)
                    .font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.10 : 0.05))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

private struct PrimaryActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.accentColor.opacity(hovering ? 0.9 : 1.0))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("⌘↵")
    }
}

private struct ErrorState: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 24))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try again") { onRetry() }
                .controlSize(.regular)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Input bar

private struct ComposerInputBar: View {
    @Binding var userThoughts: String
    let isEditable: Bool
    let isGenerating: Bool
    let canSend: Bool
    let placeholder: String
    @ObservedObject var settingsStore: SettingsStore
    let shouldFocus: Bool
    let claimsReturnShortcut: Bool
    let onSend: () -> Void

    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $userThoughts)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 48, maxHeight: 120)
                    .disabled(!isEditable)
                    .focused($editorFocused)
                    // Plain Return sends; Shift+Return inserts a newline like
                    // a normal chat input. Returning .handled swallows the
                    // event so TextEditor doesn't also insert a newline.
                    .onKeyPress(.return) {
                        if NSEvent.modifierFlags.contains(.shift) {
                            return .ignored
                        }
                        if canSend {
                            onSend()
                            return .handled
                        }
                        return .ignored
                    }
                if userThoughts.isEmpty {
                    // NSTextView uses a 5pt line-fragment padding on macOS and
                    // no vertical inset — match that so the placeholder sits
                    // exactly where the caret and first typed character will.
                    Text(placeholder)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary.opacity(0.7))
                        .padding(.leading, 5)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 8) {
                ModelPicker(settingsStore: settingsStore)
                Spacer()
                if claimsReturnShortcut {
                    SendButton(
                        enabled: canSend,
                        isGenerating: isGenerating,
                        action: onSend
                    )
                    .keyboardShortcut(.return, modifiers: .command)
                } else {
                    SendButton(
                        enabled: canSend,
                        isGenerating: isGenerating,
                        action: onSend
                    )
                }
            }
            .padding(.top, 6)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    editorFocused ? Color.accentColor.opacity(0.45) : Color.primary.opacity(0.10),
                    lineWidth: editorFocused ? 1.4 : 1
                )
                .animation(.easeOut(duration: 0.15), value: editorFocused)
        )
        .shadow(color: .black.opacity(editorFocused ? 0.08 : 0.05), radius: 10, y: 2)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .padding(.top, 4)
        .onAppear {
            if shouldFocus, isEditable {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    editorFocused = true
                }
            }
        }
        .onChange(of: isEditable) { _, newValue in
            if newValue, shouldFocus {
                editorFocused = true
            }
        }
    }
}

private struct ModelPicker: View {
    @ObservedObject var settingsStore: SettingsStore

    @State private var hovering = false

    var body: some View {
        Menu {
            menuContent
        } label: {
            HStack(spacing: 6) {
                ProviderGlyph(provider: settingsStore.selectedModel?.provider)
                Text(currentLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(hovering ? 0.10 : 0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var menuContent: some View {
        if settingsStore.allModels.isEmpty {
            Text("No models configured. Add an API key in Settings.")
        } else {
            // Top-level: newest models across every provider.
            Section("Latest") {
                ForEach(settingsStore.popularModels) { model in
                    modelButton(model, showProvider: true)
                }
            }

            // Per-provider: top 4 newest inline, rest tucked under a nested
            // submenu so clicking it opens the list instead of dismissing.
            ForEach(settingsStore.sortedGroupedModels, id: \.0) { provider, models in
                Section(provider.displayName) {
                    let preview = Array(models.prefix(4))
                    ForEach(preview) { model in
                        modelButton(model, showProvider: false)
                    }
                    if models.count > preview.count {
                        let overflow = Array(models.dropFirst(preview.count))
                        Menu("All \(provider.displayName) models (\(models.count))") {
                            ForEach(overflow) { model in
                                modelButton(model, showProvider: false)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func modelButton(_ model: AIModel, showProvider: Bool) -> some View {
        Button {
            settingsStore.selectedModelID = model.id
        } label: {
            if showProvider {
                Text("\(model.displayName) — \(model.provider.displayName)")
            } else {
                Text(model.displayName)
            }
        }
    }

    private var currentLabel: String {
        if let current = settingsStore.selectedModel {
            return current.displayName
        }
        if settingsStore.allModels.isEmpty {
            return "No model"
        }
        return "Choose model"
    }
}

private struct ProviderGlyph: View {
    let provider: AIProvider?

    var body: some View {
        Text(letter)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: 14, height: 14)
            .background(Circle().fill(color))
    }

    private var letter: String {
        provider?.badgeLetter ?? "·"
    }

    private var color: Color {
        switch provider {
        case .anthropic: return Color(red: 0.85, green: 0.50, blue: 0.30)
        case .openai: return Color(red: 0.10, green: 0.60, blue: 0.46)
        case .gemini: return Color(red: 0.30, green: 0.52, blue: 0.95)
        case .openrouter: return Color(red: 0.45, green: 0.30, blue: 0.85)
        case .none: return .secondary
        }
    }
}


private struct SendButton: View {
    let enabled: Bool
    let isGenerating: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        enabled
                        ? Color.accentColor.opacity(hovering ? 0.88 : 1.0)
                        : Color.primary.opacity(0.12)
                    )
                if isGenerating {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(enabled ? .white : .secondary)
                }
            }
            .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || isGenerating)
        .onHover { hovering = $0 }
        .help("Generate reply (⌘↵)")
    }
}
