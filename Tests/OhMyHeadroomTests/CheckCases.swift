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
    ("byte formatting and codec", { try checkByteFormattingAndCodec() }),
    ("invalid JSON", { try checkInvalidJSON() }),
    ("shared fixtures", { try checkSharedFixtures() }),
    ("progress fixture", { try checkProgressFixture() }),
    ("lazy gateway resolution", checkLazyResolution),
    ("data classification and expansion", checkDataClassificationAndExpansion),
    ("update indicator and cooldown", checkUpdateIndicatorAndCooldown),
    ("dependency path toggle", checkDependencyPathToggle),
    ("category toggle selects all paths", checkCategoryToggleSelectsAllPaths),
    ("partial selection state", checkPartialSelectionState),
    ("partial category click selects all", checkPartialCategoryClickSelectsAll),
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
