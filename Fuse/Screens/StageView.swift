import SwiftUI

// MARK: - StageView
//
// The two halves of the Duo, each running a full-bleed mini app. There is no app chrome:
// the left half *is* the browser, the right half *is* Maps. Layout follows the physical fold
// (`reservedRegions(.division)`): left | seam | right in book / flat pose, top / seam / bottom
// in tabletop pose. Fold progress melts the halves toward the seam.

struct StageView: View {
    @Bindable var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let fold = FoldGeometry.resolve(proxy)
            let size = proxy.size
            let p = model.foldProgress
            let ease = p * p * (3 - 2 * p) // smoothstep

            ZStack {
                halves(fold: fold, size: size, progress: ease)
                    .blur(radius: 14 * ease)
                    .opacity(1 - 0.9 * ease)
                    .allowsHitTesting(p < 0.05 && model.phase == .compose)

                MeltOverlay(model: model, fold: fold, size: size)
                    .allowsHitTesting(false)

                SeamView(model: model, fold: fold, size: size)
            }
            .frame(width: size.width, height: size.height)
        }
    }

    @ViewBuilder
    private func halves(fold: FoldGeometry, size: CGSize, progress: Double) -> some View {
        // The halves tilt toward the hinge like the pages of a closing book, shrink a little,
        // and are drawn in slightly so the seam feels like it is pulling them in.
        let shift: CGFloat = 36 * progress
        let scale: CGFloat = 1 - 0.14 * progress
        let tilt = 22 * progress
        if fold.isVertical {
            HStack(spacing: 0) {
                HalfView(pane: model.left, model: model)
                    .frame(width: max(fold.frame.minX, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous))
                    .rotation3DEffect(.degrees(-tilt), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
                    .scaleEffect(scale, anchor: .trailing)
                    .offset(x: shift)
                Color.clear.frame(width: max(fold.frame.width, 0))
                HalfView(pane: model.right, model: model)
                    .frame(width: max(size.width - fold.frame.maxX, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous))
                    .rotation3DEffect(.degrees(tilt), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
                    .scaleEffect(scale, anchor: .leading)
                    .offset(x: -shift)
            }
        } else {
            VStack(spacing: 0) {
                HalfView(pane: model.left, model: model)
                    .frame(height: max(fold.frame.minY, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous))
                    .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
                    .scaleEffect(scale, anchor: .bottom)
                    .offset(y: shift)
                Color.clear.frame(height: max(fold.frame.height, 0))
                HalfView(pane: model.right, model: model)
                    .frame(height: max(size.height - fold.frame.maxY, 0))
                    .clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous))
                    .rotation3DEffect(.degrees(-tilt), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                    .scaleEffect(scale, anchor: .top)
                    .offset(y: -shift)
            }
        }
    }
}

// MARK: - HalfView

/// One half of the phone: the surface, full bleed, plus a small app pill at the bottom
/// (like an app's name in the switcher) that opens the picker.
struct HalfView: View {
    let pane: Pane
    @Bindable var model: AppModel
    @State private var showPicker = false

    var body: some View {
        let surface = pane.model
        ZStack(alignment: .bottom) {
            SurfaceRegistry.view(for: surface)
                .id(pane.kind)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            appPill(surface: surface)
                .padding(.bottom, 10)
        }
        .background(Theme.ink)
        .clipped()
        .sheet(isPresented: $showPicker) {
            SurfacePicker(pane: pane) { kind in
                Haptics.selection()
                withAnimation(Theme.snappy) { pane.kind = kind }
                showPicker = false
            }
        }
    }

    private func appPill(surface: any SurfaceModel) -> some View {
        HStack(spacing: 6) {
            Button {
                showPicker = true
            } label: {
                HStack(spacing: 6) {
                    AppGlyph(kind: pane.kind, size: 18)
                    Text(surface.hasContent ? surface.headline : pane.kind.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .frame(maxWidth: 150)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, 6)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.capsule)

            if surface.hasContent {
                Button {
                    Haptics.tap()
                    withAnimation(Theme.snappy) { surface.reset() }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .frame(width: 26, height: 26)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Clear this screen")
            }
        }
        .animation(Theme.snappy, value: surface.hasContent)
    }
}

// MARK: - App glyph (looks like a home-screen icon)

struct AppGlyph: View {
    var kind: SurfaceKind
    var size: CGFloat = 44

    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(kind.tint.gradient)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: kind.symbol)
                    .font(.system(size: size * 0.5, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

// MARK: - SurfacePicker (a small home screen for one half)

struct SurfacePicker: View {
    let pane: Pane
    var onPick: (SurfaceKind) -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 16)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(SurfaceRegistry.dockOrder) { kind in
                        Button {
                            onPick(kind)
                        } label: {
                            VStack(spacing: 6) {
                                AppGlyph(kind: kind, size: 58)
                                Text(kind.title)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                        .overlay(alignment: .topTrailing) {
                            if kind == pane.kind {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.white, Color.accentColor)
                                    .offset(x: 6, y: -6)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .navigationTitle("\(pane.side.title) screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
            }
        }
        .presentationDetents([.height(300), .medium])
    }
}
