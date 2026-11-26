import SwiftUI

/// The menu bar panel. The header and footer float as glass bars, and the content scrolls
/// beneath them. Glass belongs to the controls layer, so the list itself stays opaque.
struct MenuPanelView: View {
  let model: CleanupModel

  var body: some View {
    PhaseContentView(model: model)
      .safeAreaInset(edge: .top, spacing: 0) {
        PanelHeaderView(model: model)
      }
      .safeAreaInset(edge: .bottom, spacing: 0) {
        if model.report != nil && !model.isConfirmingClean && model.phase != .cleaning {
          PanelFooterView(model: model)
        }
      }
      // Top-aligned: a centred stack would float the header down when the content is short.
      .frame(width: 460, height: 560)
  }
}
