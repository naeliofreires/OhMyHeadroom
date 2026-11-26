import Foundation

struct CleanupResult: Codable, Equatable, Sendable {
  let beforeBytes: Int
  let afterBytes: Int?
  let log: String

  var reductionBytes: Int? { afterBytes.map { beforeBytes - $0 } }
}
