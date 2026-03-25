import Foundation
#if canImport(PostHog)
import PostHog
#endif

struct AnalyticsManager {
    static let shared = AnalyticsManager()
    
    private init() {}
    
    func capture(_ event: String, properties: [String: Any]? = nil) {
        #if canImport(PostHog)
        PostHogSDK.shared.capture(event, properties: properties)
        #else
        print("[Analytics Stub] Event: \(event), Properties: \(String(describing: properties))")
        #endif
    }
}
