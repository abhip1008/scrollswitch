// Renders the README demo frames with the app's real menu bar icon code.
//
//   swiftc scripts/demo/main.swift Sources/ScrollSwitch/UI/MenuBarIcon.swift -o build/make-demo
//   build/make-demo build/demo-frames
//
// Then `make demo` turns the frames into docs/images/demo.gif.
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "demo-frames")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let width: CGFloat = 720, height: CGFloat = 240, scale: CGFloat = 2
let bar = NSColor(calibratedWhite: 0.12, alpha: 1)
let page = NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.99, alpha: 1)

struct Scene {
    let natural: Bool
    let setupSymbol: String
    let setup: String
    let result: String
    let detail: String
}

let scenes = [
    Scene(natural: false, setupSymbol: "display.2", setup: "Monitors plugged in, lid closed",
          result: "Natural scrolling OFF", detail: "The mouse wheel scrolls the normal way"),
    Scene(natural: true, setupSymbol: "laptopcomputer", setup: "Unplugged, lid open",
          result: "Natural scrolling ON", detail: "The trackpad feels natural again"),
]

func tinted(_ image: NSImage, _ color: NSColor) -> NSImage {
    let copy = NSImage(size: image.size, flipped: false) { rect in
        image.draw(in: rect)
        color.set()
        rect.fill(using: .sourceAtop)
        return true
    }
    return copy
}

func text(_ s: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, at p: NSPoint) {
    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: color]
    (s as NSString).draw(at: p, withAttributes: attrs)
}

func symbol(_ name: String, size: CGFloat, color: NSColor, center: NSPoint) {
    let config = NSImage.SymbolConfiguration(pointSize: size, weight: .regular).applying(.init(paletteColors: [color]))
    guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config) else { return }
    img.draw(in: NSRect(x: center.x - img.size.width / 2, y: center.y - img.size.height / 2, width: img.size.width, height: img.size.height))
}

func render(_ scene: Scene, progress: CGFloat) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    page.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    // Menu bar strip with the real ScrollSwitch icon, highlighted.
    let barRect = NSRect(x: 0, y: height - 34, width: width, height: 34)
    bar.setFill()
    barRect.fill()
    let iconX = width - 150
    NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
    NSBezierPath(roundedRect: NSRect(x: iconX - 6, y: barRect.minY + 5, width: 34, height: 24), xRadius: 6, yRadius: 6).fill()
    let icon = tinted(MenuBarIcon.image(natural: scene.natural, paused: false, warning: false), .white)
    icon.draw(in: NSRect(x: iconX, y: barRect.minY + 8, width: icon.size.width, height: icon.size.height))
    for (i, name) in ["wifi", "battery.75percent"].enumerated() {
        symbol(name, size: 13, color: NSColor(calibratedWhite: 1, alpha: 0.85), center: NSPoint(x: iconX + 48 + CGFloat(i) * 30, y: barRect.midY))
    }
    text("9:41", size: 13, weight: .medium, color: .white, at: NSPoint(x: width - 50, y: barRect.minY + 9))
    text("ScrollSwitch", size: 13, weight: .semibold, color: .white, at: NSPoint(x: 16, y: barRect.minY + 9))

    // Setup on the left, result on the right.
    let accent = scene.natural ? NSColor(calibratedRed: 0.20, green: 0.62, blue: 0.35, alpha: 1)
                               : NSColor(calibratedRed: 0.20, green: 0.45, blue: 0.95, alpha: 1)
    symbol(scene.setupSymbol, size: 58, color: NSColor(calibratedWhite: 0.25, alpha: 1), center: NSPoint(x: 110, y: 110))
    text(scene.setup, size: 14, weight: .medium, color: NSColor(calibratedWhite: 0.3, alpha: 1), at: NSPoint(x: 30, y: 40))

    let arrowAlpha = min(1, progress * 2)
    symbol("arrow.right", size: 30, color: accent.withAlphaComponent(arrowAlpha), center: NSPoint(x: 290, y: 110))

    let resultAlpha = min(1, max(0, progress * 2 - 0.4))
    symbol(scene.natural ? "hand.point.up.left.fill" : "computermouse.fill", size: 50,
           color: accent.withAlphaComponent(resultAlpha), center: NSPoint(x: 395, y: 112))
    text(scene.result, size: 24, weight: .bold, color: NSColor(calibratedWhite: 0.1, alpha: resultAlpha), at: NSPoint(x: 445, y: 112))
    text(scene.detail, size: 14, weight: .regular, color: NSColor(calibratedWhite: 0.35, alpha: resultAlpha), at: NSPoint(x: 447, y: 88))
    text("automatically, about 2 seconds later", size: 12, weight: .regular,
         color: NSColor(calibratedWhite: 0.5, alpha: resultAlpha), at: NSPoint(x: 447, y: 40))

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

// Each scene: a short fade-in, then hold.
var frame = 0
for scene in scenes {
    for step in 0..<10 {
        try render(scene, progress: CGFloat(step) / 9).write(to: out.appendingPathComponent(String(format: "f%03d.png", frame)))
        frame += 1
    }
    for _ in 0..<22 {
        try render(scene, progress: 1).write(to: out.appendingPathComponent(String(format: "f%03d.png", frame)))
        frame += 1
    }
}
print("Wrote \(frame) frames to \(out.path)")
