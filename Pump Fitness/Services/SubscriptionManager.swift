import Foundation
import Combine
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var latestSubscriptionExpiration: Date? = nil
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var storefrontCurrencyCode: String? = nil
    @Published var storefrontCountryCode: String? = nil
    @Published var storefrontLocale: Locale = .autoupdatingCurrent
    @Published var isDebugForcingNoSubscription: Bool = UserDefaults.standard.bool(forKey: "debug.forceNoSubscription") {
        didSet {
            UserDefaults.standard.set(isDebugForcingNoSubscription, forKey: "debug.forceNoSubscription")
        }
    }
    @Published private(set) var trialStartDate: Date? = SubscriptionManager.loadTrialStartDate()
    private static let trialStartDateKey = "proTrialStartDate"
    private static let trialActivatedKey = "proTrialActivated"
    
    // Check if the user has pro access (respects debug override)
    var hasProAccess: Bool {
        if isDebugForcingNoSubscription {
            return false
        }
        return isTrialActive || !purchasedProductIDs.isEmpty
    }

    var trialEndDate: Date? {
        guard let start = trialStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 14, to: start)
    }

    /// Convenience mirrors for view code that expects explicit flags.
    var hasActiveSubscription: Bool { hasProAccess && !isTrialActive }
    var isInTrialPeriod: Bool { isTrialActive }
    var trialDaysLeft: Int {
        guard let end = trialEndDate else { return 0 }
        let days = Int(ceil(end.timeIntervalSinceNow / 86_400))
        return max(0, days)
    }
    var subscriptionExpiryDate: Date? { latestSubscriptionExpiration }

    var isTrialActive: Bool {
        guard let start = trialStartDate,
              UserDefaults.standard.bool(forKey: Self.trialActivatedKey),
              let end = Calendar.current.date(byAdding: .day, value: 14, to: start) else { return false }
        return Date() < end
    }

    /// Returns a human-readable subscription status string for telemetry/metadata writes.
    /// Examples: "free", "trial - 13 days remaining", "12 months - 25 days remaining".
    func subscriptionStatusDescription(trialEndDate: Date?, ignoreDebugOverride: Bool = false) -> String {
        let now = Date()

        if isDebugForcingNoSubscription && !ignoreDebugOverride { return "free" }

        let resolvedTrialEnd = trialEndDate ?? self.trialEndDate
        if let trialEnd = resolvedTrialEnd, trialEnd > now {
            if let remaining = Self.remainingString(to: trialEnd) {
                return "trial - \(remaining) remaining"
            }
            return "trial - active"
        }

        if !purchasedProductIDs.isEmpty {
            let planLabel = planLabelForCurrentPurchase() ?? "pro"
            if let expiration = latestSubscriptionExpiration, let remaining = Self.remainingString(to: expiration) {
                return "\(planLabel) - \(remaining) remaining"
            }
            return "\(planLabel) - active"
        }

        return "free"
    }

    // TODO: Replace with your actual product IDs from App Store Connect
    // These should match the Product IDs you create in App Store Connect
    private let productIDs: Set<String> = [
        "com.trackerio.pro.1",
        "com.trackerio.pro.6",
        "com.trackerio.pro.12"
    ]

    private var updates: Task<Void, Never>? = nil
    private var storefrontUpdates: Task<Void, Never>? = nil

    init() {
        updates = newTransactionListenerTask()
        storefrontUpdates = newStorefrontListenerTask()
    }

    deinit {
        updates?.cancel()
        storefrontUpdates?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            await updateStorefront()
            let products = try await Product.products(for: productIDs)
            // Sort by price to keep order consistent (or use another logic)
            self.products = products.sorted(by: { $0.price < $1.price })
            
            // Update currency code from products if storefront update didn't get it
            // if storefrontCurrencyCode == nil, let firstProduct = self.products.first {
            //     storefrontCurrencyCode = firstProduct.priceFormatStyle.currencyCode
            // }
            
            // Debug: log loaded products
            if !self.products.isEmpty {
                print("Loaded products from StoreKit:")
                for p in self.products {
                    print("- id:\(p.id) name:\(p.displayName) price:\(p.displayPrice) currency:\(p.priceFormatStyle.currencyCode)")
                }
            } else {
                print("No products returned from StoreKit for ids: \(productIDs)")
            }
        } catch {
            errorMessage = "Failed to load products: \(error.localizedDescription)"
            print("StoreKit Load Error: \(error)")
        }
        isLoading = false
        
        // Also check current entitlements
        await updatePurchasedProducts()
    }

    func purchase(_ product: Product) async throws {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()
        case .userCancelled:
            break
        case .pending:
            break
        @unknown default:
            break
        }
    }

    /// Activates a single-use 14-day trial if it has never been started.
    /// Returns true if the trial was started during this call.
    func activateOnboardingTrialIfEligible() -> Bool {
        let alreadyActivated = UserDefaults.standard.bool(forKey: Self.trialActivatedKey)
        guard !alreadyActivated else { return false }
        let now = Date()
        trialStartDate = now
        UserDefaults.standard.set(now.timeIntervalSince1970, forKey: Self.trialStartDateKey)
        UserDefaults.standard.set(true, forKey: Self.trialActivatedKey)
        return true
    }

    /// Restores trial state from a known trial end date (e.g., persisted on the Account).
    /// Updates local state even if the trial is expired, ensuring we respect the server's record.
    func restoreTrialIfNeeded(trialEnd: Date) {
        let expectedStart = Calendar.current.date(byAdding: .day, value: -14, to: trialEnd) ?? Date()
        
        // If the calculated start date differs significantly (>1s) from our local record, sync it.
        // This handles both "future trial from server" and "past/expired trial from server".
        let needsUpdate: Bool
        if let currentStart = trialStartDate {
            needsUpdate = abs(currentStart.timeIntervalSince(expectedStart)) > 1
        } else {
            needsUpdate = true
        }

        if needsUpdate {
            print("SubscriptionManager: Syncing local trial state to server end date: \(trialEnd)")
            trialStartDate = expectedStart
            UserDefaults.standard.set(expectedStart.timeIntervalSince1970, forKey: Self.trialStartDateKey)
            UserDefaults.standard.set(true, forKey: Self.trialActivatedKey)
        }
    }

    /// Debug helper to wipe trial flags and start date so the trial can be re-triggered.
    func resetTrialState() {
        trialStartDate = nil
        // Remove any persisted trial flags and overwrite with safe defaults to survive restarts.
        UserDefaults.standard.removeObject(forKey: Self.trialStartDateKey)
        UserDefaults.standard.set(0, forKey: Self.trialStartDateKey)
        UserDefaults.standard.removeObject(forKey: Self.trialActivatedKey)
        UserDefaults.standard.set(false, forKey: Self.trialActivatedKey)
        UserDefaults.standard.synchronize()
    }

    func refreshSubscriptionStatus() async {
        await updatePurchasedProducts()
    }

    func restore() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    private func updatePurchasedProducts() async {
        print("SubscriptionManager: Updating purchased products...")
        var purchased: Set<String> = []
        var latestExpiration: Date? = nil

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            // Check if the subscription is still valid (revocationDate is nil)
            if transaction.revocationDate == nil {
                // StoreKit 2 currentEntitlements handles expiration automatically.
                // We do NOT manualy check expirationDate < Date() here to avoid
                // demoting users due to clock skew or grace periods that Apple considers valid.

                purchased.insert(transaction.productID)
                print("SubscriptionManager: Active entitlement found: \(transaction.productID)")

                if let exp = transaction.expirationDate {
                    if let current = latestExpiration {
                        if exp > current { latestExpiration = exp }
                    } else {
                        latestExpiration = exp
                    }
                }
            } else {
                print("SubscriptionManager: Transaction for \(transaction.productID) was revoked at \(transaction.revocationDate!)")
            }
        }

        self.purchasedProductIDs = purchased
        self.latestSubscriptionExpiration = latestExpiration
        print("SubscriptionManager: Update complete. HasPro: \(hasProAccess), Expiry: \(String(describing: latestExpiration))")
    }

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if let transaction = try? self.checkVerified(result) {
                    await transaction.finish()
                    await self.updatePurchasedProducts()
                }
            }
        }
    }

    private func newStorefrontListenerTask() -> Task<Void, Never> {
        Task.detached {
            for await _ in Storefront.updates {
                await self.updateStorefront()
                await self.loadProducts()
            }
        }
    }

    nonisolated private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum StoreError: Error {
        case failedVerification
    }
}

