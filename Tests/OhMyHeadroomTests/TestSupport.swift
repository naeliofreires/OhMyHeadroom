import Foundation

struct CheckFailure: Error, CustomStringConvertible {
  let description: String
}

func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
  guard condition() else {
    throw CheckFailure(description: message)
  }
}

final class FakeCleanupGateway: CleanupGateway, @unchecked Sendable {
  let report: ScanReport
  var scanError: Error?
  var applyError: Error?
  var afterBytes: Int? = 0
  var appliedCategories: [Category] = []
  var applyCallCount = 0
  var progressStep: ScanStep?

  init(report: ScanReport) {
    self.report = report
  }

  func scan(onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport {
    if let scanError { throw scanError }
    if let progressStep { onStep(progressStep) }
    return report
  }

  func apply(_ categories: [Category]) async throws -> CleanupResult {
    applyCallCount += 1
    if let applyError { throw applyError }
    appliedCategories = categories
    return CleanupResult(
      beforeBytes: categories.reduce(0) { $0 + $1.sizeBytes }, afterBytes: afterBytes, log: "done"
    )
  }
}

final class FakeFreeSpaceReader: FreeSpaceReader, @unchecked Sendable {
  var value: Int?

  init(value: Int?) {
    self.value = value
  }

  func currentFreeBytes() -> Int? {
    value
  }
}

struct FakeFailure: LocalizedError {
  let errorDescription: String? = "fake failure"
}

final class StepSink: @unchecked Sendable {
  var step: ScanStep?
}

final class SequencedGatewayResolver: @unchecked Sendable {
  private let fallback: any CleanupGateway
  private var firstAttempt = true

  init(fallback: any CleanupGateway) {
    self.fallback = fallback
  }

  func resolve() throws -> any CleanupGateway {
    if firstAttempt {
      firstAttempt = false
      throw FakeFailure()
    }
    return fallback
  }
}

actor BlockingCleanupGateway: CleanupGateway {
  let report: ScanReport
  private let eventStream: AsyncStream<String>
  private let eventContinuation: AsyncStream<String>.Continuation
  private var scanContinuation: CheckedContinuation<ScanReport, Never>?
  private var pendingApply: (CheckedContinuation<CleanupResult, Never>, CleanupResult)?

  init(report: ScanReport) {
    var continuation: AsyncStream<String>.Continuation?
    let events = AsyncStream<String> { continuation = $0 }
    self.report = report
    eventStream = events
    eventContinuation = continuation!
  }

  func nextEvent() async -> String? {
    for await event in eventStream {
      return event
    }
    return nil
  }

  func scan(onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport {
    eventContinuation.yield("scan")
    return await withCheckedContinuation { scanContinuation = $0 }
  }

  func apply(_ categories: [Category]) async throws -> CleanupResult {
    eventContinuation.yield("apply")
    let result = CleanupResult(
      beforeBytes: categories.reduce(0) { $0 + $1.sizeBytes }, afterBytes: 0, log: "done"
    )
    return await withCheckedContinuation { pendingApply = ($0, result) }
  }

  func releaseScan() {
    scanContinuation?.resume(returning: report)
    scanContinuation = nil
  }

  func releaseApply() {
    guard let (continuation, result) = pendingApply else { return }
    continuation.resume(returning: result)
    pendingApply = nil
  }
}

@MainActor
func makeModel() -> CleanupModel {
  CleanupModel(
    gateway: FakeCleanupGateway(report: makeReport()),
    freeSpaceReader: FakeFreeSpaceReader(value: 500)
  )
}

func makeReport() -> ScanReport {
  ScanReport(
    safe: [makeCategory("caches", 100), makeCategory("deps-projects", 200)],
    review: [],
    freeBytes: 500
  )
}

func makeCategory(_ key: String, _ size: Int) -> Category {
  Category(
    key: key,
    label: makeText(key),
    note: makeText("note"),
    sizeBytes: size,
    paths: [SizedPath(path: "/Users/test/\(key)", sizeBytes: size)],
    commands: []
  )
}

func makeText(_ value: String) -> LocalizedText {
  LocalizedText(pt: value, en: value)
}

func fixtureURL(_ name: String) -> URL {
  URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appendingPathComponent("Fixtures")
    .appendingPathComponent(name)
}
