import SwiftUI

/// The selected total and the cleanup action, which asks for confirmation before removing files.
struct PanelFooterView: View {
  let model: CleanupModel

  var body: some View {
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
    .padding(14)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(10)
  }
}
