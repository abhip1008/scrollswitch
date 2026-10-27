import AppKit

/// Menu bar icon: a mouse when Natural scrolling is OFF, a hand when it is ON, with a small
/// pause badge while paused and a dot when something is wrong.
enum MenuBarIcon {
    private static var cache: [String: NSImage] = [:]

    static func image(natural: Bool, paused: Bool, warning: Bool) -> NSImage {
        let key = "\(natural)-\(paused)-\(warning)"
        if let cached = cache[key] { return cached }

        let symbol = natural ? "hand.point.up.left.fill" : "computermouse.fill"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            ?? NSImage(size: NSSize(width: 16, height: 16))

        let size = NSSize(width: 22, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let b = base.size
            base.draw(in: NSRect(x: (rect.width - b.width) / 2 - 1, y: (rect.height - b.height) / 2, width: b.width, height: b.height))

            if paused {
                let badge = NSRect(x: rect.maxX - 9, y: 0, width: 9, height: 9)
                cutOut(badge.insetBy(dx: -1.5, dy: -1.5))
                NSColor.black.setFill()
                NSBezierPath(roundedRect: NSRect(x: badge.minX + 1.5, y: badge.minY + 1, width: 2.2, height: 7), xRadius: 0.8, yRadius: 0.8).fill()
                NSBezierPath(roundedRect: NSRect(x: badge.minX + 5.3, y: badge.minY + 1, width: 2.2, height: 7), xRadius: 0.8, yRadius: 0.8).fill()
            }
            if warning {
                let dot = NSRect(x: rect.maxX - 7, y: rect.maxY - 7, width: 6, height: 6)
                cutOut(dot.insetBy(dx: -1.5, dy: -1.5))
                NSColor.black.setFill()
                NSBezierPath(ovalIn: dot).fill()
            }
            return true
        }
        image.isTemplate = true
        cache[key] = image
        return image
    }

    private static func cutOut(_ rect: NSRect) {
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        NSColor.black.setFill()
        NSBezierPath(ovalIn: rect).fill()
        NSGraphicsContext.current?.compositingOperation = .sourceOver
    }
}
