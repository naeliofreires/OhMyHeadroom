import SwiftUI

/// One checkable category: symbol, name, why it is safe, size, and its biggest folders.
struct CategoryRowView: View {
  let category: Category
  let model: CleanupModel

  var body: some View {
    Toggle(isOn: selectionBinding) {
      HStack(alignment: .top, spacing: 10) {
        Image(systemName: category.symbolName)
          .foregroundStyle(.secondary)
          .frame(width: 20)
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text(category.label.text)
          Text(category.note.text)
            .font(.caption)
            .foregroundStyle(.secondary)
          if !biggestPathsText.isEmpty {
            Text(biggestPathsText)
              .font(.caption2)
              .foregroundStyle(.tertiary)
              .lineLimit(2)
          }
        }
        Spacer()
        Text(ByteFormat.text(category.sizeBytes))
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
    }
    .toggleStyle(.checkbox)
    .help(category.note.text)
  }

  private var selectionBinding: Binding<Bool> {
    Binding(
      get: { model.isSelected(category) },
      set: { _ in model.toggle(category) }
    )
  }

  /// The three biggest paths, shown as ~/... so the user can recognise them.
  private var biggestPathsText: String {
    category.paths
      .prefix(3)
      .map { "\(displayPath($0.path)) \(ByteFormat.text($0.sizeBytes))" }
      .joined(separator: " · ")
  }

  private func displayPath(_ path: String) -> String {
    path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
  }
}

extension Category {
  /// An SF Symbol per kind of category. Unknown keys, such as dependency folders, use a folder.
  var symbolName: String {
    switch key {
    case "app-caches": return "tray.full"
    case "package-caches": return "shippingbox"
    case "editor-caches": return "curlybraces"
    case "logs": return "doc.text"
    case "docker-prune": return "cube"
    default: return "folder"
    }
  }
}
