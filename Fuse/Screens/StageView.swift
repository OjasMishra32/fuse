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
/// with an iOS-style home indicator to go back. The indicator is a bottom safe-area inset,
/// so each surface's own chrome clears it while its content may run underneath.
///
/// Opening an app moves like an iOS app launch: the surface scales in from 0.92 while the
/// home screen zooms past to 1.08. Going home is the reverse: the surface drifts out to 1.04
/// and the home screen settles back in from 1.08.
struct HalfView: View {
    let pane: Pane
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            if pane.isHome {
                HomeScreen(pane: pane, model: model)
                    .transition(.scale(scale: 1.08).combined(with: .opacity))
            } else {
                SurfaceRegistry.view(for: pane.model)
                    .id(pane.kind)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .safeAreaInset(edge: .bottom, spacing: 0) { homeIndicator }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.92).combined(with: .opacity),
                        removal: .scale(scale: 1.04).combined(with: .opacity)))
            }
        }
        .background(Theme.ink.ignoresSafeArea())
        .animation(Theme.smooth, value: pane.isHome)
        .animation(Theme.smooth, value: pane.kind)
    }

    /// The home indicator. Tap or swipe up to return this half to the home screen.
    private var homeIndicator: some View {
        Capsule()
            .fill(.primary.opacity(0.3))
            .frame(width: 96, height: 5)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
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
            .accessibilityElement()
            .accessibilityLabel("Home")
            .accessibilityHint("Returns this screen to the app grid")
            .accessibilityAddTraits(.isButton)
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
                VStack(spacing: 24) {
                    // Only the left half carries the Demos row so the two home screens don't
                    // repeat it; the right half is the grid alone.
                    if pane.side == .left {
                        demosRow
                            .popIn(popped, index: 0)
                    }

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(Array(SurfaceRegistry.dockOrder.enumerated()), id: \.element) { index, kind in
                            appButton(kind)
                                .popIn(popped, index: index)
                        }
                    }

                    sectionLabel("Fuse")

                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(Array(utilities.enumerated()), id: \.offset) { index, item in
                            systemButton(item.title, symbol: item.symbol, tint: item.tint, action: item.action)
                                .popIn(popped, index: SurfaceRegistry.dockOrder.count + index)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 24)
                .padding(.bottom, 24)
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

    /// Very quiet wallpaper: the system background with a faint accent wash.
    private var wallpaper: some View {
        ZStack {
            Theme.ink
            Color.accentColor.opacity(scheme == .dark ? 0.08 : 0.05)
        }
        .ignoresSafeArea()
    }

    /// Hairline with a small centered label, separating the apps from Fuse's own utilities.
    private func sectionLabel(_ text: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.line).frame(height: 0.5)
            Text(text)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Rectangle().fill(Theme.line).frame(height: 0.5)
        }
        .padding(.horizontal, 8)
        .accessibilityElement(children: .combine)
    }

    // MARK: Demos row (left half only)

    /// The six live-demo scenarios as a horizontally scrolling row of cards, so a presenter can
    /// seed both halves with one tap and never needs a Mac. "See all" opens the Scenarios sheet.
    private var demosRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Demos")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    Haptics.tap()
                    model.showScenarios = true
                } label: {
                    Text("See all")
                        .font(.footnote)
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens all scenarios")
            }
            .padding(.horizontal, 4)

            // The row bleeds to the edges of the half while its first card lines up with the grid.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(DemoScenario.live) { scenario in
                        DemoCard(scenario: scenario) { model.apply(scenario) }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Theme.margin)
            }
            .padding(.horizontal, -Theme.margin)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Demos")
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
                                .overlay(Circle().stroke(Theme.ink, lineWidth: 2))
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
        .accessibilityValue(surface.hasContent ? "Has content" : "")
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

// MARK: - Demo card (home screen row)

/// One live-demo scenario as a card: accent icon tile, title, subtitle. 140 wide; 96 tall
/// with a one-line title, and every card in the row grows together when a title wraps.
private struct DemoCard: View {
    let scenario: DemoScenario
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                IconTile(symbol: scenario.symbol, tint: .accentColor, size: 28)
                Spacer(minLength: 6)
                Text(scenario.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(scenario.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.top, 2)
            }
            .padding(12)
            .frame(width: 140, alignment: .topLeading)
            .frame(minHeight: 96, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.groupedCard, in: shape)
            .overlay(shape.strokeBorder(Theme.line, lineWidth: 0.5))
            .contentShape(shape)
        }
        .buttonStyle(DemoCardStyle())
        .accessibilityLabel(scenario.title)
        .accessibilityHint(scenario.subtitle)
    }
}

/// Press-down scale to 0.96 with a light tap, like pressing a home-screen widget.
private struct DemoCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Theme.snappy, value: configuration.isPressed)
            .sensoryFeedback(.impact(weight: .light), trigger: configuration.isPressed) { _, pressed in pressed }
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
            .accessibilityHidden(true)
    }
}
