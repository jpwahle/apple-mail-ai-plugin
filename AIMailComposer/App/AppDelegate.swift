import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hotkeyService: HotkeyService?
    private var panelController: ComposerPanelController?
    private var settingsWindow: NSWindow?
    private var statusMenu: NSMenu!
    private var composeMenuItem: NSMenuItem!
    let settingsStore = SettingsStore()
    let updateChecker = UpdateChecker()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // SwiftUI's Settings scene auto-creates an empty window on launch.
        // Close any auto-created windows before we present our own UI.
        NSApp.windows.forEach { $0.close() }

        setupMenuBar()
        setupHotkey()
        observeHotkeyChanges()
        Task { await settingsStore.fetchAllModels() }
        openSettings()
        Task { updateChecker.checkForUpdates() }
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        let shortcut = currentShortcutDisplay()
        composeMenuItem = NSMenuItem(
            title: "Compose Reply (\(shortcut))",
            action: #selector(showComposerPanel),
            keyEquivalent: ""
        )

        statusMenu = NSMenu()
        statusMenu.addItem(composeMenuItem)
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        statusMenu.addItem(NSMenuItem.separator())
        statusMenu.addItem(NSMenuItem(title: "Quit Apple Mail AI Plugin", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "envelope.badge.fill", accessibilityDescription: "Apple Mail AI Plugin")
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.target = self
        }
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            openSettings()
        }
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyService = HotkeyService { [weak self] in
            self?.showComposerPanel()
        }
        hotkeyService?.register(
            keyCode: UInt32(settingsStore.hotkeyKeyCode),
            modifiers: UInt32(settingsStore.hotkeyModifiers)
        )
    }

    private func observeHotkeyChanges() {
        NotificationCenter.default.addObserver(
            forName: SettingsStore.hotkeyDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refreshHotkey()
            }
        }
    }

    private func refreshHotkey() {
        hotkeyService?.register(
            keyCode: UInt32(settingsStore.hotkeyKeyCode),
            modifiers: UInt32(settingsStore.hotkeyModifiers)
        )
        composeMenuItem.title = "Compose Reply (\(currentShortcutDisplay()))"
    }

    private func currentShortcutDisplay() -> String {
        HotkeyService.shortcutDisplayString(
            keyCode: UInt32(settingsStore.hotkeyKeyCode),
            modifiers: UInt32(settingsStore.hotkeyModifiers)
        )
    }

    // MARK: - Composer

    @objc func showComposerPanel() {
        if panelController == nil {
            panelController = ComposerPanelController(settingsStore: settingsStore)
        }
        panelController?.showPanel()
    }

    // MARK: - Settings

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
            .environmentObject(settingsStore)
            .environmentObject(updateChecker)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Apple Mail AI Plugin"
        window.contentView = NSHostingView(rootView: settingsView)
        window.center()
        window.isReleasedWhenClosed = false
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        self.settingsWindow = window
    }
}
