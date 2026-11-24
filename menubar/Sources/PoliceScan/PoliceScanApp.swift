import SwiftUI

/// Menu bar entry point. The label shows free space, so the number is visible without opening anything.
@main
struct PoliceScanApp: App {
    // A plain constant: the Command Line Tools cannot expand the @State macro, and the app
    // only has this one scene, so the model lives as long as the app does.
    private let model = CleanupModel()

    var body: some Scene {
        MenuBarExtra {
            MenuPanelView(model: model)
        } label: {
            // Label would show only the icon in the menu bar; an explicit HStack keeps the number visible.
            HStack(spacing: 4) {
                Image(systemName: "internaldrive")
                Text(model.menuBarTitle)
            }
        }
        .menuBarExtraStyle(.window)
    }
}
