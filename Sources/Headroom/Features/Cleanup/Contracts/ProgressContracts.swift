import Foundation

/// The folder the engine is measuring right now, e.g. "Docker images" at 4 of 17.
struct ScanStep: Equatable, Sendable {
  let position: Int
  let total: Int
  let label: LocalizedText
  let path: String
}

/// One line the engine writes to stderr during a scan. "start" is not shown by the UI.
struct ProgressLine: Decodable {
  let event: String
  let position: Int?
  let total: Int?
  let label: LocalizedText?
  let path: String?

  var step: ScanStep? {
    guard event == "step", let position, let total, let label, let path else { return nil }
    return ScanStep(position: position, total: total, label: label, path: path)
  }
}
