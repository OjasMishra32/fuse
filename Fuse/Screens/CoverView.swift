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

    private var idleIntensity: Double {
        switch model.readiness {
        case 0: 0.35
        case 1: 0.7
        default: 1
        }
    }

    private var idle: some View {
        VStack(spacing: 0) {
            Spacer()
            OrbView(size: 44, animated: true, intensity: idleIntensity, speed: 0.5)
                .padding(.bottom, 18)
            Text(model.readiness == 0 ? "Nothing to fuse yet" : model.readiness == 1 ? "One screen is ready" : "Ready to fuse")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .padding(.bottom, 6)
            Text(model.readiness == 0
                 ? "Open the phone and put something on each screen."
                 : model.readiness == 1 ? "Open to add the other screen, or fuse this one alone."
                 : "Fold to combine \(model.left.kind.title) and \(model.right.kind.title).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            if model.readiness > 0 {
                VStack(spacing: 0) {
                    screenRow(model.left)
                    Divider().padding(.leading, 52)
                    screenRow(model.right)
                }
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                .frame(maxWidth: 360)
                .padding(.top, 24)
            }
            Spacer()
            if model.readiness > 0 {
                Button {
                    model.fuse(trigger: .seam)
                } label: {
                    Label("Fuse now", systemImage: "circle.hexagongrid.fill").fontWeight(.semibold)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .padding(.bottom, 34)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .animation(Theme.smooth, value: model.readiness)
    }

    private func screenRow(_ pane: Pane) -> some View {
        let surface = pane.model
        return HStack(spacing: 12) {
            AppGlyph(kind: pane.kind, size: 28)
                .opacity(surface.hasContent ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 1) {
                Text(pane.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(surface.hasContent ? surface.headline : "Empty")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(surface.hasContent ? .primary : .tertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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
        .padding(Theme.gutter)
        .frame(maxWidth: 420)
        .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .padding(Theme.gutter)
    }
}
