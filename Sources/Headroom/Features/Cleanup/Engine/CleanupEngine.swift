import Foundation

enum EngineError: LocalizedError {
  case pythonMissing
  case scriptMissing(path: String)
  case failed(status: Int32, message: String)

  var errorDescription: String? {
    switch self {
    case .pythonMissing:
      return String(localized: "Python 3 was not found in /opt/homebrew/bin or /usr/local/bin.", bundle: AppLanguage.current.stringsBundle)
    case .scriptMissing(let path):
      return String(
        localized: "The engine was not found at \(path). It should be in the Headroom folder.", bundle: AppLanguage.current.stringsBundle)
    case .failed(let status, let message):
      return String(localized: "The engine failed with code \(String(status)): \(message)", bundle: AppLanguage.current.stringsBundle)
    }
  }
}

/// A launched engine process with its pipes, so its output can be read while it runs.
private struct RunningEngine {
  let process: Process
  let standardOutput: Pipe
  let standardError: Pipe
}

/// Runs the Python engine in ~/Developer/Headroom and returns what it printed.
struct CleanupEngine: CleanupGateway, Sendable {
  let pythonPath: String
  let scriptPath: String

  private static let pythonCandidates = [
    "/opt/homebrew/bin/python3",
    "/usr/local/bin/python3",
  ]

  /// A menu bar app launched from Finder gets a minimal PATH, so docker is added by hand.
  private static let toolPath = [
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/Applications/Docker.app/Contents/Resources/bin",
    "/usr/bin",
    "/bin",
    "/usr/sbin",
    "/sbin",
  ].joined(separator: ":")

  static func locate() throws -> CleanupEngine {
    let fileManager = FileManager.default
    guard let python = pythonCandidates.first(where: fileManager.isExecutableFile(atPath:)) else {
      throw EngineError.pythonMissing
    }
    let script = NSHomeDirectory() + "/Developer/Headroom/cleanup.py"
    guard fileManager.fileExists(atPath: script) else {
      throw EngineError.scriptMissing(path: script)
    }
    return CleanupEngine(pythonPath: python, scriptPath: script)
  }

  /// Runs the scan. onStep is called as soon as the engine starts measuring each folder.
  func scan(onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport {
    let output = try await run(
      arguments: ["scan", "--json", "--progress"],
      input: Data(),
      onStep: onStep
    )
    return try EngineJSON.decoder().decode(ScanReport.self, from: output)
  }

  /// Sends the picked categories on stdin; the engine deletes them and prints a log.
  func apply(_ categories: [Category]) async throws -> String {
    let input = try EngineJSON.encoder().encode(categories)
    let arguments = ["apply", "--lang", AppLanguage.current.engineCode]
    let output = try await run(arguments: arguments, input: input, onStep: nil)
    return String(decoding: output, as: UTF8.self)
  }

  /// Launches the engine, streams its progress lines, and returns its stdout once it exits.
  private func run(
    arguments: [String],
    input: Data,
    onStep: (@Sendable (ScanStep) -> Void)?
  ) async throws -> Data {
    let engine = try startProcess(arguments: arguments, input: input)
    async let messages = Self.forwardProgress(from: engine.standardError, onStep: onStep)
    let output = await Self.readOutput(of: engine)
    let otherMessages = await messages
    try checkStatus(of: engine, messages: otherMessages)
    return output
  }

  private func startProcess(arguments: [String], input: Data) throws -> RunningEngine {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: pythonPath)
    process.arguments = [scriptPath] + arguments
    process.environment = environmentWithToolPath()

    let standardOutput = Pipe()
    let standardError = Pipe()
    let standardInput = Pipe()
    process.standardOutput = standardOutput
    process.standardError = standardError
    process.standardInput = standardInput

    try process.run()
    try standardInput.fileHandleForWriting.write(contentsOf: input)
    try standardInput.fileHandleForWriting.close()
    return RunningEngine(
      process: process, standardOutput: standardOutput, standardError: standardError)
  }

  /// Reads stdout to the end on a background thread, then waits for the process to exit.
  private static func readOutput(of engine: RunningEngine) async -> Data {
    await Task.detached {
      let data = engine.standardOutput.fileHandleForReading.readDataToEndOfFile()
      engine.process.waitUntilExit()
      return data
    }.value
  }

  /// Reads stderr line by line and forwards only progress steps to the UI.
  private static func forwardProgress(
    from pipe: Pipe,
    onStep: (@Sendable (ScanStep) -> Void)?
  ) async -> [String] {
    var otherMessages: [String] = []
    do {
      for try await line in pipe.fileHandleForReading.bytes.lines {
        guard let progress = decodeProgress(line) else {
          otherMessages.append(line)
          continue
        }
        if let step = progress.step {
          onStep?(step)
        }
      }
    } catch {
      otherMessages.append(error.localizedDescription)
    }
    return otherMessages
  }

  private static func decodeProgress(_ line: String) -> ProgressLine? {
    guard let data = line.data(using: .utf8) else { return nil }
    return try? EngineJSON.decoder().decode(ProgressLine.self, from: data)
  }

  private func checkStatus(of engine: RunningEngine, messages: [String]) throws {
    let status = engine.process.terminationStatus
    guard status == 0 else {
      throw EngineError.failed(status: status, message: messages.joined(separator: "\n"))
    }
  }

  private func environmentWithToolPath() -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = Self.toolPath
    return environment
  }
}
