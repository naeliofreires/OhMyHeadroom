import SwiftUI

/// A checkbox that shows checked, mixed, or empty. SwiftUI's checkbox toggle cannot show the mixed
/// state, so a category with only some paths picked needs this drawn checkbox.
/// Example: `SelectionCheckbox(state: model.selectionState(of: category))`.
struct SelectionCheckbox: View {
  let state: CategorySelection.State

  var body: some View {
    Image(systemName: symbolName)
      .font(.system(size: 14))
      .foregroundStyle(state == .none ? Color.secondary : Color.accentColor)
      .frame(width: 18, height: 18)
      .accessibilityHidden(true)
  }

  private var symbolName: String {
    switch state {
    case .none: "square"
    case .partial: "minus.square.fill"
    case .all: "checkmark.square.fill"
    }
  }
}
