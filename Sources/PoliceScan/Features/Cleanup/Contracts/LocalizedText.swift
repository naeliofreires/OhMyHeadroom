import Foundation

enum AppLanguage: String, CaseIterable {
  case english = "en"
  case portuguese = "pt-BR"

  static let preferenceKey = "appLanguage"
  static var systemDefault: Self {
    Bundle.preferredLocalizations(from: allCases.map(\.rawValue)).first
      .flatMap(Self.init(rawValue:)) ?? .english
  }

  static var current: Self {
    UserDefaults.standard.string(forKey: preferenceKey).flatMap(Self.init(rawValue:))
      ?? systemDefault
  }

  var locale: Locale { Locale(identifier: rawValue) }
  var engineCode: String { self == .portuguese ? "pt" : "en" }

  var stringsBundle: Bundle {
    Bundle.main.url(forResource: rawValue, withExtension: "lproj")
      .flatMap(Bundle.init(url:)) ?? .main
  }
}

/// Text the engine sends in both languages.
struct LocalizedText: Codable, Hashable, Sendable {
  let pt: String
  let en: String

  var text: String {
    AppLanguage.current == .portuguese ? pt : en
  }
}
