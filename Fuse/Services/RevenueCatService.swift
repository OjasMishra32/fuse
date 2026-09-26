import Foundation
import Observation
import RevenueCat

// MARK: - RevenueCat: Fuse Pro entitlement + free-tier quota
//
// Configures the SDK from `AppConfig.revenueCatKey`, mirrors `CustomerInfo` / `Offerings`
// into observable state and owns the free-tier daily quota. When no key is configured the
// paywall keeps working in *demo mode*: `purchaseDemo()` persists a local Pro flag so a live
// demo is never blocked by App Store Connect.

/// Features gated behind Fuse Pro.
enum ProFeature: CaseIterable {
    case imageFusion
    case communityFeed
    case unlimited

    var title: String {
        switch self {
        case .imageFusion: "Image fusion"
        case .communityFeed: "Community feed"
        case .unlimited: "Unlimited fuses"
        }
    }

    var symbol: String {
        switch self {
        case .imageFusion: "photo.on.rectangle.angled"
        case .communityFeed: "person.2.wave.2"
        case .unlimited: "infinity"
        }
    }
}

@MainActor
@Observable
final class RevenueCatService {
    static let shared = RevenueCatService()

    /// Entitlement identifier configured in the RevenueCat dashboard.
    static let entitlementID = "pro"
    /// Fuses a free user gets per calendar day.
    static let freeDailyLimit = 3

    // MARK: Observable state

    private(set) var isConfigured = false
    private(set) var customerInfo: CustomerInfo?
    private(set) var offerings: Offerings?
    /// Packages of the current offering, ordered monthly → annual → lifetime → others.
    private(set) var packages: [Package] = []
    private(set) var isPurchasing = false
    private(set) var isRestoring = false
    var lastError: String?
    /// Fuses recorded today (resets at local midnight).
    private(set) var fusesUsedToday: Int = 0
    /// Local Pro unlock used when RevenueCat isn't configured.
    private(set) var demoPro: Bool = false

    // MARK: Internals

    @ObservationIgnored private var configuredKey: String?
    @ObservationIgnored private var customerInfoTask: Task<Void, Never>?
    @ObservationIgnored private var configObserver: NSObjectProtocol?
    private let defaults = UserDefaults.standard

    private enum DefaultsKey {
        static let usageDay = "fuse.pro.usage.day"
        static let usageCount = "fuse.pro.usage.count"
        static let demoPro = "fuse.pro.demo"
    }

