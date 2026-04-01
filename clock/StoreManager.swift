import Foundation
import RevenueCat
import StoreKit
import SwiftUI
internal import Combine

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var offerings: Offerings?
    @Published private(set) var lastError: Error?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    @Published private(set) var isSandboxMode: Bool = false
    @Published private(set) var isRevenueCatConfigured: Bool = AppConfiguration.isRevenueCatConfigured
    @Published private(set) var allowsTesterUnlocks: Bool = AppConfiguration.allowsTesterUnlocks
    private var hasUnlockedFreePro: Bool = false
    
    private let proEntitlementID = "Haiku Pro"
    private let preferredOfferingID = "default"
    private var customerInfoTask: Task<Void, Never>?

    private var canUseTesterUnlocks: Bool {
        // If explicitly allowed in Info.plist/Environment, we don't strictly require isSandboxMode
        // to ensure App Store reviewers never get blocked.
        return allowsTesterUnlocks
    }

    var paywallOffering: Offering? {
        if let preferred = offerings?.offering(identifier: preferredOfferingID) {
            return preferred
        }
        return offerings?.current
    }
    
    init() {
        // Initialize from local cache first for instant UI response
        self.isPro = SharedTaskManager.shared.loadIsPro()
        self.hasUnlockedFreePro = AppConfiguration.allowsTesterUnlocks && SharedTaskManager.shared.loadHasUnlockedFreePro()
        if !AppConfiguration.allowsTesterUnlocks {
            SharedTaskManager.shared.saveHasUnlockedFreePro(false)
        }
        
        // Check environment
        Task {
            await detectEnvironment()
        }

        guard isRevenueCatConfigured else {
            print("RevenueCat: Missing API key. Skipping offerings and entitlement refresh.")
            return
        }

        // Then fetch fresh status from server
        Task {
            if let info = try? await Purchases.shared.customerInfo() {
                self.updateProStatus(info)
            }
        }

        // Start listening to customer info updates
        subscribeToCustomerInfo()

        // Initial fetch of offerings
        refreshOfferings()
    }
    
    private func detectEnvironment() async {
        var detectedSandbox = false
        
        if #available(iOS 16.0, *) {
            if let result = try? await AppTransaction.shared,
               case .verified(let appTransaction) = result {
                // .sandbox covers both Sandbox and TestFlight
                if appTransaction.environment == .sandbox {
                    detectedSandbox = true
                }
            }
        }
        
        // Fallback/Double-check for older iOS or specific sandbox cases
        if !detectedSandbox {
            if #available(iOS 18.0, *) {
                // On iOS 18+, we rely strictly on AppTransaction to avoid deprecation warnings
            } else {
                if Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt" {
                    detectedSandbox = true
                }
            }
        }
        
        #if DEBUG
        detectedSandbox = true
        #endif
        
        let finalDetected = detectedSandbox
        await MainActor.run {
            self.isSandboxMode = finalDetected
        }
        
        if finalDetected {
            print("StoreManager: Sandbox/TestFlight environment detected.")
        }
    }
    
    func unlockProForFree() {
        guard canUseTesterUnlocks else { return }
        print("StoreManager: Unlocking Pro for free (Sandbox mode).")
        self.hasUnlockedFreePro = true
        SharedTaskManager.shared.saveHasUnlockedFreePro(true)
        self.isPro = true
        SharedTaskManager.shared.save(isPro: true)
        AnalyticsManager.shared.capture("purchase_completed", properties: ["method": "sandbox_free_unlock"])
    }
    
    func refreshOfferings() {
        guard isRevenueCatConfigured else {
            offerings = nil
            return
        }

        Task {
            self.lastError = nil
            do {
                let fetchedOfferings = try await Purchases.shared.offerings()
                self.offerings = fetchedOfferings
                
                if fetchedOfferings.all.isEmpty {
                    print("RevenueCat: No available offerings returned from server.")
                    self.lastError = NSError(domain: "StoreManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "No products available in the store right now."])
                } else if fetchedOfferings.offering(identifier: self.preferredOfferingID) != nil {
                    print("RevenueCat: Using preferred offering '\(self.preferredOfferingID)'.")
                } else if let currentID = fetchedOfferings.current?.identifier {
                    print("RevenueCat: Preferred offering missing. Falling back to current offering '\(currentID)'.")
                } else {
                    print("RevenueCat: Offerings found but no 'current' or preferred offering set.")
                }
            } catch {
                print("RevenueCat: Failed to fetch offerings: \(error)")
                self.lastError = error
            }
        }
    }
    
    private func subscribeToCustomerInfo() {
        guard isRevenueCatConfigured else { return }

        // The modern way to handle state changes in RevenueCat SDK
        customerInfoTask = Task {
            for await info in Purchases.shared.customerInfoStream {
                self.customerInfo = info
                self.updateProStatus(info)
            }
        }
    }
    
    private func updateProStatus(_ info: CustomerInfo) {
        var proActive = info.entitlements[proEntitlementID]?.isActive == true
        print("RevenueCat: Checking entitlement '\(proEntitlementID)'. Active: \(proActive)")
        
        // LEGACY TESTER GIFT: If they ever unlocked it during TestFlight, keep it forever.
        if canUseTesterUnlocks && hasUnlockedFreePro {
            proActive = true
        }
        
        // Keep Pro active for TestFlight/Sandbox even if RevenueCat says otherwise (for initial unlock)
        if canUseTesterUnlocks && hasUnlockedFreePro {
            proActive = true
        }
        
        if proActive != self.isPro {
            print("RevenueCat: Pro status changing from \(self.isPro) to \(proActive)")
            self.isPro = proActive
            SharedTaskManager.shared.save(isPro: proActive)
            if proActive {
                AnalyticsManager.shared.capture("purchase_completed")
            }
        }
    }
    
    func purchase(package: Package) async throws {
        guard isRevenueCatConfigured else {
            throw StoreManagerError.purchasesUnavailable
        }

        let result = try await Purchases.shared.purchase(package: package)
        updateProStatus(result.customerInfo)
    }
    
    func restore() async {
        guard isRevenueCatConfigured else {
            print("RevenueCat: Restore skipped because purchases are unavailable in this build.")
            return
        }

        do {
            let info = try await Purchases.shared.restorePurchases()
            updateProStatus(info)
            AnalyticsManager.shared.capture("purchase_restored")
        } catch {
            print("RevenueCat: Restore failed: \(error)")
        }
    }
    
    deinit {
        customerInfoTask?.cancel()
    }
}

enum StoreManagerError: LocalizedError {
    case purchasesUnavailable

    var errorDescription: String? {
        switch self {
        case .purchasesUnavailable:
            return "Purchases are unavailable in this build."
        }
    }
}
