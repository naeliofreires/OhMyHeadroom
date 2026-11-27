import AppKit
import SwiftUI

/// Menu bar entry point. The label shows free space, so the number is visible without opening anything.
@main
struct OhMyHeadroomApp: App {
  @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.systemDefault
  @AppStorage(AppTheme.preferenceKey) private var theme = AppTheme.system
  // A plain constant: the Command Line Tools cannot expand the @State macro, and the app
  // only needs one model for the menu bar and the preferences window.
  private let model = CleanupModel(
    gateway: CleanupComposition.makeGateway(),
    updateChecker: GitHubMainUpdateChecker()
  )

  var body: some Scene {
    MenuBarExtra {
      MenuPanelView(model: model)
        .environment(\.locale, language.locale)
        .id(language)
    } label: {
      menuBarLabel
    }
    .menuBarExtraStyle(.window)
    .onChange(of: theme, initial: true) {
      NSApplication.shared.appearance = theme.appearance
    }

    Window(String(localized: "Project folders", bundle: language.stringsBundle), id: ScanRootsView.windowID) {
      ScanRootsView(model: model)
        .environment(\.locale, language.locale)
        .frame(width: 500, height: 580)
    }
    .defaultLaunchBehavior(.suppressed)
    .restorationBehavior(.disabled)
    .windowResizability(.contentSize)
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
    .help("OhMyHeadroom")
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("OhMyHeadroom")

    if model.freeBytes != nil {
      label.accessibilityValue(model.menuBarTitle)
    } else {
      label
    }
  }
}

enum AppTheme: String {
  case system
  case light
  case dark

  static let preferenceKey = "appTheme"

  var appearance: NSAppearance? {
    switch self {
    case .system: nil
    case .light: NSAppearance(named: .aqua)
    case .dark: NSAppearance(named: .darkAqua)
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
