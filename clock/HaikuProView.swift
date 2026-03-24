import SwiftUI
import RevenueCat
import RevenueCatUI
import PostHog

struct HaikuProView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var showingCustomerCenter = false
    
    var body: some View {
        ZStack {
            currentTheme.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 40) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(currentTheme.accent)
                            .shadow(color: currentTheme.accent.opacity(0.3), radius: 10)
                        
                        Text("HAIKU PRO")
                            .font(.system(size: 32, weight: .bold, design: .serif))
                            .foregroundStyle(currentTheme.accent)
                            .tracking(8)
                        
                        Text("Elevate your focus.")
                            .font(.system(size: 18, weight: .light, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                    }
                    .padding(.top, 60)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 24) {
                        ProFeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Deep dive into how you spend your time with category breakdowns.")
                        ProFeatureRow(icon: "bell.badge.fill", title: "Custom Notifications", description: "Set unlimited custom reminder offsets for your tasks.")
                        ProFeatureRow(icon: "calendar.badge.plus", title: "2-Way Calendar Sync", description: "Keep your Haiku and system calendars perfectly in sync both ways.")
                        ProFeatureRow(icon: "square.grid.2x2.fill", title: "Aesthetic Widgets", description: "Track your schedule directly from your home screen.")
                        ProFeatureRow(icon: "sparkles", title: "Future Updates", description: "Get early access to all new premium features.")
                    }
                    .padding(.horizontal, 40)
                    
                    // Pricing Tiers (Dynamic from RevenueCat)
                    VStack(spacing: 16) {
                        if let currentOffering = storeManager.offerings?.current {
                            // Monthly
                            if let monthly = currentOffering.monthly {
                                PricingButton(
                                    title: "Monthly",
                                    price: monthly.localizedPriceString,
                                    subtitle: "Full access, billed monthly.",
                                    theme: currentTheme
                                ) {
                                    buyPro(monthly)
                                }
                                .disabled(isPurchasing)
                            }
                            
                            // Annual
                            if let annual = currentOffering.annual {
                                PricingButton(
                                    title: "Annual",
                                    price: annual.localizedPriceString,
                                    subtitle: "Save with yearly billing.",
                                    theme: currentTheme
                                ) {
                                    buyPro(annual)
                                }
                                .disabled(isPurchasing)
                            }
                            
                            // Lifetime
                            if let lifetime = currentOffering.lifetime {
                                PricingButton(
                                    title: "Lifetime",
                                    price: lifetime.localizedPriceString,
                                    subtitle: "One-time payment forever.",
                                    theme: currentTheme
                                ) {
                                    buyPro(lifetime)
                                }
                                .disabled(isPurchasing)
                                }
                                } else {
                                // Fallback if offerings haven't loaded yet

                            ProgressView()
                                .tint(currentTheme.accent)
                                .onAppear {
                                    storeManager.refreshOfferings()
                                }
                        }
                        
                        HStack(spacing: 20) {
                            Button(action: {
                                Task {
                                    await storeManager.restore()
                                }
                            }) {
                                Text("Restore Purchases")
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundStyle(currentTheme.accent.opacity(0.8))
                            }
                            
                            if storeManager.isPro {
                                Button(action: { showingCustomerCenter = true }) {
                                    Text("Manage Subscription")
                                        .font(.system(size: 12, weight: .medium, design: .serif))
                                        .foregroundStyle(currentTheme.accent.opacity(0.8))
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 20)
                    
                    Button(action: { dismiss() }) {
                        Text("Maybe Later")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                    }
                    .padding(.bottom, 60)
                }
            }
            .overlay {
                if isPurchasing {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        ProgressView("Processing...")
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 12).fill(currentTheme.fieldBg))
                    }
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.2))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showingCustomerCenter) {
            CustomerCenterView()
        }
        .onChange(of: storeManager.isPro) { oldValue, newValue in
            if newValue { dismiss() }
        }
        .onAppear {
            // Offerings refresh
            storeManager.refreshOfferings()
        }

    }

    private func buyPro(_ package: Package) {
        // PostHog: Track purchase initiation
        PostHogSDK.shared.capture("purchase_initiated", properties: [
            "package_identifier": package.identifier,
            "price": package.localizedPriceString,
        ])
        isPurchasing = true
        Task {
            do {
                try await storeManager.purchase(package: package)
            } catch {
                print("Purchase failed: \(error)")
            }
            isPurchasing = false
        }
    }
}

struct ProFeatureRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(currentTheme.fieldBg)
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .foregroundStyle(currentTheme.accent)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(currentTheme.textForeground)
                Text(description)
                    .font(.system(size: 13))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                    .lineLimit(2)
            }
        }
    }
}

struct PricingButton: View {
    let title: String
    let price: String
    let subtitle: String
    let theme: AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(theme.textForeground)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(theme.textForeground.opacity(0.6))
                }
                
                Spacer()
                
                Text(price)
                    .font(.system(size: 20, weight: .bold, design: .serif))
                    .foregroundStyle(theme.accent)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.fieldBg)
                    .shadow(color: theme.shadowDark, radius: 5, x: 2, y: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

