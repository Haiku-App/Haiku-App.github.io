//
//  clockApp.swift
//  clock
//
//  Created by Reswin Kandathil on 3/7/26.
//

import SwiftUI
import GoogleSignIn
import RevenueCat
import RevenueCatUI
import PostHog

@main
struct clockApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasShownPostOnboardingPaywall") private var hasShownPostOnboardingPaywall = false
    @StateObject private var storeManager = StoreManager()
    @State private var showingPaywall = false

    init() {
        #if DEBUG
        Purchases.logLevel = .debug
        #else
        Purchases.logLevel = .warn
        #endif

        if let revenueCatAPIKey = AppConfiguration.revenueCatAPIKey {
            Purchases.configure(withAPIKey: revenueCatAPIKey)
        } else {
            print("RevenueCat: Missing API key. Purchase flows are disabled for this build.")
        }

        if AppConfiguration.isTestingMode {
            print("PostHog: Disabled in testing mode.")
        } else if let projectToken = AppConfiguration.postHogProjectToken,
                  let host = AppConfiguration.postHogHost {
            print("PostHog: Initializing with token: \(projectToken) and host: \(host)")
            let config = PostHogConfig(apiKey: projectToken, host: host)
            config.captureApplicationLifecycleEvents = true
            config.debug = true // Enable PostHog debug logging
            config.personProfiles = .always
            PostHogSDK.shared.setup(config)
            AnalyticsManager.shared.capture("app_session_started")
        } else {
            print("PostHog: Missing project token or host. Analytics are disabled for this build.")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .sheet(isPresented: $showingPaywall) {
                            HaikuProView()
                                .environmentObject(storeManager)
                        }
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(storeManager)
            .task {
                _ = CategoryManager.shared
                _ = BrainDumpManager.shared
                _ = RoutineManager.shared
            }
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                if newPhase == .active {
                    Task {
                        await storeManager.syncPurchases()
                    }
                }
            }
            .onChange(of: hasCompletedOnboarding) { oldValue, newValue in
                guard !oldValue, newValue else { return }
                schedulePostOnboardingPaywall()
            }
        }
    }

    private func schedulePostOnboardingPaywall() {
        guard !hasShownPostOnboardingPaywall, !storeManager.isPro else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            guard hasCompletedOnboarding, !hasShownPostOnboardingPaywall, !storeManager.isPro else { return }
            hasShownPostOnboardingPaywall = true
            showingPaywall = true
            AnalyticsManager.shared.capture("post_onboarding_paywall_shown")
        }
    }
}
