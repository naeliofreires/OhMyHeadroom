import AppKit
import SwiftUI

/// App name, free space, the scan button, and the options menu that holds Quit.
struct PanelHeaderView: View {
    let model: CleanupModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "internaldrive")
                .font(.title)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Police Scan")
                    .font(.headline)
                Text("Free now: \(ByteFormat.text(model.freeBytes))")
                    .font(.subheadline)
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
        HStack(spacing: 8) {
            busyIndicator
            Button(scanTitle) {
                Task { await model.scan() }
            }
            .buttonStyle(.bordered)
            .keyboardShortcut("r")
            .disabled(model.isBusy)
        }
    }

    private var scanTitle: LocalizedStringKey {
        model.report == nil ? "Scan" : "Scan again"
    }

    /// Spins next to the button while the disk is being measured or cleaned. The space is
    /// always reserved, so the button does not jump when the spinner appears.
    private var busyIndicator: some View {
        ZStack {
            if model.isBusy {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Working")
            }
        }
        .frame(width: 16, height: 16)
    }

    private var optionsMenu: some View {
        Menu {
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
