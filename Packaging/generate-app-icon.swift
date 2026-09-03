#!/usr/bin/env swift

import AppKit
import Foundation

private let canvas: CGFloat = 1_024
private let outputDirectory = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "Packaging/OrgRec.iconset", isDirectory: true)

private func color(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(
        calibratedRed: CGFloat((hex >> 16) & 0xff) / 255,
        green: CGFloat((hex >> 8) & 0xff) / 255,
        blue: CGFloat(hex & 0xff) / 255,
        alpha: alpha
    )
}

private func drawIcon(in context: NSGraphicsContext, pixels: Int) {
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    let scale = CGFloat(pixels) / canvas
    context.cgContext.scaleBy(x: scale, y: scale)

    let outer = NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 218, yRadius: 218)
    NSGradient(starting: color(0xFFFDF7), ending: color(0xE9E2D4))?.draw(in: outer, angle: -72)

    context.cgContext.saveGState()
    outer.addClip()
    color(0x252521, alpha: 0.035).setStroke()
    for index in 0..<20 {
        let y = CGFloat(94 + index * 44)
        let fibre = NSBezierPath()
        fibre.move(to: NSPoint(x: 72, y: y))
        fibre.curve(
            to: NSPoint(x: 956, y: y + CGFloat((index % 3) - 1) * 7),
            controlPoint1: NSPoint(x: 350, y: y + 8),
            controlPoint2: NSPoint(x: 680, y: y - 8)
        )
        fibre.lineWidth = 2
        fibre.stroke()
    }
    context.cgContext.restoreGState()

    let pipeColor = color(0x252521)
    let lipColor = color(0xF5F1E8)
    let pipeSpecs: [(x: CGFloat, width: CGFloat, height: CGFloat)] = [
        (220, 82, 410), (312, 82, 520), (404, 86, 615), (500, 94, 690),
        (604, 86, 615), (700, 82, 520), (792, 82, 410),
    ]
    for pipe in pipeSpecs {
        let body = NSBezierPath(
            roundedRect: NSRect(x: pipe.x, y: 245, width: pipe.width, height: pipe.height),
            xRadius: pipe.width * 0.48,
            yRadius: pipe.width * 0.48
        )
        pipeColor.setFill()
        body.fill()

        let mouthY: CGFloat = 382
        let mouth = NSBezierPath(roundedRect: NSRect(x: pipe.x + 16, y: mouthY, width: pipe.width - 32, height: 48), xRadius: 10, yRadius: 10)
        lipColor.setFill()
        mouth.fill()
        let lowerLip = NSBezierPath()
        lowerLip.move(to: NSPoint(x: pipe.x + 16, y: mouthY + 4))
        lowerLip.line(to: NSPoint(x: pipe.x + pipe.width / 2, y: mouthY + 25))
        lowerLip.line(to: NSPoint(x: pipe.x + pipe.width - 16, y: mouthY + 4))
        lowerLip.close()
        pipeColor.setFill()
        lowerLip.fill()
    }

    let wave = NSBezierPath()
    wave.move(to: NSPoint(x: 130, y: 255))
    wave.curve(to: NSPoint(x: 350, y: 255), controlPoint1: NSPoint(x: 220, y: 255), controlPoint2: NSPoint(x: 250, y: 330))
    wave.curve(to: NSPoint(x: 510, y: 255), controlPoint1: NSPoint(x: 430, y: 180), controlPoint2: NSPoint(x: 455, y: 170))
    wave.curve(to: NSPoint(x: 675, y: 255), controlPoint1: NSPoint(x: 565, y: 340), controlPoint2: NSPoint(x: 600, y: 340))
    wave.curve(to: NSPoint(x: 894, y: 255), controlPoint1: NSPoint(x: 758, y: 170), controlPoint2: NSPoint(x: 815, y: 255))
    wave.lineWidth = 24
    wave.lineCapStyle = .round
    color(0x365D68).setStroke()
    wave.stroke()

    let seal = NSBezierPath(ovalIn: NSRect(x: 735, y: 690, width: 150, height: 150))
    color(0xB94732).setFill()
    seal.fill()
    let sealRing = NSBezierPath(ovalIn: NSRect(x: 759, y: 714, width: 102, height: 102))
    sealRing.lineWidth = 10
    color(0xF5F1E8, alpha: 0.92).setStroke()
    sealRing.stroke()

    NSGraphicsContext.restoreGraphicsState()
}

private func render(pixels: Int, filename: String) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixels,
        pixelsHigh: pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [.alphaFirst],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw NSError(domain: "OrgRec.Icon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create a \(pixels)-pixel icon canvas."])
    }
    drawIcon(in: context, pixels: pixels)
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "OrgRec.Icon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not encode \(filename)."])
    }
    try png.write(to: outputDirectory.appendingPathComponent(filename), options: .atomic)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
for (pixels, filename) in [
    (16, "icon_16x16.png"), (32, "icon_16x16@2x.png"),
    (32, "icon_32x32.png"), (64, "icon_32x32@2x.png"),
    (128, "icon_128x128.png"), (256, "icon_128x128@2x.png"),
    (256, "icon_256x256.png"), (512, "icon_256x256@2x.png"),
    (512, "icon_512x512.png"), (1_024, "icon_512x512@2x.png"),
] {
    try render(pixels: pixels, filename: filename)
}
