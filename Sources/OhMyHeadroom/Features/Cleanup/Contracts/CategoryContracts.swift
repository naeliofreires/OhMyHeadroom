import Foundation

/// One safe-to-clean category from the scan. It mirrors the Python engine's wire contract.
struct Category: Codable, Identifiable, Hashable, Sendable {
  let key: String
  let label: LocalizedText
  let note: LocalizedText
  let sizeBytes: Int
  let paths: [SizedPath]
  let commands: [[String]]

  var id: String { key }

  /// Deps are big and need a reinstall afterwards, so they stay unchecked by default.
  var isOffByDefault: Bool { key.hasPrefix("deps-") }
}

/// A path the engine would remove, with the bytes it occupies.
struct SizedPath: Codable, Hashable, Sendable {
  let path: String
  let sizeBytes: Int
}

/// A folder the user decides about. Never deleted by the app.
struct ReviewLine: Codable, Identifiable, Hashable, Sendable {
  let label: LocalizedText
  let note: LocalizedText
  let sizeBytes: Int?
  let folder: String?

  var id: String { label.en }
}

/// The full answer of cleanup.py scan --json.
struct ScanReport: Codable, Sendable {
  let safe: [Category]
  let review: [ReviewLine]
  let freeBytes: Int
}
