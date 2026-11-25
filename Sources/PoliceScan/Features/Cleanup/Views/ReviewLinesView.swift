import AppKit
import SwiftUI

/// Folders the app measures but never deletes. Each row can open in Finder for a manual check.
struct ReviewLinesSection: View {
  let lines: [ReviewLine]

  var body: some View {
    Section {
      ForEach(lines) { line in
        ReviewRowView(line: line)
      }
    } header: {
      Text("Review yourself")
    } footer: {
      Text("The app measures these items but deletes none of them.")
    }
  }
}

/// One review-only line: label and size, the note on what it holds, and an optional Finder link.
struct ReviewRowView: View {
  let line: ReviewLine

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      LabeledContent(line.label.text) {
        Text(ByteFormat.text(line.sizeBytes))
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      Text(line.note.text)
        .font(.caption)
        .foregroundStyle(.secondary)
      if let folder = line.folder {
        Button("Show in Finder") {
          revealInFinder(folder)
        }
        .buttonStyle(.link)
        .font(.caption)
      }
    }
  }

  private func revealInFinder(_ folder: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)])
  }
}
