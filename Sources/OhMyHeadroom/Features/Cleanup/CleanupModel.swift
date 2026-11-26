import Foundation
import Observation

/// What the panel shows: the last scan, the user's picks, and the outcome of cleaning.
@MainActor
@Observable
final class CleanupModel {
  enum Phase: Equatable {
    case idle
    case scanning
    case ready
    case cleaning
    case finished(log: String)
    case failed(message: String)
  }

  private let gateway: any CleanupGateway
  private let freeSpaceReader: any FreeSpaceReader
  private(set) var phase: Phase = .idle
  private(set) var report: ScanReport?
  private(set) var selectedKeys: Set<String> = []
  /// Held here rather than in a view's @State: the Command Line Tools cannot expand @State.
  var isConfirmingClean = false
  private(set) var freeBytes: Int?

  init(
    gateway: any CleanupGateway, freeSpaceReader: any FreeSpaceReader = FileSystemFreeSpaceReader()
  ) {
    self.gateway = gateway
    self.freeSpaceReader = freeSpaceReader
    freeBytes = freeSpaceReader.currentFreeBytes()
  }

  var isBusy: Bool {
    phase == .scanning || phase == .cleaning
  }

  var canReset: Bool {
    phase != .idle && !isBusy
  }

  func reset() {
    guard canReset else { return }
    report = nil
    selectedKeys = []
    currentStep = nil
    isConfirmingClean = false
    freeBytes = freeSpaceReader.currentFreeBytes()
    phase = .idle
  }

  var selectedCategories: [Category] {
    report?.safe.filter { selectedKeys.contains($0.key) } ?? []
  }

  var selectedBytes: Int {
    selectedCategories.reduce(0) { $0 + $1.sizeBytes }
  }

  var menuBarTitle: String {
    guard let freeBytes else { return "OhMyHeadroom" }
    return String(localized: "\(ByteFormat.text(freeBytes)) free", bundle: AppLanguage.current.stringsBundle)
  }

  func isSelected(_ category: Category) -> Bool {
    selectedKeys.contains(category.key)
  }

  func toggle(_ category: Category) {
    if selectedKeys.contains(category.key) {
      selectedKeys.remove(category.key)
    } else {
      selectedKeys.insert(category.key)
    }
  }

  /// The folder being measured right now, shown by the scan animation.
  private(set) var currentStep: ScanStep?

  /// Accepts a step only if it is further along than the one shown, so a late message
  /// cannot move the animation backwards.
  func showStep(_ step: ScanStep) {
    if let shown = currentStep, shown.position >= step.position { return }
    currentStep = step
  }

  /// Measures the disk. Nothing is deleted here.
  func scan() async {
    phase = .scanning
    currentStep = nil
    do {
      let fresh = try await gateway.scan { [weak self] step in
        Task { @MainActor in
          guard self?.phase == .scanning else { return }
          self?.showStep(step)
        }
      }
      report = fresh
      selectedKeys = Set(fresh.safe.filter { !$0.isOffByDefault }.map(\.key))
      freeBytes = fresh.freeBytes
      phase = .ready
    } catch {
      phase = .failed(message: error.localizedDescription)
    }
  }

  /// Deletes what the user picked. The report is dropped afterwards because its sizes are stale.
  func cleanSelected() async {
    let picked = selectedCategories
    guard phase == .ready, !picked.isEmpty else { return }
    isConfirmingClean = false
    phase = .cleaning
    do {
      let log = try await gateway.apply(picked)
      phase = .finished(log: log)
    } catch {
      phase = .failed(message: error.localizedDescription)
    }
    report = nil
    selectedKeys = []
    freeBytes = freeSpaceReader.currentFreeBytes()
  }
}
