import Foundation
import RevenueCat
import StoreKit
import SwiftUI
internal import Combine
import PostHog

@MainActor
class StoreManager: ObservableObject {
    @Published private(set) var offerings: Offerings?
    @Published private(set) var isPro: Bool = false
    @Published private(set) var customerInfo: CustomerInfo?
    
    private let proEntitlementID = "Haiku  Pro"
    private var customerInfoTask: Task<Void, Never>?
    
    init() {
        // Initialize from local cache first for instant UI response
        self.isPro = SharedTaskManager.shared.loadIsPro()
        
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
    
    func refreshOfferings() {
        Task {
            do {
                self.offerings = try await Purchases.shared.offerings()
            } catch {
                print("RevenueCat: Failed to fetch offerings: \(error)")
            }
        }
    }
    
    private func subscribeToCustomerInfo() {
        // The modern way to handle state changes in RevenueCat SDK
        customerInfoTask = Task {
            for await info in Purchases.shared.customerInfoStream {
                self.customerInfo = info
                self.updateProStatus(info)
            }
        }
    }
    
    func updateProStatus(_ info: CustomerInfo) {
        let proActive = info.entitlements[proEntitlementID]?.isActive == true
        print("RevenueCat: Checking entitlement '\(proEntitlementID)'. Active: \(proActive)")
        print("RevenueCat: Current active entitlements: \(info.entitlements.active.keys)")
        
        if proActive != self.isPro {
            print("RevenueCat: Pro status changing from \(self.isPro) to \(proActive)")
            self.isPro = proActive
            SharedTaskManager.shared.save(isPro: proActive)
            if proActive {
                PostHogSDK.shared.capture("purchase_completed")
            }
        }
    }
    
    func purchase(package: Package) async throws {
        let result = try await Purchases.shared.purchase(package: package)
        updateProStatus(result.customerInfo)
    }
    
    func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            updateProStatus(info)
            PostHogSDK.shared.capture("purchase_restored")
        } catch {
            print("RevenueCat: Restore failed: \(error)")
        }
    }
    
    deinit {
        customerInfoTask?.cancel()
    }
}
