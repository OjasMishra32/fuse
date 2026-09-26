import SwiftUI

// MARK: - StageView
//
// The two halves of the Duo, each running a full-bleed mini app. There is no app chrome:
// the left half *is* the browser, the right half *is* Maps. Layout follows the physical fold
// (`reservedRegions(.division)`): left | seam | right in book / flat pose, top / seam / bottom
// in tabletop pose. Fold progress melts the halves toward the seam.

struct StageView: View {
    @Bindable var model: AppModel
    @State private var breathe = false

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
            .onChange(of: model.foldPrompt) { _, armed in
                if armed {
                    withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { breathe = true }
                } else {
                    withAnimation(Theme.smooth) { breathe = false }
                }
            }
        }
    }

    /// Extra tilt while the app is inviting the fold.
    private var inviteTilt: Double { breathe ? 7 : 0 }
    private var inviteScale: CGFloat { breathe ? 0.985 : 1 }

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
                    .if(progress > 0.01) { $0.clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous)) }
                    .rotation3DEffect(.degrees(tilt + inviteTilt), axis: (x: 0, y: 1, z: 0), anchor: .trailing, perspective: 0.5)
                    .scaleEffect(scale * inviteScale, anchor: .trailing)
                    .offset(x: shift)
                Color.clear.frame(width: max(fold.frame.width, 0))
                HalfView(pane: model.right, model: model)
                    .frame(width: max(size.width - fold.frame.maxX, 0))
                    .if(progress > 0.01) { $0.clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous)) }
                    .rotation3DEffect(.degrees(-(tilt + inviteTilt)), axis: (x: 0, y: 1, z: 0), anchor: .leading, perspective: 0.5)
                    .scaleEffect(scale * inviteScale, anchor: .leading)
                    .offset(x: -shift)
            }
        } else {
            VStack(spacing: 0) {
                HalfView(pane: model.left, model: model)
                    .frame(height: max(fold.frame.minY, 0))
                    .if(progress > 0.01) { $0.clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous)) }
                    .rotation3DEffect(.degrees(tilt), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.5)
                    .scaleEffect(scale, anchor: .bottom)
                    .offset(y: shift)
                Color.clear.frame(height: max(fold.frame.height, 0))
                HalfView(pane: model.right, model: model)
                    .frame(height: max(size.height - fold.frame.maxY, 0))
                    .if(progress > 0.01) { $0.clipShape(RoundedRectangle(cornerRadius: 28 * progress, style: .continuous)) }
                    .rotation3DEffect(.degrees(-tilt), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                    .scaleEffect(scale, anchor: .top)
                    .offset(y: -shift)
            }
        }
    }
}

// MARK: - HalfView

/// One half of the phone. Either the home screen (a grid of apps) or one app, full bleed,
/// with an iOS-style home bar to go back. No Fuse chrome.
struct HalfView: View {
    let pane: Pane
    @Bindable var model: AppModel

    var body: some View {
        ZStack(alignment: .bottom) {
            if pane.isHome {
                HomeScreen(pane: pane, model: model)
                    .transition(.asymmetric(insertion: .opacity, removal: .scale(scale: 1.08).combined(with: .opacity)))
            } else {
                SurfaceRegistry.view(for: pane.model)
                    .id(pane.kind)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))

                homeBar
                    .padding(.bottom, 6)
            }
        }
        .background(Theme.ink.ignoresSafeArea())
        .animation(Theme.smooth, value: pane.isHome)
        .animation(Theme.smooth, value: pane.kind)
    }

    /// The home indicator. Tap or swipe up to return this half to the home screen.
    private var homeBar: some View {
        Capsule()
            .fill(.primary.opacity(0.35))
            .frame(width: 96, height: 5)
            .padding(.horizontal, 40)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.soft()
                pane.goHome()
            }
            .gesture(
                DragGesture(minimumDistance: 12)
                    .onEnded { value in
                        if value.translation.height < -20 {
                            Haptics.soft()
                            pane.goHome()
                        }
                    }
            )
            .accessibilityLabel("Home")
    }
}

