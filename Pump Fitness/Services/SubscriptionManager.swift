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

    var isTrialActive: Bool {
        guard let start = trialStartDate,
              UserDefaults.standard.bool(forKey: Self.trialActivatedKey),
              let end = Calendar.current.date(byAdding: .day, value: 14, to: start) else { return false }
        return Date() < end
    }

    // TODO: Replace with your actual product IDs from App Store Connect
    // These should match the Product IDs you create in App Store Connect
    private let productIDs: Set<String> = [
        "com.trackerio.pro.1month",
        "com.trackerio.pro.6months",
        "com.trackerio.pro.12months"
    ]

    private var updates: Task<Void, Never>? = nil

    init() {
        updates = newTransactionListenerTask()
    }

    deinit {
        updates?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        do {
            let products = try await Product.products(for: productIDs)
            // Sort by price to keep order consistent (or use another logic)
            self.products = products.sorted(by: { $0.price < $1.price })
            // Debug: log loaded products
            if !self.products.isEmpty {
                print("Loaded products from StoreKit:")
                for p in self.products {
                    print("- id:\(p.id) name:\(p.displayName) price:\(p.displayPrice)")
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

    /// Restores trial state from a known trial end date (e.g., persisted on the Account) when local flags were cleared.
    /// Only activates if the provided end date is in the future.
    func restoreTrialIfNeeded(trialEnd: Date) {
        guard trialEnd > Date() else { return }

        let expectedStart = Calendar.current.date(byAdding: .day, value: -14, to: trialEnd) ?? Date()
        let alreadyActivated = UserDefaults.standard.bool(forKey: Self.trialActivatedKey)

        // If activation flags are missing or the stored start date differs, refresh them.
        if !alreadyActivated || trialStartDate == nil {
            trialStartDate = expectedStart
            UserDefaults.standard.set(expectedStart.timeIntervalSince1970, forKey: Self.trialStartDateKey)
            UserDefaults.standard.set(true, forKey: Self.trialActivatedKey)
        }
    }

    /// Debug helper to wipe trial flags and start date so the trial can be re-triggered.
    func resetTrialState() {
        trialStartDate = nil
        UserDefaults.standard.removeObject(forKey: Self.trialStartDateKey)
        UserDefaults.standard.set(false, forKey: Self.trialActivatedKey)
    }

    func restore() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        var latestExpiration: Date? = nil

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            // Check if the subscription is still valid (revocationDate is nil)
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)

                if let exp = transaction.expirationDate {
                    if let current = latestExpiration {
                        if exp > current { latestExpiration = exp }
                    } else {
                        latestExpiration = exp
                    }
                }
            }
        }

        self.purchasedProductIDs = purchased
        self.latestSubscriptionExpiration = latestExpiration
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
    static func loadTrialStartDate() -> Date? {
        let timestamp = UserDefaults.standard.double(forKey: trialStartDateKey)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp)
    }
}
