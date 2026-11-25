import Foundation

enum ByteFormat {
  /// nil means macOS blocked the read, which the engine reports as "no access".
  static func text(_ bytes: Int?) -> String {
    let language = AppLanguage.current
    guard let bytes else { return String(localized: "No access", bundle: language.stringsBundle) }
    return Int64(bytes).formatted(.byteCount(style: .file).locale(language.locale))
  }
}
