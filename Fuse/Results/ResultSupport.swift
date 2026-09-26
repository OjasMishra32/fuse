import SwiftUI
import UIKit

// MARK: - Shared helpers for result rendering
//
// Small, reusable pieces that every artifact view leans on: a wrapping layout for pills,
// inline-markdown text, bordered in-card buttons, a labelled section, a hairline, and the
// staggered reveal animation used by the result screen. Everything is system-coloured and
// scales with Dynamic Type.

extension EnvironmentValues {
    /// True when rendering on the narrow cover display. Artifact views read this to tighten layout.
    @Entry var fuseCompact: Bool = false
}

/// Semantic colors used only inside results (quiz / grade / diff / checklist). Always applied as
/// low-opacity fills or symbol tints, never as text colour.
enum ResultPalette {
    static let good = Color(uiColor: .systemGreen)
    static let bad = Color(uiColor: .systemRed)
}

// MARK: Flow layout

/// Lays subviews out left-to-right and wraps onto new rows. Used for pills and action rows.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var rowSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth.isFinite ? maxWidth : nil, height: nil))
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            widest = max(widest, x - spacing)
        }
        return CGSize(width: maxWidth.isFinite ? maxWidth : widest, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxWidth = bounds.width
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(ProposedViewSize(width: maxWidth, height: nil))
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + rowSpacing
                rowHeight = 0
            }
            view.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y),
                       anchor: .topLeading,
                       proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: Inline markdown

enum InlineMarkdown {
    /// Parses inline markdown (bold / italic / links / code). Never throws — falls back to plain text.
    static func attributed(_ source: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            allowsExtendedAttributes: false,
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let parsed = try? AttributedString(markdown: source, options: options) {
            return parsed
        }
        return AttributedString(source)
    }
}

/// Multi-line text with inline markdown. Links pick up the accent colour.
struct InlineText: View {
    var text: String
    var font: Font = .body
    var color: Color = .primary

    var body: some View {
        Text(InlineMarkdown.attributed(text))
            .font(font)
            .foregroundStyle(color)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Sections

/// A section inside a result: an uppercase footnote label aligned with card content, then the content.
struct ResultSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Eyebrow(text: title)
                .padding(.leading, Theme.margin)
            content
        }
    }
}

/// Placeholder card for an artifact that came back empty.
struct EmptyArtifactCard: View {
    var text: String
    var body: some View {
        ResultCard {
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: In-card buttons

/// Small bordered capsule used inside cards (Open in Maps, Reset, Reveal…).
struct MiniButton: View {
    var title: String
    var symbol: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .lineLimit(1)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }
}

/// Copies `text` to the pasteboard and shows a brief "Copied" confirmation.
struct CopyButton: View {
    var text: String
    var title: String = "Copy"
    var size: ControlSize = .regular
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            Haptics.soft()
            withAnimation(Theme.snappy) { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(Theme.snappy) { copied = false }
            }
        } label: {
            Label(copied ? "Copied" : title, systemImage: copied ? "checkmark" : "doc.on.doc")
                .lineLimit(1)
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.capsule)
        .controlSize(size)
        .accessibilityLabel(copied ? "Copied" : title)
    }
}

/// A static confirmation pill ("Added to Calendar", "Saved to Photos"): green tint on a 12% fill.
struct StatusPill: View {
    var title: String
    var symbol: String
    var tint: Color = ResultPalette.good

    var body: some View {
        Label(title, systemImage: symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

/// An inline progress state ("Adding…", "Saving…") matching the height of a regular button.
struct WorkingLabel: View {
    var title: String
    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

/// A footnote error line: secondary text with a warning symbol, no red text.
struct ErrorFootnote: View {
    var message: String
    var body: some View {
        Label(message, systemImage: "exclamationmark.triangle")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A one-pixel separator in the system separator colour.
struct Hairline: View {
    @Environment(\.displayScale) private var scale
    var body: some View {
        Rectangle()
            .fill(Theme.line)
            .frame(height: 1 / max(scale, 1))
    }
}

// MARK: Reveal animation

private struct RevealModifier: ViewModifier {
    var shown: Bool
    var index: Int

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 18)
            .animation(Theme.smooth.delay(Double(index) * 0.09), value: shown)
    }
}

extension View {
    /// Fades and slides the view up when `shown` flips to true, staggered by `index`.
    func reveal(_ shown: Bool, index: Int) -> some View {
        modifier(RevealModifier(shown: shown, index: index))
    }
}

// MARK: Strings

extension String {
    /// "travel_plan" / "travelPlan" / "travel-plan" → "Travel plan".
    var fuseHumanized: String {
        var spaced = ""
        var previousWasLower = false
        for ch in self {
            if ch == "_" || ch == "-" {
                spaced.append(" ")
                previousWasLower = false
            } else if ch.isUppercase, previousWasLower {
                spaced.append(" ")
                spaced.append(ch)
                previousWasLower = false
            } else {
                spaced.append(ch)
                previousWasLower = ch.isLowercase
            }
        }
        let words = spaced.split(whereSeparator: { $0.isWhitespace }).map { $0.lowercased() }
        guard let first = words.first else { return "Fuse" }
        return ([first.prefix(1).uppercased() + first.dropFirst()] + words.dropFirst()).joined(separator: " ")
    }
}

extension FuseResult {
    /// "Browser and Maps", or the humanized recipe when no inputs were recorded.
    var inputsLine: String {
        if inputs.isEmpty { return recipe.fuseHumanized }
        return inputs.prefix(3).map(\.kind.title).joined(separator: " and ")
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
