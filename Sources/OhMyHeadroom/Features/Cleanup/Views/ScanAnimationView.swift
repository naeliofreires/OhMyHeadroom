import SwiftUI

struct ScanAnimationView: View {
  let step: ScanStep?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme

  private static let ink = Color(red: 0x10 / 255.0, green: 0x24 / 255.0, blue: 0x3A / 255.0)
  private static let sapphire = Color(red: 0x27 / 255.0, green: 0x64 / 255.0, blue: 0xE7 / 255.0)
  private static let cyan = Color(red: 0x64 / 255.0, green: 0xDA / 255.0, blue: 0xEB / 255.0)
  private static let pearl = Color(red: 0xE6 / 255.0, green: 0xF6 / 255.0, blue: 0xFF / 255.0)
  private static let rimDiameter: CGFloat = 156
  private static let sweepDegrees = 72.0
  private static let sweepPeriod: TimeInterval = 3

  var body: some View {
    VStack(spacing: 20) {
      instrument
        .accessibilityHidden(true)
      VStack(spacing: 8) {
        Text("Scanning your Mac")
          .font(.system(size: 20, weight: .medium))
          .foregroundStyle(.primary)
        detail
          .frame(height: 80)
      }
      .frame(maxWidth: 336)
      Text("Scanning only measures disk usage.")
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .frame(maxWidth: 336)
    }
    .multilineTextAlignment(.center)
    .padding(.horizontal, 32)
    .padding(.vertical, 16)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  private var instrument: some View {
    let haloOpacity = colorScheme == .dark ? 0.20 : 0.10
    return ZStack {
      Circle()
        .fill(RadialGradient(
          colors: [Self.cyan.opacity(haloOpacity), Self.sapphire.opacity(haloOpacity * 0.65), .clear],
          center: .center, startRadius: 44, endRadius: 92
        ))
      lens
      Circle()
        .strokeBorder(
          LinearGradient(
            colors: [Self.sapphire.opacity(0.45), Self.cyan.opacity(0.22), Self.sapphire.opacity(0.28)],
            startPoint: .topLeading, endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
        .frame(width: Self.rimDiameter, height: Self.rimDiameter)
      TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { context in
        let elapsed = context.date.timeIntervalSinceReferenceDate
        let turn = elapsed.truncatingRemainder(dividingBy: Self.sweepPeriod) / Self.sweepPeriod
        sweep
          .rotationEffect(.degrees(reduceMotion ? -126 : turn * 360 - 90))
      }
    }
    .frame(width: 184, height: 184)
  }

  private var lens: some View {
    ZStack {
      Circle()
        .fill(LinearGradient(
          colors: [Self.sapphire, Self.ink],
          startPoint: .topLeading, endPoint: .bottomTrailing
        ))
      Circle()
        .fill(RadialGradient(
          colors: [Self.pearl.opacity(0.32), Self.pearl.opacity(0)],
          center: UnitPoint(x: 0.24, y: 0.12), startRadius: 0, endRadius: 65
        ))
      Circle()
        .strokeBorder(
          LinearGradient(
            colors: [Self.pearl.opacity(0.50), Self.cyan.opacity(0.08)],
            startPoint: .topLeading, endPoint: .bottomTrailing
          ),
          lineWidth: 1
        )
      Image(systemName: "internaldrive")
        .font(.system(size: 32, weight: .medium))
        .foregroundStyle(Self.pearl)
    }
    .frame(width: 128, height: 128)
  }

  private var sweep: some View {
    Circle()
      .trim(from: 0, to: Self.sweepDegrees / 360)
      .stroke(
        AngularGradient(
          colors: [Self.cyan.opacity(0), Self.cyan],
          center: .center, startAngle: .zero, endAngle: .degrees(Self.sweepDegrees)
        ),
        style: StrokeStyle(lineWidth: 3, lineCap: .round)
      )
      .padding(0.5)
      .frame(width: Self.rimDiameter, height: Self.rimDiameter)
  }

  @ViewBuilder
  private var detail: some View {
    if let step {
      let label = step.label.text
      VStack(spacing: 4) {
        (label.isEmpty ? Text("Scanning your Mac") : Text(verbatim: label))
          .font(.system(size: 13, weight: .medium))
          .foregroundStyle(.primary)
          .lineLimit(2)
          .frame(height: 32)
        Text(verbatim: step.path)
          .font(.system(size: 11))
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .truncationMode(.middle)
          .help(Text(verbatim: step.path))
          .accessibilityLabel(Text(verbatim: step.path))
          .accessibilityHidden(step.path.isEmpty)
          .frame(height: 14)
        if step.total > 0, (1...step.total).contains(step.position) {
          Text("Checking \(String(step.position)) of \(String(step.total))")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .frame(height: 15)
        } else {
          Color.clear
            .frame(height: 15)
            .accessibilityHidden(true)
        }
      }
    } else {
      Text("Starting the scan…")
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.secondary)
    }
  }
}
