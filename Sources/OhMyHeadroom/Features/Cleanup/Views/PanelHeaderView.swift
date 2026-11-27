import AppKit
import SwiftUI

/// App name, free space, the scan button, and the options menu.
struct PanelHeaderView: View {
  let model: CleanupModel
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.openWindow) private var openWindow
  @AppStorage(AppLanguage.preferenceKey) private var language = AppLanguage.systemDefault
  @AppStorage(AppTheme.preferenceKey) private var theme = AppTheme.system

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 12) {
        Image(nsImage: BrandArtwork.headerImage)
          .renderingMode(.template)
          .frame(width: 28, height: 28)
          .foregroundStyle(Color(colorScheme == .dark ? BrandArtwork.pearl : BrandArtwork.sapphire))
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 2) {
          Text("OhMyHeadroom")
            .font(.system(size: 17, weight: .medium))
          Text("\(ByteFormat.text(model.freeBytes)) free")
            .font(.subheadline)
            .monospacedDigit()
            .foregroundStyle(.secondary)
        }
        Spacer()
        scanButton
        optionsMenu
      }
      updateBanner
    }
    .padding(14)
    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    .padding(10)
  }

  @ViewBuilder
  private var updateBanner: some View {
    switch model.updateStatus {
    case .available(let update):
      HStack(spacing: 8) {
        Button {
          NSWorkspace.shared.open(update.pageURL)
        } label: {
          HStack(spacing: 6) {
            Image(systemName: "arrow.up.circle.fill")
              .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
              Text("Update available (\(update.shortLatestSHA))")
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
              if let title = update.commitTitle {
                Text(verbatim: title)
                  .font(.caption2)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
            }
            Spacer(minLength: 4)
            Text("Open on GitHub")
              .font(.caption2.weight(.medium))
              .foregroundStyle(.blue)
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(update.commitTitle ?? GitHubMainUpdateChecker.repositoryURL.absoluteString)

        Button {
          copyUpdateCommand()
        } label: {
          Image(systemName: "doc.on.doc")
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
        .help("Copy update command")
        .accessibilityLabel("Copy update command")
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    case .checking:
      HStack(spacing: 6) {
        ProgressView()
          .controlSize(.small)
        Text("Checking for updates…")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 4)
    case .upToDate:
      statusNotice(text: "Up to date", symbol: "checkmark.circle", color: .secondary)
    case .unavailable:
      statusNotice(text: "Could not check for updates", symbol: "wifi.exclamationmark", color: .secondary)
    case .idle:
      EmptyView()
    }
  }

  private func statusNotice(text: LocalizedStringKey, symbol: String, color: Color) -> some View {
    HStack(spacing: 6) {
      Label(text, systemImage: symbol)
        .font(.caption)
        .foregroundStyle(color)
      Spacer()
      Button {
        model.dismissUpdateNotice()
      } label: {
        Image(systemName: "xmark")
          .font(.caption2)
          .foregroundStyle(.tertiary)
      }
      .buttonStyle(.borderless)
    }
    .padding(.horizontal, 4)
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
      if let update = model.availableUpdate {
        Button("Update available (\(update.shortLatestSHA))") {
          NSWorkspace.shared.open(update.pageURL)
        }
        Button("Copy update command") {
          copyUpdateCommand()
        }
        Divider()
      }
      Button("Check for updates") {
        Task { await model.checkForUpdatesNow() }
      }
      .disabled(model.updateStatus == .checking)
      Divider()
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
      Button("Project folders…") {
        NSApp.activate()
        openWindow(id: ScanRootsView.windowID)
      }
      .disabled(model.isBusy)
      Divider()
      if model.canReset {
        Button("Reset") { model.reset() }
        Divider()
      }
      Text("Version \(model.installedVersionLabel)")
      Divider()
      Button("Quit OhMyHeadroom") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q")
    } label: {
      Image(systemName: "ellipsis.circle")
        .overlay(alignment: .topTrailing) {
          if model.availableUpdate != nil {
            Circle()
              .fill(.blue)
              .frame(width: 6, height: 6)
              .offset(x: 2, y: -2)
          }
        }
    }
    .menuStyle(.borderlessButton)
    .menuIndicator(.hidden)
    .fixedSize()
    .help("More options")
    .accessibilityLabel("More options")
  }

  private func copyUpdateCommand() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(GitHubMainUpdateChecker.updateCommand, forType: .string)
  }
}
