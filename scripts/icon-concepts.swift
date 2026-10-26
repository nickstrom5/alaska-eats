// Alaska Eats icon concepts for Nick's pick, in the shared Eats Ranked icon style (state-prompts/ICON-STYLE.md v1):
// one flat, level, centred food on a plain background; no scenery, tilt, texture, gloss or gradients.
// Usage (from ak-eats/): swift scripts/icon-concepts.swift   -> playbook/brand/concept-{a,b,c}-1024.png and -512, -180, -60 copies
//   A  wild salmon fillet: plan view (recognised from above by its white fat lines), coral with a darker skin edge, on flag navy
//   B  red king crab, plan view: long jointed legs, short claws, a lighter top plane on the shell, cream spines, on flag navy
//   C  reindeer dog: a split reindeer sausage in a bun with grilled onions, on flag navy (close to Chicago's and Michigan's dogs)
// Palette candidates (Nick's call): the flag, navy #0F204B and gold #FFB612; or glacier teal #2E7D8C with fireweed #B8336A.
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

// MARK: B, red king crab (plan view: a crab is recognised from above). CoreGraphics y-up. Three long jointed walking legs a side,
// bent down at the knee, two short claws forward (up) with cream tips, and a rounded carapace with a lighter top plane.
func kingCrab(_ c: CGContext, _ s: CGFloat) {
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    func E(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: (x - w / 2) * s, y: (y - h / 2) * s, width: w * s, height: h * s) }
    let red = rgb(0xD9452B), top = rgb(0xEC7552), cream = rgb(0xF7E4C8)
    c.setLineCap(.round); c.setLineJoin(.round)
    c.setStrokeColor(red); c.setLineWidth(0.046 * s)
    // walking legs: shoulder on the shell, knee out and up, foot out and down
    for side in [-1.0, 1.0] as [CGFloat] {
        for (k, (ky, fy)) in [(0.56, 0.40), (0.50, 0.33), (0.44, 0.27)].enumerated() {
            let kk = CGFloat(k)
            let leg = CGMutablePath()
            leg.move(to: P(0.5 + side * 0.10, 0.50 - 0.045 * kk))
            leg.addLine(to: P(0.5 + side * (0.245 + 0.014 * kk), ky))
            leg.addLine(to: P(0.5 + side * (0.336 - 0.004 * kk), fy))
            c.addPath(leg); c.strokePath()
        }
    }
    // claws: a short arm forward from the front of the shell, ending in a round pincer with a cream tip
    for side in [-1.0, 1.0] as [CGFloat] {
        let arm = CGMutablePath(); arm.move(to: P(0.5 + side * 0.07, 0.56)); arm.addLine(to: P(0.5 + side * 0.13, 0.665))
        c.setStrokeColor(red); c.setLineWidth(0.05 * s); c.addPath(arm); c.strokePath()
        let claw = CGPath(ellipseIn: E(0.5 + side * 0.15, 0.705, 0.115, 0.115), transform: nil)
        c.saveGState(); c.addPath(claw); c.clip()
        c.setFillColor(red); c.fill(CGRect(x: 0, y: 0, width: s, height: s))
        c.setFillColor(cream); c.fill(CGRect(x: 0, y: 0.725 * s, width: s, height: s))
        c.restoreGState()
    }
    // carapace: a little longer than wide, red with a lighter top plane
    let shell = CGPath(ellipseIn: E(0.5, 0.475, 0.27, 0.25), transform: nil)
    c.setFillColor(red); c.addPath(shell); c.fillPath()
    c.saveGState(); c.addPath(shell); c.clip(); c.setFillColor(top); c.fillEllipse(in: E(0.5, 0.505, 0.21, 0.17)); c.restoreGState()
}

// MARK: C, reindeer dog (side elevation): a soft bun, a split dark-red sausage with its cut showing lighter, golden grilled onions on top.
func reindeerDog(_ c: CGContext, _ s: CGFloat) {
    func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGRect { CGRect(x: x * s, y: y * s, width: w * s, height: h * s) }
    func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
    let bun = rgb(0xE9B86A), bunLow = rgb(0xC98E45), sausage = rgb(0x8E2F22), cut = rgb(0xB8473A), onion = rgb(0xF0C55A)
    // sausage behind the bun's front lip
    let dog = CGPath(roundedRect: R(0.135, 0.455, 0.73, 0.17), cornerWidth: 0.085 * s, cornerHeight: 0.085 * s, transform: nil)
    c.setFillColor(sausage); c.addPath(dog); c.fillPath()
    // the split along the top: a lighter band
    c.saveGState(); c.addPath(dog); c.clip(); c.setFillColor(cut); c.fill(R(0.0, 0.565, 1.0, 0.04)); c.restoreGState()
    // bun: rounded block, darker underside
    let b = CGPath(roundedRect: R(0.17, 0.32, 0.66, 0.205), cornerWidth: 0.075 * s, cornerHeight: 0.075 * s, transform: nil)
    c.saveGState(); c.addPath(b); c.clip()
    c.setFillColor(bun); c.fill(R(0, 0, 1, 1)); c.setFillColor(bunLow); c.fill(R(0, 0, 1, 0.37))
    c.restoreGState()
    // grilled onions: four short golden curls on the sausage (36 px round-cap strokes)
    c.setStrokeColor(onion); c.setLineWidth(0.036 * s); c.setLineCap(.round)
    for (x0, x1, y) in [(0.27, 0.36, 0.635), (0.40, 0.49, 0.650), (0.53, 0.62, 0.640), (0.65, 0.73, 0.630)] as [(CGFloat, CGFloat, CGFloat)] {
        let a = CGMutablePath(); a.move(to: P(x0, y - 0.01)); a.addQuadCurve(to: P(x1, y - 0.01), control: P((x0 + x1) / 2, y + 0.045))
        c.addPath(a); c.strokePath()
    }
}

// MARK: - main
let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent().path
let out = root + "/playbook/brand"
try? FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)
func canvas(_ n: Int) -> CGContext {
    let c = CGContext(data: nil, width: n, height: n, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.setAllowsAntialiasing(true); c.setShouldAntialias(true); c.interpolationQuality = .high
    return c
}
func save(_ img: CGImage, _ name: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out + "/" + name) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("could not write \(name)") }
}
for (key, bg, draw) in [("a", NAVY, salmon), ("b", NAVY, kingCrab), ("c", NAVY, reindeerDog)] as [(String, UInt32, (CGContext, CGFloat) -> Void)] {
    let c = canvas(1024)
    c.setFillColor(rgb(bg)); c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    draw(c, 1024)
    let full = c.makeImage()!
    save(full, "concept-\(key)-1024.png")
    for n in [512, 180, 60] {
        let sm = canvas(n); sm.draw(full, in: CGRect(x: 0, y: 0, width: n, height: n)); save(sm.makeImage()!, "concept-\(key)-\(n).png")
    }
    print("wrote concept-\(key)")
}
