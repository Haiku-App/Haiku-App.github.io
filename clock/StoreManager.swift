import Foundation
import StoreKit
internal import Combine

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    
    // The Product ID we'll use (matches the .storekit file)
    let proID = "com.haiku.pro.lifetime"
    
    var isPro: Bool {
        return purchasedProductIDs.contains(proID)
    }
    
    private var updates: Task<Void, Never>? = nil

    init() {
        // Start listening for transaction updates
        updates = Task {
            for await result in Transaction.updates {
                await self.handle(transaction: result)
            }
        }
        
        Task {
            await refresh()
        }
    }

    deinit {
        updates?.cancel()
    }

    func refresh() async {
        do {
            // 1. Fetch products from Apple (or local storekit file)
            self.products = try await Product.products(for: [proID])
            
            // 2. Check current entitlements
            for await result in Transaction.currentEntitlements {
                await self.handle(transaction: result)
            }
        } catch {
            print("StoreKit: Failed to fetch products: \(error)")
        }
    }

    func purchase() async throws {
        guard let product = products.first(where: { $0.id == proID }) else { return }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            await handle(transaction: verification)
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    func restore() async {
        try? await AppStore.sync()
        await refresh()
    }

    private func handle(transaction result: VerificationResult<Transaction>) async {
        switch result {
        case .verified(let transaction):
            // Check if it's our Pro ID and if it's still valid (not revoked)
            if transaction.productID == proID {
                if transaction.revocationDate == nil {
                    self.purchasedProductIDs.insert(proID)
                } else {
                    self.purchasedProductIDs.remove(proID)
                }
            }
            await transaction.finish()
        case .unverified:
            // Handle unverified transactions (usually ignored in simple apps)
            break
        }
    }
}
