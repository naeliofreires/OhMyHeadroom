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
      Text("Manual review")
        .font(.panelHeading)
    } footer: {
      Text("OhMyHeadroom leaves these items in place.")
    }
  }
}

/// One review-only line arranged with the same hierarchy: title and size, status badge, description, and folder path.
struct ReviewRowView: View {
  let line: ReviewLine

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(line.label.text)
          .font(.panelRowEmphasis)
          .foregroundStyle(.primary)
          .fixedSize(horizontal: false, vertical: true)
        Spacer(minLength: 8)
        Text(ByteFormat.text(line.sizeBytes))
          .font(.panelRowEmphasis)
          .monospacedDigit()
          .foregroundStyle(.secondary)
          .fixedSize()
      }

      HStack(spacing: 6) {
        Text("Keep or review")
          .font(.panelBadge)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(Color.secondary.opacity(0.14), in: Capsule())
          .fixedSize()
        Text("Not deleted automatically")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }

      Text(line.note.text)
        .font(.caption)
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)

      if let folder = line.folder, let displayFolder = line.displayFolder {
        TargetContainer {
          HStack(spacing: 6) {
            Image(systemName: "folder")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
            Text(verbatim: displayFolder)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
              .help(displayFolder)
            Spacer(minLength: 8)
            Button("Show in Finder") {
              revealInFinder(folder)
            }
            .buttonStyle(.link)
            .font(.caption)
            .fixedSize()
          }
        }
      }
    }
    .padding(.vertical, 2)
  }

  private func revealInFinder(_ folder: String) {
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: folder)])
  }
}
