import SwiftUI

// MARK: - MeltOverlay
//
// The moment. As fold progress rises, each screen collapses into a blob that travels to the
// hinge; the two blobs are drawn through a blur + alpha-threshold filter so they behave like
// liquid and merge into one. The energy gradient is masked by that liquid, live previews of
// both screens ride inside the blobs until they dissolve, and sparks orbit the merge point.

struct MeltOverlay: View {
    @Bindable var model: AppModel
    var fold: FoldGeometry
    var size: CGSize

    private var p: Double { model.foldProgress }

    var body: some View {
        let ease = p * p * (3 - 2 * p)
        if p > 0.01 {
            ZStack {
                liquid(ease: ease)
                previews(ease: ease)
                if p > 0.55 { sparks(ease: ease) }
            }
            .transition(.opacity)
        }
    }

    // MARK: Geometry

    private var seam: CGPoint { CGPoint(x: fold.frame.midX, y: fold.frame.midY) }

    private var leftCenter: CGPoint {
        fold.isVertical
            ? CGPoint(x: fold.frame.minX / 2, y: size.height / 2 + 18)
            : CGPoint(x: size.width / 2, y: fold.frame.minY / 2 + 18)
    }

    private var rightCenter: CGPoint {
        fold.isVertical
            ? CGPoint(x: fold.frame.maxX + (size.width - fold.frame.maxX) / 2, y: size.height / 2 + 18)
            : CGPoint(x: size.width / 2, y: fold.frame.maxY + (size.height - fold.frame.maxY) / 2 + 18)
    }

    private func blobCenter(from origin: CGPoint, ease: Double) -> CGPoint {
        // Travel most of the way early, arrive late — feels like being pulled in.
        let travel = min(1, ease * 1.15)
        return CGPoint(x: origin.x + (seam.x - origin.x) * travel, y: origin.y + (seam.y - origin.y) * travel)
    }

    private func blobRadius(ease: Double) -> CGFloat {
        let base = min(size.width, size.height) * 0.16
        return base * (1.0 + 0.35 * ease)
    }

    // MARK: Liquid

    private func liquid(ease: Double) -> some View {
        let r = blobRadius(ease: ease)
        let a = blobCenter(from: leftCenter, ease: ease)
        let b = blobCenter(from: rightCenter, ease: ease)
        let mask = Canvas { context, _ in
            context.addFilter(.alphaThreshold(min: 0.5, color: .white))
            context.addFilter(.blur(radius: r * 0.55))
            context.drawLayer { layer in
                layer.fill(Path(ellipseIn: CGRect(x: a.x - r, y: a.y - r, width: 2 * r, height: 2 * r)), with: .color(.white))
                layer.fill(Path(ellipseIn: CGRect(x: b.x - r, y: b.y - r, width: 2 * r, height: 2 * r)), with: .color(.white))
                // A small bridge that appears late helps the merge read as one body.
                if ease > 0.7 {
                    let br = r * 0.55 * (ease - 0.7) / 0.3
                    layer.fill(Path(ellipseIn: CGRect(x: seam.x - br, y: seam.y - br, width: 2 * br, height: 2 * br)), with: .color(.white))
                }
            }
        }
        return ZStack {
            Theme.energyAngular
                .mask(mask)
                .blur(radius: 26)
                .opacity(0.65)
            Theme.energy
                .mask(mask)
            Color.white
                .mask(mask)
                .opacity(0.10 + 0.25 * ease)
                .blendMode(.plusLighter)
        }
        .ignoresSafeArea()
    }

    // MARK: Previews inside the blobs

    private func previews(ease: Double) -> some View {
        let r = blobRadius(ease: ease) * 0.86
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
                    pane.kind.tint.opacity(0.25)
                    Image(systemName: pane.kind.symbol)
                        .font(.system(size: r * 0.7, weight: .medium))
                        .foregroundStyle(pane.kind.tint)
                }
            }
        }
        .frame(width: 2 * r, height: 2 * r)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
        .opacity(fade)
        .position(point)
    }

    // MARK: Sparks

    private func sparks(ease: Double) -> some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, _ in
                let count = 42
                let strength = (ease - 0.55) / 0.45
                for i in 0..<count {
                    let seed = Double(i) * 0.61803398875
                    let angle = (seed * 2 * .pi + t * (0.6 + seed.truncatingRemainder(dividingBy: 0.5)))
                    let orbit = blobRadius(ease: ease) * (1.1 + 0.9 * (seed.truncatingRemainder(dividingBy: 0.37) / 0.37)) * (1.2 - 0.4 * strength)
                    let x = seam.x + cos(angle) * orbit
                    let y = seam.y + sin(angle) * orbit * (fold.isVertical ? 1.0 : 0.6)
                    let s = 1.2 + 2.4 * (seed.truncatingRemainder(dividingBy: 0.23) / 0.23)
                    let alpha = 0.25 + 0.75 * abs(sin(t * 3 + seed * 10))
                    let color = i % 3 == 0 ? Theme.cyan : (i % 3 == 1 ? Theme.violet : Color.white)
                    context.fill(Path(ellipseIn: CGRect(x: x - s / 2, y: y - s / 2, width: s, height: s)),
                                 with: .color(color.opacity(alpha * strength)))
                }
            }
        }
        .blendMode(.plusLighter)
        .ignoresSafeArea()
    }
}
