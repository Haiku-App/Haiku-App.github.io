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

enum PostHogEnv: String {
    case projectToken = "POSTHOG_PROJECT_TOKEN"
    case host = "POSTHOG_HOST"

    var value: String {
        guard let value = ProcessInfo.processInfo.environment[rawValue] else {
            fatalError("Set \(rawValue) in the Xcode scheme environment variables.")
        }
        return value
    }
}

@main
struct clockApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @StateObject private var storeManager = StoreManager()
    @State private var showingPaywall = false

    init() {
        // Initialize RevenueCat
        Purchases.logLevel = .debug
        Purchases.configure(withAPIKey: "test_BnEWCtQiNhXXQxCUtUuJfKUDncB")

        // Initialize PostHog
        let config = PostHogConfig(apiKey: PostHogEnv.projectToken.value, host: PostHogEnv.host.value)
        config.captureApplicationLifecycleEvents = true
        PostHogSDK.shared.setup(config)
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
