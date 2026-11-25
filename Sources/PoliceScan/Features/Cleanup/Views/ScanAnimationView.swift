import AppKit
import SwiftUI

/// What the user sees while the disk is measured: the detective (the app icon) bobbing,
/// a magnifier sweeping a row of folders as the scan moves on, and a caption that names
/// the folder being checked right now, with its path and a count.
struct ScanAnimationView: View {
  let step: ScanStep?

  private static let folderCount = 6
  /// Distance between neighbouring folder centres, in points.
  private static let folderPitch: CGFloat = 50

  var body: some View {
    TimelineView(.animation) { context in
      let time = context.date.timeIntervalSinceReferenceDate
      VStack(spacing: 20) {
        scene(time: time)
        caption
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
  }

  private func scene(time: TimeInterval) -> some View {
    HStack(spacing: 18) {
      Image(nsImage: NSApp.applicationIconImage)
        .resizable()
        .frame(width: 60, height: 60)
        .offset(y: CGFloat(sin(time * 2.4)) * 3)
        .accessibilityHidden(true)
      folderRow(time: time)
    }
  }

  private func folderRow(time: TimeInterval) -> some View {
    ZStack {
      HStack(spacing: 14) {
        ForEach(0..<Self.folderCount, id: \.self) { index in
          Image(systemName: "folder.fill")
            .font(.system(size: 30))
            .foregroundStyle(folderColor(index))
        }
      }
      Image(systemName: "magnifyingglass")
        .font(.system(size: 44, weight: .semibold))
        .foregroundStyle(.primary)
        .offset(x: lensOffset(time: time), y: 10)
        .animation(.smooth, value: currentFolder)
    }
  }

  private var caption: some View {
    VStack(spacing: 6) {
      if let step {
        Text("Checking \(String(step.position)) of \(String(step.total))")
          .font(.caption)
          .foregroundStyle(.secondary)
        Text(step.label.text)
          .font(.headline)
        Text(step.path)
          .font(.caption)
          .foregroundStyle(.secondary)
          .lineLimit(2)
        ProgressView(value: Double(step.position), total: Double(step.total))
          .frame(width: 240)
      } else {
        Text("Starting the scan…")
          .foregroundStyle(.secondary)
      }
      Label("Usually 1–2 min", systemImage: "clock")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
    .multilineTextAlignment(.center)
  }

  /// Which folder the magnifier is over. The row is a progress track: folders behind the
  /// lens are the ones already checked.
  private var currentFolder: Int {
    guard let step, step.total > 0 else { return 0 }
    let index = (step.position - 1) * Self.folderCount / step.total
    return min(max(index, 0), Self.folderCount - 1)
  }

  private func folderColor(_ index: Int) -> Color {
    if index == currentFolder { return .accentColor }
    if index < currentFolder { return .accentColor.opacity(0.45) }
    return .secondary.opacity(0.35)
  }

  /// Moves the lens to the current folder, with a small wobble so it looks like it is scanning.
  private func lensOffset(time: TimeInterval) -> CGFloat {
    let centre = CGFloat(Self.folderCount - 1) / 2
    let target = (CGFloat(currentFolder) - centre) * Self.folderPitch
    return target + CGFloat(sin(time * 3)) * 2
  }
}
