import SwiftUI
import UIKit
import CoreText

/// Alaska's flag (Nick's pick, 2026-10-26), light only: navy #0F204B (15.8:1 on white) for titles, tint and accents; gold #FFB612
/// only as a fill under navy text (9.0:1; gold text on white is 1.8:1 and fails AA); a lighter navy #2A4A8C (8.5:1) for links;
/// a deep salmon #B5472C (5.4:1, a shade under the icon's skin edge) for hand-checked picks on the map and the title's shadow. No seal, no college marks
/// (UAA green/gold, UAF blue/gold). The names `green`/`gold`/`red` are kept from Wisconsin Eats so the shared views read the same:
/// here `green` is the flag navy, `gold` the flag gold and `red` the salmon.
enum Theme {
    static let green = Color(hex: 0x0F204B)      // flag navy: titles, tint, primary text accents
    static let green2 = Color(hex: 0x2A4A8C)     // lighter navy: links
    static let gold = Color(hex: 0xFFB612)       // flag gold: fills under navy text only
    static let goldSoft = Color(hex: 0xFFEBB8)
    static let lime = Color(hex: 0x2A4A8C)       // the header band's second tone, fills only
    static let limeSoft = Color(hex: 0xE1E6F1)
    static let sand = Color(hex: 0xF5F6F9)
    static let red = Color(hex: 0xB5472C)        // deep salmon: hand-checked pins, the title shadow
    static let ink = Color(hex: 0x0B1530)
    static let ink2 = Color(hex: 0x22304F)
    static let muted = Color(hex: 0x535E76)
    static let surface = Color.white
    static let surface2 = Color(hex: 0xF3F5FA)
    static let surface3 = Color(hex: 0xE1E6F1)
    static let rule = Color(hex: 0xDBE0EB)
    static let rule2 = Color(hex: 0xB3BDD2)
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

/// A small uppercase label: "HALIBUT, SALMON & CRAB", "AMERICA'S CLASSIC".
struct Chip: View {
    enum Style { case gold, green, red, plain, dashed }
    let text: String
    var style: Style = .plain

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .tracking(0.4)
            .padding(.horizontal, 7).padding(.vertical, 3)
            .foregroundStyle(style == .green || style == .red ? Color.white : style == .dashed ? Theme.muted : style == .gold ? Theme.ink : Theme.green)
            .background {
                RoundedRectangle(cornerRadius: 5).fill(style == .gold ? Theme.goldSoft : style == .green ? Theme.green : style == .red ? Theme.red
                                                       : style == .dashed ? .clear : Theme.surface2)
            }
            .overlay {
                if style == .dashed { RoundedRectangle(cornerRadius: 5).strokeBorder(Theme.rule2, style: StrokeStyle(lineWidth: 1, dash: [3, 2])) }
            }
            .accessibilityLabel(text)
    }
}

/// Alaska Eats' lettering: the system face drawn compressed and heavy for titles and guide names (like a roadhouse sign), and the
/// system monospaced face for numbers, dates and small labels. No bundled fonts.
struct DisplayFont: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .black
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.6), weight: weight).width(.compressed))
    }
}

/// Numbers, dates and small labels in the system monospaced face, scaled like DisplayFont.
struct MonoFont: ViewModifier {
    let size: CGFloat
    var weight: Font.Weight = .semibold
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    func body(content: Content) -> some View {
        content.font(.system(size: size * min(scale, 1.6), weight: weight, design: .monospaced))
    }
}

extension View {
    func displayFont(_ size: CGFloat, weight: Font.Weight = .black) -> some View {
        modifier(DisplayFont(size: size, weight: weight))
    }

    func monoFont(_ size: CGFloat, weight: Font.Weight = .semibold) -> some View {
        modifier(MonoFont(size: size, weight: weight))
    }
}

/// The flag's Big Dipper and North Star under the Home title (2026-10-26, the leaderboard's header element): a navy band with the
/// dipper's seven gold stars at the left and Polaris, larger, at the right. Flat five-point stars; no seal, no map.
struct Stripes: View {
    var height: CGFloat = 6

    var body: some View {
        ZStack {
            Rectangle().fill(Theme.green)
            Stars().fill(Theme.gold)
        }
        .frame(height: height * 4)
        .accessibilityHidden(true)
    }

    /// the eight stars, placed as on the flag's field (x and y as fractions of the band, the dipper kept in the left third)
    private struct Stars: Shape {
        static let dipper: [(CGFloat, CGFloat)] = [(0.10, 0.70), (0.14, 0.60), (0.18, 0.64), (0.22, 0.50), (0.235, 0.75), (0.285, 0.80), (0.295, 0.38)]

        func path(in r: CGRect) -> Path {
            var p = Path()
            let small = r.height * 0.16
            for (x, y) in Self.dipper { star(&p, CGPoint(x: r.minX + x * r.width, y: r.minY + y * r.height), small) }
            star(&p, CGPoint(x: r.minX + 0.86 * r.width, y: r.minY + 0.42 * r.height), r.height * 0.30)
            return p
        }

        private func star(_ p: inout Path, _ c: CGPoint, _ radius: CGFloat) {
            for k in 0..<10 {
                let a = -CGFloat.pi / 2 + CGFloat(k) * .pi / 5
                let rr = k % 2 == 0 ? radius : radius * 0.42
                let pt = CGPoint(x: c.x + rr * cos(a), y: c.y + rr * sin(a))
                k == 0 ? p.move(to: pt) : p.addLine(to: pt)
            }
            p.closeSubpath()
        }
    }
}

extension View {
    /// An inline navigation title in the display type. UINavigationBar.appearance() didn't reach every SwiftUI bar on iOS 27
    /// (the Map title went from compressed blue to plain black after a push and pop; place titles were always plain), so the
    /// title is our own view in the bar. The navigation title is still set, for the back button and VoiceOver.
    func inlineTitle(_ title: String) -> some View {
        navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title).displayFont(19, weight: .heavy).foregroundStyle(Theme.green)
                        .lineLimit(1).minimumScaleFactor(0.7)
                        .accessibilityAddTraits(.isHeader)
                }
            }
    }
}
