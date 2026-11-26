import Foundation

/// Metadata for a newer commit available on the remote `main` branch.
struct AppUpdate: Equatable, Sendable {
  let installedSHA: String
  let latestSHA: String
  let commitTitle: String?
  let pageURL: URL

  var shortLatestSHA: String { String(latestSHA.prefix(7)) }
}

/// Outcome of checking for a newer app build.
enum UpdateCheckResult: Equatable, Sendable {
  case upToDate
  case available(AppUpdate)
  case unavailable
}

/// Abstracts remote update checks so `CleanupModel` tests run offline and deterministically.
protocol UpdateChecking: Sendable {
  var installedVersionLabel: String { get }
  func checkForUpdate() async -> UpdateCheckResult
}

/// Default no-op checker used by headless tests that do not exercise updates.
struct NoopUpdateChecker: UpdateChecking {
  let installedVersionLabel: String = "1.0"
  func checkForUpdate() async -> UpdateCheckResult { .unavailable }
}

/// Checks the latest commit on `main` against the commit SHA embedded in `Info.plist` by `build-app.sh`.
struct GitHubMainUpdateChecker: UpdateChecking {
  static let commitInfoPlistKey = "OhMyHeadroomCommitSHA"
  static let repositoryURL = URL(string: "https://github.com/naeliofreires/OhMyHeadroom")!
  static let latestMainCommitAPI = URL(
    string: "https://api.github.com/repos/naeliofreires/OhMyHeadroom/commits/main"
  )!
  static let updateCommand = "git pull && ./build-app.sh"

  private let installedVersion: String
  private let installedSHA: String?
  private let session: URLSession

  init(
    bundle: Bundle = .main,
    session: URLSession = .shared
  ) {
    let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    let rawSHA = bundle.object(forInfoDictionaryKey: Self.commitInfoPlistKey) as? String
    let trimmed = rawSHA?.trimmingCharacters(in: .whitespacesAndNewlines)
    self.installedVersion = version
    self.installedSHA = (trimmed?.isEmpty == false) ? trimmed : nil
    self.session = session
  }

  init(installedVersion: String, installedSHA: String?, session: URLSession = .shared) {
    self.installedVersion = installedVersion
    self.installedSHA = installedSHA
    self.session = session
  }

  var installedVersionLabel: String {
    guard let installedSHA else { return installedVersion }
    return "\(installedVersion) (\(String(installedSHA.prefix(7))))"
  }

  func checkForUpdate() async -> UpdateCheckResult {
    guard let installedSHA else { return .unavailable }
    var request = URLRequest(url: Self.latestMainCommitAPI, timeoutInterval: 8)
    request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
    request.setValue("OhMyHeadroom/\(installedVersion)", forHTTPHeaderField: "User-Agent")

    do {
      let (data, response) = try await session.data(for: request)
      guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
        return .unavailable
      }
      return Self.evaluate(data: data, installedSHA: installedSHA)
    } catch {
      return .unavailable
    }
  }

  static func evaluate(data: Data, installedSHA: String) -> UpdateCheckResult {
    guard let decoded = try? JSONDecoder().decode(GitHubCommitPayload.self, from: data),
      !decoded.sha.isEmpty
    else {
      return .unavailable
    }
    if decoded.sha.caseInsensitiveCompare(installedSHA) == .orderedSame {
      return .upToDate
    }
    let firstLine = decoded.commit?.message?
      .split(separator: "\n", maxSplits: 1)
      .first
      .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
    let title = (firstLine?.isEmpty == false) ? firstLine : nil
    return .available(
      AppUpdate(
        installedSHA: installedSHA,
        latestSHA: decoded.sha,
        commitTitle: title,
        pageURL: decoded.htmlUrl ?? repositoryURL
      )
    )
  }
}

private struct GitHubCommitPayload: Decodable {
  let sha: String
  let htmlUrl: URL?
  let commit: CommitInfo?

  enum CodingKeys: String, CodingKey {
    case sha
    case htmlUrl = "html_url"
    case commit
  }

  struct CommitInfo: Decodable {
    let message: String?
  }
}
