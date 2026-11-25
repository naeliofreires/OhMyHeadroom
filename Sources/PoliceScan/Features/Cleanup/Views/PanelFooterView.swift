import SwiftUI

/// The selected total and the destructive action. Delete always asks first, with Cancel offered.
struct PanelFooterView: View {
  let model: CleanupModel

  var body: some View {
    HStack {
      Text("Selected: \(ByteFormat.text(model.selectedBytes))")
        .monospacedDigit()
        .foregroundStyle(.secondary)
      Spacer()
      Button("Delete…", systemImage: "trash", role: .destructive) {
        model.isConfirmingClean = true
      }
      .buttonStyle(.glassProminent)
      .tint(.red)
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
      Button("Delete", role: .destructive) {
        Task { await model.cleanSelected() }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Apps recreate caches. Reinstall dependencies after deletion.")
    }
  }

  private var confirmationBinding: Binding<Bool> {
    Binding(
      get: { model.isConfirmingClean },
      set: { model.isConfirmingClean = $0 }
    )
  }

  private var confirmationTitle: String {
    let size = ByteFormat.text(model.selectedBytes)
    return String(localized: "Delete selected items (\(size))?")
  }
}
