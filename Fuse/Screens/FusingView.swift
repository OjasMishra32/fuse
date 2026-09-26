import SwiftUI

// MARK: - FusingView
//
// Shown while the model is working: a quiet ring, the stage, both inputs, elapsed time.
// Renders on the inner display (overlay) and on the cover.

struct FusingView: View {
    @Bindable var model: AppModel
    var compact: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.ink.opacity(compact ? 1 : 0.94).ignoresSafeArea()

                VStack(spacing: compact ? 22 : 26) {
                    ring(t: t)
                        .frame(width: 96, height: 96)

                    VStack(spacing: 8) {
                        Text(model.fusingStage)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .contentTransition(.opacity)
                            .id(model.fusingStage)
                            .transition(.blurReplace)
                        HStack(spacing: 8) {
                            inputLabel(model.left)
                            Image(systemName: "plus")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                            inputLabel(model.right)
                        }
                        if !model.instruction.isEmpty {
                            Text("“\(model.instruction)”")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                        }
                    }
                    .animation(Theme.snappy, value: model.fusingStage)

                    HStack(spacing: 14) {
                        Text(elapsed())
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Button("Cancel") { model.cancelFuse() }
                            .font(.footnote)
                            .buttonStyle(.plain)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
        }
    }

    private func elapsed() -> String {
        guard let start = model.fusingStartedAt else { return "" }
        return String(format: "%.1fs", max(0, Date().timeIntervalSince(start)))
    }

    private func ring(t: TimeInterval) -> some View {
        ZStack {
            Circle()
                .stroke(Color(uiColor: .systemFill), lineWidth: 5)
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                .rotationEffect(.radians(t * 2.4))
            FuseMark(progress: 1)
                .frame(width: 30, height: 30)
                .foregroundStyle(.primary)
        }
    }

    private func inputLabel(_ pane: Pane) -> some View {
        let surface = pane.model
        return HStack(spacing: 5) {
            AppGlyph(kind: pane.kind, size: 16)
            Text(surface.hasContent ? surface.headline : pane.kind.title)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: 160)
    }
}
