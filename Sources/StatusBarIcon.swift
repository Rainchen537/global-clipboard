import AppKit

enum StatusBarIcon {
    static func makeImage() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)

        image.lockFocus()
        defer { image.unlockFocus() }

        NSColor.black.setStroke()

        func roundedRect(_ rect: NSRect, radius: CGFloat, width: CGFloat, alpha: CGFloat) {
            let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            path.lineWidth = width
            path.lineJoinStyle = .round
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }

        func line(from start: NSPoint, to end: NSPoint, width: CGFloat = 1.35, alpha: CGFloat = 1) {
            let path = NSBezierPath()
            path.move(to: start)
            path.line(to: end)
            path.lineWidth = width
            path.lineCapStyle = .round
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }

        roundedRect(NSRect(x: 3.0, y: 2.5, width: 11.5, height: 12.5), radius: 2.2, width: 1.35, alpha: 0.55)
        roundedRect(NSRect(x: 5.0, y: 4.0, width: 10.5, height: 12.0), radius: 2.0, width: 1.45, alpha: 1)

        let clipPath = NSBezierPath()
        clipPath.move(to: NSPoint(x: 8.2, y: 14.8))
        clipPath.curve(
            to: NSPoint(x: 12.3, y: 14.8),
            controlPoint1: NSPoint(x: 8.55, y: 16.7),
            controlPoint2: NSPoint(x: 11.95, y: 16.7)
        )
        clipPath.line(to: NSPoint(x: 13.4, y: 14.8))
        clipPath.lineWidth = 1.45
        clipPath.lineCapStyle = .round
        clipPath.lineJoinStyle = .round
        NSColor.black.setStroke()
        clipPath.stroke()

        line(from: NSPoint(x: 7.5, y: 10.9), to: NSPoint(x: 12.9, y: 10.9))
        line(from: NSPoint(x: 7.5, y: 8.2), to: NSPoint(x: 12.2, y: 8.2), alpha: 0.88)
        line(from: NSPoint(x: 7.5, y: 5.5), to: NSPoint(x: 10.7, y: 5.5), alpha: 0.78)

        image.isTemplate = true
        image.accessibilityDescription = "剪贴板历史"
        return image
    }
}
