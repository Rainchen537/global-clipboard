import AppKit
import Foundation

// 从源 PNG 生成 1024×1024 的 macOS app 图标主图。
// 默认会裁掉源图四周的纯白留边，并使用约 22% 的圆角半径，贴近 macOS 图标观感。

let outputSize = 1024
let cornerRadius = CGFloat(outputSize) * 0.21875
let contentInset = CGFloat(outputSize) * 0.105
let cropPaddingRatio = 0.075

let args = CommandLine.arguments
let sourceURL: URL
let outputURL: URL

if args.count >= 3 {
    sourceURL = URL(fileURLWithPath: args[1])
    outputURL = URL(fileURLWithPath: args[2])
} else if args.count == 2 {
    outputURL = URL(fileURLWithPath: args[1])
    sourceURL = outputURL.deletingLastPathComponent().appendingPathComponent("source_logo.png")
} else {
    sourceURL = URL(fileURLWithPath: "source_logo.png")
    outputURL = URL(fileURLWithPath: "icon_1024.png")
}

guard let sourceImage = NSImage(contentsOf: sourceURL),
      let sourceCGImage = sourceImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fatalError("Cannot load source logo: \(sourceURL.path)")
}

let sourceRep = NSBitmapImageRep(cgImage: sourceCGImage)
let width = sourceCGImage.width
let height = sourceCGImage.height

func isContentPixel(x: Int, y: Int) -> Bool {
    guard let color = sourceRep.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB),
          color.alphaComponent > 0.02 else {
        return false
    }

    let red = color.redComponent
    let green = color.greenComponent
    let blue = color.blueComponent
    let maxDistanceFromWhite = max(abs(1 - red), abs(1 - green), abs(1 - blue))
    let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue

    return maxDistanceFromWhite > 0.028 || luminance < 0.965
}

var minX = width
var minY = height
var maxX = 0
var maxY = 0

for y in 0..<height {
    for x in 0..<width where isContentPixel(x: x, y: y) {
        minX = min(minX, x)
        minY = min(minY, y)
        maxX = max(maxX, x)
        maxY = max(maxY, y)
    }
}

let detectedCrop: CGRect
if minX <= maxX, minY <= maxY {
    let detectedWidth = CGFloat(maxX - minX + 1)
    let detectedHeight = CGFloat(maxY - minY + 1)
    let paddedSide = max(detectedWidth, detectedHeight) * (1 + cropPaddingRatio * 2)
    let centerX = CGFloat(minX + maxX + 1) / 2
    let centerY = CGFloat(minY + maxY + 1) / 2

    let cropSide = min(paddedSide, CGFloat(width), CGFloat(height))
    let cropX = min(max(centerX - cropSide / 2, 0), CGFloat(width) - cropSide)
    let cropY = min(max(centerY - cropSide / 2, 0), CGFloat(height) - cropSide)
    detectedCrop = CGRect(x: cropX.rounded(.down), y: cropY.rounded(.down), width: cropSide.rounded(.down), height: cropSide.rounded(.down))
} else {
    let cropSide = min(width, height)
    detectedCrop = CGRect(x: (width - cropSide) / 2, y: (height - cropSide) / 2, width: cropSide, height: cropSide)
}

guard let croppedCGImage = sourceCGImage.cropping(to: detectedCrop) else {
    fatalError("Cannot crop source logo")
}

let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: outputSize,
    pixelsHigh: outputSize,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
bitmap.size = NSSize(width: outputSize, height: outputSize)

let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext
graphicsContext.imageInterpolation = .high

let canvas = CGRect(x: 0, y: 0, width: outputSize, height: outputSize)
let roundedPlate = NSBezierPath(roundedRect: canvas, xRadius: cornerRadius, yRadius: cornerRadius)

graphicsContext.cgContext.clear(canvas)
roundedPlate.addClip()

let plateGradient = NSGradient(colors: [
    NSColor(calibratedRed: 1.000, green: 1.000, blue: 1.000, alpha: 1),
    NSColor(calibratedRed: 0.982, green: 0.984, blue: 0.990, alpha: 1)
])!
plateGradient.draw(in: roundedPlate, angle: -90)

let croppedImage = NSImage(cgImage: croppedCGImage, size: NSSize(width: croppedCGImage.width, height: croppedCGImage.height))
let imageRect = canvas.insetBy(dx: contentInset, dy: contentInset)
croppedImage.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: false, hints: [
    .interpolation: NSImageInterpolation.high
])

NSGraphicsContext.restoreGraphicsState()

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphicsContext

let strokeRect = canvas.insetBy(dx: 2, dy: 2)
let strokePath = NSBezierPath(roundedRect: strokeRect, xRadius: cornerRadius - 2, yRadius: cornerRadius - 2)
NSColor(white: 0, alpha: 0.055).setStroke()
strokePath.lineWidth = 4
strokePath.stroke()

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("encode failed")
}

try png.write(to: outputURL)
print("wrote \(outputURL.path)")
