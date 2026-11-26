import Foundation

/// How a deletable category behaves after removal, used to group rows and distinguish data types.
enum CategoryGroup: Hashable, Sendable {
  case automatic
  case dependencies
}

/// Visual and behavioral classification of a safe-to-clean category.
enum CategoryDataKind: Hashable, Sendable {
  case appCache
  case packageCache
  case editorCache
  case logs
  case docker
  case worktreeDependencies
  case projectDependencies
  case temporary

  init(categoryKey: String) {
    switch categoryKey {
    case "app-caches": self = .appCache
    case "package-caches": self = .packageCache
    case "editor-caches": self = .editorCache
    case "logs": self = .logs
    case "docker-prune": self = .docker
    case let key where key.hasPrefix("deps-") && key.contains("worktree"):
      self = .worktreeDependencies
    case let key where key.hasPrefix("deps-"):
      self = .projectDependencies
    default:
      self = .temporary
    }
  }

  var group: CategoryGroup {
    switch self {
    case .worktreeDependencies, .projectDependencies: .dependencies
    case .appCache, .packageCache, .editorCache, .logs, .docker, .temporary: .automatic
    }
  }

  var badge: LocalizedText {
    switch self {
    case .appCache: LocalizedText(pt: "Cache de apps", en: "App cache")
    case .packageCache: LocalizedText(pt: "Cache de pacotes", en: "Package cache")
    case .editorCache: LocalizedText(pt: "Cache de editores", en: "Editor cache")
    case .logs: LocalizedText(pt: "Logs", en: "Logs")
    case .docker: LocalizedText(pt: "Docker", en: "Docker")
    case .worktreeDependencies: LocalizedText(pt: "Deps de worktrees", en: "Worktree deps")
    case .projectDependencies: LocalizedText(pt: "Deps de projetos", en: "Project deps")
    case .temporary: LocalizedText(pt: "Temporário", en: "Temporary")
    }
  }

  var recovery: LocalizedText {
    switch self {
    case .appCache, .editorCache:
      LocalizedText(pt: "Recriado automaticamente", en: "Auto-recreated")
    case .packageCache:
      LocalizedText(pt: "Baixado de novo no install", en: "Re-downloaded on install")
    case .logs:
      LocalizedText(pt: "Registros descartáveis", en: "Disposable records")
    case .docker:
      LocalizedText(pt: "Imagens e cache (sem volumes)", en: "Images & cache (volumes kept)")
    case .worktreeDependencies, .projectDependencies:
      LocalizedText(pt: "Requer reinstalação", en: "Reinstall required")
    case .temporary:
      LocalizedText(pt: "Recriado quando necessário", en: "Recreated as needed")
    }
  }

  var symbolName: String {
    switch self {
    case .appCache: "tray.full"
    case .packageCache: "shippingbox"
    case .editorCache: "curlybraces"
    case .logs: "doc.text"
    case .docker: "cube"
    case .worktreeDependencies: "arrow.triangle.branch"
    case .projectDependencies: "folder.badge.gearshape"
    case .temporary: "folder"
    }
  }
}

/// Shortens filesystem paths against the user's home directory for display.
enum PathDisplay {
  static func abbreviate(_ path: String, home: String = NSHomeDirectory()) -> String {
    if path == home { return "~" }
    let prefix = home.hasSuffix("/") ? home : home + "/"
    if path.hasPrefix(prefix) {
      return "~/" + path.dropFirst(prefix.count)
    }
    return path
  }
}

/// One safe-to-clean category from the scan. It mirrors the Python engine's wire contract.
struct Category: Codable, Identifiable, Hashable, Sendable {
  static let previewPathLimit = 3

  let key: String
  let label: LocalizedText
  let note: LocalizedText
  let sizeBytes: Int
  let paths: [SizedPath]
  let commands: [[String]]

  var id: String { key }

  /// Deps are big and need a reinstall afterwards, so they stay unchecked by default.
  var isOffByDefault: Bool { key.hasPrefix("deps-") }

  var dataKind: CategoryDataKind { CategoryDataKind(categoryKey: key) }

  var symbolName: String { dataKind.symbolName }

  var hasMorePaths: Bool { paths.count > Self.previewPathLimit }

  func visiblePaths(expanded: Bool) -> [SizedPath] {
    expanded ? paths : Array(paths.prefix(Self.previewPathLimit))
  }

  var commandLines: [String] {
    commands.map { $0.joined(separator: " ") }
  }

  var targetCountSummary: LocalizedText? {
    if !paths.isEmpty {
      let count = paths.count
      return count == 1
        ? LocalizedText(pt: "1 caminho", en: "1 path")
        : LocalizedText(pt: "\(count) caminhos", en: "\(count) paths")
    }
    if !commands.isEmpty {
      let count = commands.count
      return count == 1
        ? LocalizedText(pt: "1 comando", en: "1 command")
        : LocalizedText(pt: "\(count) comandos", en: "\(count) commands")
    }
    return nil
  }
}

/// A path the engine would remove, with the bytes it occupies.
struct SizedPath: Codable, Hashable, Sendable {
  let path: String
  let sizeBytes: Int

  var displayPath: String { PathDisplay.abbreviate(path) }
}

/// A folder the user decides about. Never deleted by the app.
struct ReviewLine: Codable, Identifiable, Hashable, Sendable {
  let label: LocalizedText
  let note: LocalizedText
  let sizeBytes: Int?
  let folder: String?

  var id: String { label.en }

  var displayFolder: String? {
    folder.map { PathDisplay.abbreviate($0) }
  }
}

/// The full answer of cleanup.py scan --json.
struct ScanReport: Codable, Sendable {
  let safe: [Category]
  let review: [ReviewLine]
  let freeBytes: Int
}
