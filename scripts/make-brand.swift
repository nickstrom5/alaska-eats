// Alaska Eats brand: the app icon (Nick's pick 2026-10-26, concept A of scripts/icon-concepts.swift: a wild salmon fillet on flag
// navy), in the shared Eats Ranked style (../state-prompts/ICON-STYLE.md). Usage, from ak-eats/: swift scripts/make-brand.swift
// -> AlaskaEats/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png, the website's icons (docs/icon-512.png, icon-192.png,
// apple-touch-icon.png, favicon-32.png) and share image (docs/og.png).
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: 1)
}
let NAVY: UInt32 = 0x0F204B, GOLD: UInt32 = 0xFFB612

// MARK: A, salmon fillet (plan view). CoreGraphics y-up, units of the canvas. Thick shoulder at the left, tapering to the tail at the
// right; a darker band of skin along the lower edge; five white fat lines curving across the flesh (Wisconsin's holes idea, as marks).
func salmon(_ c: CGContext, _ s: CGFloat) {
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    let flesh = rgb(0xF2845C), skin = rgb(0xC9583A), fat = rgb(0xFBE3D3)
    let body = CGMutablePath()
    body.move(to: P(0.155, 0.47))
    body.addCurve(to: P(0.30, 0.655), control1: P(0.150, 0.585), control2: P(0.205, 0.650))
    body.addCurve(to: P(0.845, 0.525), control1: P(0.50, 0.665), control2: P(0.72, 0.600))
    body.addCurve(to: P(0.845, 0.405), control1: P(0.870, 0.505), control2: P(0.870, 0.425))
    body.addCurve(to: P(0.30, 0.300), control1: P(0.72, 0.335), control2: P(0.50, 0.290))
    body.addCurve(to: P(0.155, 0.47), control1: P(0.205, 0.305), control2: P(0.160, 0.370))
    body.closeSubpath()
    c.saveGState(); c.addPath(body); c.clip()
    c.setFillColor(flesh); c.fill(CGRect(x: 0, y: 0, width: s, height: s))
    // skin: the lower 26% of the fillet, a hard edge following the belly line
    let belly = CGMutablePath()
    belly.move(to: P(0.0, 0.0)); belly.addLine(to: P(0.0, 0.395))
    belly.addCurve(to: P(1.0, 0.43), control1: P(0.35, 0.335), control2: P(0.70, 0.355))
    belly.addLine(to: P(1.0, 0.0)); belly.closeSubpath()
    c.setFillColor(skin); c.addPath(belly); c.fillPath()
    c.restoreGState()
    // fat lines: five gentle arcs across the flesh, 36 px round-cap strokes, shorter toward the tail
    c.setStrokeColor(fat); c.setLineWidth(0.036 * s); c.setLineCap(.round)
    for (x, top, bot) in [(0.29, 0.600, 0.420), (0.40, 0.612, 0.405), (0.51, 0.598, 0.400), (0.62, 0.572, 0.402), (0.72, 0.540, 0.410)] as [(CGFloat, CGFloat, CGFloat)] {
        let a = CGMutablePath()
        a.move(to: P(x - 0.03, top)); a.addQuadCurve(to: P(x - 0.03, bot), control: P(x + 0.045, (top + bot) / 2))
        c.addPath(a); c.strokePath()
    }
}

func save(_ ctx: CGContext, _ path: String) {
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, ctx.makeImage()!, nil)
    guard CGImageDestinationFinalize(d) else { fatalError("could not write \(path)") }
    print("wrote", path)
}

func canvas(_ w: Int, _ h: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setShouldAntialias(true)
    return ctx
}

func render(_ n: Int, _ path: String) {
    let ctx = canvas(n, n)
    ctx.setFillColor(rgb(NAVY)); ctx.fill(CGRect(x: 0, y: 0, width: n, height: n))
    salmon(ctx, CGFloat(n))
    save(ctx, path)
}
render(1024, "AlaskaEats/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
try? FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
for (n, name) in [(512, "icon-512.png"), (192, "icon-192.png"), (180, "apple-touch-icon.png"), (32, "favicon-32.png")] {
    render(n, "docs/" + name)
}

/// A flat five-point star centred at c (the flag's Big Dipper and North Star).
func star(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat) {
    for k in 0..<10 {
        let a = CGFloat.pi / 2 + CGFloat(k) * .pi / 5
        let rr = k % 2 == 0 ? r : r * 0.42
        let p = CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
        k == 0 ? ctx.move(to: p) : ctx.addLine(to: p)
    }
    ctx.closePath(); ctx.fillPath()
}

/// The share image (1200 x 630): flag navy, the salmon fillet on its own tile at the left, the name and tagline at the right, and the
/// flag's Big Dipper and North Star in gold along the top right.
func og(_ path: String) {
    let W = 1200, H = 630
    let ctx = canvas(W, H)
    ctx.setFillColor(rgb(NAVY)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
    ctx.setFillColor(rgb(0x1B3266))
    ctx.addPath(CGPath(roundedRect: CGRect(x: 60, y: 95, width: 440, height: 440), cornerWidth: 96, cornerHeight: 96, transform: nil)); ctx.fillPath()
    ctx.saveGState(); ctx.translateBy(x: 60, y: 95); salmon(ctx, 440); ctx.restoreGState()
    ctx.setFillColor(rgb(GOLD))
    for (x, y) in [(600, 470), (640, 485), (678, 478), (716, 500), (730, 470), (785, 462), (800, 512)] as [(CGFloat, CGFloat)] { star(ctx, CGPoint(x: x, y: y), 11) }
    star(ctx, CGPoint(x: 1080, y: 540), 26)
    let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = ns
    let title = NSFont(name: "AvenirNextCondensed-Heavy", size: 108) ?? NSFont.boldSystemFont(ofSize: 96)
    let sub = NSFont(name: "AvenirNextCondensed-DemiBold", size: 42) ?? NSFont.boldSystemFont(ofSize: 40)
    NSAttributedString(string: "ALASKA EATS", attributes: [.font: title, .foregroundColor: NSColor.white]).draw(at: NSPoint(x: 548, y: 300))
    NSAttributedString(string: "HALIBUT, ROADHOUSES & REINDEER", attributes: [.font: sub, .foregroundColor: NSColor(cgColor: rgb(GOLD))!]).draw(at: NSPoint(x: 552, y: 240))
    NSGraphicsContext.restoreGraphicsState()
    save(ctx, path)
}
og("docs/og.png")
