import SwiftUI
import UIKit

// MARK: - Fuse design language
//
// Dark, quiet, one spectacular moment (the melt). Liquid Glass for chrome, SF Pro for text,
// a single violet→cyan "energy" gradient reserved for the seam and anything that is fusing.
// Everything else is neutral so the energy reads.

enum Theme {
    // Palette
    static let ink = Color(red: 0.035, green: 0.04, blue: 0.07)             // page background
    static let ink2 = Color(red: 0.07, green: 0.08, blue: 0.13)             // raised surface
    static let ink3 = Color(red: 0.11, green: 0.12, blue: 0.18)             // pane chrome
    static let line = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.94)
    static let textSecondary = Color.white.opacity(0.58)
    static let textTertiary = Color.white.opacity(0.36)

    static let violet = Color(red: 0.55, green: 0.42, blue: 1.0)
    static let cyan = Color(red: 0.32, green: 0.86, blue: 1.0)
    static let magenta = Color(red: 1.0, green: 0.40, blue: 0.78)
    static let mint = Color(red: 0.36, green: 0.95, blue: 0.72)

    /// The fuse energy gradient. Left → right across the seam.
    static let energy = LinearGradient(colors: [violet, cyan], startPoint: .leading, endPoint: .trailing)
    static let energyVertical = LinearGradient(colors: [violet, cyan], startPoint: .top, endPoint: .bottom)
    static let energyAngular = AngularGradient(colors: [violet, cyan, magenta, violet], center: .center)

    // Radii — concentric with the Duo's corners
    static let radiusPane: CGFloat = 26
    static let radiusCard: CGFloat = 18
    static let radiusChip: CGFloat = 12

    // Motion
    static let snappy = Animation.spring(response: 0.36, dampingFraction: 0.82)
    static let smooth = Animation.spring(response: 0.55, dampingFraction: 0.86)
    static let melt = Animation.interpolatingSpring(stiffness: 120, damping: 18)

    /// Background used everywhere: ink with a faint mesh so glass has something to refract.
    static var background: some View {
        ZStack {
            ink.ignoresSafeArea()
            MeshGradient(
                width: 3, height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.5], [0.5, 0.5], [1, 0.5],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    ink, ink2, ink,
                    Color(red: 0.10, green: 0.08, blue: 0.20), ink2, Color(red: 0.05, green: 0.12, blue: 0.18),
                    ink, ink2, ink
                ]
            )
            .opacity(0.9)
            .ignoresSafeArea()
        }
    }
}

// MARK: - Typography

extension Font {
    static func fuse(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    static let fuseWordmark = Font.system(size: 15, weight: .semibold, design: .rounded)
    static let fuseTitle = Font.system(size: 28, weight: .bold)
    static let fuseHeadline = Font.system(size: 17, weight: .semibold)
    static let fuseBody = Font.system(size: 15, weight: .regular)
    static let fuseCaption = Font.system(size: 12, weight: .medium)
    static let fuseMono = Font.system(size: 13, weight: .regular, design: .monospaced)
}

// MARK: - Reusable chrome

/// A capsule chip with an SF Symbol, used for the surface dock and result actions.
struct Chip: View {
    var title: String
    var symbol: String
    var tint: Color = Theme.textPrimary
    var selected: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.fuseCaption)
                    .lineLimit(1)
            }
            .foregroundStyle(selected ? Color.black.opacity(0.85) : tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background {
                if selected {
                    Capsule().fill(tint)
                } else {
                    Capsule().fill(.white.opacity(0.06))
                        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                }
            }
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
    }
}

/// Round icon button on glass.
struct GlassIconButton: View {
    var symbol: String
    var size: CGFloat = 36
    var tint: Color = Theme.textPrimary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .buttonStyle(.plain)
    }
}

/// Primary call-to-action with the energy gradient.
struct EnergyButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let symbol { Image(systemName: symbol).font(.system(size: 14, weight: .bold)) }
                Text(title).font(.system(size: 15, weight: .semibold))
            }
            .foregroundStyle(.black.opacity(0.9))
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
            .background(Theme.energy, in: Capsule())
            .shadow(color: Theme.violet.opacity(0.35), radius: 14, y: 6)
        }
        .buttonStyle(.plain)
    }
}

/// Secondary pill on glass.
struct GlassButton: View {
    var title: String
    var symbol: String? = nil
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if let symbol { Image(systemName: symbol).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(Theme.textPrimary)
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
            .glassEffect(.regular.interactive(), in: .capsule)
        }
        .buttonStyle(.plain)
    }
}

/// Section label used inside results.
struct Eyebrow: View {
    var text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .semibold))
            .tracking(1.1)
            .foregroundStyle(Theme.textTertiary)
    }
}

/// A card surface used by result artifacts.
struct ResultCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.ink2, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous).stroke(Theme.line, lineWidth: 1))
    }
}

/// Empty-state placeholder used by surfaces that have nothing on them yet.
struct SurfaceEmptyState: View {
    var symbol: String
    var title: String
    var hint: String
    var tint: Color
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(tint.opacity(0.9))
            Text(title)
                .font(.fuseHeadline)
                .foregroundStyle(Theme.textPrimary)
            Text(hint)
                .font(.fuseCaption)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 240)
        }
        .padding(24)
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
