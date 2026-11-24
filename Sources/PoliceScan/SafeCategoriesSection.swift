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
        } footer: {
            Text("Apps and tools recreate these files. Quit the apps before deleting.")
        }
    }
}
