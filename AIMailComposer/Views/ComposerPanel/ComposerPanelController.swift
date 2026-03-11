import AppKit
import SwiftUI

@MainActor
final class ComposerPanelController {
    private var panel: NSPanel?
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
    }

    func showPanel() {
        if let existingPanel = panel {
            existingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let viewModel = ComposerViewModel(settingsStore: settingsStore) { [weak self] in
            self?.closePanel()
        }

        let contentView = ComposerView(viewModel: viewModel)
            .environmentObject(settingsStore)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 480),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "AI Mail Composer"
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.isReleasedWhenClosed = false

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.panel = panel

        Task {
            await viewModel.activate()
        }
    }

    func closePanel() {
        panel?.close()
        panel = nil
    }
}
