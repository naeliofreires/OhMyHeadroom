import Foundation

/// Which items the user picked in each category. An item is a path in a path category
/// and a command line in a command category. The rules live here, not in SwiftUI,
/// so the Swift checks reach every rule that changes what the panel shows.
struct CategorySelection: Sendable {
  /// Whether none, some, or all items of a category are picked.
  enum State: Equatable, Sendable {
    case none
    case partial
    case all
  }

  private var allItemsByKey: [String: [String]]
  private var pickedByKey: [String: Set<String>]

  /// Picks every item, except in categories that are off by default.
  /// Example: `CategorySelection(categories: report.safe)`.
  init(categories: [Category]) {
    allItemsByKey = [:]
    pickedByKey = [:]
    for category in categories {
      let items = Self.items(of: category)
      allItemsByKey[category.key] = items
      pickedByKey[category.key] = category.isOffByDefault ? [] : Set(items)
    }
  }

  /// The command line the engine and the panel both show for one command.
  static func commandLine(_ command: [String]) -> String {
    command.joined(separator: " ")
  }

  static func items(of category: Category) -> [String] {
    category.paths.map(\.path) + category.commands.map(commandLine)
  }

  func state(of category: Category) -> State {
    let all = allItemsByKey[category.key] ?? []
    let picked = pickedByKey[category.key] ?? []
    if picked.isEmpty { return .none }
    return picked.count == all.count ? .all : .partial
  }

  func isItemSelected(_ item: String, in category: Category) -> Bool {
    pickedByKey[category.key]?.contains(item) ?? false
  }

  /// A fully picked category is cleared. Any other state picks every item.
  mutating func toggleCategory(_ category: Category) {
    if state(of: category) == .all {
      pickedByKey[category.key] = []
      return
    }
    pickedByKey[category.key] = Set(allItemsByKey[category.key] ?? [])
  }

  /// Ignores an item that does not belong to the category, so it cannot skew the state.
  mutating func toggleItem(_ item: String, in category: Category) {
    let belongs = allItemsByKey[category.key]?.contains(item) ?? false
    if !belongs { return }
    var picked = pickedByKey[category.key] ?? []
    if picked.contains(item) {
      picked.remove(item)
    } else {
      picked.insert(item)
    }
    pickedByKey[category.key] = picked
  }

  /// The categories with at least one picked item, each reduced to its picked paths and commands.
  /// Example: `selection.selectedCategories(from: report.safe)`.
  func selectedCategories(from categories: [Category]) -> [Category] {
    categories.compactMap { narrowed($0) }
  }

  /// "3 de 12 caminhos" when only some paths are picked; nil when none or all are.
  /// Example: `selection.pathCountSummary(for: category)`.
  func pathCountSummary(for category: Category) -> LocalizedText? {
    let total = category.paths.count
    let selected = category.paths.filter { isItemSelected($0.path, in: category) }.count
    if selected == 0 || selected == total { return nil }
    return LocalizedText(
      pt: "\(selected) de \(total) caminhos",
      en: "\(selected) of \(total) paths"
    )
  }

  private func narrowed(_ category: Category) -> Category? {
    let picked = pickedByKey[category.key] ?? []
    let paths = category.paths.filter { picked.contains($0.path) }
    let commands = category.commands.filter { picked.contains(Self.commandLine($0)) }
    if paths.isEmpty && commands.isEmpty { return nil }
    return Category(
      key: category.key,
      label: category.label,
      note: category.note,
      sizeBytes: narrowedSize(of: category, keptPaths: paths),
      paths: paths,
      commands: commands
    )
  }

  /// A category without paths keeps its own size; otherwise its size is the kept paths' sum.
  private func narrowedSize(of category: Category, keptPaths: [SizedPath]) -> Int {
    if category.paths.isEmpty { return category.sizeBytes }
    return keptPaths.reduce(0) { $0 + $1.sizeBytes }
  }
}
