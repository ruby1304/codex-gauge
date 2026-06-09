import SwiftUI

@main
struct CodexGaugeApp: App {
    @State private var model = UsageModel()

    var body: some Scene {
        MenuBarExtra {
            PopoverView(model: model)
        } label: {
            Text(model.menuBarTitle)
                .foregroundStyle(model.menuBarColor ?? .primary)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: model)
        }
    }
}
