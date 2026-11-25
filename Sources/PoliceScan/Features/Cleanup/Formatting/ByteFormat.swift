import Foundation

enum ByteFormat {
  /// nil means macOS blocked the read, which the engine reports as "no access".
  static func text(_ bytes: Int?) -> String {
    guard let bytes else { return String(localized: "No access") }
    return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
  }
}
