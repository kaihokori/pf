import Foundation
import Combine
import StoreKit

@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()

    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isDebugForcingNoSubscription: Bool = UserDefaults.standard.bool(forKey: "debug.forceNoSubscription") {
        didSet {
            UserDefaults.standard.set(isDebugForcingNoSubscription, forKey: "debug.forceNoSubscription")
        }
    }
    
    // Check if the user has pro access (respects debug override)
    var hasProAccess: Bool {
        if isDebugForcingNoSubscription {
            return false
        }
        return !purchasedProductIDs.isEmpty
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

    func restore() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }
            
            // Check if the subscription is still valid (revocationDate is nil)
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        self.purchasedProductIDs = purchased
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
