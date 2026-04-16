# Settings Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open settings on app launch and on menu bar click, reorganize settings into two categories (Keys + Writing Style) with user-customizable writing instructions.

**Architecture:** Replace the 3-tab `TabView` with a 2-segment `Picker`. Merge model selection into the Keys view. Add a new Writing Style view with a free-text `TextEditor`. Persist custom instructions via `@AppStorage` and append them to the system prompt at generation time. Change menu bar icon to open settings on left-click, show menu on right-click.

**Tech Stack:** SwiftUI, AppKit (NSStatusItem, NSWindow, NSEvent)

---

### Task 1: Add `customWritingInstructions` to SettingsStore

**Files:**
- Modify: `AIMailComposer/App/SettingsStore.swift:8-9`

- [ ] **Step 1: Add the new property and remove `launchAtLogin`**

In `SettingsStore.swift`, replace:

```swift
@AppStorage("selectedModelID") var selectedModelID: String = ""
@AppStorage("launchAtLogin") var launchAtLogin: Bool = false
```

with:

```swift
@AppStorage("selectedModelID") var selectedModelID: String = ""
@AppStorage("customWritingInstructions") var customWritingInstructions: String = ""
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/jp/code/aimail && xcodebuild -scheme AIMailComposer -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Expected: Compile errors in `GeneralSettingsView` referencing `launchAtLogin`. That's expected — we'll fix it in Task 5.

- [ ] **Step 3: Commit**

```bash
git add AIMailComposer/App/SettingsStore.swift
git commit -m "feat: add customWritingInstructions to SettingsStore, remove launchAtLogin"
```

---

### Task 2: Thread custom instructions into SystemPrompt

**Files:**
- Modify: `AIMailComposer/Services/AI/SystemPrompt.swift:4`
- Modify: `AIMailComposer/Views/ComposerPanel/ComposerViewModel.swift:77-80`

- [ ] **Step 1: Add `customInstructions` parameter to `SystemPrompt.compose`**

In `SystemPrompt.swift`, change the method signature from:

```swift
static func compose(context: ComposerContext, userThoughts: String) -> (system: String, user: String) {
```

to:

```swift
static func compose(context: ComposerContext, userThoughts: String, customInstructions: String = "") -> (system: String, user: String) {
```

- [ ] **Step 2: Append custom instructions to the system message**

In `SystemPrompt.swift`, just before the final `return (system, ...)` line, replace:

```swift
        return (system, userParts.joined(separator: "\n"))
```

with:

```swift
        var finalSystem = system
        let trimmed = customInstructions.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            finalSystem += "\n\n## Additional instructions from the user\n" + trimmed
        }

        return (finalSystem, userParts.joined(separator: "\n"))
```

- [ ] **Step 3: Pass custom instructions from ComposerViewModel**

In `ComposerViewModel.swift`, change:

```swift
        let (systemPrompt, userMessage) = SystemPrompt.compose(
            context: context,
            userThoughts: trimmed
        )
```

to:

```swift
        let (systemPrompt, userMessage) = SystemPrompt.compose(
            context: context,
            userThoughts: trimmed,
            customInstructions: settingsStore.customWritingInstructions
        )
```

- [ ] **Step 4: Commit**

```bash
git add AIMailComposer/Services/AI/SystemPrompt.swift AIMailComposer/Views/ComposerPanel/ComposerViewModel.swift
git commit -m "feat: thread custom writing instructions into system prompt"
```

---

### Task 3: Create WritingStyleView

**Files:**
- Create: `AIMailComposer/Views/Settings/WritingStyleView.swift`

- [ ] **Step 1: Create the view file**

Create `AIMailComposer/Views/Settings/WritingStyleView.swift`:

```swift
import SwiftUI

struct WritingStyleView: View {
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add your own instructions to guide how emails are written. For example: \"Keep it casual\" or \"Always sign off with Cheers\".")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            TextEditor(text: $settingsStore.customWritingInstructions)
                .font(.body)
                .frame(maxHeight: .infinity)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .textBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .overlay(alignment: .topLeading, content: {
                    if settingsStore.customWritingInstructions.isEmpty {
                        Text("e.g. Be concise and friendly, use British English...")
                            .foregroundStyle(.tertiary)
                            .padding(.leading, 13)
                            .padding(.top, 16)
                            .allowsHitTesting(false)
                    }
                })
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add AIMailComposer/Views/Settings/WritingStyleView.swift
git commit -m "feat: add WritingStyleView with free-text instructions editor"
```

---

### Task 4: Merge model selection into APIKeySettingsView

**Files:**
- Modify: `AIMailComposer/Views/Settings/APIKeySettingsView.swift`

- [ ] **Step 1: Add model list below the key fields**

Replace the entire contents of `APIKeySettingsView.swift` with:

```swift
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
        VStack(spacing: 0) {
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

            Divider()

            modelSection
        }
    }

    // MARK: - Model Selection

    private var isFetching: Bool {
        settingsStore.isFetchingAnthropic
            || settingsStore.isFetchingOpenAI
            || settingsStore.isFetchingGemini
            || settingsStore.isFetchingOpenRouter
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

            fetchErrorLines
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
        }
    }

    // MARK: - Save

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
```

- [ ] **Step 2: Commit**

```bash
git add AIMailComposer/Views/Settings/APIKeySettingsView.swift
git commit -m "feat: merge model selection into APIKeySettingsView"
```

---

### Task 5: Replace SettingsView TabView with segmented Picker, delete old files

**Files:**
- Modify: `AIMailComposer/Views/Settings/SettingsView.swift`
- Delete: `AIMailComposer/Views/Settings/ModelSelectionView.swift`

- [ ] **Step 1: Rewrite SettingsView with segmented picker**

Replace the entire contents of `SettingsView.swift` with:

```swift
import SwiftUI

