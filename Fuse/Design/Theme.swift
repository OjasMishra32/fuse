import SwiftUI
import UIKit

// MARK: - Fuse design language
//
// It should look like Apple shipped it. System colors, system materials, SF Pro, native
// iOS 26 glass button styles, and the device's own appearance (light or dark). One accent,
// no gradients in chrome. The one expressive element is the orb (Design/Orb.swift), and it
// appears only where the fuse itself is the subject.

enum Theme {
    // Surfaces (adapt to light/dark automatically)
    static let ink = Color(uiColor: .systemBackground)
    static let ink2 = Color(uiColor: .secondarySystemBackground)
    static let ink3 = Color(uiColor: .tertiarySystemBackground)
    static let grouped = Color(uiColor: .systemGroupedBackground)
    static let groupedCard = Color(uiColor: .secondarySystemGroupedBackground)
    static let line = Color(uiColor: .separator)

    // Text
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textTertiary = Color(uiColor: .tertiaryLabel)

    // Accent. Kept as named tokens because the rest of the app refers to them.
    static let accent = Color.accentColor
    static let violet = Color.accentColor
    static let cyan = Color(uiColor: .systemTeal)
    static let magenta = Color(uiColor: .systemPink)
    static let mint = Color(uiColor: .systemMint)

    /// Flat accent fills. Named "energy" for historical reasons; there is no gradient any more.
    static let energy = LinearGradient(colors: [Color.accentColor, Color.accentColor], startPoint: .leading, endPoint: .trailing)
    static let energyVertical = LinearGradient(colors: [Color.accentColor, Color.accentColor], startPoint: .top, endPoint: .bottom)
    static let energyAngular = AngularGradient(colors: [Color.accentColor.opacity(0.9), Color.accentColor.opacity(0.35), Color.accentColor.opacity(0.9)], center: .center)

    // Radii, iOS inset-grouped scale
    static let radiusPane: CGFloat = 0
    static let radiusCard: CGFloat = 14
    static let radiusChip: CGFloat = 10
    /// Small icon tile (Settings-style) radius.
    static let radiusTile: CGFloat = 7

    // Spacing. Screens use `gutter` for their side margins, rows use `margin`.
    static let gutter: CGFloat = 20
    static let margin: CGFloat = 16

    // Motion
    static let snappy = Animation.spring(response: 0.36, dampingFraction: 0.82)
    static let smooth = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let melt = Animation.interpolatingSpring(stiffness: 120, damping: 18)
    /// Slow idle breath for the seam's ready glow.
    static let breath = Animation.easeInOut(duration: 2.2).repeatForever(autoreverses: true)

    /// Plain system background.
    static var background: some View {
        Color(uiColor: .systemBackground).ignoresSafeArea()
    }
}

// MARK: - Typography (system text styles)

extension Font {
    static func fuse(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static let fuseWordmark = Font.subheadline.weight(.semibold)
    static let fuseTitle = Font.title.weight(.bold)
    static let fuseHeadline = Font.headline
    static let fuseBody = Font.body
    static let fuseCaption = Font.footnote.weight(.medium)
    static let fuseMono = Font.system(.footnote, design: .monospaced)
}

// MARK: - Reusable chrome (thin wrappers over native styles)

/// Capsule chip on glass. Selected chips use the prominent glass style.
struct Chip: View {
    var title: String
    var symbol: String
    var tint: Color = .accentColor
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Group {
            if selected {
                Button(action: action) { label }
                    .buttonStyle(.glassProminent)
                    .tint(tint)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.glass)
            }
        }
        .buttonBorderShape(.capsule)
        .controlSize(.small)
    }

    private var label: some View {
        Label(title, systemImage: symbol)
            .font(.footnote.weight(.medium))
            .lineLimit(1)
    }
}

/// Round icon button on glass.
struct GlassIconButton: View {
    var symbol: String
    var size: CGFloat = 36
    var tint: Color = .primary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
    }
}

/// Primary call to action: native prominent glass in the accent color.
struct EnergyButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            if let symbol {
                Label(title, systemImage: symbol).fontWeight(.semibold)
            } else {
                Text(title).fontWeight(.semibold)
            }
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
    }
}

/// Secondary pill on glass.
struct GlassButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            if let symbol {
                Label(title, systemImage: symbol).fontWeight(.medium)
            } else {
                Text(title).fontWeight(.medium)
            }
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.capsule)
        .controlSize(.regular)
    }
}

/// Section label used inside results (matches inset-grouped section headers).
struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.footnote)
            .foregroundStyle(.secondary)
    }
}

/// A Settings-style icon tile: SF Symbol on a small rounded square in one tint.
struct IconTile: View {
    var symbol: String
    var tint: Color = .accentColor
    var size: CGFloat = 30

    var body: some View {
        RoundedRectangle(cornerRadius: Theme.radiusTile, style: .continuous)
            .fill(tint)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: symbol)
                    .font(.system(size: size * 0.53, weight: .medium))
                    .foregroundStyle(.white)
            )
            .accessibilityHidden(true)
    }
}

/// A grouped card, like an inset-grouped table cell.
struct ResultCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
    }
}

/// Empty-state placeholder used by surfaces that have nothing on them yet.
struct SurfaceEmptyState: View {
    var symbol: String
    var title: String
    var hint: String
    var tint: Color
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(hint)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Haptics

enum Haptics {
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy() { UIImpactFeedbackGenerator(style: .heavy).impactOccurred(intensity: 1) }
    static func rigid() { UIImpactFeedbackGenerator(style: .rigid).impactOccurred() }
    static func soft() { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}

// MARK: - Small helpers

extension View {
    /// Conditional modifier helper.
    @ViewBuilder
    func `if`<T: View>(_ condition: Bool, transform: (Self) -> T) -> some View {
        if condition { transform(self) } else { self }
    }
}

extension Color {
    static let fuseInk = Theme.ink
}
