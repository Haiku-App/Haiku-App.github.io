import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @State private var currentPage = 0
    @State private var selectedGoal: UserGoal? = nil
    @State private var taskTitle: String = ""
    @State private var selectedTimeSlot: TimeSlot = .morning
    @FocusState private var taskTitleFocused: Bool

    // MARK: - Models

    enum UserGoal: String, CaseIterable {
        case work = "Work & Focus"
        case personal = "Personal Life"
        case both = "A Bit of Both"

        var emoji: String {
            switch self {
            case .work:     return "💼"
            case .personal: return "🌿"
            case .both:     return "⚖️"
            }
        }

        var suggestedTask: String {
            switch self {
            case .work:     return "Deep Work"
            case .personal: return "Morning Run"
            case .both:     return "Morning Routine"
            }
        }

        /// Category name to assign — matches default categories where possible
        var categoryName: String {
            switch self {
            case .work:     return "Deep Work"   // matches default category exactly
            case .personal: return "Personal"
            case .both:     return "Routine"
            }
        }

        var fallbackColor: Color {
            switch self {
            case .work:     return Color(red: 0.75, green: 0.55, blue: 0.45)   // terracotta
            case .personal: return Color(red: 0.45, green: 0.65, blue: 0.85)  // blue
            case .both:     return Color(red: 0.55, green: 0.72, blue: 0.55)  // sage
            }
        }
    }

    enum TimeSlot: String, CaseIterable {
        case morning = "Morning"
        case afternoon = "Afternoon"
        case evening = "Evening"

        var startMinutes: Int {
            switch self {
            case .morning:   return 9 * 60
            case .afternoon: return 13 * 60
            case .evening:   return 18 * 60
            }
        }

        var endMinutes: Int {
            switch self {
            case .morning:   return 11 * 60
            case .afternoon: return 15 * 60
            case .evening:   return 20 * 60
            }
        }

        var timeLabel: String {
            switch self {
            case .morning:   return "9 – 11 AM"
            case .afternoon: return "1 – 3 PM"
            case .evening:   return "6 – 8 PM"
            }
        }

        var clockHour: Int {
            switch self {
            case .morning:   return 10
            case .afternoon: return 14
            case .evening:   return 19
            }
        }
    }

    // MARK: - Derived

    private var builtTask: ClockTask {
        let title = taskTitle.trimmingCharacters(in: .whitespaces).isEmpty
            ? (selectedGoal?.suggestedTask ?? "My First Task")
            : taskTitle
        let goalCategoryName = selectedGoal?.categoryName
        let matchedCategory = CategoryManager.shared.categories.first {
            $0.name.caseInsensitiveCompare(goalCategoryName ?? "") == .orderedSame
        }
        let color = matchedCategory?.color ?? selectedGoal?.fallbackColor ?? Color(red: 0.55, green: 0.72, blue: 0.55)
        return ClockTask(
            title: title,
            startMinutes: selectedTimeSlot.startMinutes,
            endMinutes: selectedTimeSlot.endMinutes,
            color: color,
            categoryId: matchedCategory?.id,
            categoryName: goalCategoryName
        )
    }

    private var clockPreviewDate: Date {
        Calendar.current.date(bySettingHour: selectedTimeSlot.clockHour, minute: 0, second: 0, of: Date()) ?? Date()
    }

    private var displayTitle: String {
        let t = taskTitle.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? (selectedGoal?.suggestedTask ?? "your task") : t
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            currentTheme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // Pages
                ZStack {
                    if currentPage == 0 { introPage.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentPage == 1 { goalPage.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentPage == 2 { taskPage.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                    if currentPage == 3 { notificationPage.transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i == currentPage ? currentTheme.accent : currentTheme.accent.opacity(0.25))
                            .frame(width: i == currentPage ? 8 : 6, height: i == currentPage ? 8 : 6)
                            .animation(.spring(response: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 16)

                // Navigation
                VStack(spacing: 14) {
                    if currentPage < 3 {
                        primaryButton

                        Button(action: {
                            AnalyticsManager.shared.capture("onboarding_skipped", properties: ["page_skipped_from": currentPage])
                            completeOnboarding(requestNotifications: false)
                        }) {
                            Text("Skip")
                                .font(.system(size: 14, design: .serif))
                                .foregroundStyle(currentTheme.accent.opacity(0.5))
                        }
                    } else {
                        // Notification step has its own buttons inline — just reserve space
                        Color.clear.frame(height: 50)
                        Color.clear.frame(height: 20)
                    }
                }
                .padding(.bottom, 28)
            }
        }
    }

    // MARK: - Primary button

    private var primaryButton: some View {
        Button(action: advance) {
            Text(currentPage == 2 ? "Add to my day →" : "Next")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(currentTheme.bg)
                .frame(width: 200, height: 50)
                .background(currentTheme.accent.opacity(canAdvance ? 1 : 0.4))
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .shadow(color: currentTheme.accent.opacity(0.3), radius: 10, x: 0, y: 5)
        }
        .disabled(!canAdvance)
    }

    private var canAdvance: Bool {
        if currentPage == 1 { return selectedGoal != nil }
        return true
    }

    private func advance() {
        taskTitleFocused = false
        withAnimation(.easeInOut(duration: 0.35)) {
            currentPage += 1
        }
    }

    // MARK: - Step 0: Intro

    private var introPage: some View {
        VStack(spacing: 40) {
            Spacer()

            // Animated clock illustration
            let mockTasks = [
                ClockTask(title: "Morning Routine",   startMinutes: 6 * 60,      endMinutes: 8 * 60 + 30, color: Color(red: 0.45, green: 0.65, blue: 0.85)),
                ClockTask(title: "Deep Focus",        startMinutes: 10 * 60,     endMinutes: 13 * 60,     color: Color(red: 0.85, green: 0.55, blue: 0.45)),
                ClockTask(title: "Afternoon Flow",    startMinutes: 14 * 60 + 30,endMinutes: 17 * 60,     color: Color(red: 0.65, green: 0.75, blue: 0.55)),
                ClockTask(title: "Evening Wind Down", startMinutes: 19 * 60,     endMinutes: 21 * 60 + 30,color: Color(red: 0.75, green: 0.65, blue: 0.85))
            ]
            StaticClockView(
                now: Calendar.current.date(bySettingHour: 10, minute: 15, second: 0, of: Date()) ?? Date(),
                tasks: mockTasks,
                is24HourClock: true,
                theme: currentTheme,
                showHands: true,
                showText: true,
                showCenterText: false,
                animationProgress: 1.0
            )
            .frame(width: 280, height: 280)

            VStack(spacing: 14) {
                Text("HAIKU")
                    .font(.system(size: 28, weight: .bold, design: .serif))
                    .foregroundStyle(currentTheme.accent)
                    .tracking(8)

                Text("Your day, on a clock.")
                    .font(.system(size: 18, weight: .medium, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))

                Text("Add tasks to a 24-hour clock face and actually see your day — not just a list of boxes.")
                    .font(.system(size: 15, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
        }
    }

    // MARK: - Step 1: Goal picker

    private var goalPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 32) {
                VStack(spacing: 12) {
                    Text("QUICK QUESTION")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(3)

                    Text("What do you mostly plan?")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(1)
                        .multilineTextAlignment(.center)

                    Text("We'll suggest a first task to get you started.")
                        .font(.system(size: 14, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 10) {
                    ForEach(UserGoal.allCases, id: \.self) { goal in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedGoal = goal
                                taskTitle = goal.suggestedTask
                            }
                        }) {
                            HStack(spacing: 16) {
                                Text(goal.emoji)
                                    .font(.system(size: 22))
                                Text(goal.rawValue)
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundStyle(currentTheme.textForeground)
                                Spacer()
                                if selectedGoal == goal {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(currentTheme.accent)
                                        .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(currentTheme.fieldBg)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(selectedGoal == goal ? currentTheme.accent.opacity(0.5) : Color.clear, lineWidth: 1.5)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 2: Task builder

    private var taskPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 10) {
                    Text("ADD YOUR FIRST TASK")
                        .font(.system(size: 12, weight: .regular, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(3)

                    Text("See your day take shape.")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(1)
                }

                // Live clock — updates as they pick time
                StaticClockView(
                    now: clockPreviewDate,
                    tasks: [builtTask],
                    is24HourClock: true,
                    theme: currentTheme,
                    showHands: true,
                    showText: true,
                    showCenterText: false,
                    animationProgress: 1.0
                )
                .frame(width: 190, height: 190)
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: selectedTimeSlot)

                VStack(spacing: 10) {
                    // Task name field
                    TextField("Task name", text: $taskTitle)
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(currentTheme.textForeground)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(currentTheme.fieldBg))
                        .focused($taskTitleFocused)

                    // Time slot selector
                    HStack(spacing: 8) {
                        ForEach(TimeSlot.allCases, id: \.self) { slot in
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    selectedTimeSlot = slot
                                }
                                taskTitleFocused = false
                            }) {
                                VStack(spacing: 3) {
                                    Text(slot.rawValue)
                                        .font(.system(size: 13, weight: .semibold, design: .serif))
                                        .foregroundStyle(selectedTimeSlot == slot ? currentTheme.bg : currentTheme.textForeground)
                                    Text(slot.timeLabel)
                                        .font(.system(size: 10, design: .serif))
                                        .foregroundStyle(selectedTimeSlot == slot ? currentTheme.bg.opacity(0.75) : currentTheme.textForeground.opacity(0.45))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedTimeSlot == slot ? currentTheme.accent : currentTheme.fieldBg)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 32)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Step 3: Notification ask

    private var notificationPage: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 28) {
                // Their actual task on the clock
                StaticClockView(
                    now: clockPreviewDate,
                    tasks: [builtTask],
                    is24HourClock: true,
                    theme: currentTheme,
                    showHands: true,
                    showText: true,
                    showCenterText: false,
                    animationProgress: 1.0
                )
                .frame(width: 210, height: 210)

                VStack(spacing: 12) {
                    Text("Looking good.")
                        .font(.system(size: 26, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(2)

                    Text("Want a heads-up before \"\(displayTitle)\" starts?")
                        .font(.system(size: 15, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        AnalyticsManager.shared.capture("onboarding_notification_accepted")
                        completeOnboarding(requestNotifications: true)
                    }) {
                        Text("Yes, remind me")
                            .font(.system(size: 17, weight: .semibold, design: .serif))
                            .foregroundStyle(currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(currentTheme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .shadow(color: currentTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 32)

                    Button(action: {
                        AnalyticsManager.shared.capture("onboarding_notification_skipped")
                        completeOnboarding(requestNotifications: false)
                    }) {
                        Text("Not now")
                            .font(.system(size: 14, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.35))
                    }
                }
            }

            Spacer()
            Spacer()
        }
    }

    private func completeOnboarding(requestNotifications: Bool) {
        saveFirstTask()

        if requestNotifications {
            NotificationManager.shared.requestAuthorization()
        }

        AnalyticsManager.shared.capture("onboarding_completed", properties: [
            "goal": selectedGoal?.rawValue ?? "skipped",
            "task_title": builtTask.title,
            "time_slot": selectedTimeSlot.rawValue,
            "notifications_accepted": requestNotifications ? "true" : "false",
        ])

        withAnimation(.spring()) {
            hasCompletedOnboarding = true
        }
    }

    private func saveFirstTask() {
        let today = Calendar.current.startOfDay(for: Date())
        var existing = SharedTaskManager.shared.load() ?? [:]
        var todayTasks = existing[today, default: []]
        todayTasks.append(builtTask)
        existing[today] = todayTasks
        SharedTaskManager.shared.save(tasksByDate: existing)
    }
}

#Preview {
    OnboardingView()
}
