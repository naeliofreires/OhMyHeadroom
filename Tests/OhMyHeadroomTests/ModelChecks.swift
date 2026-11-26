import Foundation

@MainActor
func checkLanguageSwitch() async throws {
  let defaults = UserDefaults.standard
  let key = AppLanguage.preferenceKey
  let previous = defaults.string(forKey: key)
  defer { defaults.set(previous, forKey: key) }

  let model = makeModel()
  await model.scan()
  let label = LocalizedText(pt: "Arquivos", en: "Files")
  for (language, expectedLabel, engineCode) in [
    (AppLanguage.english, "Files", "en"), (.portuguese, "Arquivos", "pt"), (.english, "Files", "en"),
  ] {
    defaults.set(language.rawValue, forKey: key)
    let expectedSize = language == .portuguese ? "1,5 MB" : "1.5 MB"
    try check(ByteFormat.text(1_500_000) == expectedSize, "localized byte formatting")
    try check(label.text == expectedLabel && AppLanguage.current.engineCode == engineCode,
              "language mismatch for \(language)")
    try check(model.phase == .ready && model.selectedKeys == ["caches"], "language reset scan")
  }
}

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
func checkReset() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  let reader = FakeFreeSpaceReader(value: 700)
  let model = CleanupModel(gateway: gateway, freeSpaceReader: reader)
  try check(!model.canReset, "reset available before scanning")
  await model.scan()
  try check(model.canReset, "reset unavailable after scan")
  model.toggle(gateway.report.safe[1])
  model.showStep(ScanStep(position: 1, total: 1, label: makeText("One"), path: "~/one"))
  model.isConfirmingClean = true
  model.reset()
  try check(model.phase == .idle && !model.canReset, "reset did not return to idle")
  try check(model.report == nil && model.selectedKeys.isEmpty, "scan results retained")
  try check(model.currentStep == nil && !model.isConfirmingClean, "transient UI retained")
  try check(model.freeBytes == 700 && gateway.applyCallCount == 0, "reset side effects")
  await model.scan()
  try check(model.phase == .ready && model.selectedKeys == ["caches"], "fresh scan defaults")
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
  let result = CleanupResult(beforeBytes: 100, afterBytes: 0, log: "done")
  try check(model.phase == .finished(result: result), "successful cleanup phase")
  try check(model.report == nil && model.selectedKeys.isEmpty, "stale cleanup state retained")
  try check(model.freeBytes == 700, "free space was not refreshed")
  try check(gateway.appliedCategories.map(\.key) == ["caches"], "wrong categories applied")
}

@MainActor
func checkCleanupComparison() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  gateway.afterBytes = 25
  let reader = FakeFreeSpaceReader(value: 500)
  let model = CleanupModel(gateway: gateway, freeSpaceReader: reader)
  await model.scan()
  try check(model.selectedBytes == 100 && model.freeBytes == 500, "initial selected and free bytes")
  reader.value = 700
  await model.cleanSelected()
  try check(model.report == nil && model.selectedKeys.isEmpty, "stale selection retained")
  try check(model.freeBytes == 700, "global free space was not refreshed")
  guard case .finished(let caches) = model.phase else {
    throw CheckFailure(description: "cache comparison missing")
  }
  try check(caches == CleanupResult(beforeBytes: 100, afterBytes: 25, log: "done"),
            "wrong cache comparison")
  try check(caches.reductionBytes == 75, "wrong cache reduction")

  await model.scan()
  try check(model.phase == .ready, "scan retained the previous result")
  for category in gateway.report.safe { model.toggle(category) }
  try check(model.selectedKeys == ["deps-projects"], "dependency selection")
  await model.cleanSelected()
  try check(model.phase == .finished(result: CleanupResult(beforeBytes: 200, afterBytes: 25, log: "done")),
            "wrong dependency comparison")
  model.reset()
  try check(model.phase == .idle, "reset retained the previous result")
}

@MainActor
func checkUnavailableCleanupComparison() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  gateway.afterBytes = nil
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  await model.cleanSelected()
  guard case .finished(let result) = model.phase else {
    throw CheckFailure(description: "unavailable measurement did not finish")
  }
  try check(result == CleanupResult(beforeBytes: 100, afterBytes: nil, log: "done"),
            "wrong unavailable comparison")
  try check(result.reductionBytes == nil, "unavailable measurement has a reduction")
}

@MainActor
func checkCleanupGrowth() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  gateway.afterBytes = 125
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  await model.cleanSelected()
  guard case .finished(let result) = model.phase else {
    throw CheckFailure(description: "growth comparison missing")
  }
  try check(result.afterBytes == 125 && result.reductionBytes == -25, "growth comparison was clamped")
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
  model.reset()
  try check(model.phase == .scanning && model.isBusy, "scanning phase not observable")
  await gateway.releaseScan()
  await scanTask.value
  model.isConfirmingClean = true
  let cleanTask = Task { await model.cleanSelected() }
  let applyEvent = await gateway.nextEvent()
  try check(applyEvent == "apply", "apply did not start")
  model.reset()
  try check(model.phase == .cleaning && model.isBusy, "cleaning phase not observable")
  try check(!model.isConfirmingClean, "confirmation retained while cleaning")
  await gateway.releaseApply()
  await cleanTask.value
  try check(model.phase == .finished(result: CleanupResult(beforeBytes: 100, afterBytes: 0, log: "done")),
            "cleanup did not keep the result after release")
}
