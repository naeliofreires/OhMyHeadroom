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
