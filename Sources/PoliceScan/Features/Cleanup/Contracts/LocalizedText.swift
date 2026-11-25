import Foundation

/// Text the engine sends in both languages. Example: text.text selects the current locale.
struct LocalizedText: Codable, Hashable, Sendable {
  let pt: String
  let en: String

  var text: String {
    LocalizedText.isPortuguese ? pt : en
  }

  /// The code the engine's --lang flag expects: "pt" or "en".
  static var languageCode: String {
    isPortuguese ? "pt" : "en"
  }

  private static var isPortuguese: Bool {
    Locale.current.language.languageCode?.identifier == "pt"
  }
}
