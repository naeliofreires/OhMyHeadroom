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
    .confirmationDialog(
      confirmationTitle,
      isPresented: confirmationBinding,
      titleVisibility: .visible
    ) {
      Button("Clear", role: .destructive) {
        Task { await model.cleanSelected() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Files in the selected categories will be removed. Apps recreate caches. Reinstall dependencies after cleanup.")
    }
  }

  private var confirmationBinding: Binding<Bool> {
    Binding(
      get: { model.isConfirmingClean },
      set: { model.isConfirmingClean = $0 }
    )
  }

  private var confirmationTitle: LocalizedStringKey {
    let size = ByteFormat.text(model.selectedBytes)
    return "Clear selected categories (\(size))?"
  }
}
