#!/usr/bin/env swift

import AppKit

// Generate app icon with exact pixel dimensions
func generateIcon(pixelSize: Int) -> NSImage {
    // Create bitmap with exact pixel dimensions
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Failed to create bitmap")
    }
    
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    
    let size = CGFloat(pixelSize)
    
    // Background gradient - blue-purple
    let gradient = NSGradient(colors: [
        NSColor(red: 0.4, green: 0.5, blue: 0.95, alpha: 1.0),
        NSColor(red: 0.6, green: 0.4, blue: 0.9, alpha: 1.0)
    ])!
    
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.2
    let roundedPath = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.05, dy: size * 0.05), xRadius: cornerRadius, yRadius: cornerRadius)
    gradient.draw(in: roundedPath, angle: -45)
    
    // Draw document icon
    let docWidth = size * 0.45
    let docHeight = size * 0.55
    let docX = size * 0.18
    let docY = size * 0.22
    
    let docRect = NSRect(x: docX, y: docY, width: docWidth, height: docHeight)
    let docPath = NSBezierPath(roundedRect: docRect, xRadius: 4, yRadius: 4)
    NSColor.white.withAlphaComponent(0.95).setFill()
    docPath.fill()
    
    // Horizontal lines on document (representing text)
    NSColor(white: 0.7, alpha: 1.0).setStroke()
    let lineY1 = docY + docHeight * 0.7
    let lineY2 = docY + docHeight * 0.5
    let lineY3 = docY + docHeight * 0.3
    let lineX1 = docX + docWidth * 0.15
    let lineX2 = docX + docWidth * 0.85
    
    for lineY in [lineY1, lineY2, lineY3] {
        let linePath = NSBezierPath()
        linePath.move(to: NSPoint(x: lineX1, y: lineY))
        linePath.line(to: NSPoint(x: lineX2, y: lineY))
        linePath.lineWidth = size * 0.02
        linePath.stroke()
    }
    
    // Magnifying glass
    let glassRadius = size * 0.18
    let glassCenterX = size * 0.65
    let glassCenterY = size * 0.45
    
    // Magnifying glass circle
    let glassPath = NSBezierPath(ovalIn: NSRect(
        x: glassCenterX - glassRadius,
        y: glassCenterY - glassRadius,
        width: glassRadius * 2,
        height: glassRadius * 2
    ))
    NSColor.white.withAlphaComponent(0.3).setFill()
    glassPath.fill()
    NSColor.white.setStroke()
    glassPath.lineWidth = size * 0.03
    glassPath.stroke()
    
    // Magnifying glass handle
    let handlePath = NSBezierPath()
    let handleStartX = glassCenterX + glassRadius * 0.7
    let handleStartY = glassCenterY - glassRadius * 0.7
    handlePath.move(to: NSPoint(x: handleStartX, y: handleStartY))
    handlePath.line(to: NSPoint(x: handleStartX + glassRadius * 0.5, y: handleStartY - glassRadius * 0.5))
    handlePath.lineWidth = size * 0.04
    handlePath.lineCapStyle = .round
    NSColor.white.setStroke()
    handlePath.stroke()
    
    NSGraphicsContext.restoreGraphicsState()
    
    let image = NSImage(size: NSSize(width: pixelSize, height: pixelSize))
    image.addRepresentation(bitmap)
    return image
}

func saveIcon(_ image: NSImage, to path: String) {
    guard let bitmap = image.representations.first as? NSBitmapImageRep,
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to create PNG for \(path)")
        return
    }
    
    do {
        try pngData.write(to: URL(fileURLWithPath: path))
        print("Created: \(path)")
    } catch {
        print("Failed to write \(path): \(error)")
    }
}

// Generate all sizes with exact pixel dimensions
let sizes: [(pixelSize: Int, suffix: String)] = [
    (16, "16x16"),
    (32, "16x16@2x"),
    (32, "32x32"),
    (64, "32x32@2x"),
    (128, "128x128"),
    (256, "128x128@2x"),
    (256, "256x256"),
    (512, "256x256@2x"),
    (512, "512x512"),
    (1024, "512x512@2x")
]

let outputDir = "Parallax/Resources/Assets.xcassets/AppIcon.appiconset"

for item in sizes {
    let image = generateIcon(pixelSize: item.pixelSize)
    let filename = "icon_\(item.suffix).png"
    saveIcon(image, to: "\(outputDir)/\(filename)")
}

print("\nDone!")

