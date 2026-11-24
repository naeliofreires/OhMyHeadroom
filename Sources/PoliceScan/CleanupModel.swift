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

    private(set) var phase: Phase = .idle
    private(set) var report: ScanReport?
    private(set) var selectedKeys: Set<String> = []
    /// Held here rather than in a view's @State: the Command Line Tools cannot expand @State.
    var isConfirmingClean = false
    private(set) var freeBytes: Int? = CleanupModel.currentFreeBytes()

    var isBusy: Bool {
        phase == .scanning || phase == .cleaning
    }

    var selectedCategories: [Category] {
        report?.safe.filter { selectedKeys.contains($0.key) } ?? []
    }

    var selectedBytes: Int {
        selectedCategories.reduce(0) { $0 + $1.sizeBytes }
    }

    var menuBarTitle: String {
        guard let freeBytes else { return "Police Scan" }
        return String(localized: "\(ByteFormat.text(freeBytes)) free")
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
            let engine = try CleanupEngine.locate()
            let fresh = try await engine.scan { [weak self] step in
                Task { @MainActor in self?.showStep(step) }
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
        guard !picked.isEmpty else { return }
        phase = .cleaning
        do {
            let engine = try CleanupEngine.locate()
            let log = try await engine.apply(picked)
            phase = .finished(log: log)
        } catch {
            phase = .failed(message: error.localizedDescription)
        }
        report = nil
        selectedKeys = []
        freeBytes = Self.currentFreeBytes()
    }

    /// Same number the engine reads with shutil.disk_usage, so the menu bar matches the terminal.
    private static func currentFreeBytes() -> Int? {
        let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
        return (attributes?[.systemFreeSize] as? NSNumber)?.intValue
    }
}