    private init() {
        demoPro = defaults.bool(forKey: DefaultsKey.demoPro)
        fusesUsedToday = loadUsage()
        configObserver = NotificationCenter.default.addObserver(
            forName: AppConfig.didChange, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.configure() }
        }
        configure()
    }

    // MARK: - Pro state

    var isPro: Bool {
        if demoPro { return true }
        return customerInfo?.entitlements[Self.entitlementID]?.isActive ?? false
    }

    var canFuse: Bool { isPro || usedTodayLive < Self.freeDailyLimit }

    var remainingFree: Int { max(0, Self.freeDailyLimit - usedTodayLive) }

    func canUse(_ feature: ProFeature) -> Bool {
        switch feature {
        case .unlimited, .imageFusion, .communityFeed: isPro
        }
    }

    /// One-line status for the Settings screen.
    var statusText: String {
        if isConfigured {
            if isPro { return demoPro ? "Configured · demo Pro unlocked" : "Configured · Pro active" }
            return packages.isEmpty ? "Configured · loading offerings…" : "Configured · \(packages.count) package\(packages.count == 1 ? "" : "s")"
        }
        return demoPro ? "Not configured · demo Pro unlocked" : "Not configured · demo paywall"
    }

    // MARK: - Configuration

    /// Idempotent. Safe to call at launch and again whenever `AppConfig.didChange` fires.
    func configure() {
        guard AppConfig.hasRevenueCat else {
            // The SDK can't be torn down once configured; just reflect that the key is gone.
            if !Purchases.isConfigured { isConfigured = false }
            return
        }
        let key = AppConfig.revenueCatKey
        if Purchases.isConfigured, configuredKey == key {
            isConfigured = true
            return
        }
        Purchases.logLevel = .warn
        Purchases.configure(withAPIKey: key)
        configuredKey = key
        isConfigured = true
        lastError = nil
        startObservingCustomerInfo()
        Task { await refresh() }
    }

    /// Re-fetches `CustomerInfo` and `Offerings`.
    func refresh() async {
        guard isConfigured else { return }
        do {
            customerInfo = try await Purchases.shared.customerInfo()
        } catch {
            lastError = error.localizedDescription
        }
        do {
            let fetched = try await Purchases.shared.offerings()
            offerings = fetched
            packages = Self.orderedPackages(from: fetched)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startObservingCustomerInfo() {
        customerInfoTask?.cancel()
        customerInfoTask = Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                guard let self else { return }
                self.customerInfo = info
            }
        }
    }

    private static func orderedPackages(from offerings: Offerings) -> [Package] {
        let offering = offerings.current
            ?? offerings.all.values.sorted { $0.identifier < $1.identifier }.first
        guard let offering else { return [] }
        func rank(_ package: Package) -> Int {
            switch package.packageType {
            case .monthly: 0
            case .annual: 1
            case .lifetime: 2
            default: 3
            }
        }
        return offering.availablePackages.sorted { rank($0) < rank($1) }
    }

    // MARK: - Purchasing

    func purchase(_ package: Package) async {
        guard isConfigured, !isPurchasing else { return }
        isPurchasing = true
        lastError = nil
        defer { isPurchasing = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return }
            customerInfo = result.customerInfo
            if isPro { Haptics.success() }
        } catch {
            lastError = error.localizedDescription
            Haptics.warning()
        }
    }

    func restore() async {
        guard !isRestoring else { return }
        isRestoring = true
        lastError = nil
        defer { isRestoring = false }
        guard isConfigured else {
            // Demo mode: the persisted flag *is* the purchase record.
            demoPro = defaults.bool(forKey: DefaultsKey.demoPro)
            if demoPro { Haptics.success() } else { lastError = "Nothing to restore on this device yet." }
            return
        }
        do {
            customerInfo = try await Purchases.shared.restorePurchases()
            if isPro { Haptics.success() } else { lastError = "No active Fuse Pro subscription found for this Apple Account." }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Demo-mode unlock. Persisted so it survives relaunches.
    func purchaseDemo() {
        demoPro = true
        defaults.set(true, forKey: DefaultsKey.demoPro)
        lastError = nil
        Haptics.success()
    }

    func resetDemo() {
        demoPro = false
        defaults.removeObject(forKey: DefaultsKey.demoPro)
    }

    // MARK: - Free-tier quota

    func recordFuse() {
        if defaults.string(forKey: DefaultsKey.usageDay) != Self.dayStamp() {
            fusesUsedToday = 0
        }
        fusesUsedToday += 1
        defaults.set(fusesUsedToday, forKey: DefaultsKey.usageCount)
        defaults.set(Self.dayStamp(), forKey: DefaultsKey.usageDay)
    }

    func resetDailyUsage() {
        fusesUsedToday = 0
        defaults.removeObject(forKey: DefaultsKey.usageCount)
        defaults.removeObject(forKey: DefaultsKey.usageDay)
    }

    /// `fusesUsedToday`, but 0 if the stored day has rolled over while the app stayed open.
    private var usedTodayLive: Int {
        defaults.string(forKey: DefaultsKey.usageDay) == Self.dayStamp() ? fusesUsedToday : 0
    }

    private func loadUsage() -> Int {
        guard defaults.string(forKey: DefaultsKey.usageDay) == Self.dayStamp() else { return 0 }
        return defaults.integer(forKey: DefaultsKey.usageCount)
    }

    private static func dayStamp(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return "\(c.year ?? 0)-\(c.month ?? 0)-\(c.day ?? 0)"
    }
}
