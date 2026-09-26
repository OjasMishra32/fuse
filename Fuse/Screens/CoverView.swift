import SwiftUI

// MARK: - CoverView
//
// What the outer display shows while the phone is closed. Closing is the command, so the
// cover is where the answer lands: progress while fusing, the result when it is ready.
// The background fills the display; everything else stays inside the safe area, clear of
// the camera cutout and the display's rounded corners.

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

    private var idleTitle: String {
        switch model.readiness {
        case 0: "Nothing to fuse yet"
        case 1: "One screen is ready"
        default: "Ready to fuse"
        }
    }

    private var idleHint: String {
        switch model.readiness {
        case 0: "Open the phone and put something on each screen."
        case 1: "Open to add the other screen, or fuse this one alone."
        default: "Fold to combine \(model.left.kind.title) and \(model.right.kind.title)."
        }
    }

    private var idle: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            OrbView(size: 44, animated: true, intensity: idleIntensity, speed: 0.5)
                .padding(.bottom, 16)
            Text(idleTitle)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)
            Text(idleHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
            if model.readiness > 0 {
                VStack(spacing: 0) {
                    screenRow(model.left)
                    Divider().padding(.leading, 52)
                    screenRow(model.right)
                }
                .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
                .frame(maxWidth: 360)
                .padding(.top, 24)
            }
            Spacer(minLength: 0)
            if model.readiness > 0 {
                Button {
                    model.fuse(trigger: .seam)
                } label: {
                    Label("Fuse Now", systemImage: "circle.hexagongrid.fill").fontWeight(.semibold)
                }
                .buttonStyle(.glassProminent)
                .buttonBorderShape(.capsule)
                .padding(.bottom, 16)
            }
        }
        .padding(.horizontal, Theme.gutter)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(Theme.smooth, value: model.readiness)
    }

    private func screenRow(_ pane: Pane) -> some View {
        let surface = pane.model
        return HStack(spacing: 12) {
            AppGlyph(kind: pane.kind, size: 28)
                .opacity(surface.hasContent ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 2) {
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
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Failure

struct FailureCard: View {
    var message: String
    var compact: Bool = false
    var onRetry: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Text("That fuse didn't take")
                .font(.headline)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 320)
            HStack(spacing: 12) {
                GlassButton(title: "Back", symbol: "arrow.uturn.backward", action: onDismiss)
                EnergyButton(title: "Try Again", symbol: "arrow.clockwise", action: onRetry)
            }
            .padding(.top, 4)
        }
        .padding(Theme.gutter)
        .frame(maxWidth: 420)
        .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        .padding(Theme.gutter)
    }
}
