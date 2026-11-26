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
        localized: "The engine was not found at \(path). Reinstall OhMyHeadroom to restore it.", bundle: AppLanguage.current.stringsBundle)
    case .failed(let status, let message):
      return String(localized: "The engine failed with code \(String(status)): \(message)", bundle: AppLanguage.current.stringsBundle)
    }
  }
}

/// Sends one engine command and returns what it printed. The process transport is the real one;
/// tests inject a recording transport so the command wiring is checked without a child process.
protocol EngineTransport: Sendable {
  func exchange(
    arguments: [String],
    input: Data,
    onStep: (@Sendable (ScanStep) -> Void)?
  ) async throws -> Data
}

/// Runs the bundled Python engine through an injected transport.
struct CleanupEngine: CleanupGateway, Sendable {
  let transport: any EngineTransport

  private static let pythonCandidates = [
    "/opt/homebrew/bin/python3",
    "/usr/local/bin/python3",
  ]

  static func locate() throws -> CleanupEngine {
    let fileManager = FileManager.default
    guard let python = pythonCandidates.first(where: fileManager.isExecutableFile(atPath:)) else {
      throw EngineError.pythonMissing
    }
    let script = Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/Engine/cleanup.py").path
    guard fileManager.fileExists(atPath: script) else {
      throw EngineError.scriptMissing(path: script)
    }
    let transport = ProcessEngineTransport(pythonPath: python, scriptPath: script)
    return CleanupEngine(transport: transport)
  }

  /// Runs the scan. onStep is called as soon as the engine starts measuring each folder.
  func scan(onStep: @escaping @Sendable (ScanStep) -> Void) async throws -> ScanReport {
    let output = try await transport.exchange(
      arguments: ["scan", "--json", "--progress"],
      input: Data(),
      onStep: onStep
    )
    return try EngineJSON.decoder().decode(ScanReport.self, from: output)
  }

  /// Builds the `apply` arguments. Example: `CleanupEngine.applyArguments(language: "en", permanent: true)`.
  static func applyArguments(language: String, permanent: Bool) -> [String] {
    var arguments = ["apply", "--json", "--lang", language]
    if permanent {
      arguments.append("--permanent")
    }
    return arguments
  }

  /// Sends the selected categories and decodes the comparison and execution log.
  func apply(_ categories: [Category], permanent: Bool) async throws -> CleanupResult {
    let input = try EngineJSON.encoder().encode(categories)
    let arguments = Self.applyArguments(
      language: AppLanguage.current.engineCode, permanent: permanent)
    let output = try await transport.exchange(arguments: arguments, input: input, onStep: nil)
    return try EngineJSON.decoder().decode(CleanupResult.self, from: output)
  }
}
