import Foundation

protocol CleanupGateway: Sendable {
  func scan(onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport
  func apply(_ categories: [Category]) async throws -> String
}

protocol FreeSpaceReader: Sendable {
  func currentFreeBytes() -> Int?
}

struct FileSystemFreeSpaceReader: FreeSpaceReader {
  func currentFreeBytes() -> Int? {
    let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
    return (attributes?[.systemFreeSize] as? NSNumber)?.intValue
  }
}

struct LazyCleanupGateway: CleanupGateway {
  let resolve: @Sendable () throws -> any CleanupGateway

  /// Resolves the engine for each operation so installation changes are retried.
  func scan(onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport {
    let gateway = try resolve()
    return try await gateway.scan(onStep: onStep)
  }

  func apply(_ categories: [Category]) async throws -> String {
    let gateway = try resolve()
    return try await gateway.apply(categories)
  }
}
