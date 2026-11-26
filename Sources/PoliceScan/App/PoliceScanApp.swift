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
      menuBarLabel
    }
    .menuBarExtraStyle(.window)
  }

  @ViewBuilder
  private var menuBarLabel: some View {
    let label = HStack(spacing: 4) {
      Image(nsImage: BrandArtwork.menuBarImage)
        .renderingMode(.template)
        .frame(width: 18, height: 18)
        .accessibilityHidden(true)
      Text(model.menuBarTitle)
        .monospacedDigit()
    }
    .environment(\.locale, language.locale)
    .help("Headroom")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Headroom")

    if model.freeBytes != nil {
      label.accessibilityValue(model.menuBarTitle)
    } else {
      label
    }
  }
}

/// Composition root for the cleanup feature. Resolution stays lazy so a missing engine can be
/// installed after launch and retried on the next operation.
enum CleanupComposition {
  static func makeGateway() -> any CleanupGateway {
    LazyCleanupGateway(resolve: { try CleanupEngine.locate() })
  }
}
