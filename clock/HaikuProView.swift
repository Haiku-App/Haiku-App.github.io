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
    @State private var selectedPlan: PlanType = .annual
    @State private var showDismissButton = false

    /// Pass to highlight the feature that triggered this paywall (e.g. "analytics", "calendar", "notifications", "widgets")
    var focusFeature: String? = nil

    enum PlanType { case monthly, annual }

    var body: some View {
        ZStack {
            currentTheme.bg.ignoresSafeArea()

            // Ambient blobs
            ZStack {
                Circle()
                    .fill(currentTheme.accent.opacity(0.12))
                    .frame(width: 300)
                    .blur(radius: 60)
                    .offset(x: appearanceAnimate ? 100 : -100, y: -180)
                Circle()
                    .fill(currentTheme.accent.opacity(0.08))
                    .frame(width: 250)
                    .blur(radius: 50)
                    .offset(x: appearanceAnimate ? -120 : 80, y: 180)
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: appearanceAnimate)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {

                    // MARK: Header
                    VStack(spacing: 10) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(currentTheme.accent)
                            .shadow(color: currentTheme.accent.opacity(0.3), radius: 10)
                            .offset(y: appearanceAnimate ? -6 : 0)
                            .animation(.easeInOut(duration: 3).repeatForever(autoreverses: true), value: appearanceAnimate)

                        Text("HAIKU PRO")
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(currentTheme.accent)
                            .tracking(8)

                        Text("The focus layer your calendar is missing.")
                            .font(.system(size: 14, weight: .light, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 52)
                    .opacity(appearanceAnimate ? 1 : 0)
                    .offset(y: appearanceAnimate ? 0 : 10)

                    // MARK: Social proof
                    HStack(spacing: 4) {
                        ForEach(0..<5, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(currentTheme.accent)
                        }
                        Text("4.8 · 2,400+ ratings")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.45))
                    }
                    .padding(.top, 14)
                    .opacity(appearanceAnimate ? 1 : 0)

                    // MARK: Features
                    VStack(alignment: .leading, spacing: 14) {
                        ProFeatureRow(
                            icon: "chart.bar.fill",
                            title: "Power Hours Analytics",
                            description: "See exactly where your hours go.",
                            highlight: focusFeature == "analytics",
                            delay: 0.1, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "bell.badge.fill",
                            title: "Custom Notifications",
                            description: "Never miss a task start time.",
                            highlight: focusFeature == "notifications",
                            delay: 0.2, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "calendar.badge.plus",
                            title: "2-Way Calendar Sync",
                            description: "Your calendar and tasks, always aligned.",
                            highlight: focusFeature == "calendar",
                            delay: 0.3, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "square.grid.2x2.fill",
                            title: "Aesthetic Widgets",
                            description: "Your day at a glance, without opening the app.",
                            highlight: focusFeature == "widgets",
                            delay: 0.4, animate: appearanceAnimate
                        )
                    }
                    .padding(.horizontal, 36)
                    .padding(.top, 28)

                    // MARK: Pricing
                    if let offering = storeManager.paywallOffering {
                        planSelector(offering: offering)
                            .padding(.top, 24)
                            .opacity(appearanceAnimate ? 1 : 0)
                            .scaleEffect(appearanceAnimate ? 1 : 0.97)
                    } else if storeManager.isSandboxMode && storeManager.paywallOffering == nil {
                        sandboxView.padding(.top, 24)
                    } else if !storeManager.isRevenueCatConfigured {
                        unconfiguredView.padding(.top, 24)
                    } else {
                        loadingView.padding(.top, 24)
                    }

                    // MARK: Footer links
                    HStack(spacing: 20) {
                        Button("Restore") {
                            Task { await storeManager.restore() }
                        }
                        .disabled(!storeManager.isRevenueCatConfigured)

                        if storeManager.isPro && storeManager.isRevenueCatConfigured {
                            Button("Manage") { showingCustomerCenter = true }
                        }

                        Button("Maybe Later") {
                            AnalyticsManager.shared.capture("paywall_dismissed")
                            dismiss()
                        }
                    }
                    .font(.system(size: 11, weight: .medium, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.3))
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }

            // MARK: Delayed close button (appears after 3s)
            if showDismissButton {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            AnalyticsManager.shared.capture("paywall_dismissed")
                            dismiss()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 26))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.15))
                        }
                        .padding(20)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }

            // MARK: Purchase overlay
            if isPurchasing {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    ProgressView("Processing...")
                        .padding()
                        .background(RoundedRectangle(cornerRadius: 12).fill(currentTheme.fieldBg))
                }
            }
        }
        .sheet(isPresented: $showingCustomerCenter) {
            CustomerCenterView()
        }
        .onAppear {
            var props: [String: String] = [:]
            if let f = focusFeature { props["focus_feature"] = f }
            AnalyticsManager.shared.capture("paywall_viewed", properties: props)

            withAnimation(.easeOut(duration: 0.7)) { appearanceAnimate = true }

            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(.easeIn(duration: 0.3)) { showDismissButton = true }
            }
        }
        .onChange(of: storeManager.isPro) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Plan selector

    @ViewBuilder
    private func planSelector(offering: Offering) -> some View {
        VStack(spacing: 12) {
            if let annual = offering.annual {
                PlanOptionRow(
                    title: "Annual",
                    price: annual.localizedPriceString + "/yr",
                    perMonth: monthlyEquivalent(for: annual),
                    badge: "BEST VALUE · SAVE 58%",
                    trialLabel: trialLabel(for: annual),
                    isSelected: selectedPlan == .annual,
                    theme: currentTheme
                ) { selectedPlan = .annual }
            }

            if let monthly = offering.monthly {
                PlanOptionRow(
                    title: "Monthly",
                    price: monthly.localizedPriceString + "/mo",
                    perMonth: nil,
                    badge: nil,
                    trialLabel: trialLabel(for: monthly),
                    isSelected: selectedPlan == .monthly,
                    theme: currentTheme
                ) { selectedPlan = .monthly }
            }

            // Primary CTA
            Button(action: { purchaseSelected(offering: offering) }) {
                Text(ctaTitle(offering: offering))
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(currentTheme.bg)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(currentTheme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if let subtitle = ctaSubtitle(offering: offering) {
                Text(subtitle)
                    .font(.system(size: 10, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.35))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 28)
    }

    private func ctaTitle(offering: Offering) -> String {
        let pkg = selectedPlan == .annual ? offering.annual : offering.monthly
        let hasTrial = pkg.flatMap { trialLabel(for: $0) } != nil
        switch selectedPlan {
        case .annual: return hasTrial ? "Start Free Trial" : "Start Annual Plan"
        case .monthly: return hasTrial ? "Start Free Trial" : "Start Monthly Plan"
        }
    }

    private func ctaSubtitle(offering: Offering) -> String? {
        let pkg = selectedPlan == .annual ? offering.annual : offering.monthly
        guard let pkg else { return "Cancel anytime." }
        if let trial = trialLabel(for: pkg) {
            let price = pkg.localizedPriceString
            let period = selectedPlan == .annual ? "/yr" : "/mo"
            return "\(trial) free, then \(price)\(period). Cancel anytime."
        }
        return "Cancel anytime."
    }

    private func trialLabel(for package: Package) -> String? {
        guard let discount = package.storeProduct.introductoryDiscount,
              discount.price == 0 else { return nil }
        let value = discount.subscriptionPeriod.value
        switch discount.subscriptionPeriod.unit {
        case .day:   return "\(value)-Day"
        case .week:  return "\(value * 7)-Day"
        case .month: return "\(value)-Month"
        default:     return "\(value)-Day"
        }
    }

    private func monthlyEquivalent(for package: Package) -> String? {
        guard package.packageType == .annual else { return nil }
        let monthly = package.storeProduct.price / 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = package.storeProduct.currencyCode ?? "USD"
        formatter.maximumFractionDigits = 2
        guard let formatted = formatter.string(from: monthly as NSDecimalNumber) else { return nil }
        return "\(formatted)/mo"
    }

    private func purchaseSelected(offering: Offering) {
        let pkg: Package? = selectedPlan == .annual ? offering.annual : offering.monthly
        guard let pkg else { return }
        buyPro(pkg)
    }

    private func buyPro(_ package: Package) {
        if storeManager.allowsTesterUnlocks {
            storeManager.unlockProForFree()
            return
        }
        AnalyticsManager.shared.capture("purchase_initiated", properties: [
            "package_identifier": package.identifier,
            "price": package.localizedPriceString,
            "plan_type": selectedPlan == .annual ? "annual" : "monthly",
        ])
        isPurchasing = true
        Task {
            do {
                try await storeManager.purchase(package: package)
            } catch {
                AnalyticsManager.shared.capture("purchase_failed", properties: ["error": error.localizedDescription])
            }
            isPurchasing = false
        }
    }

    // MARK: - State fallback views

    private var sandboxView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 24))
                .foregroundStyle(currentTheme.accent)
            Text("Reviewer / Sandbox Mode")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(currentTheme.textForeground)
            Text("Products are still being approved. Use the free unlock below to test Pro features.")
                .font(.system(size: 11))
                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                AnalyticsManager.shared.capture("testflight_free_unlock_clicked")
                storeManager.unlockProForFree()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("UNLOCK FOR FREE (REVIEWER)")
                }
                .font(.system(size: 13, weight: .bold, design: .serif))
                .foregroundStyle(currentTheme.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(currentTheme.accent.opacity(0.1))
                .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 28)
    }

    private var unconfiguredView: some View {
        VStack(spacing: 8) {
            Image(systemName: storeManager.allowsTesterUnlocks ? "wrench.and.screwdriver.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(currentTheme.accent)
            Text(storeManager.allowsTesterUnlocks ? "Tester build detected." : "Purchases unavailable in this build.")
                .font(.system(size: 13, weight: .semibold, design: .serif))
                .foregroundStyle(currentTheme.textForeground)
            Text(storeManager.allowsTesterUnlocks ? "Use the free tester unlock below to access Pro." : "Add a RevenueCat API key to enable subscriptions.")
                .font(.system(size: 11, weight: .regular, design: .serif))
                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }

    private var loadingView: some View {
        VStack(spacing: 16) {
            if storeManager.lastError != nil {
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(currentTheme.accent)
                Text("Could not load products.")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(currentTheme.textForeground)
                Text("Please check your internet connection and try again.")
                    .font(.system(size: 11))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button(action: { storeManager.refreshOfferings() }) {
                    Text("Retry")
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(currentTheme.accent.opacity(0.1))
                        .clipShape(Capsule())
                }
            } else {
                ProgressView()
                    .tint(currentTheme.accent)
                Text("Syncing with App Store...")
                    .font(.system(size: 11))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                    .padding(.top, 8)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8.0) {
                            if storeManager.paywallOffering == nil && storeManager.lastError == nil {
                                storeManager.refreshOfferings()
                            }
                        }
                    }
            }
        }
        .padding(.horizontal, 28)
    }
}

