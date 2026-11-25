import SwiftUI

/// Picks the body for the current phase. Each phase is a small view, so this switch stays short.
struct PhaseContentView: View {
    let model: CleanupModel

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .idle:
            ContentUnavailableView(
                "Ready to scan",
                systemImage: "internaldrive",
                description: Text("Scanning won’t delete files.")
            )
        case .scanning:
            ScanAnimationView(step: model.currentStep)
        case .cleaning:
            workingView("Deleting selection…")
        case .ready:
            ReadyFormView(model: model)
        case .finished(let log):
            FinishedFormView(log: log)
        case .failed(let message):
            ContentUnavailableView(
                "Could not finish",
                systemImage: "exclamationmark.triangle",
                description: Text(message)
            )
        }
    }

    private func workingView(_ message: LocalizedStringKey) -> some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.large)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The scan result: safe categories to pick, then review-only folders.
struct ReadyFormView: View {
    let model: CleanupModel

    var body: some View {
        Form {
            SafeCategoriesSection(model: model)
            ReviewLinesSection(lines: model.report?.review ?? [])
        }
        .formStyle(.grouped)
    }
}

/// The log of the last cleaning run, with a reminder that the numbers on screen are now old.
struct FinishedFormView: View {
    let log: String

    var body: some View {
        Form {
            Section {
                Text(log)
                    .font(.system(.callout, design: .monospaced))
                    .textSelection(.enabled)
            } header: {
                Label("Done", systemImage: "checkmark.circle")
                    .font(.panelHeading)
            } footer: {
                Label("Rescan to update sizes.", systemImage: "arrow.clockwise")
            }
        }
        .formStyle(.grouped)
    }
}
