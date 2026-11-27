import Foundation

protocol CleanupGateway: Sendable {
  func scan(dependencyRoots: [String], onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport
  /// `permanent` true deletes for good; false moves each selected path to the Trash.
  func apply(_ categories: [Category], permanent: Bool) async throws -> CleanupResult
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
  func scan(dependencyRoots: [String], onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport {
    let gateway = try resolve()
    return try await gateway.scan(dependencyRoots: dependencyRoots, onStep: onStep)
  }

  func apply(_ categories: [Category], permanent: Bool) async throws -> CleanupResult {
    let gateway = try resolve()
    return try await gateway.apply(categories, permanent: permanent)
  }
}
