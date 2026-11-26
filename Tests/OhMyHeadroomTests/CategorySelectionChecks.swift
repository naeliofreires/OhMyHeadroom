import Foundation

/// A dependency category with `count` paths. Path `i` is `i * unitBytes` bytes, so every path has
/// a distinct size and a wrong sum cannot pass by accident. Off by default, like the app.
func makeDependencyCategory(count: Int, unitBytes: Int = 10) -> Category {
  let paths = (1...count).map { index in
    SizedPath(path: pathString(index), sizeBytes: unitBytes * index)
  }
  return Category(
    key: "deps-projects",
    label: makeText("Project deps"),
    note: makeText("Reinstall"),
    sizeBytes: paths.reduce(0) { $0 + $1.sizeBytes },
    paths: paths,
    commands: []
  )
}

func pathString(_ index: Int) -> String {
  "/Users/test/app\(index)/node_modules"
}

@MainActor
func checkDependencyPathToggle() async throws {
  let category = makeDependencyCategory(count: 3)
  var selection = CategorySelection(categories: [category])
  try check(selection.state(of: category) == .none, "dependency category starts unselected")

  selection.toggleCategory(category)
  selection.toggleItem(pathString(2), in: category)
  try check(!selection.isItemSelected(pathString(2), in: category), "unchecked path stayed selected")
  try check(selection.isItemSelected(pathString(1), in: category), "other path was removed")
  try check(selection.isItemSelected(pathString(3), in: category), "other path was removed")
  try check(selection.state(of: category) == .partial, "one unchecked path should be partial")

  selection.toggleItem(pathString(2), in: category)
  try check(selection.isItemSelected(pathString(2), in: category), "checked path was not added back")
}

@MainActor
func checkCategoryToggleSelectsAllPaths() async throws {
  let category = makeDependencyCategory(count: 5)
  var selection = CategorySelection(categories: [category])

  selection.toggleCategory(category)
  try check(selection.state(of: category) == .all, "category check did not select every path")
  for index in 1...5 {
    try check(selection.isItemSelected(pathString(index), in: category),
              "path \(index) beyond the preview was not selected")
  }

  selection.toggleCategory(category)
  try check(selection.state(of: category) == .none, "category uncheck did not clear every path")
}

@MainActor
func checkPartialSelectionState() async throws {
  let category = makeDependencyCategory(count: 3)
  var selection = CategorySelection(categories: [category])

  selection.toggleCategory(category)
  selection.toggleItem(pathString(1), in: category)
  try check(selection.state(of: category) == .partial, "missing path did not report partial")

  selection.toggleItem(pathString(1), in: category)
  try check(selection.state(of: category) == .all, "all paths picked did not report all")
}

@MainActor
func checkPartialCategoryClickSelectsAll() async throws {
  let category = makeDependencyCategory(count: 3)
  var selection = CategorySelection(categories: [category])

  selection.toggleCategory(category)
  selection.toggleItem(pathString(3), in: category)
  try check(selection.state(of: category) == .partial, "setup did not reach partial")

  selection.toggleCategory(category)
  try check(selection.state(of: category) == .all, "partial click did not select every path")
}

@MainActor
func checkSelectedCategoriesKeepPickedPaths() async throws {
  let category = makeDependencyCategory(count: 4)
  var selection = CategorySelection(categories: [category])
  selection.toggleCategory(category)
  selection.toggleItem(pathString(2), in: category)

  let narrowed = selection.selectedCategories(from: [category])
  try check(narrowed.count == 1, "expected one selected category")
  try check(narrowed[0].paths.map(\.path) == [pathString(1), pathString(3), pathString(4)],
            "picked paths were not kept in their original order")
  try check(narrowed[0].sizeBytes == 80, "category size is not the sum of picked paths (10+30+40)")
}

@MainActor
func checkEmptyCategoryAbsentFromSelection() async throws {
  let category = makeDependencyCategory(count: 2)
  let selection = CategorySelection(categories: [category])

  try check(selection.selectedCategories(from: [category]).isEmpty,
            "unselected category reached the cleanup")
}

@MainActor
func checkCommandCategoryKeepsSize() async throws {
  let docker = Category(
    key: "docker-prune",
    label: makeText("Docker"),
    note: makeText("Images"),
    sizeBytes: 50,
    paths: [],
    commands: [["docker", "image", "prune", "-a", "-f"]]
  )
  let selection = CategorySelection(categories: [docker])

  let narrowed = selection.selectedCategories(from: [docker])
  try check(narrowed.count == 1 && narrowed[0].sizeBytes == 50,
            "command category lost its size")
  try check(narrowed[0].commandLines == ["docker image prune -a -f"],
            "command category lost its command")
}

/// Unchecking every path one by one must read as unchecked, not partial or full.
@MainActor
func checkUncheckingEveryPathClearsCategory() async throws {
  let category = makeDependencyCategory(count: 3)
  var selection = CategorySelection(categories: [category])
  selection.toggleCategory(category)
  for index in 1...3 {
    selection.toggleItem(pathString(index), in: category)
  }

  try check(selection.state(of: category) == .none, "every path unchecked did not read as none")
  try check(selection.selectedCategories(from: [category]).isEmpty,
            "every path unchecked still reached the cleanup")
}

/// An item that is not in the category must be ignored, or the state would read as full.
@MainActor
func checkForeignItemIsIgnored() async throws {
  let category = makeDependencyCategory(count: 3)
  var selection = CategorySelection(categories: [category])
  selection.toggleItem(pathString(1), in: category)
  selection.toggleItem(pathString(2), in: category)
  selection.toggleItem("/Users/test/elsewhere/node_modules", in: category)

  try check(selection.state(of: category) == .partial, "foreign item changed the category state")
  try check(selection.selectedCategories(from: [category])[0].paths.count == 2,
            "foreign item reached the cleanup")
}

@MainActor
func checkSelectedPathCountSummary() async throws {
  let category = makeDependencyCategory(count: 12)
  var selection = CategorySelection(categories: [category])
  try check(selection.pathCountSummary(for: category) == nil, "empty category showed a count")

  selection.toggleCategory(category)
  try check(selection.pathCountSummary(for: category) == nil, "full category showed a count")

  selection.toggleCategory(category)
  for index in 1...3 {
    selection.toggleItem(pathString(index), in: category)
  }
  let summary = selection.pathCountSummary(for: category)
  try check(summary == LocalizedText(pt: "3 de 12 caminhos", en: "3 of 12 paths"),
            "partial count summary is wrong: \(String(describing: summary))")
}
