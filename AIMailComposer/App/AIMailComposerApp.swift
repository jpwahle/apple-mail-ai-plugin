import SwiftUI

@main
struct AIMailComposerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible scenes — this is a menu bar app.
        // Settings window is managed manually by AppDelegate.
        Window("Hidden", id: "hidden") {
            EmptyView()
        }
        .defaultSize(width: 0, height: 0)
    }
}
