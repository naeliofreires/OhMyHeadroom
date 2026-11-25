import SwiftUI

/// Menu bar entry point. The label shows free space, so the number is visible without opening anything.
@main
struct PoliceScanApp: App {
  @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.systemDefault
  // A plain constant: the Command Line Tools cannot expand the @State macro, and the app
  // only has this one scene, so the model lives as long as the app does.
  private let model = CleanupModel(gateway: CleanupComposition.makeGateway())

  var body: some Scene {
    MenuBarExtra {
      MenuPanelView(model: model)
        .environment(\.locale, language.locale)
        .id(language)
    } label: {
      // Label would show only the icon in the menu bar; an explicit HStack keeps the number visible.
      HStack(spacing: 4) {
        Image(systemName: "internaldrive")
        Text(model.menuBarTitle)
          .monospacedDigit()
      }
      .environment(\.locale, language.locale)
    }
    .menuBarExtraStyle(.window)
  }
}

/// Composition root for the cleanup feature. Resolution stays lazy so a missing engine can be
/// installed after launch and retried on the next operation.
enum CleanupComposition {
  static func makeGateway() -> any CleanupGateway {
    LazyCleanupGateway(resolve: { try CleanupEngine.locate() })
  }
}
