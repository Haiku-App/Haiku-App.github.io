import Foundation
import StoreKit
internal import Combine

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs = Set<String>()
    @Published private(set) var isPro: Bool = false
    
    // Product IDs
    let proLifetimeID = "reswin.clock.pro.lifetime"
    let proMonthlyID = "reswin.clock.pro.monthly"
    let proAnnualID = "reswin.clock.pro.annual"
    
    var allProIDs: Set<String> {
        [proLifetimeID, proMonthlyID, proAnnualID]
    }
    
    private func updateIsPro() {
        let result = !purchasedProductIDs.intersection(allProIDs).isEmpty
        if result != isPro {
            print("StoreKit: isPro changed to \(result), updating and saving")
            isPro = result
            // Save to SharedTaskManager in background so it doesn't block the actor
            Task.detached {
                SharedTaskManager.shared.save(isPro: result)
            }
        }
    }
    
    private var updates: Task<Void, Never>? = nil
    private var refreshTask: Task<Void, Never>? = nil

    init() {
        // Initial state from SharedTaskManager
        self.isPro = SharedTaskManager.shared.loadIsPro()
        
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
        refreshTask?.cancel()
    }

    func refresh() async {
        // Prevent multiple simultaneous refreshes
        if let existingTask = refreshTask {
            await existingTask.value
            return
        }
        
        let task = Task {
            // Small delay to allow StoreKit 2 to settle its connection to the local .storekit file
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            let bundleID = Bundle.main.bundleIdentifier ?? "unknown"
            print("StoreKit: Starting refresh for Bundle ID: \(bundleID)")
            
            // Debug check for the file in bundle
            if let path = Bundle.main.path(forResource: "Products", ofType: "storekit") {
                print("StoreKit: Products.storekit FOUND in bundle at: \(path)")
            } else {
                print("StoreKit: Products.storekit NOT found in main bundle (This is normal if only using Scheme configuration)")
            }

            print("StoreKit: Looking for Product IDs: \(allProIDs)")
            do {
                // 1. Fetch products from Apple (or local storekit file)
                print("StoreKit: Calling Product.products(for:)...")
                let fetchedProducts = try await Product.products(for: Array(allProIDs))
                print("StoreKit: Successfully fetched \(fetchedProducts.count) products")
                
                if fetchedProducts.isEmpty {
                    print("StoreKit: WARNING: No products were found. Check your StoreKit configuration and product IDs.")
                    print("StoreKit: Troubleshooting Tips:")
                    print("  1. Ensure the StoreKit configuration is selected in your scheme editor.")
                    print("  2. Ensure the product IDs in the StoreKit file match exactly.")
                    print("  3. Ensure the StoreKit file is added to the app target's bundle.")
                }
                
                for product in fetchedProducts {
                    print("StoreKit: Found product - \(product.id) [\(product.displayPrice)]")
                }
                
                self.products = fetchedProducts
                
                // 2. Check current entitlements
                print("StoreKit: Checking current entitlements...")
                for await result in Transaction.currentEntitlements {
                    await self.handle(transaction: result)
                }
                updateIsPro()
                print("StoreKit: Refresh complete. isPro: \(isPro)")
            } catch {
                print("StoreKit: CRITICAL ERROR fetching products: \(error)")
                print("StoreKit: Error details: \(error.localizedDescription)")
            }
        }
        
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    func purchase(product: Product) async throws {
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
            // Check if it's one of our Pro IDs and if it's still valid (not revoked)
            if allProIDs.contains(transaction.productID) {
                if transaction.revocationDate == nil {
                    self.purchasedProductIDs.insert(transaction.productID)
                } else {
                    self.purchasedProductIDs.remove(transaction.productID)
                }
            }
            await transaction.finish()
            updateIsPro()
        case .unverified:
            // Handle unverified transactions (usually ignored in simple apps)
            break
        }
    }
}
