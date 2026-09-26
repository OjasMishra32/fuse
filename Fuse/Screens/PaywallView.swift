import SwiftUI
import RevenueCat

// MARK: - Fuse Pro paywall
//
// Custom paywall on Theme (not RevenueCatUI's template): the orb, a title and one line, three
// benefit rows, plans as selectable rows, a prominent Continue, and the legal footnote. Plans
// come from the current RevenueCat offering; without one it shows two mock plans and
// `Continue` unlocks demo Pro.

struct PaywallView: View {
    var onDismiss: () -> Void

    @State private var selectedPlanID: String?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var store: RevenueCatService { .shared }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Theme.grouped.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    hero
                    benefits
                    planRows
                    callToAction
                    legal
                }
                .padding(.horizontal, Theme.gutter)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)

            GlassIconButton(symbol: "xmark", size: 34, tint: .primary) {
                Haptics.tap()
                onDismiss()
            }
            .padding(.horizontal, Theme.margin)
            .padding(.top, 12)
            .accessibilityLabel("Close")
        }
        .onAppear { ensureSelection() }
        .onChange(of: store.packages.count) { _, _ in ensureSelection() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: 16) {
            // Half speed: a slow breath rather than the Fusing screen's working rhythm.
            OrbView(size: 88, animated: !reduceMotion, speed: 0.5)
                .frame(width: 88, height: 88)
                .padding(.top, 8)
            VStack(spacing: 6) {
                Text("Fuse Pro")
                    .font(.title.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                Text("Unlimited fuses, image fusion and the community feed.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Benefits

    private var benefits: some View {
        ResultCard(padding: 0) {
            VStack(spacing: 0) {
                BenefitRow(symbol: "infinity",
                           title: "Unlimited fuses",
                           detail: "No daily cap. Fold as often as the idea strikes.")
                Hairline().padding(.leading, Theme.margin + 30 + 12)
                BenefitRow(symbol: "photo.on.rectangle.angled",
                           title: "Image fusion",
                           detail: "Edit a photo toward the reference on the other screen.")
                Hairline().padding(.leading, Theme.margin + 30 + 12)
                BenefitRow(symbol: "person.2",
                           title: "Community fuses",
                           detail: "Browse and reopen what other Duo owners fused.")
            }
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
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
            PlanOption(id: "mock.monthly", title: "Monthly", detail: "Cancel anytime",
                       price: "$4.99", period: "per month", badge: nil, package: nil),
            PlanOption(id: "mock.yearly", title: "Yearly", detail: "Two months free",
                       price: "$29.99", period: "per year", badge: "Best value", package: nil)
        ]
    }

    private var planRows: some View {
        ResultCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(Array(plans.enumerated()), id: \.element.id) { index, plan in
                    if index > 0 { Hairline().padding(.leading, Theme.margin + 22 + 12) }
                    PlanRow(
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
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusCard, style: .continuous))
        }
    }

    private func ensureSelection() {
        let current = plans
        guard !current.isEmpty else { return }
        if let selectedPlanID, current.contains(where: { $0.id == selectedPlanID }) { return }
        selectedPlanID = (current.first { $0.badge != nil } ?? current[0]).id
    }

    // MARK: Call to action

    private var callToAction: some View {
        VStack(spacing: 12) {
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if store.isPro {
                Label("You're Pro. Fold away.", systemImage: "checkmark.seal.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Button {
                    Haptics.tap()
                    onDismiss()
                } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
            } else {
                // Continue keeps its height while the label gives way to a spinner.
                Button {
                    Task { await continueTapped() }
                } label: {
                    ZStack {
                        Text("Continue")
                            .fontWeight(.semibold)
                            .opacity(store.isPurchasing ? 0 : 1)
                        if store.isPurchasing {
                            ProgressView()
                                .tint(.white)
                                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .animation(Theme.snappy, value: store.isPurchasing)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .disabled(store.isPurchasing)
                .accessibilityLabel(store.isPurchasing ? "Purchasing" : "Continue")
            }

            HStack(spacing: 24) {
                Button {
                    Haptics.tap()
                    Task { await store.restore() }
                } label: {
                    HStack(spacing: 6) {
                        if store.isRestoring { ProgressView().controlSize(.mini) }
                        Text("Restore Purchases")
                    }
                }
                .disabled(store.isRestoring)

                Button("Not Now") {
                    Haptics.tap()
                    onDismiss()
                }
            }
            .font(.subheadline)
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .padding(.top, 4)
        }
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
        VStack(spacing: 6) {
            Text(store.isConfigured
                 ? "Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings › Apple Account › Subscriptions."
                 : "Demo build: no App Store products are configured, so Continue unlocks Fuse Pro on this device only. Add a RevenueCat key in Settings to sell real subscriptions.")
            Text("Purchases powered by RevenueCat")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
    }

    // MARK: Copy helpers

    private static func fallbackTitle(for type: PackageType) -> String {
        switch type {
        case .annual: "Yearly"
        case .monthly: "Monthly"
        case .weekly: "Weekly"
        case .lifetime: "Lifetime"
        case .sixMonth: "6 months"
        case .threeMonth: "3 months"
        case .twoMonth: "2 months"
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

/// SF Symbol on an accent tile, a title and one line of detail. Like a Settings row.
private struct BenefitRow: View {
    var symbol: String
    var title: String
    var detail: String

    var body: some View {
        HStack(spacing: 12) {
            IconTile(symbol: symbol, tint: .accentColor, size: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, Theme.margin)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }
}

/// A selectable plan: checkmark, name and detail, price and period. The badge sits by the name.
private struct PlanRow: View {
    var title: String
    var detail: String
    var price: String
    var period: String
    var badge: String?
    var selected: Bool
    var action: () -> Void

    /// Bumps only when this row becomes the selection, so the checkmark bounces on arrival
    /// and the row losing it simply fades back.
    @State private var bounce = 0

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : Color(uiColor: .tertiaryLabel))
                    .frame(width: 22)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, options: .nonRepeating, value: bounce)
                    .onChange(of: selected) { _, isSelected in
                        if isSelected { bounce += 1 }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor, in: Capsule())
                        }
                    }
                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.primary)
                    if !period.isEmpty {
                        Text(period)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 10)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
