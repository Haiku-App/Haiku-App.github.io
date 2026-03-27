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
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
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

        if let projectToken = AppConfiguration.postHogProjectToken,
           let host = AppConfiguration.postHogHost {
            let config = PostHogConfig(apiKey: projectToken, host: host)
            config.captureApplicationLifecycleEvents = true
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
            .onOpenURL { url in
                GIDSignIn.sharedInstance.handle(url)
            }
        }
    }
}
