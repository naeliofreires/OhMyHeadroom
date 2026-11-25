import Foundation

@MainActor
func checkInitialState() async throws {
  let model = makeModel()
  try check(model.phase == .idle, "initial phase")
  try check(model.freeBytes == 500, "initial free space")
  try check(model.report == nil, "initial report")
}

@MainActor
func checkScanSelection() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  try check(model.phase == .ready, "scan phase")
  try check(model.selectedKeys == ["caches"], "dependency default selection")
  try check(model.selectedBytes == 100, "selected bytes")
}

@MainActor
func checkProgressMonotonicity() async throws {
  let model = makeModel()
  let step2 = ScanStep(position: 2, total: 3, label: makeText("Two"), path: "~/two")
  let step1 = ScanStep(position: 1, total: 3, label: makeText("One"), path: "~/one")
  let step3 = ScanStep(position: 3, total: 3, label: makeText("Three"), path: "~/three")
  model.showStep(step2)
  model.showStep(step1)
  try check(model.currentStep == step2, "late progress moved backwards")
  model.showStep(step3)
  try check(model.currentStep == step3, "new progress was ignored")
}

@MainActor
func checkToggleSelection() async throws {
  let model = makeModel()
  await model.scan()
  guard let dependency = model.report?.safe.first(where: { $0.key == "deps-projects" }) else {
    throw CheckFailure(description: "dependency category missing")
  }
  model.toggle(dependency)
  try check(model.isSelected(dependency), "toggle did not select")
  try check(model.selectedBytes == 300, "toggle selected bytes")
  model.toggle(dependency)
  try check(!model.isSelected(dependency), "toggle did not deselect")
}

@MainActor
func checkEmptyCleanup() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  guard let category = model.report?.safe.first else {
    throw CheckFailure(description: "safe category missing")
  }
  model.toggle(category)
  await model.cleanSelected()
  try check(gateway.applyCallCount == 0, "empty cleanup called gateway")
  try check(model.phase == .ready, "empty cleanup changed phase")
}

@MainActor
func checkSuccessfulCleanup() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  let reader = FakeFreeSpaceReader(value: 500)
  let model = CleanupModel(gateway: gateway, freeSpaceReader: reader)
  await model.scan()
  reader.value = 700
  await model.cleanSelected()
  try check(model.phase == .finished(log: "done"), "successful cleanup phase")
  try check(model.report == nil && model.selectedKeys.isEmpty, "stale cleanup state retained")
  try check(model.freeBytes == 700, "free space was not refreshed")
  try check(gateway.appliedCategories.map(\.key) == ["caches"], "wrong categories applied")
}

@MainActor
func checkFailedCleanup() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  gateway.applyError = FakeFailure()
  let reader = FakeFreeSpaceReader(value: 500)
  let model = CleanupModel(gateway: gateway, freeSpaceReader: reader)
  await model.scan()
  reader.value = 600
  await model.cleanSelected()
  try check(model.phase == .failed(message: "fake failure"), "failed cleanup phase")
  try check(model.report == nil && model.selectedKeys.isEmpty, "failed cleanup state retained")
  try check(model.freeBytes == 600, "failed cleanup free space")
}

@MainActor
func checkScanFailure() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  gateway.scanError = FakeFailure()
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  try check(model.phase == .failed(message: "fake failure"), "failed scan phase")
}

@MainActor
func checkBusyPhases() async throws {
  let gateway = BlockingCleanupGateway(report: makeReport())
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  let scanTask = Task { await model.scan() }
  let scanEvent = await gateway.nextEvent()
  try check(scanEvent == "scan", "scan did not start")
  try check(model.phase == .scanning && model.isBusy, "scanning phase not observable")
  await gateway.releaseScan()
  await scanTask.value
  let cleanTask = Task { await model.cleanSelected() }
  let applyEvent = await gateway.nextEvent()
  try check(applyEvent == "apply", "apply did not start")
  try check(model.phase == .cleaning && model.isBusy, "cleaning phase not observable")
  await gateway.releaseApply()
  await cleanTask.value
}
