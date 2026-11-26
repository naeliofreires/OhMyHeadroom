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
  let gateway = FakeCleanupGateway(report: makeReport())
  let model = CleanupModel(gateway: gateway, freeSpaceReader: FakeFreeSpaceReader(value: 500))
  await model.scan()
  model.movesToTrash = false
  await model.cleanSelected()
  try check(gateway.appliedPermanentFlags == [true], "trash toggle off: \(gateway.appliedPermanentFlags)")
  let arguments = CleanupEngine.applyArguments(language: "en", permanent: true)
  try check(arguments.last == "--permanent", "permanent flag missing from engine arguments")
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
