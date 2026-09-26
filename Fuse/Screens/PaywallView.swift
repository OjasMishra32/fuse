import SwiftUI
import RevenueCat

// MARK: - Fuse Pro paywall
//
// Custom paywall on Theme (not RevenueCatUI's template). Cards come from the current
// RevenueCat offering; without one it shows two mock plans and `Continue` unlocks demo Pro.

struct PaywallView: View {
    var onDismiss: () -> Void

    @State private var selectedPlanID: String?

    private var store: RevenueCatService { .shared }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.grouped.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    benefits
                    planCards
                    callToAction
                    legal
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 60)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            HStack {
                Spacer()
                GlassIconButton(symbol: "xmark", size: 34, tint: Theme.textSecondary) {
                    Haptics.tap()
                    onDismiss()
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 12)
        }
        .onAppear { ensureSelection() }
        .onChange(of: store.packages.count) { _, _ in ensureSelection() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 18) {
            DuoSeamHero()
                .frame(height: 168)
            VStack(spacing: 8) {
                Eyebrow(text: "Fuse Pro")
                Text("Fold without limits.")
                    .font(.fuseTitle)
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Unlimited fuses, image fusion and the community feed. Everything the seam can do.")
                    .font(.fuseBody)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
        }
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(spacing: 12) {
            BenefitRow(symbol: "infinity", tint: Theme.violet,
                       title: "Unlimited fuses",
                       detail: "No daily cap. Fold as often as the idea strikes.")
            BenefitRow(symbol: "photo.on.rectangle.angled", tint: Theme.magenta,
                       title: "Image fusion",
                       detail: "Edit a photo toward the reference on the other screen.")
            BenefitRow(symbol: "person.2.wave.2", tint: Theme.cyan,
                       title: "Community fuses",
                       detail: "Browse and reopen what other Duo owners fused, live via Supabase.")
        }
    }

    // MARK: Plans

    private struct PlanOption: Identifiable {
        var id: String
        var title: String
        var detail: String
        var price: String
        var period: String
        var badge: String?
        var package: Package?
    }

    private var plans: [PlanOption] {
        let live = store.packages.map { package -> PlanOption in
            let storeTitle = package.storeProduct.localizedTitle
            return PlanOption(
                id: package.identifier,
                title: storeTitle.isEmpty ? Self.fallbackTitle(for: package.packageType) : storeTitle,
                detail: Self.detail(for: package.packageType),
                price: package.localizedPriceString,
                period: Self.period(for: package.packageType),
                badge: package.packageType == .annual ? "Best value" : nil,
                package: package
            )
        }
        if !live.isEmpty { return live }
        return [
            PlanOption(id: "mock.monthly", title: "Fuse Pro Monthly", detail: "Cancel anytime",
                       price: "$4.99", period: "per month", badge: nil, package: nil),
            PlanOption(id: "mock.yearly", title: "Fuse Pro Yearly", detail: "Two months free",
                       price: "$29.99", period: "per year", badge: "Best value", package: nil)
        ]
    }

    private var planCards: some View {
        VStack(spacing: 10) {
            ForEach(plans) { plan in
                PlanCard(
                    title: plan.title,
                    detail: plan.detail,
                    price: plan.price,
                    period: plan.period,
                    badge: plan.badge,
                    selected: plan.id == selectedPlanID
                ) {
                    Haptics.selection()
                    withAnimation(Theme.snappy) { selectedPlanID = plan.id }
                }
            }
        }
        .padding(.top, 4)
    }

    private func ensureSelection() {
        let current = plans
        guard !current.isEmpty else { return }
        if let selectedPlanID, current.contains(where: { $0.id == selectedPlanID }) { return }
        selectedPlanID = (current.first { $0.badge != nil } ?? current[0]).id
    }

    // MARK: Call to action

    private var callToAction: some View {
        VStack(spacing: 14) {
            if let error = store.lastError {
                Text(error)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.magenta)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if store.isPro {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.energy)
                    Text("You're Pro. Fold away.")
                        .font(.fuseHeadline)
                        .foregroundStyle(Theme.textPrimary)
                }
                GlassButton(title: "Done", symbol: "checkmark") {
                    Haptics.tap()
                    onDismiss()
                }
            } else if store.isPurchasing {
                ProgressView()
                    .tint(Theme.textPrimary)
                    .frame(height: 44)
            } else {
                EnergyButton(title: "Continue", symbol: "bolt.fill") {
                    Task { await continueTapped() }
                }
            }

            HStack(spacing: 24) {
                Button {
                    Haptics.tap()
                    Task { await store.restore() }
                } label: {
                    HStack(spacing: 6) {
                        if store.isRestoring { ProgressView().controlSize(.mini).tint(Theme.textSecondary) }
                        Text("Restore")
                    }
                }
                .disabled(store.isRestoring)

                Button("Not now") {
                    Haptics.tap()
                    onDismiss()
                }
            }
            .font(.fuseCaption)
            .foregroundStyle(Theme.textSecondary)
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
        .padding(.top, 4)
    }

    private func continueTapped() async {
        Haptics.medium()
        guard let plan = plans.first(where: { $0.id == selectedPlanID }) ?? plans.first else { return }
        if store.isConfigured, let package = plan.package {
            await store.purchase(package)
            if store.isPro { onDismiss() }
        } else {
            store.purchaseDemo()
            onDismiss()
        }
    }

    // MARK: Legal

    private var legal: some View {
        VStack(spacing: 8) {
            Text(store.isConfigured
                 ? "Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple Account › Subscriptions."
                 : "Demo build: no App Store products are configured, so Continue unlocks Fuse Pro on this device only. Add a RevenueCat key in Settings to sell real subscriptions.")
            Text("Purchases powered by RevenueCat")
        }
        .font(.caption2)
        .foregroundStyle(Theme.textTertiary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
    }

    // MARK: Copy helpers

    private static func fallbackTitle(for type: PackageType) -> String {
        switch type {
        case .annual: "Fuse Pro Yearly"
        case .monthly: "Fuse Pro Monthly"
        case .weekly: "Fuse Pro Weekly"
        case .lifetime: "Fuse Pro Lifetime"
        case .sixMonth: "Fuse Pro · 6 months"
        case .threeMonth: "Fuse Pro · 3 months"
        case .twoMonth: "Fuse Pro · 2 months"
        default: "Fuse Pro"
        }
    }

    private static func detail(for type: PackageType) -> String {
        switch type {
        case .annual: "Two months free"
        case .lifetime: "Pay once, fuse forever"
        default: "Cancel anytime"
        }
    }

    private static func period(for type: PackageType) -> String {
        switch type {
        case .annual: "per year"
        case .monthly: "per month"
        case .weekly: "per week"
        case .lifetime: "one time"
        case .sixMonth: "per 6 months"
        case .threeMonth: "per 3 months"
        case .twoMonth: "per 2 months"
        default: ""
        }
    }
}

