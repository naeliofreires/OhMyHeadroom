import SwiftUI

/// The checkable safe categories, grouped the way System Settings groups its rows.
struct SafeCategoriesSection: View {
    let model: CleanupModel

    var body: some View {
        Section {
            ForEach(model.report?.safe ?? []) { category in
                CategoryRowView(category: category, model: model)
            }
        } header: {
            Text("Safe to delete")
                .font(.panelHeading)
        } footer: {
            Text("Quit affected apps before deleting.")
        }
    }
}
