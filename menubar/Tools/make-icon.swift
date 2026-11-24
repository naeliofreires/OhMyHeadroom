// Draws the Police Scan icon at every size macOS asks for, then packs them with iconutil.
// The artwork is a gold magnifying glass with a dark lens, on a near-black background with a
// thin gold frame. One object, gold on black, no figure.
// Run once from the menubar folder:
//   mkdir -p Resources && swiftc Tools/make-icon.swift -o /tmp/make-icon && /tmp/make-icon Resources
import AppKit
import Foundation

/// File names and pixel sizes that iconutil expects inside an .iconset folder.
let iconsetEntries: [(file: String, pixels: Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024),
]

/// Colours of the noir lupa: a warm black background, gold metal, and dark glass.
enum Palette {
    static let backgroundTop = NSColor(calibratedRed: 0.17, green: 0.15, blue: 0.13, alpha: 1)
    static let backgroundBottom = NSColor(calibratedRed: 0.02, green: 0.02, blue: 0.03, alpha: 1)
    static let goldLight = NSColor(calibratedRed: 0.99, green: 0.91, blue: 0.62, alpha: 1)
    static let goldMid = NSColor(calibratedRed: 0.86, green: 0.67, blue: 0.28, alpha: 1)
    static let goldDark = NSColor(calibratedRed: 0.52, green: 0.35, blue: 0.10, alpha: 1)
    static let glassTop = NSColor(calibratedRed: 0.20, green: 0.18, blue: 0.16, alpha: 1)
    static let glassBottom = NSColor(calibratedRed: 0.03, green: 0.03, blue: 0.04, alpha: 1)
}

/// The lupa in unit coordinates: the lens centre, the outer radius of the gold rim, and its thickness.
let lensCentre: (x: CGFloat, y: CGFloat) = (0.44, 0.42)
let rimOuterRadius: CGFloat = 0.23
let rimThickness: CGFloat = 0.055
let rimInnerRadius: CGFloat = rimOuterRadius - rimThickness

/// Maps unit coordinates to canvas points. Unit (0, 0) is the top-left corner of the artwork,
/// (1, 1) the bottom-right, so the drawing reads top-down the way it is designed.
struct Artwork {
    let body: NSRect

    func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
        NSPoint(x: body.minX + x * body.width, y: body.maxY - y * body.height)
    }

    func length(_ value: CGFloat) -> CGFloat {
        value * body.width
    }
}

/// Apple's grid: the artwork sits inside ~824 of 1024 points, with a margin for the shadow.
func artworkRect(in bounds: NSRect) -> NSRect {
    let margin = bounds.width * 100 / 1024
    return bounds.insetBy(dx: margin, dy: margin)
}

func drawBackground(_ shape: NSBezierPath) {
    NSGradient(starting: Palette.backgroundTop, ending: Palette.backgroundBottom)?.draw(in: shape, angle: -90)
}

/// A thin gold line just inside the edge, like the border of a plaque.
func drawFrame(_ art: Artwork) {
    let inset = art.length(0.035)
    let frame = art.body.insetBy(dx: inset, dy: inset)
    let radius = frame.width * 0.2237
    let path = NSBezierPath(roundedRect: frame, xRadius: radius, yRadius: radius)
    path.lineWidth = art.length(0.008)
    Palette.goldMid.withAlphaComponent(0.45).setStroke()
    path.stroke()
}

/// An ellipse given by its centre and size in unit coordinates.
func ellipse(_ art: Artwork, centerX: CGFloat, centerY: CGFloat, width: CGFloat, height: CGFloat) -> NSBezierPath {
    let center = art.point(centerX, centerY)
    let rect = NSRect(
        x: center.x - art.length(width) / 2,
        y: center.y - art.length(height) / 2,
        width: art.length(width),
        height: art.length(height)
    )
    return NSBezierPath(ovalIn: rect)
}

/// A thick, round-capped line between two unit points, used for the handle.
func stroke(_ art: Artwork, from start: (CGFloat, CGFloat), to end: (CGFloat, CGFloat), width: CGFloat, color: NSColor) {
    let path = NSBezierPath()
    path.move(to: art.point(start.0, start.1))
    path.line(to: art.point(end.0, end.1))
    path.lineWidth = art.length(width)
    path.lineCapStyle = .round
    color.setStroke()
    path.stroke()
}

