import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore
    @EnvironmentObject var updateChecker: UpdateChecker

    private var shortcutDisplay: String {
        HotkeyService.shortcutDisplayString(
            keyCode: UInt32(settingsStore.hotkeyKeyCode),
            modifiers: UInt32(settingsStore.hotkeyModifiers)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 24) {
                howToUse
                Divider()
                shortcutSection
                Divider()
                updateSection
            }
            .padding(20)

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - How to Use

    private var howToUse: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("How to Use")
                .font(.system(size: 13, weight: .semibold))

            VStack(alignment: .leading, spacing: 10) {
                step(1, "Open or reply to an email in Apple Mail")
                step(2, "Press **\(shortcutDisplay)** to open the AI composer")
                step(3, "Describe what you want to say")
                step(4, "Your reply is generated and inserted into the draft")
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Shortcut

    private var shortcutSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keyboard Shortcut")
                .font(.system(size: 13, weight: .semibold))

            Text("Global shortcut to open the composer panel from anywhere.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            ShortcutRecorderView(settingsStore: settingsStore)
        }
    }

    // MARK: - Updates

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Updates")
                .font(.system(size: 13, weight: .semibold))

            HStack(spacing: 12) {
                Text("Version \(updateChecker.currentVersion)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                Spacer()

                updateStatusView
            }
        }
    }

    @ViewBuilder
    private var updateStatusView: some View {
        switch updateChecker.state {
        case .idle:
            Button("Check for Updates") {
                updateChecker.checkForUpdates(manual: true)
            }
            .controlSize(.small)

        case .checking:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

        case .downloading:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Downloading v\(updateChecker.latestVersion ?? "")...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

        case .readyToInstall:
            Button("Relaunch to Update to v\(updateChecker.latestVersion ?? "")") {
                updateChecker.install()
            }
            .controlSize(.small)

        case .installing:
            HStack(spacing: 6) {
                ProgressView()
                    .controlSize(.small)
                Text("Installing...")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }

        case .failed(let message):
            VStack(alignment: .trailing, spacing: 4) {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(2)
                Button("Retry") {
                    updateChecker.checkForUpdates(manual: true)
                }
                .controlSize(.small)
            }
        }
    }
}

// MARK: - Shortcut Recorder

private struct ShortcutRecorderView: View {
    @ObservedObject var settingsStore: SettingsStore
    @State private var isRecording = false
    @State private var eventMonitor: Any?

    private var displayString: String {
        HotkeyService.shortcutDisplayString(
            keyCode: UInt32(settingsStore.hotkeyKeyCode),
            modifiers: UInt32(settingsStore.hotkeyModifiers)
        )
    }

    var body: some View {
        HStack(spacing: 10) {
            // Current shortcut badge
            Text(isRecording ? "Press shortcut…" : displayString)
                .font(isRecording
                    ? .system(size: 12)
                    : .system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(isRecording ? .secondary : .primary)
                .frame(minWidth: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(isRecording ? 0.03 : 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isRecording ? Color.accentColor : Color.primary.opacity(0.1),
                            lineWidth: isRecording ? 1.5 : 1
                        )
                )

            Button(isRecording ? "Cancel" : "Record New Shortcut") {
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
            }
            .controlSize(.small)
        }
        .onDisappear {
            stopRecording()
        }
    }

    private func startRecording() {
        isRecording = true
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Escape cancels recording
            if event.keyCode == 53 { // kVK_Escape
                stopRecording()
                return nil
            }

            // Require at least one modifier key
            let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
            guard !mods.isEmpty else { return event }

            let carbonMods = HotkeyService.carbonModifiers(from: event.modifierFlags)
            settingsStore.setHotkey(keyCode: Int(event.keyCode), modifiers: Int(carbonMods))
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        isRecording = false
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
