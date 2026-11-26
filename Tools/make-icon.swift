// Draws the Headroom icon at every size macOS asks for, then packs them with iconutil.
// Compile this file with Sources/PoliceScan/BrandArtwork.swift.
// Run once from the repository root:
//   swiftc Sources/PoliceScan/BrandArtwork.swift Tools/make-icon.swift -o /tmp/make-icon
//   /tmp/make-icon Resources
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


/// Apple's grid: the artwork sits inside ~824 of 1024 points, with a margin for the shadow.
func artworkRect(in bounds: NSRect) -> NSRect {
    let margin = bounds.width * 100 / 1024
    return bounds.insetBy(dx: margin, dy: margin)
}

func drawBackground(_ shape: NSBezierPath) {
    NSGradient(starting: BrandArtwork.sapphire, ending: BrandArtwork.ink)?.draw(in: shape, angle: -45)
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
    let markInset = body.width * 0.12
    BrandArtwork.drawMark(
        in: body.insetBy(dx: markInset, dy: markInset),
        primary: BrandArtwork.pearl,
        accent: BrandArtwork.cyan
    )
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

@main
enum IconGenerator {
    static func main() throws {
        let outputDirectory = URL(
            fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
        )
        let iconsetURL = outputDirectory.appendingPathComponent("AppIcon.iconset")
        try writeIconset(into: iconsetURL)
        try packIcns(
            iconsetURL: iconsetURL,
            outputURL: outputDirectory.appendingPathComponent("AppIcon.icns")
        )
        try? FileManager.default.removeItem(at: iconsetURL)
        print("wrote \(outputDirectory.path)/AppIcon.icns")
    }
}
