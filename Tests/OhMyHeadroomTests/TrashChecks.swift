import Foundation

/// Trash-mode checks: the engine arguments and the model's permanent flag. Run by Tools/check-swift.sh.
@MainActor
func checkApplyArgumentsOmitPermanentByDefault() throws {
  let arguments = CleanupEngine.applyArguments(language: "en", permanent: false)
  try check(arguments == ["apply", "--json", "--lang", "en"], "trash apply arguments: \(arguments)")
}

@MainActor
func checkApplyArgumentsAddPermanentWhenRequested() throws {
  let arguments = CleanupEngine.applyArguments(language: "pt-BR", permanent: true)
  try check(
    arguments == ["apply", "--json", "--lang", "pt-BR", "--permanent"],
    "permanent apply arguments: \(arguments)")
}

@MainActor
func checkTrashToggleDefaultSendsTrash() async throws {
  let gateway = FakeCleanupGateway(report: makeReport())
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  await model.cleanSelected()
  try check(gateway.appliedPermanentFlags == [false], "trash toggle default: \(gateway.appliedPermanentFlags)")
}

@MainActor
func checkTrashToggleOffSendsPermanent() async throws {
  let transport = try makeRecordingTransport()
  let model = CleanupModel(gateway: CleanupEngine(transport: transport), freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  model.movesToTrash = false
  await model.cleanSelected()
  let applyCall = transport.calls.last ?? []
  try check(applyCall.first == "apply" && applyCall.last == "--permanent", "toggle off did not reach the engine: \(applyCall)")
}

@MainActor
func checkEngineApplyOmitsPermanentByDefault() async throws {
  let transport = try makeRecordingTransport()
  _ = try await CleanupEngine(transport: transport).apply([], permanent: false)
  let applyCall = transport.calls.last ?? []
  try check(applyCall.first == "apply" && !applyCall.contains("--permanent"), "default apply sent permanent: \(applyCall)")
}

@MainActor
func makeRecordingTransport() throws -> RecordingEngineTransport {
  try RecordingEngineTransport(
    scanReport: makeReport(),
    applyResult: CleanupResult(beforeBytes: 100, afterBytes: 0, log: "done"))
}

@MainActor
func checkTrashNoteShownWhileToggleOn() throws {
  let model = CleanupModel(gateway: FakeCleanupGateway(report: makeReport()))
  try check(model.shouldShowTrashNote, "trash note hidden while toggle on")
}

@MainActor
func checkTrashNoteHiddenWhileToggleOff() throws {
  let model = CleanupModel(gateway: FakeCleanupGateway(report: makeReport()))
  model.movesToTrash = false
  try check(!model.shouldShowTrashNote, "trash note shown while toggle off")
}
