// Draws the app icon into App/Resources/Assets.xcassets/AppIcon.appiconset. Run with `just app-icon`.
// A 3×3 cube face on a dark background; the top-right sticker is the timer's "ready" green.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func color(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: a)
}

/// Draws the 3×3 face (one green "ready" sticker) centered in `rect`.
func drawFace(_ ctx: CGContext, in rect: CGRect) {
    let gapRatio: CGFloat = 30.0 / 180.0
    let sticker = rect.width / (3 + 2 * gapRatio)
    let gap = sticker * gapRatio
    for row in 0..<3 {
        for col in 0..<3 {
            let x = rect.minX + CGFloat(col) * (sticker + gap)
            let y = rect.maxY - CGFloat(row + 1) * sticker - CGFloat(row) * gap  // row 0 at the top
            let r = CGRect(x: x, y: y, width: sticker, height: sticker)
            let isGreen = row == 0 && col == 2
            ctx.setFillColor(isGreen ? color(0x30D158) : color(0xF2F2F7, 0.92))
            ctx.addPath(CGPath(roundedRect: r, cornerWidth: sticker * 0.2, cornerHeight: sticker * 0.2, transform: nil))
            ctx.fillPath()
        }
    }
}

func render(size: Int, mac: Bool) -> CGImage {
    let s = CGFloat(size)
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    let k = s / 1024
    let bgTop = color(0x2A2A2D), bgBottom = color(0x111113)
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB)!, colors: [bgTop, bgBottom] as CFArray, locations: [0, 1])!

    if mac {
        // Apple's macOS icon grid: 824×824 rounded rect centered on the 1024 canvas, with a soft shadow.
        let body = CGRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
        let shape = CGPath(roundedRect: body, cornerWidth: 185.4 * k, cornerHeight: 185.4 * k, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 20 * k, color: color(0x000000, 0.3))
        ctx.addPath(shape); ctx.setFillColor(bgBottom); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(shape); ctx.clip()
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
        ctx.restoreGState()
        let face = 480 * k
        drawFace(ctx, in: CGRect(x: (s - face) / 2, y: (s - face) / 2, width: face, height: face))
    } else {
        // iOS: full-bleed square; the system applies the rounded mask.
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
        let face = 600 * k
        drawFace(ctx, in: CGRect(x: (s - face) / 2, y: (s - face) / 2, width: face, height: face))
    }
    return ctx.makeImage()!
}

func write(_ image: CGImage, to path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let out = CommandLine.arguments[1]
write(render(size: 1024, mac: false), to: "\(out)/icon-ios-1024.png")
for size in [16, 32, 64, 128, 256, 512, 1024] {
    write(render(size: size, mac: true), to: "\(out)/icon-mac-\(size).png")
}
