// Usage: swift assets/banner.swift <space-grotesk.woff2> <out.png> <theme: dark|light>
// The font is the one IsAcademy ships in assets/fonts/space-grotesk-latin.woff2.
// Renders the GitHub profile banner (1600x400, shown at 800x200) with CoreGraphics and CoreText, no downloads.
// Same brand tokens as IsAcademy: dark --gold #c8953f / --gold-2 #e2b25c, light --gold-text #7a5212, surface #fffdf9.
import Foundation
import CoreGraphics
import CoreText
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
let fontURL = URL(fileURLWithPath: a[1]) as CFURL, out = a[2], dark = a[3] == "dark"
let W: CGFloat = 1600, H: CGFloat = 400
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
func rgb(_ h: UInt32, _ al: CGFloat = 1) -> CGColor {
  CGColor(srgbRed: CGFloat((h >> 16) & 255) / 255, green: CGFloat((h >> 8) & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: al)
}
let bg = dark ? rgb(0x111318) : rgb(0xfffdf9)
let lift = dark ? rgb(0x1d2129) : rgb(0xf6efe2)
let gold1 = dark ? rgb(0xe2b25c) : rgb(0x8a5d16), gold2 = dark ? rgb(0xc8953f) : rgb(0x7a5212)
let ink = dark ? rgb(0xd7d9de) : rgb(0x2b2e35), muted = dark ? rgb(0x8b9099) : rgb(0x6b6f78)
let pixel = dark ? 0xc8953f as UInt32 : 0xb58534

// background with a soft lift on the left, where the text sits
ctx.setFillColor(bg); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
let glow = CGGradient(colorsSpace: cs, colors: [lift, bg] as CFArray, locations: [0, 1])!
ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 380, y: 220), startRadius: 0,
                       endCenter: CGPoint(x: 380, y: 220), endRadius: 760, options: [.drawsAfterEndLocation])

// right side: a trail of pixels dissolving, the "ink and pixels" motif of IsAcademy
var seed: UInt64 = 7
func rnd() -> CGFloat { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((seed >> 33) % 10000) / 10000 }
let cell: CGFloat = 22
for col in 0..<11 {
  for row in 0..<Int(H / cell) {
    let x = 1360 + CGFloat(col) * cell, y = CGFloat(row) * cell
    let t = 1 - CGFloat(col) / 10                   // 1 near the text, 0 at the edge: denser towards the edge
    let band: CGFloat = 1
    let p = (1 - t) * 0.85 * max(0, band)
    if rnd() < p {
      let al = (0.10 + 0.55 * (1 - t)) * (dark ? 1 : 0.85)
      ctx.setFillColor(rgb(pixel, al))
      ctx.fill(CGRect(x: x + 3, y: y + 3, width: cell - 6, height: cell - 6))
    }
  }
}

// text helpers (Space Grotesk variable font, weight axis)
let descs = CTFontManagerCreateFontDescriptorsFromURL(fontURL) as! [CTFontDescriptor]
func font(_ size: CGFloat, _ wght: CGFloat) -> CTFont {
  let d = CTFontDescriptorCreateCopyWithVariation(descs[0], NSNumber(value: 0x77676874), wght)
  return CTFontCreateWithFontDescriptor(d, size, nil)
}
func line(_ s: String, _ f: CTFont, _ color: CGColor, kern: CGFloat = 0) -> CTLine {
  let attr = NSAttributedString(string: s, attributes: [kCTFontAttributeName as NSAttributedString.Key: f,
    kCTForegroundColorAttributeName as NSAttributedString.Key: color, kCTKernAttributeName as NSAttributedString.Key: kern])
  return CTLineCreateWithAttributedString(attr)
}
let x0: CGFloat = 120

// name with the brand gold gradient
let nameLine = line("Ismael Sarmiento", font(112, 600), gold2, kern: -1.5)
let namePath = CGMutablePath()
for run in CTLineGetGlyphRuns(nameLine) as! [CTRun] {
  let n = CTRunGetGlyphCount(run)
  var g = [CGGlyph](repeating: 0, count: n), p = [CGPoint](repeating: .zero, count: n)
  CTRunGetGlyphs(run, CFRange(location: 0, length: n), &g); CTRunGetPositions(run, CFRange(location: 0, length: n), &p)
  let rf = (CTRunGetAttributes(run) as NSDictionary)[kCTFontAttributeName] as! CTFont
  for i in 0..<n { if let gp = CTFontCreatePathForGlyph(rf, g[i], nil) {
    namePath.addPath(gp, transform: CGAffineTransform(translationX: x0 + p[i].x, y: 205)) } }
}
ctx.saveGState(); ctx.addPath(namePath); ctx.clip()
let gold = CGGradient(colorsSpace: cs, colors: [gold1, gold2] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(gold, start: CGPoint(x: 0, y: 320), end: CGPoint(x: 0, y: 200), options: [])
ctx.restoreGState()

// role and stack
ctx.textPosition = CGPoint(x: x0 + 4, y: 140)
CTLineDraw(line("Lead Data Engineer · Gobierno del dato · Fundador de IsAcademy", font(38, 500), ink), ctx)
// thin gold rule
ctx.setFillColor(gold2); ctx.fill(CGRect(x: x0 + 4, y: 112, width: 56, height: 3))
ctx.textPosition = CGPoint(x: x0 + 4, y: 70)
CTLineDraw(line("Python  ·  SQL  ·  Spark  ·  Airflow  ·  Inteligencia Artificial", font(28, 400), muted, kern: 0.4), ctx)

let img = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, img, nil); CGImageDestinationFinalize(dest)
print("ok \(out)")
