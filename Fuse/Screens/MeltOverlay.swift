import SwiftUI

// MARK: - MeltOverlay
//
// The moment. As the phone closes:
//   1. a soft multi-hue glow traces the edges of both halves (the same language as the
//      system's intelligence glow), brightening as the fold deepens;
//   2. each screen collapses into a glass drop that travels to the hinge; the drops are drawn
//      through a blur + alpha-threshold filter so they behave like liquid and merge into one;
//   3. at the end a single pulse of light runs along the seam.
// Live previews of both screens ride inside the drops until they dissolve.

struct MeltOverlay: View {
    @Bindable var model: AppModel
    var fold: FoldGeometry
    var size: CGSize

    private var p: Double { model.foldProgress }

    var body: some View {
        let ease = p * p * (3 - 2 * p)
        if p > 0.01 {
            TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                ZStack {
                    edgeGlow(ease: ease, t: t)
                    liquid(ease: ease, t: t)
                    previews(ease: ease)
                    seamPulse(ease: ease, t: t)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: Palette (only ever used here)

    private func glow(angle: Double) -> AngularGradient {
        AngularGradient(
            colors: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.35, green: 0.85, blue: 0.95),
                     Color(red: 1.0, green: 0.55, blue: 0.75), Color(red: 1.0, green: 0.75, blue: 0.45),
                     Color(red: 0.25, green: 0.55, blue: 1.0)],
            center: .center,
            angle: .degrees(angle)
        )
    }

    // MARK: Edge glow

    private func edgeGlow(ease: Double, t: TimeInterval) -> some View {
        let strength = min(1, ease * 1.6)
        let shape = RoundedRectangle(cornerRadius: 44, style: .continuous)
        return ZStack {
            shape
                .strokeBorder(glow(angle: t * 40), lineWidth: 18 + 30 * ease)
                .blur(radius: 22 + 14 * ease)
                .opacity(0.85 * strength)
            shape
                .strokeBorder(glow(angle: t * 40 + 90), lineWidth: 2.5)
                .blur(radius: 0.6)
                .opacity(0.9 * strength)
        }
        .padding(-6)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Geometry

    private var seam: CGPoint { CGPoint(x: fold.frame.midX, y: fold.frame.midY) }

    private var leftCenter: CGPoint {
        fold.isVertical
            ? CGPoint(x: fold.frame.minX / 2, y: size.height / 2)
            : CGPoint(x: size.width / 2, y: fold.frame.minY / 2)
    }

    private var rightCenter: CGPoint {
        fold.isVertical
            ? CGPoint(x: fold.frame.maxX + (size.width - fold.frame.maxX) / 2, y: size.height / 2)
            : CGPoint(x: size.width / 2, y: fold.frame.maxY + (size.height - fold.frame.maxY) / 2)
    }

    private func blobCenter(from origin: CGPoint, ease: Double) -> CGPoint {
        let travel = min(1, ease * 1.15)
        return CGPoint(x: origin.x + (seam.x - origin.x) * travel, y: origin.y + (seam.y - origin.y) * travel)
    }

    private func blobRadius(ease: Double) -> CGFloat {
        let base = min(size.width, size.height) * 0.16
        return base * (1.0 + 0.3 * ease)
    }

    // MARK: Liquid

    private func liquid(ease: Double, t: TimeInterval) -> some View {
        let r = blobRadius(ease: ease)
        let a = blobCenter(from: leftCenter, ease: ease)
        let b = blobCenter(from: rightCenter, ease: ease)
        let mask = Canvas { context, _ in
            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
            context.addFilter(.blur(radius: r * 0.55))
            context.drawLayer { layer in
                layer.fill(Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r, width: 2 * r, height: 2 * r)), with: .color(.white))
                layer.fill(Path(ellipseIn: CGRect(x: b.x - r, y: b.y - r, width: 2 * r, height: 2 * r)), with: .color(.white))
                if ease > 0.7 {
                    let br = r * 0.55 * (ease - 0.7) / 0.3
                    layer.fill(Path(ellipseIn: CGRect(x: seam.x - br, y: seam.y - br, width: 2 * br, height: 2 * br)), with: .color(.white))
                }
            }
        }
        return ZStack {
            // Glass body
            Color(uiColor: .systemGray5)
                .mask(mask)
            // A whisper of the glow inside the glass, stronger as the drops merge.
            glow(angle: -t * 30)
                .opacity(0.22 + 0.33 * ease)
                .mask(mask)
            // Highlight along the top edge.
            LinearGradient(colors: [.white.opacity(0.6), .clear], startPoint: .top, endPoint: .center)
                .mask(mask)
                .opacity(0.8)
        }
        .compositingGroup()
        .shadow(color: .black.opacity(0.16), radius: 20, y: 10)
        .ignoresSafeArea()
    }

    // MARK: Previews inside the drops

    private func previews(ease: Double) -> some View {
        let r = blobRadius(ease: ease) * 0.84
        let fade = max(0, 1 - ease * 1.6)
        return ZStack {
            preview(model.left, r: r, at: blobCenter(from: leftCenter, ease: ease), fade: fade)
            preview(model.right, r: r, at: blobCenter(from: rightCenter, ease: ease), fade: fade)
        }
    }

    @ViewBuilder
    private func preview(_ pane: Pane, r: CGFloat, at point: CGPoint, fade: Double) -> some View {
        let surface = pane.model
        Group {
            if let thumb = surface.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    AppGlyph(kind: pane.kind, size: r * 0.9)
                }
            }
        }
        .frame(width: 2 * r, height: 2 * r)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 1))
        .opacity(fade)
        .position(point)
    }

    // MARK: Seam pulse

    @ViewBuilder
    private func seamPulse(ease: Double, t: TimeInterval) -> some View {
        if ease > 0.85 {
            let k = (ease - 0.85) / 0.15
            let length = (fold.isVertical ? size.height : size.width) * (0.2 + 0.8 * k)
            Group {
                if fold.isVertical {
                    Capsule().fill(.white).frame(width: 3, height: length)
                        .overlay(Capsule().fill(glow(angle: t * 60)).frame(width: 14, height: length).blur(radius: 12))
                } else {
                    Capsule().fill(.white).frame(width: length, height: 3)
                        .overlay(Capsule().fill(glow(angle: t * 60)).frame(width: length, height: 14).blur(radius: 12))
                }
            }
            .opacity(0.9 * k)
            .position(seam)
            .allowsHitTesting(false)
        }
    }
}
