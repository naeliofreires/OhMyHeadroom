import AppKit
import SwiftUI

/// Edits the folders searched for project and worktree dependencies.
struct ScanRootsView: View {
  static let windowID = "project-folders"

  let model: CleanupModel
  @Environment(\.dismissWindow) private var dismissWindow

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Choose where OhMyHeadroom looks for project dependencies.")
        .font(.subheadline)
        .foregroundStyle(.secondary)

      Group {
        if model.scanRoots.isEmpty {
          ContentUnavailableView(
            "No project folders",
            systemImage: "folder",
            description: Text("Dependency scanning is off. Add a folder to enable it.")
          )
        } else {
          List(model.scanRoots, id: \.self) { path in
            rootRow(path)
          }
          .listStyle(.inset)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)

      HStack {
        Button("Done") { dismissWindow(id: Self.windowID) }
        Spacer()
        Button("Add folder…", systemImage: "plus", action: chooseFolder)
          .buttonStyle(.borderedProminent)
          .disabled(model.isBusy)
      }
    }
    .padding(16)
  }

  private func rootRow(_ path: String) -> some View {
    let displayPath = PathDisplay.abbreviate(path)
    return HStack {
      Text(verbatim: displayPath)
        .lineLimit(1)
        .truncationMode(.middle)
        .help(path)
      Spacer()
      Button {
        model.removeScanRoot(path)
      } label: {
        Image(systemName: "minus.circle")
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(Text("Remove \(displayPath)"))
      .help(Text("Remove \(displayPath)"))
      .disabled(model.isBusy)
    }
  }

  private func chooseFolder() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.prompt = String(localized: "Add folder", bundle: AppLanguage.current.stringsBundle)
    let complete: (NSApplication.ModalResponse) -> Void = { response in
      model.addScanRoot(response == .OK ? panel.url : nil)
    }
    if let window = NSApp.keyWindow {
      panel.beginSheetModal(for: window, completionHandler: complete)
    } else {
      panel.begin(completionHandler: complete)
    }
  }
}
