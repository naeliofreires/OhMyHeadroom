import Foundation

/// One cache, plus a dependency category of three paths that starts unselected.
func makePartialDependencyReport() -> ScanReport {
  ScanReport(
    safe: [makeCategory("caches", 100), makeDependencyCategory(count: 3)],
    review: [],
    freeBytes: 500
  )
}

@MainActor
func makePartialDependencyModel() -> (CleanupModel, FakeCleanupGateway) {
  let gateway = FakeCleanupGateway(report: makePartialDependencyReport())
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  return (model, gateway)
}

@MainActor
func requireDependencyCategory(_ model: CleanupModel) throws -> Category {
  guard let category = model.report?.safe.first(where: { $0.key == "deps-projects" }) else {
    throw CheckFailure(description: "dependency category missing")
  }
  return category
}

@MainActor
func checkPartialCleanupSendsSelectedPaths() async throws {
  let (model, gateway) = makePartialDependencyModel()
  await model.scan()
  let dependency = try requireDependencyCategory(model)
  model.toggle(dependency)
  model.toggleItem(pathString(2), in: dependency)

  await model.cleanSelected()
  guard let sent = gateway.appliedCategories.first(where: { $0.key == "deps-projects" }) else {
    throw CheckFailure(description: "dependency category was not sent")
  }
  try check(sent.paths.map(\.path) == [pathString(1), pathString(3)],
            "cleanup sent unselected paths")
  try check(sent.sizeBytes == 20, "sent size is not the sum of selected paths")
}

@MainActor
func checkSelectedBytesFollowPathSelection() async throws {
  let (model, _) = makePartialDependencyModel()
  await model.scan()
  let dependency = try requireDependencyCategory(model)
  model.toggle(dependency)
  try check(model.selectedBytes == 130, "header total did not include every dependency path")

  model.toggleItem(pathString(2), in: dependency)
  try check(model.selectedBytes == 120, "header total did not drop the unchecked path")
}

@MainActor
func checkEmptyCategoryLeftOutOfCleanup() async throws {
  let (model, gateway) = makePartialDependencyModel()
  await model.scan()
  let dependency = try requireDependencyCategory(model)
  model.toggle(dependency)
  for index in 1...3 {
    model.toggleItem(pathString(index), in: dependency)
  }

  await model.cleanSelected()
  let sentKeys = gateway.appliedCategories.map(\.key)
  try check(sentKeys == ["caches"], "category with no picked path reached the cleanup: \(sentKeys)")
}

@MainActor
func checkCleanupSelectionThroughModelOnly() async throws {
  let (model, gateway) = makePartialDependencyModel()
  await model.scan()
  let dependency = try requireDependencyCategory(model)
  model.toggle(dependency)
  model.toggleItem(pathString(1), in: dependency)
  try check(model.selectedKeys == ["caches", "deps-projects"], "selected keys before cleanup")

  await model.cleanSelected()
  try check(gateway.applyCallCount == 1, "cleanup did not reach the gateway once")
  try check(model.selectedKeys.isEmpty, "cleanup did not clear the selection")
  guard case .finished = model.phase else {
    throw CheckFailure(description: "cleanup did not finish")
  }
}

@MainActor
func checkRescanResetsPathSelection() async throws {
  let (model, _) = makePartialDependencyModel()
  await model.scan()
  let dependency = try requireDependencyCategory(model)
  model.toggle(dependency)
  model.toggleItem(pathString(1), in: dependency)

  await model.scan()
  let rescanned = try requireDependencyCategory(model)
  try check(model.selectionState(of: rescanned) == .none,
            "rescan kept a path selection from before")
}

@MainActor
func checkConfirmationCountFromModel() async throws {
  let (model, _) = makePartialDependencyModel()
  await model.scan()
  let dependency = try requireDependencyCategory(model)
  model.toggle(dependency)
  model.toggleItem(pathString(2), in: dependency)

  let summary = model.pathCountSummary(forKey: "deps-projects")
  try check(summary == LocalizedText(pt: "2 de 3 caminhos", en: "2 of 3 paths"),
            "confirmation summary is wrong: \(String(describing: summary))")
  try check(model.pathCountSummary(forKey: "caches") == nil, "whole category showed a count")
}
