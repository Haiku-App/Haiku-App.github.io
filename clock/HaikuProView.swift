import SwiftUI
import RevenueCat
import RevenueCatUI

struct HaikuProView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    @State private var showingCustomerCenter = false
    @State private var appearanceAnimate = false
    
    var body: some View {
        ZStack {
            // Animated Background Layer
            currentTheme.bg.ignoresSafeArea()
            
            // Subtle Moving Blobs for "Zen" feel
            ZStack {
                Circle()
                    .fill(currentTheme.accent.opacity(0.15))
                    .frame(width: 300)
                    .blur(radius: 60)
                    .offset(x: appearanceAnimate ? 100 : -100, y: appearanceAnimate ? -150 : -200)
                
                Circle()
                    .fill(currentTheme.accent.opacity(0.1))
                    .frame(width: 250)
                    .blur(radius: 50)
                    .offset(x: appearanceAnimate ? -120 : 80, y: appearanceAnimate ? 200 : 150)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: appearanceAnimate)

            VStack(spacing: 0) {
                // Header - Floating and Zen
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(currentTheme.accent)
                        .shadow(color: currentTheme.accent.opacity(0.3), radius: 10)
                        .offset(y: appearanceAnimate ? -10 : 0)
                        .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: appearanceAnimate)
                    
                    Text("HAIKU PRO")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(8)
                        .opacity(appearanceAnimate ? 1 : 0)
                        .offset(y: appearanceAnimate ? 0 : 10)
                    
                    Text("Elevate your focus.")
                        .font(.system(size: 16, weight: .light, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                        .opacity(appearanceAnimate ? 1 : 0)
                        .offset(y: appearanceAnimate ? 0 : 10)
                }
                .padding(.top, 40)
                
                Spacer(minLength: 20)
                
                // Features - Staggered Slide-in
                VStack(alignment: .leading, spacing: 18) {
                    ProFeatureRow(icon: "chart.bar.fill", title: "Advanced Analytics", description: "Deep dive into your time.", delay: 0.1, animate: appearanceAnimate)
                    ProFeatureRow(icon: "bell.badge.fill", title: "Custom Notifications", description: "Unlimited reminder offsets.", delay: 0.2, animate: appearanceAnimate)
                    ProFeatureRow(icon: "calendar.badge.plus", title: "2-Way Calendar Sync", description: "Perfectly in sync both ways.", delay: 0.3, animate: appearanceAnimate)
                    ProFeatureRow(icon: "square.grid.2x2.fill", title: "Aesthetic Widgets", description: "Track from your home screen.", delay: 0.4, animate: appearanceAnimate)
                }
                .padding(.horizontal, 40)
                
                Spacer(minLength: 20)
                
                // Pricing - Horizontal and Compact
                VStack(spacing: 20) {
                    if let currentOffering = storeManager.offerings?.current {
                        HStack(spacing: 10) {
                            if let monthly = currentOffering.monthly {
                                CompactPricingButton(
                                    title: "Monthly",
                                    price: monthly.localizedPriceString,
                                    theme: currentTheme
                                ) { buyPro(monthly) }
                            } else {
                                CompactPricingButton(
                                    title: "Monthly",
                                    price: "$3.99",
                                    theme: currentTheme
                                ) { } // Disabled until loaded
                            }
                            
                            if let annual = currentOffering.annual {
                                CompactPricingButton(
                                    title: "Annual",
                                    price: annual.localizedPriceString,
                                    isBestValue: true,
                                    theme: currentTheme
                                ) { buyPro(annual) }
                            } else {
                                CompactPricingButton(
                                    title: "Annual",
                                    price: "$19.99",
                                    isBestValue: true,
                                    theme: currentTheme
                                ) { }
                            }
                            
                            if let lifetime = currentOffering.lifetime {
                                CompactPricingButton(
                                    title: "Lifetime",
                                    price: lifetime.localizedPriceString,
                                    theme: currentTheme
                                ) { buyPro(lifetime) }
                            } else {
                                CompactPricingButton(
                                    title: "Lifetime",
                                    price: "$49.99",
                                    theme: currentTheme
                                ) { }
                            }
                        }
                        .padding(.horizontal, 20)
                        .opacity(appearanceAnimate ? 1 : 0)
                        .scaleEffect(appearanceAnimate ? 1 : 0.95)
                    } else {
                        ProgressView()
                            .tint(currentTheme.accent)
                            .onAppear { storeManager.refreshOfferings() }
                    }
                    
                    // Footer Links
                    HStack(spacing: 24) {
                        Button("Restore") {
                            Task { await storeManager.restore() }
                        }
                        
                        if storeManager.isPro {
                            Button("Manage") { showingCustomerCenter = true }
                        }
                        
                        Button("Maybe Later") { dismiss() }
                    }
                    .font(.system(size: 12, weight: .medium, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                }
                .padding(.bottom, 30)
            }
            .padding(.bottom, 10) // Small safety buffer
            
            // Processing Overlay
            if isPurchasing {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Processing...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(currentTheme.fieldBg))
                }
            }
            
            // Close Button
            VStack {
                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.15))
                    }
                    .padding(20)
                }
                Spacer()
            }
        }
        .sheet(isPresented: $showingCustomerCenter) {
            CustomerCenterView()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                appearanceAnimate = true
            }
        }
        .onChange(of: storeManager.isPro) { oldValue, newValue in
            if newValue { dismiss() }
        }
    }

    private func buyPro(_ package: Package) {
        AnalyticsManager.shared.capture("purchase_initiated", properties: [
            "package_identifier": package.identifier,
            "price": package.localizedPriceString,
        ])
        isPurchasing = true
        Task {
            do {
                try await storeManager.purchase(package: package)
            } catch {
                print("Purchase failed: \(error)")
                AnalyticsManager.shared.capture("purchase_failed", properties: ["error": error.localizedDescription])
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
    let delay: Double
    let animate: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(currentTheme.accent)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .serif))
                    .foregroundStyle(currentTheme.textForeground)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.6))
            }
        }
        .opacity(animate ? 1 : 0)
        .offset(x: animate ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animate)
    }
}

struct CompactPricingButton: View {
    let title: String
    let price: String
    var isBestValue: Bool = false
    let theme: AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 11, weight: .bold, design: .serif))
                    .foregroundStyle(theme.textForeground.opacity(0.7))
                
                Text(price)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(theme.accent)
                
                if isBestValue {
                    Text("SAVE 58%")
                        .font(.system(size: 7, weight: .black))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(theme.accent)
                        .foregroundStyle(theme.bg)
                        .clipShape(Capsule())
                } else {
                    // Empty space to maintain height parity
                    Text("")
                        .font(.system(size: 7))
                        .padding(.vertical, 2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(theme.fieldBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isBestValue ? theme.accent.opacity(0.4) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
