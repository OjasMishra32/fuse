import SwiftUI

// MARK: - StageView
//
// The two halves of the Duo. Layout follows the physical fold (`reservedRegions(.division)`):
// left | seam | right when the fold is vertical (book / flat), top / seam / bottom when the
// device is in tabletop pose. Fold progress melts the panes toward the seam.

struct StageView: View {
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldGeometry.resolve(proxy)
            let size = proxy.size
            let p = model.foldProgress
            let ease = p * p * (3 - 2 * p) // smoothstep

            ZStack {
                panes(fold: fold, size: size, progress: ease)
                    .blur(radius: 18 * ease)
                    .opacity(1 - 0.92 * ease)
                    .allowsHitTesting(p < 0.05 && model.phase == .compose)

                MeltOverlay(model: model, fold: fold, size: size)
                    .allowsHitTesting(false)

                SeamView(model: model, fold: fold, size: size)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func panes(fold: FoldGeometry, size: CGSize, progress: Double) -> some View {
        let shift: CGFloat = 46 * progress
        let scale: CGFloat = 1 - 0.22 * progress
        if fold.isVertical {
            HStack(spacing: 0) {
                PaneView(pane: model.left, model: model)
                    .frame(width: max(fold.frame.minX, 0))
                    .scaleEffect(scale, anchor: .trailing)
                    .offset(x: shift)
                Color.clear.frame(width: max(fold.frame.width, 0))
                PaneView(pane: model.right, model: model)
                    .frame(width: max(size.width - fold.frame.maxX, 0))
                    .scaleEffect(scale, anchor: .leading)
                    .offset(x: -shift)
            }
        } else {
            VStack(spacing: 0) {
                PaneView(pane: model.left, model: model)
                    .frame(height: max(fold.frame.minY, 0))
                    .scaleEffect(scale, anchor: .bottom)
                    .offset(y: shift)
                Color.clear.frame(height: max(fold.frame.height, 0))
                PaneView(pane: model.right, model: model)
                    .frame(height: max(size.height - fold.frame.maxY, 0))
                    .scaleEffect(scale, anchor: .top)
                    .offset(y: -shift)
            }
        }
    }
}

// MARK: - PaneView

struct PaneView: View {
    let pane: Pane
    @Bindable var model: AppModel

    var body: some View {
        let surface = pane.model
        VStack(spacing: 0) {
            header(surface: surface)
            SurfaceRegistry.view(for: surface)
                .id(pane.kind)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusPane - 6, style: .continuous))
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
        }
        .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusPane, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusPane, style: .continuous)
                .stroke(surface.hasContent ? pane.kind.tint.opacity(0.35) : Theme.line, lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.top, 44)
        .padding(.bottom, 8)
        .animation(Theme.snappy, value: surface.hasContent)
    }

    private func header(surface: any SurfaceModel) -> some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SurfaceRegistry.dockOrder) { kind in
                    Button {
                        Haptics.selection()
                        withAnimation(Theme.snappy) { pane.kind = kind }
                    } label: {
                        Label(kind.title, systemImage: kind.symbol)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: pane.kind.symbol)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(pane.kind.tint)
                    Text(pane.kind.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Theme.textTertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.white.opacity(0.06), in: Capsule())
            }
            .menuStyle(.button)
            .buttonStyle(.plain)

            Text(surface.hasContent ? surface.headline : pane.side.title.lowercased() + " screen")
                .font(.fuseCaption)
                .foregroundStyle(surface.hasContent ? Theme.textSecondary : Theme.textTertiary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            if surface.hasContent {
                Button {
                    Haptics.tap()
                    withAnimation(Theme.snappy) { surface.reset() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 22, height: 22)
                        .background(.white.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
    }
}
