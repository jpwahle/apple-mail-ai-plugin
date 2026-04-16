import AppKit
import SwiftUI

@MainActor
final class ComposerPanelController: NSObject {
    private var panel: NSPanel?
    private var viewModel: ComposerViewModel?
    private let settingsStore: SettingsStore

    init(settingsStore: SettingsStore) {
        self.settingsStore = settingsStore
        super.init()
    }

    func showPanel() {
        if let existingPanel = panel {
            existingPanel.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }

        let viewModel = ComposerViewModel(settingsStore: settingsStore) { [weak self] in
            self?.closePanel()
        }

        let contentView = ComposerView(viewModel: viewModel)
            .environmentObject(settingsStore)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "AI Mail Composer"
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.contentView = NSHostingView(rootView: contentView)
        panel.center()
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate()

        self.panel = panel
        self.viewModel = viewModel

        Task {
            await viewModel.activate()
            if let frame = viewModel.context?.composeWindowFrame {
                self.anchorPanel(toComposeWindow: frame)
            }
        }
    }

    /// Place the panel flush against the right edge of the Mail compose window,
    /// so the two read as a single visual unit.
    ///
    /// `frame` comes from AppleScript/AX (top-left origin). We convert to
    /// Cocoa's bottom-left origin and clamp to the screen containing the
    /// compose window.
    private func anchorPanel(toComposeWindow axFrame: CGRect) {
        guard let panel else { return }
        let screens = NSScreen.screens
        guard let primary = NSScreen.screens.first(where: { $0.frame.origin == .zero }) ?? screens.first else { return }

        // Convert AX top-left to Cocoa bottom-left using the primary display height.
        // AX y is measured from the top of the primary display.
        let primaryHeight = primary.frame.height
        let cocoaY = primaryHeight - axFrame.origin.y - axFrame.size.height
        let composeCocoa = CGRect(x: axFrame.origin.x, y: cocoaY, width: axFrame.size.width, height: axFrame.size.height)

        // Find the screen that contains the compose window's center.
        let center = CGPoint(x: composeCocoa.midX, y: composeCocoa.midY)
        let targetScreen = screens.first(where: { $0.frame.contains(center) }) ?? primary

        let desiredWidth: CGFloat = max(panel.frame.width, 420)
        let desiredHeight = min(composeCocoa.height, targetScreen.visibleFrame.height - 40)

        // Prefer the right side; fall back to the left if there isn't room.
        var x = composeCocoa.maxX + 12
        let screenFrame = targetScreen.visibleFrame
        if x + desiredWidth > screenFrame.maxX {
            let leftX = composeCocoa.minX - desiredWidth - 12
            if leftX >= screenFrame.minX {
                x = leftX
            } else {
                x = screenFrame.maxX - desiredWidth - 8
            }
        }

        var y = composeCocoa.origin.y + (composeCocoa.height - desiredHeight) / 2
        y = max(screenFrame.minY + 8, min(y, screenFrame.maxY - desiredHeight - 8))

        let target = NSRect(x: x, y: y, width: desiredWidth, height: desiredHeight)
        panel.setFrame(target, display: true, animate: true)
    }

    func closePanel() {
        panel?.close()
        // windowWillClose(_:) clears the stored references.
    }
}

extension ComposerPanelController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Runs when closed via standard red close button OR via closePanel().
        // Drop references so showPanel() creates a fresh instance next time.
        panel = nil
        viewModel = nil
    }
}
