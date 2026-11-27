import SwiftUI

/// One checkable category arranged in a clear hierarchy:
/// title and total size, data-type badge and recovery impact, description, and affected paths or commands.
struct CategoryRowView: View {
  let category: Category
  let model: CleanupModel

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Button {
        model.toggle(category)
      } label: {
        HStack(alignment: .top, spacing: 10) {
          SelectionCheckbox(state: model.selectionState(of: category))
          categoryIcon
          VStack(alignment: .leading, spacing: 4) {
            headerRow
            metadataRow
            Text(category.note.text)
              .font(.caption)
              .foregroundStyle(.secondary)
              .fixedSize(horizontal: false, vertical: true)
          }
        }
      }
      .buttonStyle(.plain)
      .help(category.note.text)

      targetBreakdown
        .padding(.leading, 22)
    }
    .padding(.vertical, 2)
  }

  private var categoryIcon: some View {
    Image(systemName: category.dataKind.symbolName)
      .font(.system(size: 12, weight: .semibold))
      .foregroundStyle(category.dataKind.tint)
      .frame(width: 24, height: 24)
      .background(
        category.dataKind.tint.opacity(0.14),
        in: RoundedRectangle(cornerRadius: 6, style: .continuous)
      )
      .accessibilityHidden(true)
  }

  private var headerRow: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(category.label.text)
        .font(.panelRowEmphasis)
        .foregroundStyle(.primary)
        .fixedSize(horizontal: false, vertical: true)
      Spacer(minLength: 8)
      Text(ByteFormat.text(pickedBytes))
        .font(.panelRowEmphasis)
        .monospacedDigit()
        .foregroundStyle(pickedBytes > 0 ? .primary : .secondary)
        .fixedSize()
    }
  }

  /// The header shows what the user picked, so a partly picked row matches what will be cleared.
  private var pickedBytes: Int {
    model.pickedBytes(for: category)
  }

  private var metadataRow: some View {
    HStack(spacing: 6) {
      DataKindPill(kind: category.dataKind)
      Text(category.dataKind.recovery.text)
        .font(.caption2)
        .foregroundStyle(.secondary)
        .lineLimit(1)
      if let summary = category.targetCountSummary {
        Text(verbatim: "· \(summary.text)")
          .font(.caption2)
          .monospacedDigit()
          .foregroundStyle(.tertiary)
          .fixedSize()
      }
    }
  }

  @ViewBuilder
  private func pathCheckbox(for item: SizedPath) -> some View {
    if CategorySelection.allowsPathPicking(category) {
      Button {
        model.toggleItem(item.path, in: category)
      } label: {
        SelectionCheckbox(state: model.itemState(item.path, in: category))
      }
      .buttonStyle(.plain)
    }
  }

  @ViewBuilder
  private var targetBreakdown: some View {
    if !category.paths.isEmpty {
      let expanded = model.isExpanded(category)
      let visible = category.visiblePaths(expanded: expanded)
      TargetContainer {
        ForEach(visible.indices, id: \.self) { index in
          let item = visible[index]
          let displayPath = item.displayPath
          HStack(spacing: 6) {
            pathCheckbox(for: item)
            Image(systemName: "folder")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
            Text(verbatim: displayPath)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
              .help(displayPath)
            Spacer(minLength: 8)
            Text(ByteFormat.text(item.sizeBytes))
              .font(.caption)
              .monospacedDigit()
              .foregroundStyle(.secondary)
              .fixedSize()
          }
        }
        if category.hasMorePaths {
          Button {
            model.toggleExpanded(category)
          } label: {
            Label(
              expanded
                ? LocalizedStringKey("Show fewer paths")
                : LocalizedStringKey("Show all \(String(category.paths.count)) paths"),
              systemImage: expanded ? "chevron.up" : "chevron.down"
            )
            .font(.caption)
          }
          .buttonStyle(.link)
          .padding(.top, 2)
        }
      }
    } else if !category.commands.isEmpty {
      let lines = category.commandLines
      TargetContainer {
        ForEach(lines.indices, id: \.self) { index in
          let command = lines[index]
          HStack(spacing: 6) {
            Image(systemName: "terminal")
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .accessibilityHidden(true)
            Text(verbatim: command)
              .font(.system(.caption, design: .monospaced))
              .foregroundStyle(.secondary)
              .lineLimit(1)
              .truncationMode(.middle)
              .help(command)
            Spacer(minLength: 0)
          }
        }
      }
    } else {
      Text("No items found in this category.")
        .font(.caption2)
        .foregroundStyle(.tertiary)
    }
  }

}

/// Shared inset container for listing affected paths or commands under a row.
struct TargetContainer<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      content()
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(
      Color.primary.opacity(0.035),
      in: RoundedRectangle(cornerRadius: 8, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
    )
  }
}

/// Color-coded pill identifying what kind of data a category removes.
struct DataKindPill: View {
  let kind: CategoryDataKind

  var body: some View {
    Text(kind.badge.text)
      .font(.panelBadge)
      .foregroundStyle(kind.tint)
      .padding(.horizontal, 6)
      .padding(.vertical, 2)
      .background(kind.tint.opacity(0.14), in: Capsule())
      .fixedSize()
  }
}

extension CategoryDataKind {
  var tint: Color {
    switch self {
    case .appCache: .blue
    case .packageCache: .teal
    case .editorCache: .indigo
    case .logs: .secondary
    case .docker: .cyan
    case .worktreeDependencies, .projectDependencies: .orange
    case .temporary: .secondary
    }
  }
}
