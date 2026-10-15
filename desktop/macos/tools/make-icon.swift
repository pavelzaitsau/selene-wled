// Draws the Selene app icon as a 1024x1024 PNG: a dark screen with a crescent moon, and a
// blurred colour wheel behind the screen that stands for the backlight.
// Usage: swift tools/make-icon.swift out.png
import AppKit
import CoreImage

let size = 1024
let out = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let full = CGRect(x: 0, y: 0, width: size, height: size)
let center = CGPoint(x: 512, y: 512)

func context() -> CGContext {
    CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [r, g, b, a])!
}
func gradient(_ colors: [CGColor]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
}

// The macOS icon grid: an 824-pixel rounded square, 100 pixels in from each edge.
let tile = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824),
                  cornerWidth: 185, cornerHeight: 185, transform: nil)
let screen = CGRect(x: 512 - 280, y: 512 - 185, width: 560, height: 370)
let screenPath = CGPath(roundedRect: screen, cornerWidth: 28, cornerHeight: 28, transform: nil)

// The backlight: a colour wheel on a frame around the screen, blurred into a halo.
let glow = context()
glow.addPath(CGPath(roundedRect: screen.insetBy(dx: -45, dy: -45), cornerWidth: 60, cornerHeight: 60, transform: nil))
glow.addPath(CGPath(rect: screen.insetBy(dx: 30, dy: 30), transform: nil))
glow.clip(using: .evenOdd)
for step in 0..<360 {
    let start = CGFloat(step) * .pi / 180
    glow.setFillColor(NSColor(hue: CGFloat(step) / 360, saturation: 0.8, brightness: 1, alpha: 1).cgColor)
    glow.move(to: center)
    glow.addArc(center: center, radius: 700, startAngle: start, endAngle: start + .pi / 170, clockwise: false)
    glow.fillPath()
}
let blurred = CIImage(cgImage: glow.makeImage()!).clampedToExtent().applyingGaussianBlur(sigma: 34).cropped(to: full)
let glowImage = CIContext().createCGImage(blurred, from: full)!

let ctx = context()
ctx.addPath(tile)
ctx.clip()
ctx.drawLinearGradient(gradient([color(0.12, 0.13, 0.22), color(0.03, 0.03, 0.07)]),
                       start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
ctx.setBlendMode(.screen)
ctx.draw(glowImage, in: full)
ctx.setBlendMode(.normal)

ctx.saveGState()
ctx.addPath(screenPath)
ctx.clip()
ctx.drawLinearGradient(gradient([color(0.10, 0.11, 0.20), color(0.02, 0.02, 0.05)]),
                       start: CGPoint(x: 512, y: screen.maxY), end: CGPoint(x: 512, y: screen.minY), options: [])
ctx.restoreGState()

// The crescent: the moon disc minus a disc shifted up and to the right.
let moon = CGRect(x: 512 - 115, y: 512 - 115, width: 230, height: 230)
let crescent = context()
crescent.addRect(full)
crescent.addEllipse(in: moon.offsetBy(dx: 78, dy: 48))
crescent.clip(using: .evenOdd)
crescent.addEllipse(in: moon)
crescent.clip()
crescent.drawLinearGradient(gradient([color(1, 0.98, 0.90), color(0.92, 0.85, 0.68)]),
                            start: CGPoint(x: moon.minX, y: moon.maxY), end: CGPoint(x: moon.maxX, y: moon.minY), options: [])
ctx.setShadow(offset: .zero, blur: 30, color: color(1, 0.95, 0.8, 0.5))
ctx.draw(crescent.makeImage()!, in: full)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
