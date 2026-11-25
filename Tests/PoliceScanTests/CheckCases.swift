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
    ("failed cleanup", checkFailedCleanup),
    ("failed scan", checkScanFailure),
    ("busy phases", checkBusyPhases),
    ("byte formatting and codec", { try checkByteFormattingAndCodec() }),
    ("invalid JSON", { try checkInvalidJSON() }),
    ("shared fixtures", { try checkSharedFixtures() }),
    ("progress fixture", { try checkProgressFixture() }),
    ("lazy gateway resolution", checkLazyResolution),
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
