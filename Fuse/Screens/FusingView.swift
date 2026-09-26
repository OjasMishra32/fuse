import SwiftUI

// MARK: - FusingView
//
// Shown while the model is working: the merged orb breathing at the seam, the stage of the
// fuse, both inputs, elapsed time. Renders on the inner display (overlay) and on the cover.

struct FusingView: View {
    @Bindable var model: AppModel
    var compact: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.ink.opacity(compact ? 1 : 0.92).ignoresSafeArea()

                VStack(spacing: compact ? 22 : 26) {
                    orb(t: t)
                        .frame(width: compact ? 150 : 170, height: compact ? 150 : 170)

                    VStack(spacing: 8) {
                        Text(model.fusingStage)
                            .font(.system(size: compact ? 17 : 19, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)
                            .contentTransition(.opacity)
                            .id(model.fusingStage)
                            .transition(.blurReplace)
                        HStack(spacing: 8) {
                            inputChip(model.left)
                            Text("+")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(Theme.textTertiary)
                            inputChip(model.right)
                        }
                        if !model.instruction.isEmpty {
                            Text("“\(model.instruction)”")
                                .font(.fuseCaption)
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                    }
                    .animation(Theme.snappy, value: model.fusingStage)

                    HStack(spacing: 14) {
                        Text(elapsed(t: t))
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(Theme.textTertiary)
                        Button("Cancel") { model.cancelFuse() }
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textSecondary)
                            .buttonStyle(.plain)
                    }
                }
                .padding(24)
            }
        }
    }

    private func elapsed(t: TimeInterval) -> String {
        guard let start = model.fusingStartedAt else { return "" }
        let s = max(0, Date().timeIntervalSince(start))
        return String(format: "%.1fs", s)
    }

    private func orb(t: TimeInterval) -> some View {
        let breathe = 1 + 0.06 * sin(t * 2.2)
        return ZStack {
            Circle()
                .fill(Theme.energyAngular)
                .blur(radius: 34)
                .opacity(0.55)
                .scaleEffect(1.25 * breathe)
            Circle()
                .fill(Theme.energyAngular)
                .rotationEffect(.radians(t * 1.1))
                .mask(
                    Circle().strokeBorder(lineWidth: 18)
                )
                .blur(radius: 1)
            Circle()
                .fill(Theme.energyAngular)
                .rotationEffect(.radians(-t * 0.7))
                .mask(Circle().strokeBorder(lineWidth: 6).padding(24))
                .opacity(0.9)
            Circle()
                .fill(.clear)
                .glassEffect(.regular, in: .circle)
                .padding(36)
            FuseMark(progress: 1)
                .frame(width: 40, height: 40)
                .foregroundStyle(.white)
                .scaleEffect(breathe)
        }
    }

    private func inputChip(_ pane: Pane) -> some View {
        let surface = pane.model
        return HStack(spacing: 5) {
            Image(systemName: pane.kind.symbol)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(pane.kind.tint)
            Text(surface.hasContent ? surface.headline : pane.kind.title)
                .font(.fuseCaption)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(.white.opacity(0.06), in: Capsule())
        .frame(maxWidth: 150)
    }
}
