typealias CheckCase = @MainActor () async throws -> Void

func allCheckCases() -> [(String, CheckCase)] {
  [
    ("initial state", checkInitialState),
    ("switch app language", checkLanguageSwitch),
    ("scan selection", checkScanSelection),
    ("reset and scan again", checkReset),
    ("progress monotonicity", checkProgressMonotonicity),
    ("toggle selection", checkToggleSelection),
    ("empty cleanup", checkEmptyCleanup),
    ("successful cleanup", checkSuccessfulCleanup),
    ("cleanup comparison", checkCleanupComparison),
    ("unavailable cleanup comparison", checkUnavailableCleanupComparison),
    ("cleanup growth", checkCleanupGrowth),
    ("failed cleanup", checkFailedCleanup),
    ("failed scan", checkScanFailure),
    ("busy phases", checkBusyPhases),
    ("scan roots start with four defaults", { try checkDefaultScanRoots() }),
    ("adding a scan root appends the folder", { try checkAddScanRoot() }),
    ("removing a scan root preserves its files", { try checkRemoveScanRoot() }),
    ("reopening restores the exact scan roots", { try checkPersistedScanRoots() }),
    ("changing scan roots clears an open report", checkScanRootChangeClearsReport),
    ("scan roots cannot change during scan or cleanup", checkBusyScanRootEdits),
    ("cancelling or repeating a scan root preserves the report", checkIgnoredScanRootEdits),
    ("app scan sends saved roots including an empty list", checkAppScanSendsSavedRoots),
    ("byte formatting and codec", { try checkByteFormattingAndCodec() }),
    ("invalid JSON", { try checkInvalidJSON() }),
    ("shared fixtures", { try checkSharedFixtures() }),
    ("progress fixture", { try checkProgressFixture() }),
    ("lazy gateway resolution", checkLazyResolution),
    ("data classification and expansion", checkDataClassificationAndExpansion),
    ("update indicator and cooldown", checkUpdateIndicatorAndCooldown),
    ("apply arguments omit permanent by default", { try checkApplyArgumentsOmitPermanentByDefault() }),
    ("apply arguments add permanent when requested", { try checkApplyArgumentsAddPermanentWhenRequested() }),
    ("trash toggle default sends trash", checkTrashToggleDefaultSendsTrash),
    ("trash toggle off sends permanent", checkTrashToggleOffSendsPermanent),
    ("engine apply omits permanent by default", checkEngineApplyOmitsPermanentByDefault),
    ("trash note shown while toggle on", { try checkTrashNoteShownWhileToggleOn() }),
    ("trash note hidden while toggle off", { try checkTrashNoteHiddenWhileToggleOff() }),
  ]
}

@MainActor
func runCheck(_ name: String, _ checkCase: CheckCase) async -> Bool {
  do {
    try await checkCase()
    print("PASS \(name)")
    return true
  } catch {
    print("FAIL \(name): \(error)")
    return false
  }
}
