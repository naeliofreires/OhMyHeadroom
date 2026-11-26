import SwiftUI

/// The checkable categories grouped by behavior: auto-recreated caches/artifacts vs. dependencies requiring reinstall.
struct SafeCategoriesSection: View {
  let model: CleanupModel

  var body: some View {
    CategoryGroupSection(
      title: "Caches & temporary data",
      footer: "Recreated automatically or re-downloaded when needed. Quit affected apps first.",
      categories: model.automaticCategories,
      model: model
    )
    CategoryGroupSection(
      title: "Dependencies & builds",
      footer: "Unchecked by default. Reinstall dependencies or rebuild before running these projects.",
      categories: model.dependencyCategories,
      model: model
    )
  }
}

private struct CategoryGroupSection: View {
  let title: LocalizedStringKey
  let footer: LocalizedStringKey
  let categories: [Category]
  let model: CleanupModel

  var body: some View {
    if !categories.isEmpty {
      Section {
        ForEach(categories) { category in
          CategoryRowView(category: category, model: model)
        }
      } header: {
        Text(title)
          .font(.panelHeading)
      } footer: {
        Text(footer)
      }
    }
  }
}
