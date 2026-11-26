import AppKit

enum BrandArtwork {
  static let ink = NSColor(srgbRed: 0x10 / 255.0, green: 0x24 / 255.0, blue: 0x3A / 255.0, alpha: 1)
  static let sapphire = NSColor(srgbRed: 0x27 / 255.0, green: 0x64 / 255.0, blue: 0xE7 / 255.0, alpha: 1)
  static let cyan = NSColor(srgbRed: 0x64 / 255.0, green: 0xDA / 255.0, blue: 0xEB / 255.0, alpha: 1)
  static let pearl = NSColor(srgbRed: 0xE6 / 255.0, green: 0xF6 / 255.0, blue: 0xFF / 255.0, alpha: 1)

  static func drawMark(in bounds: NSRect, primary: NSColor, accent: NSColor) {
    let side = min(bounds.width, bounds.height)
    let square = NSRect(
      x: bounds.midX - side / 2,
      y: bounds.midY - side / 2,
      width: side,
      height: side
    )
    let radius = side * 0.29
    let lineWidth = side * 0.105

    func cocoaPoint(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
      NSPoint(x: square.minX + x * side, y: square.maxY - y * side)
    }

    let mainArc = NSBezierPath()
    mainArc.appendArc(
      withCenter: cocoaPoint(0.50, 0.60),
      radius: radius,
      startAngle: 45,
      endAngle: -225,
      clockwise: true
    )
    mainArc.lineWidth = lineWidth
    mainArc.lineCapStyle = .round
    primary.setStroke()
    mainArc.stroke()

    let cap = NSBezierPath()
    cap.appendArc(
      withCenter: cocoaPoint(0.50, 0.38),
      radius: radius,
      startAngle: 135,
      endAngle: 45,
      clockwise: true
    )
    cap.lineWidth = lineWidth
    cap.lineCapStyle = .round
    accent.setStroke()
    cap.stroke()
  }

  static let menuBarImage = templateImage(size: NSSize(width: 18, height: 18))
  static let headerImage = templateImage(size: NSSize(width: 28, height: 28))

  private static func templateImage(size: NSSize) -> NSImage {
    let image = NSImage(size: size, flipped: false) { bounds in
      drawMark(in: bounds, primary: .black, accent: .black)
      return true
    }
    image.isTemplate = true
    return image
  }
}
