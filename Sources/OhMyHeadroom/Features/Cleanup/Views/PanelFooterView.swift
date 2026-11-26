import SwiftUI

/// The selected total, the Trash toggle with its note, and the cleanup action, which asks for confirmation before removing files.
struct PanelFooterView: View {
  @Bindable var model: CleanupModel

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle("Move to Trash", isOn: $model.movesToTrash)
      if model.shouldShowTrashNote {
        Text("Space is freed only when the Trash is emptied.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      HStack {
        Text("Selected: \(ByteFormat.text(model.selectedBytes))")
          .monospacedDigit()
          .foregroundStyle(.secondary)
        Spacer()
        Button("Clear…", systemImage: "eraser") {
          model.isConfirmingClean = true
        }
        .buttonStyle(.glassProminent)
        .disabled(model.selectedCategories.isEmpty || model.isBusy)
      }
    }
    .padding(14)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(10)
  }
}
