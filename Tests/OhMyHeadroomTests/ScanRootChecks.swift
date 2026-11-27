import Foundation

private let initialScanRoots = ["Developer", ".herdr", ".t3", ".synara"].map {
  URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent($0).path
}

@MainActor
private final class ScanRootsFixture {
  private let suite = "OhMyHeadroomChecks.ScanRoots.\(UUID().uuidString)"
  private let gateway = FakeCleanupGateway(report: makeReport())

  deinit {
    UserDefaults.standard.removePersistentDomain(forName: suite)
  }

  func makeModel(gateway: (any CleanupGateway)? = nil) -> CleanupModel {
    CleanupModel(
      gateway: gateway ?? self.gateway,
      freeSpaceReader: FakeFreeSpaceReader(value: 500),
      defaults: UserDefaults(suiteName: suite)!
    )
  }
}

@MainActor
func checkDefaultScanRoots() throws {
  let fixture = ScanRootsFixture()
  try check(fixture.makeModel().scanRoots == initialScanRoots, "incorrect initial scan roots")
}

@MainActor
func checkAddScanRoot() throws {
  let fixture = ScanRootsFixture()
  let model = fixture.makeModel()
  let folder = URL(fileURLWithPath: "/Projects With Spaces")
  model.addScanRoot(folder)
  try check(model.scanRoots == initialScanRoots + [folder.path], "new folder missing or reordered")
}

@MainActor
func checkRemoveScanRoot() throws {
  let fixture = ScanRootsFixture()
  let model = fixture.makeModel()
  let files = FileManager.default
  let folder = files.temporaryDirectory.appendingPathComponent(UUID().uuidString)
  try files.createDirectory(at: folder, withIntermediateDirectories: true)
  defer { try? files.removeItem(at: folder) }
  let dependency = folder.appendingPathComponent("node_modules")
  try files.createDirectory(at: dependency, withIntermediateDirectories: false)
  let entry = dependency.appendingPathComponent("sentinel")
  let contents = Data([1, 2, 3])
  try contents.write(to: entry)

  model.addScanRoot(folder)
  guard let added = model.scanRoots.last, model.scanRoots.count == initialScanRoots.count + 1 else {
    throw CheckFailure(description: "temporary root was not added")
  }
  model.removeScanRoot(added)

  try check(model.scanRoots == initialScanRoots, "removed folder still appears in roots")
  let remaining = try Data(contentsOf: entry)
  try check(remaining == contents, "removing the root changed its on-disk contents")
}

@MainActor
func checkPersistedScanRoots() throws {
  let fixture = ScanRootsFixture()
  let model = fixture.makeModel()
  let unavailable = URL(fileURLWithPath: "/Volumes/Disconnected/\(UUID().uuidString)")
  model.removeScanRoot(initialScanRoots[0])
  model.addScanRoot(unavailable)
  let reopened = fixture.makeModel()
  try check(reopened.scanRoots == Array(initialScanRoots.dropFirst()) + [unavailable.path],
            "saved roots changed on reopen")
  for path in reopened.scanRoots { reopened.removeScanRoot(path) }
  try check(fixture.makeModel().scanRoots.isEmpty, "empty saved roots reverted to defaults")
}

@MainActor
func checkScanRootChangeClearsReport() async throws {
  let fixture = ScanRootsFixture()
  let model = fixture.makeModel()
  let folder = URL(fileURLWithPath: "/New Project")
  let edits: [(String, () -> Void)] = [
    ("addition", { model.addScanRoot(folder) }),
    ("removal", { model.removeScanRoot(initialScanRoots[0]) }),
  ]
  for (name, edit) in edits {
    await model.scan()
    guard let dependency = model.dependencyCategories.first else {
      throw CheckFailure(description: "initial scan did not find the fixture dependency")
    }
    model.toggle(dependency)
    try check(model.isSelected(dependency), "fixture dependency was not selected")
    edit()
    try check(model.phase == .idle && model.report == nil && model.selectedKeys.isEmpty,
              "previous report could still be used for cleanup after \(name)")
  }
}

@MainActor
func checkBusyScanRootEdits() async throws {
  let fixture = ScanRootsFixture()
  let gateway = BlockingCleanupGateway(report: makeReport())
  let model = fixture.makeModel(gateway: gateway)
  let extra = URL(fileURLWithPath: "/Projects")

  let scanning = Task { await model.scan() }
  let scanEvent = await gateway.nextEvent()
  model.addScanRoot(extra)
  model.removeScanRoot(initialScanRoots[0])
  let rootsDuringScan = model.scanRoots
  let phaseDuringScan = model.phase
  await gateway.releaseScan()
  await scanning.value
  try check(scanEvent == "scan" && phaseDuringScan == .scanning && rootsDuringScan == initialScanRoots,
            "roots or phase changed during scan")

  let cleaning = Task { await model.cleanSelected() }
  let cleanupEvent = await gateway.nextEvent()
  model.addScanRoot(extra)
  model.removeScanRoot(initialScanRoots[0])
  let rootsDuringCleanup = model.scanRoots
  let phaseDuringCleanup = model.phase
  await gateway.releaseApply()
  await cleaning.value
  try check(cleanupEvent == "apply" && phaseDuringCleanup == .cleaning && rootsDuringCleanup == initialScanRoots,
            "roots or phase changed during cleanup")
  try check(fixture.makeModel().scanRoots == initialScanRoots, "busy edits reached preferences")
}

@MainActor
func checkIgnoredScanRootEdits() async throws {
  let fixture = ScanRootsFixture()
  let model = fixture.makeModel()
  await model.scan()
  let selection = model.selectedKeys
  let report = model.report
  let existing = URL(fileURLWithPath: initialScanRoots[0])
  try check(report != nil && model.phase == .ready, "fixture scan did not finish")
  for folder in [nil, existing] {
    model.addScanRoot(folder)
    try check(model.scanRoots == initialScanRoots, "cancel or duplicate edited the roots")
    try check(model.phase == .ready && model.report?.safe == report?.safe && model.selectedKeys == selection,
              "cancel or duplicate discarded the report")
  }
}

@MainActor
func checkAppScanSendsSavedRoots() async throws {
  let fixture = ScanRootsFixture()
  let transport = try RecordingEngineTransport(
    scanReport: makeReport(), applyResult: CleanupResult(beforeBytes: 0, afterBytes: 0, log: "")
  )
  let gateway = LazyCleanupGateway(resolve: { CleanupEngine(transport: transport) })
  let model = fixture.makeModel(gateway: gateway)
  for path in model.scanRoots { model.removeScanRoot(path) }
  let folders = ["/Project Space", "/Volumes/Disconnected/Projects"]
  for path in folders { model.addScanRoot(URL(fileURLWithPath: path)) }
  await model.scan()
  try check(model.phase == .ready, "scan with saved roots did not finish")
  for path in folders { model.removeScanRoot(path) }
  await model.scan()
  try check(model.phase == .ready, "scan with no roots did not finish")

  let expectedArguments = ["scan", "--json", "--progress", "--scan-roots-stdin"]
  let inputs = try transport.inputs.map { try JSONDecoder().decode([String].self, from: $0) }
  try check(transport.calls == [expectedArguments, expectedArguments], "scan did not request roots from stdin")
  try check(inputs == [folders, []], "scan input did not distinguish explicit and empty roots")
}