// MARK: - Plan option row

struct PlanOptionRow: View {
    let title: String
    let price: String
    let perMonth: String?
    let badge: String?
    let trialLabel: String?
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? theme.accent : theme.textForeground.opacity(0.2), lineWidth: 2)
                        .frame(width: 20, height: 20)
                    if isSelected {
                        Circle()
                            .fill(theme.accent)
                            .frame(width: 10, height: 10)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(theme.textForeground)
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .black))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(theme.accent)
                                .foregroundStyle(theme.bg)
                                .clipShape(Capsule())
                        }
                    }
                    if let trialLabel {
                        Text("\(trialLabel) free trial included")
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(theme.accent.opacity(0.8))
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(price)
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(isSelected ? theme.accent : theme.textForeground)
                    if let perMonth {
                        Text(perMonth)
                            .font(.system(size: 11, design: .serif))
                            .foregroundStyle(theme.textForeground.opacity(0.45))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(theme.fieldBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(isSelected ? theme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Feature row

struct ProFeatureRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    let icon: String
    let title: String
    let description: String
    var highlight: Bool = false
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
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(highlight ? currentTheme.accent : currentTheme.textForeground)
                Text(description)
                    .font(.system(size: 12))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.6))
            }

            Spacer()

            if highlight {
                Text("THIS ONE")
                    .font(.system(size: 7, weight: .black))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(currentTheme.accent.opacity(0.15))
                    .foregroundStyle(currentTheme.accent)
                    .clipShape(Capsule())
            }
        }
        .padding(highlight ? 10 : 0)
        .background(
            Group {
                if highlight {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(currentTheme.accent.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(currentTheme.accent.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        )
        .opacity(animate ? 1 : 0)
        .offset(x: animate ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(delay), value: animate)
    }
}
