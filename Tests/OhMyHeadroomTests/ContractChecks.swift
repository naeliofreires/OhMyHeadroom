import Foundation

func checkByteFormattingAndCodec() throws {
  try check(ByteFormat.text(1) == "1 byte", "byte formatting")
  try check(ByteFormat.text(nil) == String(localized: "No access"), "missing byte formatting")
  let category = makeReport().safe[0]
  let data = try EngineJSON.encoder().encode([category])
  let decoded = try EngineJSON.decoder().decode([Category].self, from: data)
  try check(decoded == [category], "JSON round trip")
  try check(String(decoding: data, as: UTF8.self).contains("size_bytes"), "snake case encoding")
}

func checkInvalidJSON() throws {
  do {
    _ = try EngineJSON.decoder().decode(ScanReport.self, from: Data("{".utf8))
    throw CheckFailure(description: "invalid JSON was accepted")
  } catch is CheckFailure {
    throw CheckFailure(description: "invalid JSON was accepted")
  } catch {}
}

func checkSharedFixtures() throws {
  let reportData = try Data(contentsOf: fixtureURL("scan-report.json"))
  let fixtureReport = try EngineJSON.decoder().decode(ScanReport.self, from: reportData)
  let selected = fixtureReport.safe.filter { !$0.isOffByDefault }
  let actualData = try EngineJSON.encoder().encode(selected)
  let expectedData = try Data(contentsOf: fixtureURL("cleanup-plan.json"))
  let actual = try JSONSerialization.jsonObject(with: actualData) as? NSObject
  let expected = try JSONSerialization.jsonObject(with: expectedData) as? NSObject
  try check(actual == expected, "cleanup plan fixture mismatch")

  let resultData = try Data(contentsOf: fixtureURL("cleanup-result.json"))
  let result = try EngineJSON.decoder().decode(CleanupResult.self, from: resultData)
  try check(result == CleanupResult(beforeBytes: 1200, afterBytes: 200, log: "done\n"),
            "cleanup result fixture mismatch")
  let unavailableData = Data(#"{"before_bytes":1200,"after_bytes":null,"log":"done\n"}"#.utf8)
  let unavailable = try EngineJSON.decoder().decode(CleanupResult.self, from: unavailableData)
  try check(unavailable == CleanupResult(beforeBytes: 1200, afterBytes: nil, log: "done\n"),
            "unavailable result decode mismatch")
}

func checkProgressFixture() throws {
  let lines = try String(contentsOf: fixtureURL("progress.jsonl"), encoding: .utf8)
    .split(separator: "\n")
  let steps = lines.compactMap { line in
    try? EngineJSON.decoder().decode(ProgressLine.self, from: Data(line.utf8)).step
  }
  try check(steps.map(\.position) == [1], "progress fixture steps")
  try check(steps.first?.path == "~/Library/Caches", "progress fixture path")
}

func checkLazyResolution() async throws {
  let fake = FakeCleanupGateway(report: makeReport())
  fake.afterBytes = 25
  fake.progressStep = ScanStep(position: 1, total: 1, label: makeText("Caches"), path: "~/Caches")
  let resolver = SequencedGatewayResolver(fallback: fake)
  let gateway = LazyCleanupGateway(resolve: { try resolver.resolve() })
  do { _ = try await gateway.scan(dependencyRoots: []) { _ in } } catch {}
  let sink = StepSink()
  let scanned = try await gateway.scan(dependencyRoots: []) { sink.step = $0 }
  let result = try await gateway.apply(scanned.safe, permanent: false)
  try check(sink.step?.position == 1, "scan progress was not forwarded")
  try check(fake.applyCallCount == 1, "apply was not forwarded")
  try check(result == CleanupResult(beforeBytes: 300, afterBytes: 25, log: "done"),
            "cleanup result was not forwarded")
}
