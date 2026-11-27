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
    case .finished(let result):
      FinishedFormView(result: result)
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
    let selected = model.selectedCategories
    return VStack(spacing: 14) {
      Text("Clear selected categories (\(size))?")
        .font(.headline)
        .multilineTextAlignment(.center)

      ScrollView {
        VStack(alignment: .leading, spacing: 8) {
          ForEach(selected) { category in
            HStack(spacing: 8) {
              DataKindPill(kind: category.dataKind)
              Text(category.label.text)
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(1)
              if let summary = model.pathCountSummary(forKey: category.key) {
                Text(verbatim: "· \(summary.text)")
                  .font(.caption)
                  .monospacedDigit()
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer(minLength: 8)
              Text(ByteFormat.text(category.sizeBytes))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .fixedSize()
            }
          }
        }
        .padding(10)
      }
      .frame(maxHeight: 200)
      .background(
        Color.primary.opacity(0.04),
        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
      )

      Text("Files in the selected categories will be removed. Apps recreate caches. Reinstall dependencies after cleanup.")
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)

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
    .padding(.horizontal, 28)
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

/// Compares the selected sizes before and after cleanup and shows the execution log.
struct FinishedFormView: View {
  let result: CleanupResult

  var body: some View {
    Form {
      Section {
        comparisonRow("Before", bytes: result.beforeBytes)
        comparisonRow("After", bytes: result.afterBytes)
        let reduction = result.reductionBytes
        if let reduction, reduction < 0 {
          comparisonRow("Increase", bytes: -reduction)
        } else {
          comparisonRow("Reduction", bytes: reduction)
        }
      } header: {
        Label("Selected cleanup", systemImage: "eraser")
          .font(.panelHeading)
      } footer: {
        if result.afterBytes == nil {
          Text("The remaining size could not be measured. See the cleanup log below.")
        }
      }
      Section {
        Text(result.log)
          .font(.system(.callout, design: .monospaced))
          .textSelection(.enabled)
      } header: {
        Label("Done", systemImage: "checkmark.circle")
          .font(.panelHeading)
      } footer: {
        Label("Scan again to refresh all categories.", systemImage: "arrow.clockwise")
      }
    }
    .formStyle(.grouped)
  }

  private func comparisonRow(_ label: LocalizedStringKey, bytes: Int?) -> some View {
    LabeledContent(label) {
      if let bytes {
        Text(ByteFormat.text(bytes))
          .monospacedDigit()
      } else {
        Text("Unavailable")
      }
    }
  }
}