/// The gold rim as a ring: an outer circle with the inner circle cut out.
func goldRing(_ art: Artwork) -> NSBezierPath {
    let outer = ellipse(
        art,
        centerX: lensCentre.x, centerY: lensCentre.y,
        width: rimOuterRadius * 2, height: rimOuterRadius * 2
    )
    let inner = ellipse(
        art,
        centerX: lensCentre.x, centerY: lensCentre.y,
        width: rimInnerRadius * 2, height: rimInnerRadius * 2
    )
    let ring = NSBezierPath()
    ring.append(outer)
    ring.append(inner)
    ring.windingRule = .evenOdd
    return ring
}

/// A short highlight on the dark glass, so the lens reads as glass rather than a black disc.
func drawGlint(_ art: Artwork) {
    let centre = art.point(lensCentre.x, lensCentre.y)
    let radius = art.length(rimInnerRadius - 0.03)
    let arc = NSBezierPath()
    arc.appendArc(withCenter: centre, radius: radius, startAngle: 115, endAngle: 160)
    arc.lineWidth = art.length(0.012)
    arc.lineCapStyle = .round
    NSColor.white.withAlphaComponent(0.45).setStroke()
    arc.stroke()
}

/// The lupa: a handle, a dark glass lens, and a gold rim with a metallic gradient.
func drawLupa(_ art: Artwork) {
    let diagonal: CGFloat = 0.707
    let handleStart = (
        lensCentre.x + (rimOuterRadius - 0.01) * diagonal,
        lensCentre.y + (rimOuterRadius - 0.01) * diagonal
    )
    let handleEnd = (
        lensCentre.x + (rimOuterRadius + 0.30) * diagonal,
        lensCentre.y + (rimOuterRadius + 0.30) * diagonal
    )
    stroke(art, from: handleStart, to: handleEnd, width: 0.09, color: Palette.goldMid)

    let lens = ellipse(
        art,
        centerX: lensCentre.x, centerY: lensCentre.y,
        width: rimInnerRadius * 2, height: rimInnerRadius * 2
    )
    NSGradient(starting: Palette.glassTop, ending: Palette.glassBottom)?.draw(in: lens, angle: -90)
    drawGlint(art)

    NSGradient(colors: [Palette.goldLight, Palette.goldMid, Palette.goldDark])?
        .draw(in: goldRing(art), angle: -45)
}

/// Renders one PNG at an exact pixel size, bypassing the screen scale that NSImage would apply.
func renderPNG(pixels: Int) -> Data? {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        return nil
    }
    let bounds = NSRect(x: 0, y: 0, width: CGFloat(pixels), height: CGFloat(pixels))
    let body = artworkRect(in: bounds)
    let shape = NSBezierPath(
        roundedRect: body,
        xRadius: body.width * 0.2237,
        yRadius: body.width * 0.2237
    )
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawBackground(shape)
    shape.addClip()
    let art = Artwork(body: body)
    drawFrame(art)
    drawLupa(art)
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])
}

func writeIconset(into iconsetURL: URL) throws {
    try? FileManager.default.removeItem(at: iconsetURL)
    try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)
    for entry in iconsetEntries {
        guard let data = renderPNG(pixels: entry.pixels) else {
            fatalError("could not render \(entry.file)")
        }
        try data.write(to: iconsetURL.appendingPathComponent(entry.file))
    }
}

func packIcns(iconsetURL: URL, outputURL: URL) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
        fatalError("iconutil failed with status \(process.terminationStatus)")
    }
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconsetURL = outputDirectory.appendingPathComponent("AppIcon.iconset")
try writeIconset(into: iconsetURL)
try packIcns(iconsetURL: iconsetURL, outputURL: outputDirectory.appendingPathComponent("AppIcon.icns"))
try? FileManager.default.removeItem(at: iconsetURL)
print("wrote \(outputDirectory.path)/AppIcon.icns")
