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
    @State private var showDismissButton = false

    /// Pass to highlight the feature that triggered this paywall (e.g. "analytics", "calendar", "notifications", "routines")
    var focusFeature: String? = nil

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

                        Text("Unlock everything in Haiku Pro.")
                            .font(.system(size: 14, weight: .light, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.7))
                            .multilineTextAlignment(.center)

                        Text("Pay once. Keep it for life.")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.45))
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
                        Text("Future Pro updates included.")
                            .font(.system(size: 12, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.45))
                    }
                    .padding(.top, 14)
                    .opacity(appearanceAnimate ? 1 : 0)

                    // MARK: Features
                    VStack(alignment: .leading, spacing: 14) {
                        ProFeatureRow(
                            icon: "rectangle.stack.badge.plus",
                            title: "Unlimited Routines",
                            description: "Free includes 2 saved routines. Pro removes the cap.",
                            highlight: focusFeature == "routines",
                            delay: 0.1, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "bell.badge.fill",
                            title: "Custom Notifications",
                            description: "Get flexible reminders before your day drifts.",
                            highlight: focusFeature == "notifications",
                            delay: 0.2, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "calendar.badge.plus",
                            title: "Apple + Google Calendar Sync",
                            description: "Keep your clock aligned with the calendar you already use.",
                            highlight: focusFeature == "calendar",
                            delay: 0.3, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "checklist",
                            title: "Apple Reminders Sync",
                            description: "Turn brain-dump tasks into reminders without leaving Haiku.",
                            highlight: false,
                            delay: 0.4, animate: appearanceAnimate
                        )
                        ProFeatureRow(
                            icon: "chart.pie.fill",
                            title: "Insights",
                            description: "Unlock analytics like peak focus windows and momentum trends.",
                            highlight: focusFeature == "analytics",
                            delay: 0.5, animate: appearanceAnimate
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
                    } else if AppConfiguration.isTestingMode && storeManager.paywallOffering == nil {
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

    // MARK: - Paywall card

    @ViewBuilder
    private func planSelector(offering: Offering) -> some View {
        VStack(spacing: 12) {
            if let package = primaryPackage(from: offering) {
                LifetimeOfferCard(
                    title: package.packageType == .lifetime ? "Lifetime Access" : fallbackTitle(for: package),
                    price: package.localizedPriceString,
                    eyebrow: package.packageType == .lifetime ? "ONE-TIME PURCHASE" : "CURRENT APP STORE OFFER",
                    subtitle: package.packageType == .lifetime ? "Everything in Haiku Pro, unlocked forever." : fallbackSubtitle(for: package),
                    footnote: package.packageType == .lifetime ? "Future Pro updates included." : fallbackFootnote(for: package),
                    theme: currentTheme
                )
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
        guard let package = primaryPackage(from: offering) else { return "Unlock Pro" }
        if package.packageType == .lifetime {
            return "Unlock Pro for \(package.localizedPriceString)"
        }
        let hasTrial = trialLabel(for: package) != nil
        return hasTrial ? "Start Free Trial" : "Unlock Pro"
    }

    private func ctaSubtitle(offering: Offering) -> String? {
        guard let package = primaryPackage(from: offering) else { return nil }
        if package.packageType == .lifetime {
            return "No subscription."
        }
        if let trial = trialLabel(for: package) {
            return "\(trial) free, then \(package.localizedPriceString)\(periodSuffix(for: package)). Cancel anytime."
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

    private func primaryPackage(from offering: Offering) -> Package? {
        if let lifetime = offering.availablePackages.first(where: { $0.packageType == .lifetime }) {
            return lifetime
        }
        return offering.annual ?? offering.monthly ?? offering.availablePackages.first
    }

    private func purchaseSelected(offering: Offering) {
        let pkg = primaryPackage(from: offering)
        guard let pkg else { return }
        buyPro(pkg)
    }

    private func buyPro(_ package: Package) {
        AnalyticsManager.shared.capture("purchase_initiated", properties: [
            "package_identifier": package.identifier,
            "price": package.localizedPriceString,
            "plan_type": packageTypeLabel(for: package),
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

    private func periodSuffix(for package: Package) -> String {
        switch package.packageType {
        case .annual:
            return "/yr"
        case .monthly:
            return "/mo"
        default:
            return ""
        }
    }

    private func packageTypeLabel(for package: Package) -> String {
        switch package.packageType {
        case .lifetime:
            return "lifetime"
        case .annual:
            return "annual"
        case .monthly:
            return "monthly"
        default:
            return package.identifier
        }
    }

    private func fallbackTitle(for package: Package) -> String {
        switch package.packageType {
        case .annual:
            return "Annual Access"
        case .monthly:
            return "Monthly Access"
        default:
            return "Haiku Pro"
        }
    }

    private func fallbackSubtitle(for package: Package) -> String {
        if let trial = trialLabel(for: package) {
            return "\(trial) free, then \(package.localizedPriceString)\(periodSuffix(for: package))."
        }
        return "Unlock all Haiku Pro features."
    }

    private func fallbackFootnote(for package: Package) -> String {
        switch package.packageType {
        case .annual, .monthly:
            return "Subscription manages through your Apple ID. Cancel anytime."
        default:
            return "Future Pro updates included."
        }
    }

    // MARK: - State fallback views

    private var sandboxView: some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver.fill")
                .font(.system(size: 24))
                .foregroundStyle(currentTheme.accent)
            Text("Testing Mode")
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(currentTheme.textForeground)
            Text("Use the testing toggle below when you need to turn Haiku Pro on or off during sandbox testing.")
                .font(.system(size: 11))
                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Button(action: {
                AnalyticsManager.shared.capture("testflight_free_unlock_clicked")
                storeManager.setTestingProEnabled(!storeManager.isTestingProEnabled)
            }) {
                HStack(spacing: 8) {
                    Image(systemName: storeManager.isTestingProEnabled ? "xmark.seal.fill" : "checkmark.seal.fill")
                    Text(storeManager.isTestingProEnabled ? "TURN TESTING PRO OFF" : "TURN TESTING PRO ON")
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
            Text(storeManager.allowsTesterUnlocks ? "Testing controls appear only in sandbox/testing mode." : "Add a RevenueCat API key to enable purchases.")
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

// MARK: - Offer card

struct LifetimeOfferCard: View {
    let title: String
    let price: String
    let eyebrow: String
    let subtitle: String
    let footnote: String
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(eyebrow)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(theme.bg)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(theme.accent)
                .clipShape(Capsule())

            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(theme.textForeground)

                    Text(subtitle)
                        .font(.system(size: 13, weight: .light, design: .serif))
                        .foregroundStyle(theme.textForeground.opacity(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(price)
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundStyle(theme.accent)
                    Text("lifetime")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textForeground.opacity(0.45))
                }
            }

            Text(footnote)
                .font(.system(size: 11, design: .serif))
                .foregroundStyle(theme.textForeground.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(theme.fieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(theme.accent.opacity(0.35), lineWidth: 1.5)
                )
        )
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
