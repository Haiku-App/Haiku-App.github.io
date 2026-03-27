import Foundation

enum AppConfiguration {
    static let postHogProjectToken = configuredString(
        envKey: "POSTHOG_PROJECT_TOKEN",
        plistKey: "PostHogProjectToken"
    )

    static let postHogHost = configuredString(
        envKey: "POSTHOG_HOST",
        plistKey: "PostHogHost"
    )

    static let revenueCatAPIKey = configuredString(
        envKey: "REVENUECAT_API_KEY",
        plistKey: "RevenueCatAPIKey"
    )

    static var isPostHogConfigured: Bool {
        postHogProjectToken != nil && postHogHost != nil
    }

    static var isRevenueCatConfigured: Bool {
        revenueCatAPIKey != nil
    }

    private static func configuredString(envKey: String, plistKey: String) -> String? {
        if let value = ProcessInfo.processInfo.environment[envKey] {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }

        return nil
    }
}
