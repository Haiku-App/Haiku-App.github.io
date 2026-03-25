import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    
    var body: some View {
        ZStack {
            currentTheme.bg.ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    OnboardingStepView(
                        title: "HAIKU",
                        subtitle: "Time, simplified.",
                        description: "Experience a more mindful way to manage your day through visual flow.",
                        imageName: "clock",
                        step: 0,
                        theme: currentTheme
                    )
                    .tag(0)

                    OnboardingStepView(
                        title: "A Circle to Live In",
                        subtitle: "Find your center.",
                        description: "Time isn’t just a list of boxes to check. It’s a circle to live in. By visualizing your day as a flow, you find more space for what matters.",
                        imageName: "leaf.fill",
                        step: 1,
                        theme: currentTheme
                    )
                    .tag(1)
                    
                    OnboardingStepView(
                        title: "Visual Flow",
                        subtitle: "See your tasks.",
                        description: "Your schedule is laid out on a 24-hour clock, giving you a natural sense of time.",
                        imageName: "calendar",
                        step: 2,
                        theme: currentTheme
                    )
                    .tag(2)
                    
                    OnboardingStepView(
                        title: "Gentle Reminders",
                        subtitle: "Stay in your rhythm.",
                        description: "Get subtle notifications before your next task, so you never have to rush.",
                        imageName: "bell",
                        step: 3,
                        theme: currentTheme
                    )
                    .tag(3)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                
                VStack(spacing: 20) {
                    if currentPage == 3 {
                        Button(action: {
                            NotificationManager.shared.requestAuthorization()
                            // PostHog: Track onboarding completion
                            AnalyticsManager.shared.capture("onboarding_completed")
                            withAnimation(.spring()) {
                                hasCompletedOnboarding = true
                            }
                        }) {
                            Text("Get Started")
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(currentTheme.bg)
                                .frame(width: 200, height: 50)
                                .background(currentTheme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .shadow(color: currentTheme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Button(action: {
                            withAnimation {
                                currentPage += 1
                            }
                        }) {
                            Text("Next")
                                .font(.system(size: 18, weight: .medium, design: .serif))
                                .foregroundStyle(currentTheme.accent)
                                .frame(width: 200, height: 50)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 15)
                                        .stroke(currentTheme.accent, lineWidth: 1)
                                )
                        }
                    }
                    
                    Button(action: {
                        // PostHog: Track onboarding skip
                        AnalyticsManager.shared.capture("onboarding_skipped", properties: [
                            "page_skipped_from": currentPage,
                        ])
                        withAnimation {
                            hasCompletedOnboarding = true
                        }
                    }) {
                        Text("Skip")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(currentTheme.accent.opacity(0.6))
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct OnboardingStepView: View {
    let title: String
    let subtitle: String
    let description: String
    let imageName: String
    let step: Int
    let theme: AppTheme
    
    @State private var isAnimating = false
    @State private var animationProgress: Double = 0.0
    
    // Mock tasks for Step 1
    private let mockTasks = [
        ClockTask(title: "Morning Yoga", startMinutes: 7 * 60, endMinutes: 8 * 60, color: Color(red: 0.85, green: 0.78, blue: 0.58)),
        ClockTask(title: "Deep Work", startMinutes: 9 * 60, endMinutes: 12 * 60, color: Color(red: 0.75, green: 0.55, blue: 0.45)),
        ClockTask(title: "Lunch Break", startMinutes: 12 * 60, endMinutes: 13 * 60, color: Color(red: 0.45, green: 0.50, blue: 0.35))
    ]
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            // Animated Illustration Area
            ZStack {
                if step == 0 {
                    // Step 0: Realistic Clock with Mock Tasks
                    StaticClockView(
                        now: Calendar.current.date(bySettingHour: 10, minute: 15, second: 0, of: Date()) ?? Date(),
                        tasks: mockTasks,
                        is24HourClock: false,
                        theme: theme,
                        showHands: true,
                        showText: true,
                        showCenterText: false,
                        animationProgress: animationProgress
                    )
                    .frame(width: 280, height: 280)
                    .scaleEffect(isAnimating ? 1.0 : 0.8)
                    .opacity(isAnimating ? 1.0 : 0)
                    .onAppear {
                        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                            isAnimating = true
                        }
                        withAnimation(.easeInOut(duration: 1.5).delay(0.2)) {
                            animationProgress = 1.0
                        }
                    }
                } else if step == 1 {
                    // Step 1: Zen Ripple Animation
                    ZStack {
                        ForEach(0..<4) { i in
                            Circle()
                                .stroke(theme.accent.opacity(0.3), lineWidth: 1)
                                .frame(width: 100, height: 100)
                                .scaleEffect(isAnimating ? 3.0 : 1.0)
                                .opacity(isAnimating ? 0.0 : 1.0)
                                .animation(
                                    .easeOut(duration: 3.0)
                                    .repeatForever(autoreverses: false)
                                    .delay(Double(i) * 0.7),
                                    value: isAnimating
                                )
                        }
                        
                        Image(systemName: "leaf.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(theme.accent)
                            .shadow(color: theme.accent.opacity(0.3), radius: 10)
                            .scaleEffect(isAnimating ? 1.05 : 0.95)
                            .animation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true), value: isAnimating)
                    }
                    .onAppear {
                        isAnimating = true
                    }
                } else if step == 2 {
                    // Step 2: Animated Task Timeline
                    VStack(alignment: .leading, spacing: 15) {
                        ForEach(0..<3) { i in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(mockTasks[i].color)
                                    .frame(width: 12, height: 12)
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(theme.fieldBg)
                                    .frame(width: 180, height: 44)
                                    .overlay(
                                        Text(mockTasks[i].title)
                                            .font(.system(size: 14, weight: .medium, design: .serif))
                                            .foregroundStyle(theme.textForeground.opacity(0.8))
                                            .padding(.leading, 12),
                                        alignment: .leading
                                    )
                                    .shadow(color: theme.shadowDark, radius: 4, x: 2, y: 2)
                            }
                            .offset(x: isAnimating ? 0 : -200)
                            .opacity(isAnimating ? 1 : 0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(Double(i) * 0.2), value: isAnimating)
                        }
                    }
                    .onAppear { isAnimating = true }
                } else {
                    // Step 3: Beautiful Pulsing Bell
                    ZStack {
                        Circle()
                            .fill(theme.accent.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .scaleEffect(isAnimating ? 1.2 : 0.8)
                        
                        Circle()
                            .stroke(theme.accent.opacity(0.2), lineWidth: 1)
                            .frame(width: 250, height: 250)
                            .scaleEffect(isAnimating ? 1.1 : 0.9)

                        Image(systemName: "bell.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(theme.accent)
                            .rotationEffect(.degrees(isAnimating ? 15 : -15))
                    }
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            isAnimating = true
                        }
                    }
                }
            }
            .frame(height: 300)
            
            VStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(theme.accent)
                    .tracking(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Text(subtitle)
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(theme.textForeground.opacity(0.9))
                
                Text(description)
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(theme.textForeground.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
        }
    }
}


#Preview {
    OnboardingView()
}