// MARK: - Pieces

/// Two folded panes with the fusing seam glowing between them.
private struct DuoSeamHero: View {
    var body: some View {
        ZStack {
            HStack(spacing: 16) {
                pane(side: -1)
                pane(side: 1)
            }
            SeamGlow()
        }
    }

    private func pane(side: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
        return shape
            .fill(Theme.ink3)
            .overlay(alignment: side < 0 ? .trailing : .leading) {
                Rectangle()
                    .fill(Theme.energy)
                    .frame(width: 44)
                    .blur(radius: 20)
                    .opacity(0.45)
            }
            .clipShape(shape)
            .overlay(shape.stroke(Theme.line, lineWidth: 1))
            .frame(width: 96, height: 128)
            .rotation3DEffect(.degrees(Double(side) * -16), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
    }
}

/// The seam: a thin energy line with a slow-breathing glow.
private struct SeamGlow: View {
    var body: some View {
        ZStack {
            Capsule()
                .fill(Theme.energyVertical)
                .frame(width: 56, height: 150)
                .blur(radius: 30)
                .phaseAnimator([0.35, 0.85]) { view, phase in
                    view
                        .opacity(phase)
                        .scaleEffect(x: 0.75 + 0.5 * phase, y: 1)
                } animation: { _ in
                    .easeInOut(duration: 1.6)
                }
            Capsule()
                .fill(Theme.energyVertical)
                .frame(width: 3, height: 134)
                .shadow(color: Theme.cyan.opacity(0.9), radius: 8)
        }
    }
}

private struct BenefitRow: View {
    var symbol: String
    var tint: Color
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 40, height: 40)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.fuseHeadline)
                    .foregroundStyle(Theme.textPrimary)
                Text(detail)
                    .font(.fuseCaption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
    }
}

private struct PlanCard: View {
    var title: String
    var detail: String
    var price: String
    var period: String
    var badge: String?
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(selected ? AnyShapeStyle(Theme.energy) : AnyShapeStyle(Theme.textTertiary))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.fuseHeadline)
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text(detail)
                        .font(.fuseCaption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    if !period.isEmpty {
                        Text(period)
                            .font(.fuseCaption)
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
            .padding(Theme.margin)
            .background(Theme.groupedCard, in: RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous)
                    .stroke(selected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Theme.line), lineWidth: selected ? 1.5 : 1)
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Text(badge.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color.accentColor, in: Capsule())
                        .offset(x: -12, y: -10)
                }
            }
        }
        .buttonStyle(.plain)
        .animation(Theme.snappy, value: selected)
    }
}
