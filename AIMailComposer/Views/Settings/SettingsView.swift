import SwiftUI

struct SettingsView: View {
    enum Tab: String, CaseIterable {
        case general = "General"
        case keys = "Keys"
        case writing = "Writing"
    }

    @State private var selectedTab: Tab = .general

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $selectedTab) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()

            Group {
                switch selectedTab {
                case .general:
                    GeneralSettingsView()
                case .keys:
                    APIKeySettingsView()
                case .writing:
                    WritingStyleView()
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(minWidth: 500, minHeight: 560, alignment: .top)
    }
}
