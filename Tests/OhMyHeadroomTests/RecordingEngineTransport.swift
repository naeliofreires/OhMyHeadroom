import Foundation

/// Named fake transport: records each engine call's arguments and replies with canned JSON.
final class RecordingEngineTransport: EngineTransport, @unchecked Sendable {
  private(set) var calls: [[String]] = []
  private(set) var inputs: [Data] = []
  let scanOutput: Data
  let applyOutput: Data

  init(scanReport: ScanReport, applyResult: CleanupResult) throws {
    scanOutput = try EngineJSON.encoder().encode(scanReport)
    applyOutput = try EngineJSON.encoder().encode(applyResult)
  }

  func exchange(
    arguments: [String],
    input: Data,
    onStep: (@Sendable (ScanStep) -> Void)?
  ) async throws -> Data {
    calls.append(arguments)
    inputs.append(input)
    return arguments.first == "apply" ? applyOutput : scanOutput
  }
}