// MARK: - Home screen (one half)

struct HomeScreen: View {
    let pane: Pane
    @Bindable var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @State private var popped = false

    /// Panes whose grid has already popped in this launch. The stagger plays once per half.
    private static var poppedPanes: Set<ObjectIdentifier> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8, alignment: .top), count: 4)
    private let glyph: CGFloat = 60

    private var utilities: [(title: String, symbol: String, tint: Color, action: () -> Void)] {
        [
            ("Scenarios", "wand.and.stars", Color(uiColor: .systemIndigo), { model.showScenarios = true }),
            ("History", "clock.arrow.circlepath", Color(uiColor: .systemOrange), { model.showHistory = true }),
            ("Community", "person.2", Color(uiColor: .systemGreen), { model.showCommunity = true }),
            ("Settings", "gearshape", Color(uiColor: .systemGray), { model.showSettings = true }),
        ]
    }

    var body: some View {
        ZStack {
            wallpaper
            ScrollView(showsIndicators: false) {
                VStack(spacing: 28) {
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(Array(SurfaceRegistry.dockOrder.enumerated()), id: \.element) { index, kind in
                            appButton(kind)
                                .popIn(popped, index: index)
                        }
                    }

                    sectionLabel("Fuse")

                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(Array(utilities.enumerated()), id: \.offset) { index, item in
                            systemButton(item.title, symbol: item.symbol, tint: item.tint, action: item.action)
                                .popIn(popped, index: SurfaceRegistry.dockOrder.count + index)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 44)
                .padding(.bottom, 32)
            }
        }
        .onAppear {
            let id = ObjectIdentifier(pane)
            if Self.poppedPanes.contains(id) {
                popped = true
            } else {
                Self.poppedPanes.insert(id)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { popped = true }
            }
        }
    }

    /// Very quiet wallpaper: the system background with a faint tint toward the top.
    private var wallpaper: some View {
        LinearGradient(
            colors: scheme == .dark
                ? [Color(red: 0.08, green: 0.10, blue: 0.14), Color(red: 0.03, green: 0.03, blue: 0.05)]
                : [Color(red: 0.92, green: 0.95, blue: 0.99), Color(red: 0.97, green: 0.97, blue: 0.98)],
            startPoint: .top, endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    /// Thin divider with a small centered label, separating the apps from Fuse's own utilities.
    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(.secondary.opacity(0.25)).frame(height: 0.5)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle().fill(.secondary.opacity(0.25)).frame(height: 0.5)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    private func appButton(_ kind: SurfaceKind) -> some View {
        let surface = pane.model(for: kind)
        return Button {
            Haptics.tap()
            pane.open(kind)
        } label: {
            VStack(spacing: 6) {
                AppGlyph(kind: kind, size: glyph)
                    .overlay(alignment: .topTrailing) {
                        if surface.hasContent {
                            Circle().fill(Color.accentColor).frame(width: 10, height: 10)
                                .overlay(Circle().stroke(.white, lineWidth: 2))
                                .offset(x: 3, y: -3)
                        }
                    }
                Text(kind.title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(kind.title)
    }

    private func systemButton(_ title: String, symbol: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: glyph * 0.22, style: .continuous)
                    .fill(tint.gradient)
                    .frame(width: glyph, height: glyph)
                    .overlay(Image(systemName: symbol).font(.system(size: glyph * 0.46, weight: .medium)).foregroundStyle(.white))
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Pop-in (home grid)

private struct PopInModifier: ViewModifier {
    var shown: Bool
    var index: Int

    func body(content: Content) -> some View {
        content
            .scaleEffect(shown ? 1 : 0.82)
            .opacity(shown ? 1 : 0)
            .animation(Theme.snappy.delay(Double(index) * 0.03), value: shown)
    }
}

private extension View {
    /// Scales and fades the view in when `shown` flips true, staggered by `index`.
    func popIn(_ shown: Bool, index: Int) -> some View {
        modifier(PopInModifier(shown: shown, index: index))
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

