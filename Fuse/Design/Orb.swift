import SwiftUI

// MARK: - The orb
//
// The one expressive element in Fuse. A soft multi-hue disc that slowly rotates and breathes,
// with a highlight and a wide, faint outer glow. It appears only where the fuse itself is the
// subject: the seam core, the cover's idle mark, the Fusing screen, and as a small glyph on
// results. Everything else in the app stays quiet and system-coloured.

enum Orb {
    /// The palette every glow in the app shares (orb, melt, fusing edge glow).
    static func glow(angle: Double) -> AngularGradient {
        AngularGradient(
            colors: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.35, green: 0.85, blue: 0.95),
                     Color(red: 1.0, green: 0.55, blue: 0.75), Color(red: 1.0, green: 0.75, blue: 0.45),
                     Color(red: 0.25, green: 0.55, blue: 1.0)],
            center: .center,
            angle: .degrees(angle)
        )
    }
}

struct OrbView: View {
    /// Diameter of the disc's frame. The outer glow extends a little past it.
    var size: CGFloat = 132
    /// Live (breathing, rotating) or a single static frame for lists and headers.
    var animated: Bool = true
    /// 0...1. Dims the glow and desaturates the disc; 1 is the full Fusing-screen orb.
    var intensity: Double = 1
    /// Playback speed multiplier for the rotation and the breath.
    var speed: Double = 1

    var body: some View {
        if animated {
            TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                frame(t: timeline.date.timeIntervalSinceReferenceDate * speed)
            }
        } else {
            frame(t: 2.4, breathing: false)
        }
    }

    private func frame(t: TimeInterval, breathing: Bool = true) -> some View {
        let clamped = min(max(intensity, 0), 1)
        let breathe = breathing ? 1 + 0.045 * sin(t * 1.6) : 1
        let rim = max(0.75, size / 132)
        return ZStack {
            // Wide, faint halo.
            Circle()
                .fill(Orb.glow(angle: t * 28))
                .blur(radius: size * 0.2)
                .opacity(0.55 * clamped)
                .scaleEffect(1.35 * breathe)
            // The disc.
            Circle()
                .fill(Orb.glow(angle: -t * 40))
                .blur(radius: size * 0.045)
                .opacity(0.6 + 0.35 * clamped)
                .scaleEffect(0.86 * breathe)
            // Highlight, top left.
            Circle()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.85), .white.opacity(0.0)],
                                   center: UnitPoint(x: 0.35, y: 0.3),
                                   startRadius: 0, endRadius: size * 0.45)
                )
                .scaleEffect(0.86 * breathe)
                .blendMode(.plusLighter)
            // Rim.
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: rim)
                .scaleEffect(0.86 * breathe)
        }
        .frame(width: size, height: size)
        .saturation(0.45 + 0.55 * clamped)
        .animation(Theme.smooth, value: clamped)
        .accessibilityHidden(true)
    }
}

// MARK: - Small glyph for rows and headers

/// Static orb sized for a list row or a result header, with the layout footprint of an icon.
struct OrbGlyph: View {
    var size: CGFloat = 28
    var body: some View {
        OrbView(size: size, animated: false, intensity: 0.9)
            .frame(width: size, height: size)
    }
}
