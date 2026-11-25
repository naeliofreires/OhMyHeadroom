import AppKit
import SwiftUI

/// App name, free space, the scan button, and the options menu.
struct PanelHeaderView: View {
  let model: CleanupModel
  @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.systemDefault

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "internaldrive")
        .font(.title)
        .foregroundStyle(.tint)
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text("Police Scan")
          .font(.panelHeading)
        Text("\(ByteFormat.text(model.freeBytes)) free")
          .font(.subheadline)
          .monospacedDigit()
          .foregroundStyle(.secondary)
      }
      Spacer()
      scanButton
      optionsMenu
    }
    .padding(14)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(10)
  }

  private var scanButton: some View {
    Button {
      Task { await model.scan() }
    } label: {
      Label {
        Text(model.report == nil ? LocalizedStringKey("Scan") : "Rescan")
      } icon: {
        if model.isBusy {
          ProgressView()
            .controlSize(.small)
            .accessibilityLabel("Working")
        } else {
          Image(systemName: model.report == nil ? "magnifyingglass" : "arrow.clockwise")
        }
      }
    }
    .buttonStyle(.bordered)
    .keyboardShortcut("r")
    .disabled(model.isBusy)
  }

  private var optionsMenu: some View {
    Menu {
      Picker("Language", selection: $language) {
        Text(verbatim: "English").tag(AppLanguage.english)
        Text(verbatim: "Português (Brasil)").tag(AppLanguage.portuguese)
      }
      .pickerStyle(.menu)
      Divider()
      if model.canReset {
        Button("Reset") { model.reset() }
        Divider()
      }
      Button("Quit Police Scan") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    } label: {
      Image(systemName: "ellipsis.circle")
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("More options")
    .accessibilityLabel("More options")
  }
}
