import Darwin
import Dispatch
import Foundation

@main
@MainActor
struct PoliceScanChecks {
  static func main() async {
    enforceCheckDeadline()
    let cases = allCheckCases()
    let passed = await countPassed(cases)
    print("Swift checks: \(passed)/\(cases.count) passed")
    if passed != cases.count { exit(1) }
  }
}

private func enforceCheckDeadline() {
  // A lifecycle regression must fail the suite even if a fake gateway stays suspended.
  DispatchQueue.global().asyncAfter(deadline: .now() + 15) {
    print("FAIL Swift checks exceeded the 15-second execution deadline")
    exit(1)
  }
}

@MainActor
private func countPassed(_ cases: [(String, CheckCase)]) async -> Int {
  var passed = 0
  for (name, checkCase) in cases {
    if await runCheck(name, checkCase) { passed += 1 }
  }
  return passed
}
