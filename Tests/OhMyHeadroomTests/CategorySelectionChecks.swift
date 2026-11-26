import Foundation

/// A dependency category with `count` paths, each of `sizeBytes`. Off by default, like the app.
func makeDependencyCategory(count: Int, sizeBytes: Int = 10) -> Category {
  let paths = (1...count).map { index in
    SizedPath(path: "/Users/test/app\(index)/node_modules", sizeBytes: sizeBytes)
  }
  return Category(
    key: "deps-projects",
    label: makeText("Project deps"),
    note: makeText("Reinstall"),
    sizeBytes: sizeBytes * count,
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
  let category = makeDependencyCategory(count: 4, sizeBytes: 10)
  var selection = CategorySelection(categories: [category])
  selection.toggleCategory(category)
  selection.toggleItem(pathString(2), in: category)

  let narrowed = selection.selectedCategories(from: [category])
  try check(narrowed.count == 1, "expected one selected category")
  try check(narrowed[0].paths.map(\.path) == [pathString(1), pathString(3), pathString(4)],
            "picked paths were not kept in their original order")
  try check(narrowed[0].sizeBytes == 30, "category size is not the sum of picked paths")
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
