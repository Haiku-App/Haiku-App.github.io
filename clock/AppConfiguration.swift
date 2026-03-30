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

    static let allowsTesterUnlocks = configuredBool(
        envKey: "ENABLE_TESTER_UNLOCKS",
        plistKey: "EnableTesterUnlocks"
    )

    static let isGoogleSignInEnabled = configuredBool(
        envKey: "ENABLE_GOOGLE_SIGN_IN",
        plistKey: "EnableGoogleSignIn"
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

    private static func configuredBool(envKey: String, plistKey: String) -> Bool {
        if let value = ProcessInfo.processInfo.environment[envKey] {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "on":
                return true
            default:
                break
            }
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: plistKey) as? Bool {
            return value
        }

        if let value = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String {
            switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "1", "true", "yes", "on":
                return true
            default:
                break
            }
        }

        return false
    }
}
