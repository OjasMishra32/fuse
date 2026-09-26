import SwiftUI

// MARK: - FusingView
//
// While the model works. It should feel like the system thinking, not an app loading:
// a soft breathing orb, the intelligence glow along the bottom edge, a calm title, and the
// two inputs in a grouped card. Renders on the inner display (overlay) and on the cover.

struct FusingView: View {
    @Bindable var model: AppModel
    var compact: Bool = false

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 60)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Theme.ink.opacity(compact ? 1 : 0.96)

                edgeGlow(t: t)

                VStack(spacing: 0) {
                    Spacer()

                    orb(t: t)
                        .frame(width: 132, height: 132)
                        .padding(.bottom, 30)

                    Text(model.fusingStage)
                        .font(.system(.title2, design: .default, weight: .semibold))
                        .foregroundStyle(.primary)
                        .contentTransition(.opacity)
                        .id(model.fusingStage)
                        .transition(.blurReplace)
                        .padding(.bottom, 6)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 26)

                    inputsCard
                        .frame(maxWidth: 360)

                    if !model.instruction.isEmpty {
                        Text("“\(model.instruction)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                            .padding(.top, 14)
                    }

                    Spacer()

                    HStack(spacing: 14) {
                        Text(elapsed())
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(.tertiary)
                        Button("Cancel") { model.cancelFuse() }
                            .buttonStyle(.bordered)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                    }
                    .padding(.bottom, 34)
                }
                .padding(.horizontal, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(Theme.snappy, value: model.fusingStage)
            }
            .ignoresSafeArea()
        }
    }

    private var subtitle: String {
        "Fusing \(model.left.kind.title) and \(model.right.kind.title)"
    }

    private func elapsed() -> String {
        guard let start = model.fusingStartedAt else { return "" }
        return String(format: "%.1fs", max(0, Date().timeIntervalSince(start)))
    }

    // MARK: Palette (same as the fold)

    private func glow(angle: Double) -> AngularGradient {
        AngularGradient(
            colors: [Color(red: 0.25, green: 0.55, blue: 1.0), Color(red: 0.35, green: 0.85, blue: 0.95),
                     Color(red: 1.0, green: 0.55, blue: 0.75), Color(red: 1.0, green: 0.75, blue: 0.45),
                     Color(red: 0.25, green: 0.55, blue: 1.0)],
            center: .center,
            angle: .degrees(angle)
        )
    }

    // MARK: Orb

    private func orb(t: TimeInterval) -> some View {
        let breathe = 1 + 0.045 * sin(t * 1.6)
        return ZStack {
            Circle()
                .fill(glow(angle: t * 28))
                .blur(radius: 26)
                .opacity(0.55)
                .scaleEffect(1.35 * breathe)
            Circle()
                .fill(glow(angle: -t * 40))
                .blur(radius: 6)
                .opacity(0.95)
                .scaleEffect(0.86 * breathe)
            Circle()
                .fill(
                    RadialGradient(colors: [.white.opacity(0.85), .white.opacity(0.0)], center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 60)
                )
                .scaleEffect(0.86 * breathe)
                .blendMode(.plusLighter)
            Circle()
                .strokeBorder(.white.opacity(0.35), lineWidth: 1)
                .scaleEffect(0.86 * breathe)
        }
    }

    // MARK: Edge glow (bottom)

    private func edgeGlow(t: TimeInterval) -> some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .strokeBorder(glow(angle: t * 35), lineWidth: 26)
                .blur(radius: 30)
                .frame(height: 260)
                .opacity(0.5 + 0.15 * sin(t * 2))
                .padding(.horizontal, -40)
                .offset(y: 120)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    // MARK: Inputs

    private var inputsCard: some View {
        VStack(spacing: 0) {
            inputRow(model.left)
            Divider().padding(.leading, 52)
            inputRow(model.right)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func inputRow(_ pane: Pane) -> some View {
        let surface = pane.model
        return HStack(spacing: 12) {
            AppGlyph(kind: pane.kind, size: 28)
            VStack(alignment: .leading, spacing: 1) {
                Text(pane.kind.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(surface.hasContent ? surface.headline : "Empty")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
