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
        description: Text("Scanning only measures disk usage.")
      )
    case .scanning:
      ScanAnimationView(step: model.currentStep)
    case .cleaning:
      workingView("Clearing selected categories…")
    case .ready:
      if model.isConfirmingClean {
        confirmationView
      } else {
        ReadyFormView(model: model)
      }
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

  private var confirmationView: some View {
    let size = ByteFormat.text(model.selectedBytes)
    return VStack(spacing: 12) {
      Text("Clear selected categories (\(size))?")
        .font(.headline)
      Text("Files in the selected categories will be removed. Apps recreate caches. Reinstall dependencies after cleanup.")
        .foregroundStyle(.secondary)
      HStack(spacing: 12) {
        Button("Cancel", role: .cancel) {
          model.isConfirmingClean = false
        }
        .buttonStyle(.bordered)
        .keyboardShortcut(.cancelAction)
        Button("Clear", role: .destructive) {
          Task { await model.cleanSelected() }
        }
        .buttonStyle(.borderedProminent)
        .tint(.red)
      }
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal, 32)
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
