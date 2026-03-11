import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyService: HotkeyService?
    private var panelController: ComposerPanelController?
    private var settingsWindow: NSWindow?
    let settingsStore = SettingsStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHotkey()
        Task { await settingsStore.fetchAllModels() }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "envelope.badge.fill", accessibilityDescription: "AI Mail Composer")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Compose Reply (⌥H)", action: #selector(showComposerPanel), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit AI Mail Composer", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
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
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "AI Mail Composer Settings"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }
}