struct SettingsView: View {
    enum Tab: String, CaseIterable {
        case keys = "Keys"
        case writingStyle = "Writing Style"
    }

    @State private var selectedTab: Tab = .keys

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            switch selectedTab {
            case .keys:
                APIKeySettingsView()
            case .writingStyle:
                WritingStyleView()
            }
        }
        .frame(width: 500, height: 520)
    }
}
```

- [ ] **Step 2: Delete ModelSelectionView.swift**

```bash
git rm AIMailComposer/Views/Settings/ModelSelectionView.swift
```

- [ ] **Step 3: Verify build**

Run: `cd /Users/jp/code/aimail && xcodebuild -scheme AIMailComposer -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: Commit**

```bash
git add AIMailComposer/Views/Settings/SettingsView.swift
git commit -m "feat: replace TabView with segmented picker, remove ModelSelectionView"
```

---

### Task 6: Change menu bar icon behavior and open settings on launch

**Files:**
- Modify: `AIMailComposer/App/AppDelegate.swift`

- [ ] **Step 1: Rewrite AppDelegate**

Replace the entire contents of `AppDelegate.swift` with:

```swift
import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyService: HotkeyService?
    private var panelController: ComposerPanelController?
    private var settingsWindow: NSWindow?
    private var statusMenu: NSMenu!
    let settingsStore = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkey()
        Task { await settingsStore.fetchAllModels() }
        openSettings()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        // Build the menu (shown on right-click only)
        statusMenu = NSMenu()
        statusMenu.addItem(NSMenuItem(title: "Compose Reply (⌥H)", action: #selector(showComposerPanel), keyEquivalent: ""))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit AI Mail Composer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "envelope.badge.fill", accessibilityDescription: "AI Mail Composer")
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            // Right-click: show dropdown menu
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            // Remove menu so the next left-click doesn't trigger it
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            // Left-click: open settings
            openSettings()
        }
    }

    private func setupHotkey() {
        hotkeyService = HotkeyService { [weak self] in
            self?.showComposerPanel()
        }
        hotkeyService?.register()
    }

    @objc func showComposerPanel() {
        if panelController == nil {
            panelController = ComposerPanelController(settingsStore: settingsStore)
        }
        panelController?.showPanel()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(settingsStore)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 520),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Mail Composer"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/jp/code/aimail && xcodebuild -scheme AIMailComposer -configuration Debug -destination 'platform=macOS' build 2>&1 | tail -5`

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add AIMailComposer/App/AppDelegate.swift
git commit -m "feat: left-click menu icon opens settings, right-click shows menu, open settings on launch"
```

---

### Task 7: Manual smoke test

- [ ] **Step 1: Build and run**

Run: `cd /Users/jp/code/aimail && make build && make run` (or open in Xcode and run)

- [ ] **Step 2: Verify settings opens on launch**

Expected: Settings window appears immediately when the app starts.

- [ ] **Step 3: Verify segmented picker**

Expected: Two segments at the top — "Keys" and "Writing Style". Keys is selected by default. API key fields are visible with model list below them.

- [ ] **Step 4: Click "Writing Style" segment**

Expected: Free-text editor with placeholder text appears. Type some instructions, switch to Keys and back — text persists.

- [ ] **Step 5: Test menu bar icon**

- Left-click the envelope icon: Settings window comes to front.
- Right-click the envelope icon: Dropdown menu appears (Compose Reply, Settings, Quit).

- [ ] **Step 6: Test custom instructions end-to-end**

Type instructions like "Always sign off with Cheers" in Writing Style. Use ⌥H to compose an email. Verify the AI follows the custom instruction.

- [ ] **Step 7: Final commit**

If any fixes were needed during smoke testing, commit them:

```bash
git add -A
git commit -m "fix: address issues found during smoke test"
```
