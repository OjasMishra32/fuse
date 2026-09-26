import SwiftUI

// MARK: - CoverView
//
// What the outer display shows while the phone is closed. Closing is the command, so the
// cover is where the answer lands: progress while fusing, the result when it is ready.

struct CoverView: View {
    @Bindable var model: AppModel

    var body: some View {
        ZStack {
            Theme.background
            switch model.phase {
            case .fusing:
                FusingView(model: model, compact: true)
                    .transition(.opacity)
            case .result:
                if let result = model.currentResult {
                    ResultView(
                        result: result,
                        compact: true,
                        onFollowUp: { model.followUp($0) },
                        onDismiss: { model.dismissResult() },
                        onRefuse: { model.refuse() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            case .failed(let message):
                FailureCard(message: message, compact: true, onRetry: { model.refuse() }, onDismiss: { model.dismissResult() })
            case .compose:
                idle
            }
        }
        .animation(Theme.smooth, value: model.phase)
    }

    private var idle: some View {
        VStack(spacing: 16) {
            Spacer()
            FuseMark(progress: Double(model.readiness) / 2)
                .frame(width: 44, height: 44)
                .foregroundStyle(.primary)
            Text(model.readiness == 0
                 ? "Open the phone. Put something on each screen. Close it."
                 : model.readiness == 1 ? "One screen is ready. Open to add the other, or fuse it alone."
                 : "Both screens are ready. Fold to fuse.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)
            HStack(spacing: 10) {
                screenDot(model.left)
                screenDot(model.right)
            }
            Spacer()
            if model.readiness > 0 {
                EnergyButton(title: "Fuse now", symbol: "circle.hexagongrid.fill") {
                    model.fuse(trigger: .seam)
                }
                .padding(.bottom, 30)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }

    private func screenDot(_ pane: Pane) -> some View {
        let surface = pane.model
        return HStack(spacing: 6) {
            AppGlyph(kind: pane.kind, size: 16)
                .opacity(surface.hasContent ? 1 : 0.4)
            Text(surface.hasContent ? surface.headline : "Empty")
                .font(.footnote)
                .foregroundStyle(surface.hasContent ? .primary : .tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemFill), in: Capsule())
        .frame(maxWidth: 150)
    }
}

// MARK: - Failure

struct FailureCard: View {
    var message: String
    var compact: Bool = false
    var onRetry: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
            Text("That fuse didn't take")
                .font(.fuseHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text(message)
                .font(.fuseCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .frame(maxWidth: 320)
            HStack(spacing: 10) {
                GlassButton(title: "Back", symbol: "arrow.uturn.backward", action: onDismiss)
                EnergyButton(title: "Try again", symbol: "arrow.clockwise", action: onRetry)
            }
        }
        .padding(24)
        .frame(maxWidth: 420)
        .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .padding(20)
    }
}
