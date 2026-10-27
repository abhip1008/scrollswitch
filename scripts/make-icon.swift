// Draws the app icon and writes an .iconset folder for iconutil.
//
//   swift scripts/make-icon.swift build/AppIcon.iconset && iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "AppIcon.iconset")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let rect = NSRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
    let tile = NSBezierPath(roundedRect: rect, xRadius: s * 0.18, yRadius: s * 0.18)
    NSGradient(starting: NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1),
               ending: NSColor(calibratedRed: 0.42, green: 0.25, blue: 0.85, alpha: 1))!.draw(in: tile, angle: -90)

    let config = NSImage.SymbolConfiguration(pointSize: s * 0.26, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    func symbol(_ name: String, at point: NSPoint) {
        guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
        img.draw(in: NSRect(x: point.x - img.size.width / 2, y: point.y - img.size.height / 2,
                            width: img.size.width, height: img.size.height))
    }
    symbol("computermouse.fill", at: NSPoint(x: s * 0.34, y: s * 0.62))
    symbol("hand.point.up.left.fill", at: NSPoint(x: s * 0.66, y: s * 0.38))
    symbol("arrow.left.arrow.right", at: NSPoint(x: s * 0.66, y: s * 0.66))
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

for base in [16, 32, 128, 256, 512] {
    try render(base).write(to: out.appendingPathComponent("icon_\(base)x\(base).png"))
    try render(base * 2).write(to: out.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
print("Wrote \(out.path)")