private extension SubscriptionManager {
    static func remainingString(to date: Date) -> String? {
        guard date > Date() else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.year, .month, .day, .hour]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        return formatter.string(from: Date(), to: date)
    }

    func planLabelForCurrentPurchase() -> String? {
        guard let id = purchasedProductIDs.first else { return nil }
        if id.contains("12month") || id.contains("12months") { return "12 months" }
        if id.contains("6month") || id.contains("6months") { return "6 months" }
        if id.contains("1month") { return "1 month" }
        return "pro"
    }

    func updateStorefront() async {
        guard let storefront = await Storefront.current else { return }
        storefrontCurrencyCode = SubscriptionManager.currencyCode(for: storefront)
        storefrontCountryCode = storefront.countryCode
        storefrontLocale = SubscriptionManager.locale(for: storefront)
    }

    static func locale(for storefront: Storefront) -> Locale {
        if #available(iOS 16, *) {
            let region = Locale.Region(storefront.countryCode)
            var components = Locale.Components()
            components.region = region
            return Locale(components: components)
        }
        let identifier = Locale.identifier(fromComponents: [NSLocale.Key.countryCode.rawValue: storefront.countryCode])
        return Locale(identifier: identifier)
    }

    static func currencyCode(for storefront: Storefront) -> String? {
        let locale = locale(for: storefront)
        return locale.currency?.identifier
    }

    static func loadTrialStartDate() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: trialStartDateKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
