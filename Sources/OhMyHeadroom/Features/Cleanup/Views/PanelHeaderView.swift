import AppKit
import SwiftUI

/// App name, free space, the scan button, and the options menu.
struct PanelHeaderView: View {
  let model: CleanupModel
  @Environment(\.colorScheme) private var colorScheme
  @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.systemDefault
  @AppStorage(AppTheme.preferenceKey) private var theme = AppTheme.system

  var body: some View {
    HStack(spacing: 12) {
      Image(nsImage: BrandArtwork.headerImage)
        .renderingMode(.template)
        .frame(width: 28, height: 28)
        .foregroundStyle(Color(colorScheme == .dark ? BrandArtwork.pearl : BrandArtwork.sapphire))
        .accessibilityHidden(true)
      VStack(alignment: .leading, spacing: 2) {
        Text("OhMyHeadroom")
          .font(.system(size: 17, weight: .semibold))
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
    .disabled(model.isBusy || model.isConfirmingClean)
  }

  private var optionsMenu: some View {
    Menu {
      Picker("Language", selection: $language) {
        Text(verbatim: "English").tag(AppLanguage.english)
        Text(verbatim: "Português (Brasil)").tag(AppLanguage.portuguese)
      }
      .pickerStyle(.menu)
      Picker("Theme", selection: $theme) {
        Text("System").tag(AppTheme.system)
        Text("Light").tag(AppTheme.light)
        Text("Dark").tag(AppTheme.dark)
      }
      .pickerStyle(.menu)
      Divider()
      if model.canReset {
        Button("Reset") { model.reset() }
        Divider()
      }
      Button("Quit OhMyHeadroom") {
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
