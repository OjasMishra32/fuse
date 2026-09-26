import SwiftUI

// MARK: - FusingView
//
// While the model works. It should feel like the system thinking, not an app loading:
// the orb breathing, the intelligence glow along the bottom edge, a calm title, and the
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

                    OrbView(size: 132, animated: true, intensity: 1)
                        .padding(.bottom, 30)

                    Text(headline)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .frame(maxWidth: 360)
                        .padding(.bottom, 6)

                    Text(model.fusingStage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                        .id(model.fusingStage)
                        .transition(.blurReplace)
                        .padding(.bottom, 24)

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
                            .buttonStyle(.glass)
                            .buttonBorderShape(.capsule)
                            .controlSize(.small)
                    }
                    .padding(.bottom, 34)
                }
                .padding(.horizontal, Theme.gutter)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(Theme.snappy, value: model.fusingStage)
            }
            .ignoresSafeArea()
        }
    }

    /// Says what is being made, in the user's words when they gave any. Falls back to the
    /// kinds, never to raw page titles, which truncate badly.
    private var headline: String {
        let spoken = model.instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        if !spoken.isEmpty { return Self.progressive(spoken) }
        if let s = model.defaultSuggestion { return Self.progressive(s.title) }
        if model.left.kind == .web && model.right.kind == .web { return "Fusing two pages" }
        return "Fusing \(model.left.kind.title) and \(model.right.kind.title)"
    }

    /// "Merge images" → "Merging images". Falls back to the text itself.
    static func progressive(_ text: String) -> String {
        var words = text.split(separator: " ").map(String.init)
        guard let first = words.first?.lowercased() else { return text }
        let map: [String: String] = [
            "merge": "Merging", "compare": "Comparing", "plan": "Planning", "make": "Making", "write": "Writing",
            "find": "Finding", "add": "Adding", "create": "Creating", "draft": "Drafting", "grade": "Grading",
            "build": "Building", "summarize": "Summarizing", "put": "Putting", "fix": "Fixing", "reply": "Replying",
            "repaint": "Repainting", "recap": "Recapping", "order": "Ordering", "explain": "Explaining", "turn": "Turning",
            "combine": "Combining", "generate": "Generating", "prepare": "Preparing", "check": "Checking", "list": "Listing",
            "rewrite": "Rewriting", "translate": "Translating", "schedule": "Scheduling", "book": "Booking", "split": "Splitting",
            "save": "Saving", "review": "Reviewing", "match": "Matching", "route": "Routing", "quiz": "Quizzing", "shorten": "Shortening"
        ]
        if let ing = map[first] {
            words[0] = ing
        } else {
            words[0] = first.prefix(1).uppercased() + first.dropFirst()
        }
        var out = words.joined(separator: " ")
        if out.hasSuffix(".") { out.removeLast() }
        return out.count > 64 ? String(out.prefix(61)) + "…" : out
    }

    private func elapsed() -> String {
        guard let start = model.fusingStartedAt else { return "" }
        return String(format: "%.1fs", max(0, Date().timeIntervalSince(start)))
    }

    // MARK: Edge glow (bottom)

    private func edgeGlow(t: TimeInterval) -> some View {
        VStack {
            Spacer()
            RoundedRectangle(cornerRadius: 60, style: .continuous)
                .strokeBorder(Orb.glow(angle: t * 35), lineWidth: 26)
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
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
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
