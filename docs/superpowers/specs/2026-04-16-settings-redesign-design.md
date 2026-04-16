# Settings Page Redesign

## Goal

Open settings on app launch and when clicking the menu bar icon. Reorganize settings into two clear categories: Keys and Writing Style.

## Behavior Changes

### Menu bar icon (left-click opens settings)

Currently the envelope icon shows a dropdown menu on click. Change to:

- **Left-click**: Opens the settings window directly
- **Right-click**: Shows the dropdown menu (Compose Reply, Settings, Quit)

Implementation: Use `button.sendAction(on: [.leftMouseUp])` to set a left-click action on the status item button. On left-click, call `openSettings()`. For right-click, programmatically show the menu via `statusItem.menu` assignment + `button.performClick(nil)` pattern, or use `NSEvent` monitoring.

### Open settings on launch

Call `openSettings()` from `applicationDidFinishLaunching`, after `setupMenuBar()` and `setupHotkey()`.

## Settings Layout

Replace the current `TabView` with a **segmented control** (`Picker` with `.segmented` style) at the top of the window. Two segments:

### Segment 1: "Keys"

Contains everything needed to connect to AI providers:

1. **API key fields** (unchanged from current `APIKeySettingsView`):
   - Anthropic (`sk-ant-api03-...`)
   - OpenAI (`sk-...`)
   - Google Gemini (`AIza...`)
   - OpenRouter (`sk-or-v1-...`) with footer description
   - "Save Keys" button + status message

2. **Model selection** (moved from its own tab):
   - Grouped model list by provider with "Popular" section
   - Refresh button
   - Empty/error states

The keys and model list are shown together in a single scrollable form. Keys at the top, model picker below.

### Segment 2: "Writing Style"

User-friendly way to customize how the AI writes emails.

1. **Description text** (static, not editable):
   > "Add your own instructions to guide how emails are written. For example: 'Keep it casual' or 'Always sign off with Cheers'."

2. **TextEditor** (multi-line text area):
   - Placeholder-like behavior when empty
   - Persisted via `@AppStorage("customWritingInstructions")`
   - No character limit enforced in UI

3. **How it integrates with the system prompt**:
   - The hardcoded base prompt in `SystemPrompt.swift` stays unchanged
   - If `customWritingInstructions` is non-empty, append it to the system message:
     ```
     \(baseSystemPrompt)

     ## Additional instructions from the user
     \(customWritingInstructions)
     ```
   - If empty, the system prompt is identical to today

No "Launch at login" toggle (dropped to keep things minimal).

## Window

- Title: "AI Mail Composer"
- Size: `NSRect(x: 0, y: 0, width: 500, height: 520)` (slightly taller to fit model list in Keys)
- Style: `.titled, .closable` (unchanged)

## Files Changed

| File | Change |
|------|--------|
| `AppDelegate.swift` | Left-click opens settings, right-click shows menu. Call `openSettings()` on launch. |
| `SettingsView.swift` | Replace `TabView` with segmented `Picker` switching between Keys and Writing Style views. Remove `GeneralSettingsView`. |
| `APIKeySettingsView.swift` | Add model selection list below the key fields (merge content from `ModelSelectionView`). |
| `ModelSelectionView.swift` | Delete file (content merged into `APIKeySettingsView`). |
| `SettingsStore.swift` | Add `@AppStorage("customWritingInstructions")` property. Remove `launchAtLogin`. |
| `SystemPrompt.swift` | Accept optional `customInstructions: String` parameter. Append to system message when non-empty. |
| `ComposerViewModel.swift` | Pass `settingsStore.customWritingInstructions` through to `SystemPrompt.compose()`. |

New file: `WritingStyleView.swift` in `Views/Settings/` for the Writing Style segment.
