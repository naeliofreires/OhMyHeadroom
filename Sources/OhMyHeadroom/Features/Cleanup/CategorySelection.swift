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

  mutating func toggleItem(_ item: String, in category: Category) {
    var picked = pickedByKey[category.key] ?? []
    if picked.contains(item) {
      picked.remove(item)
    } else {
      picked.insert(item)
    }
    pickedByKey[category.key] = picked
  }
}
