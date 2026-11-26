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
    ("selected categories keep picked paths", checkSelectedCategoriesKeepPickedPaths),
    ("empty category absent from selection", checkEmptyCategoryAbsentFromSelection),
    ("command category keeps its size", checkCommandCategoryKeepsSize),
    ("selected path count summary", checkSelectedPathCountSummary),
    ("unchecking every path clears category", checkUncheckingEveryPathClearsCategory),
    ("foreign item is ignored", checkForeignItemIsIgnored),
    ("path picking limited to dependencies", checkPathPickingLimitedToDependencies),
    ("confirmation count from model", checkConfirmationCountFromModel),
    ("partial cleanup sends selected paths", checkPartialCleanupSendsSelectedPaths),
    ("selected bytes follow path selection", checkSelectedBytesFollowPathSelection),
    ("empty category left out of cleanup", checkEmptyCategoryLeftOutOfCleanup),
    ("cleanup selection through model only", checkCleanupSelectionThroughModelOnly),
    ("rescan resets path selection", checkRescanResetsPathSelection),
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
