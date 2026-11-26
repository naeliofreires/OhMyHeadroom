import Foundation

/// A launched engine process with its pipes, so its output can be read while it runs.
private struct RunningEngine {
  let process: Process
  let standardOutput: Pipe
  let standardError: Pipe
}

/// Runs the bundled Python engine as a child process: input on stdin, output on stdout, progress on stderr.
struct ProcessEngineTransport: EngineTransport, Sendable {
  let pythonPath: String
  let scriptPath: String

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

  /// Launches the engine, streams its progress lines, and returns its stdout once it exits.
  func exchange(
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
    process.arguments = ["-B", scriptPath] + arguments
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
