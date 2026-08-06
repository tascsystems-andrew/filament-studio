// Filament Studio — app-icon generator.
//
// Draws the icon at multiple sizes using Core Graphics and emits a full macOS
// .iconset folder ready for `iconutil -c icns`. Design: dark rounded-rect
// background, stylised triode envelope centred, warm orange filament glow at
// the bottom, cyan accent on the plate curves — matches the app's own look.
//
//     swiftc GenerateIcon.swift -o ./build/generate-icon
//     ./build/generate-icon ./build/AppIcon.iconset
//     iconutil -c icns ./build/AppIcon.iconset -o ./build/AppIcon.icns

import AppKit
import CoreGraphics

// ---- Colours matching Filament Studio's CSS palette ------------------------
let bgColor      = CGColor(red: 0.055, green: 0.067, blue: 0.086, alpha: 1.0)  // --bg  #0e1116
let panelColor   = CGColor(red: 0.098, green: 0.114, blue: 0.145, alpha: 1.0)  // --panel
let wireColor    = CGColor(red: 0.604, green: 0.702, blue: 0.784, alpha: 1.0)  // wire
let accentCyan   = CGColor(red: 0.239, green: 0.839, blue: 1.000, alpha: 1.0)  // --accent2 #3dd6ff
let accentOrange = CGColor(red: 1.000, green: 0.549, blue: 0.259, alpha: 1.0)  // --accent  #ff8c42
let orangeGlow   = CGColor(red: 1.000, green: 0.549, blue: 0.259, alpha: 0.60)

// ---- Draw the whole icon at any size, using proportional geometry ----------
func drawIcon(size: CGFloat) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let ctx = CGContext(data: nil,
                        width: Int(size), height: Int(size),
                        bitsPerComponent: 8, bytesPerRow: 0,
                        space: colorSpace,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)

    // Apple squircle rounded rect: corner radius ≈ 22.37% of icon size (macOS Big Sur+ mask).
    let cornerR = size * 0.2237
    let bgRect = CGRect(x: 0, y: 0, width: size, height: size)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: cornerR, cornerHeight: cornerR, transform: nil)
    ctx.addPath(bgPath)
    ctx.setFillColor(bgColor)
    ctx.fillPath()

    // Clip everything below to the squircle so the glow doesn't spill.
    ctx.addPath(bgPath)
    ctx.clip()

    // ---- Triode envelope (vertical capsule, centred) -----------------------
    // Envelope occupies ~62% of icon height, ~46% of width.
    let envW = size * 0.46
    let envH = size * 0.62
    let envX = (size - envW) / 2
    let envY = (size - envH) / 2 + size * 0.02          // nudge down for optical centre
    let envRect = CGRect(x: envX, y: envY, width: envW, height: envH)
    let envPath = CGPath(roundedRect: envRect, cornerWidth: envW/2, cornerHeight: envW/2, transform: nil)

    // Warm bottom glow — radial gradient from the base of the envelope.
    let gradColors = [orangeGlow, CGColor(red: 1.0, green: 0.549, blue: 0.259, alpha: 0.0)] as CFArray
    let gradient = CGGradient(colorsSpace: colorSpace,
                              colors: gradColors,
                              locations: [0.0, 1.0])!
    ctx.saveGState()
    ctx.addPath(envPath); ctx.clip()
    let glowCentre = CGPoint(x: size/2, y: envY + envW/2 + size*0.02)
    ctx.drawRadialGradient(gradient,
                           startCenter: glowCentre, startRadius: 0,
                           endCenter: glowCentre,   endRadius: envH * 0.65,
                           options: [])
    ctx.restoreGState()

    // Envelope stroke.
    ctx.addPath(envPath)
    ctx.setStrokeColor(wireColor)
    ctx.setLineWidth(size * 0.018)
    ctx.strokePath()

    // ---- Internal elements (plate / grid / cathode) ------------------------
    let elLeft  = envX + envW * 0.20
    let elRight = envX + envW * 0.80
    // Elements distributed in the upper 65% of the envelope.
    let plateY   = envY + envH * 0.72
    let gridY    = envY + envH * 0.55
    let cathY    = envY + envH * 0.38

    // Plate — thick cyan bar with a subtle glow underneath.
    ctx.setStrokeColor(accentCyan)
    ctx.setLineWidth(size * 0.030)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: elLeft, y: plateY))
    ctx.addLine(to: CGPoint(x: elRight, y: plateY))
    ctx.strokePath()

    // Grid — dashed line, wire colour.
    ctx.setStrokeColor(wireColor)
    ctx.setLineWidth(size * 0.012)
    let dashLen: CGFloat = size * 0.030
    ctx.setLineDash(phase: 0, lengths: [dashLen, dashLen])
    ctx.move(to: CGPoint(x: elLeft, y: gridY))
    ctx.addLine(to: CGPoint(x: elRight, y: gridY))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    // Cathode — warm orange filament (thick, glowing).
    ctx.setStrokeColor(accentOrange)
    ctx.setLineWidth(size * 0.038)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: elLeft, y: cathY))
    ctx.addLine(to: CGPoint(x: elRight, y: cathY))
    ctx.strokePath()

    // ---- Base pins (three small circles under the envelope) ----------------
    let pinR = size * 0.020
    let pinY = envY - size * 0.030
    let pinSpacing = envW * 0.32
    for dx in [-pinSpacing, 0, pinSpacing] {
        let px = size/2 + dx
        ctx.setFillColor(wireColor)
        ctx.fillEllipse(in: CGRect(x: px - pinR, y: pinY - pinR, width: pinR*2, height: pinR*2))
    }

    return ctx.makeImage()!
}

// ---- Save a CGImage as PNG at the given path ------------------------------
func writePNG(_ image: CGImage, to path: String) throws {
    let url = URL(fileURLWithPath: path)
    let dest = CGImageDestinationCreateWithURL(url as CFURL,
                                                "public.png" as CFString,
                                                1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    if !CGImageDestinationFinalize(dest) {
        throw NSError(domain: "GenerateIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to write \(path)"])
    }
}

// ---- Emit the full iconset ------------------------------------------------
guard CommandLine.arguments.count >= 2 else {
    print("usage: generate-icon <output-iconset-dir>")
    exit(1)
}
let outDir = CommandLine.arguments[1]
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

// Apple's macOS iconset spec: (base size, retina bool) → filename
let entries: [(size: CGFloat, scale: Int, filename: String)] = [
    (16,  1, "icon_16x16.png"),
    (16,  2, "icon_16x16@2x.png"),
    (32,  1, "icon_32x32.png"),
    (32,  2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]

for entry in entries {
    let pixelSize = entry.size * CGFloat(entry.scale)
    let image = drawIcon(size: pixelSize)
    let outPath = (outDir as NSString).appendingPathComponent(entry.filename)
    try writePNG(image, to: outPath)
    print("→ \(entry.filename) (\(Int(pixelSize))×\(Int(pixelSize)))")
}
print("→ done: \(outDir)")
