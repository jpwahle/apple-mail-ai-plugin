import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            APIKeySettingsView()
                .tabItem {
                    Label("API Keys", systemImage: "key")
                }
            ModelSelectionView()
                .tabItem {
                    Label("Models", systemImage: "cpu")
                }
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject var settingsStore: SettingsStore

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settingsStore.launchAtLogin)
            Section {
                LabeledContent("Hotkey") {
                    Text("⌥H (Option + H)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
