import SwiftUI
import UIKit

// MARK: - Shared helpers for result rendering
//
// Small, reusable pieces that every artifact view leans on: a wrapping layout for chips,
// inline-markdown text, a progress bar, a copy button with feedback, and the staggered
// reveal animation used by the result screen.

extension EnvironmentValues {
    /// True when rendering on the narrow cover display. Artifact views read this to tighten layout.
    @Entry var fuseCompact: Bool = false
}

/// Semantic colors used only inside results (quiz / grade / diff). Everything else stays neutral.
enum ResultPalette {
    static let good = Theme.mint
    static let bad = Color(red: 1.0, green: 0.42, blue: 0.42)
    static let warn = Color(red: 1.0, green: 0.80, blue: 0.36)
}

// MARK: Flow layout

/// Lays subviews out left-to-right and wraps onto new rows. Used for chips and action rows.
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

/// Body text with inline markdown, styled for results.
struct InlineText: View {
    var text: String
    var font: Font = .fuseBody
    var color: Color = Theme.textPrimary

    var body: some View {
        Text(InlineMarkdown.attributed(text))
            .font(font)
            .foregroundStyle(color)
            .tint(Theme.cyan)
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: Progress bar

struct ProgressBar: View {
    var fraction: Double
    var tint: Color = Theme.violet
    var height: CGFloat = 5

    private var clamped: CGFloat {
        guard fraction.isFinite else { return 0 }
        return CGFloat(min(max(fraction, 0), 1))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.08))
                Capsule().fill(tint)
                    .frame(width: max(geo.size.width * clamped, clamped > 0 ? height : 0))
            }
        }
        .frame(height: height)
        .animation(Theme.snappy, value: clamped)
    }
}

// MARK: Small controls

/// Tiny inline text button used inside cards (Copy, Open in Maps…).
struct MiniButton: View {
    var title: String
    var symbol: String
    var tint: Color = Theme.textSecondary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 11, weight: .semibold))
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(.white.opacity(0.06)))
            .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

/// Copies `text` to the pasteboard and shows a brief "Copied" confirmation.
struct CopyMiniButton: View {
    var text: String
    var title: String = "Copy"
    @State private var copied = false

    var body: some View {
        MiniButton(title: copied ? "Copied" : title,
                   symbol: copied ? "checkmark" : "doc.on.doc",
                   tint: copied ? Theme.mint : Theme.textSecondary) {
            UIPasteboard.general.string = text
            Haptics.soft()
            withAnimation(Theme.snappy) { copied = true }
            Task {
                try? await Task.sleep(for: .seconds(1.4))
                withAnimation(Theme.snappy) { copied = false }
            }
        }
        .animation(Theme.snappy, value: copied)
    }
}

/// A static pill used for confirmations ("Added", "Saved") and errors.
struct StatusPill: View {
    var title: String
    var symbol: String
    var tint: Color = Theme.mint

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: symbol).font(.system(size: 13, weight: .bold))
            Text(title).font(.system(size: 14, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(Capsule().fill(tint.opacity(0.14)))
        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
    }
}

/// A 1pt hairline in the theme's line color.
struct Hairline: View {
    var body: some View {
        Rectangle().fill(Theme.line).frame(height: 1)
    }
}

// MARK: Reveal animation

private struct RevealModifier: ViewModifier {
    var shown: Bool
    var index: Int

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : 16)
            .animation(Theme.smooth.delay(Double(index) * 0.06), value: shown)
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

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
