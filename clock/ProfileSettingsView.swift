import SwiftUI
import EventKit

struct ProfileSettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("notificationOffsetsData") private var notificationOffsetsData = ""
    @AppStorage(CalendarSyncProvider.storageKey) private var activeCalendarSyncProvider: CalendarSyncProvider = .none
    @AppStorage(ReminderManager.syncEnabledKey) private var isAppleRemindersSyncEnabled = false
    @EnvironmentObject var storeManager: StoreManager
    private var isPro: Bool { storeManager.isPro }
    @ObservedObject var googleCalendarManager = GoogleCalendarManager.shared
    @ObservedObject private var reminderManager = ReminderManager.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var appleCalendarStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var appleRemindersStatus: EKAuthorizationStatus = ReminderManager.currentAuthorizationStatus()
    
    @Binding var is24HourClock: Bool
    @Binding var showingCustomOffsetAlert: Bool
    @State private var showingPaywall = false
    @State private var paywallFocusFeature: String? = nil
    private let isGoogleSignInEnabled = AppConfiguration.isGoogleSignInEnabled

    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }
    private var testingProBinding: Binding<Bool> {
        Binding(
            get: { storeManager.isTestingProEnabled },
            set: { storeManager.setTestingProEnabled($0) }
        )
    }
    private var appVersionText: String {
        return "Version 1.2"
    }

    private var isAppleConnected: Bool {
        activeCalendarSyncProvider == .apple
    }

    private var isGoogleConnected: Bool {
        activeCalendarSyncProvider == .google && googleCalendarManager.isSignedIn
    }

    private var appleButtonBlockedByGoogle: Bool {
        activeCalendarSyncProvider == .google
    }

    private var googleButtonBlockedByApple: Bool {
        activeCalendarSyncProvider == .apple
    }

    private var isAppleAuthorized: Bool {
        CalendarManager.hasCalendarAccess(status: appleCalendarStatus)
    }

    private var isAppleRemindersAuthorized: Bool {
        ReminderManager.hasReminderAccess(status: appleRemindersStatus)
    }

    private var isAppleRemindersConnected: Bool {
        isAppleRemindersSyncEnabled && isAppleRemindersAuthorized
    }

    private var offsets: [Int] {
        if notificationOffsetsData.isEmpty { return [] }
        return notificationOffsetsData.split(separator: ",").compactMap { Int($0) }
    }

    private var uses12HourClock: Binding<Bool> {
        Binding(
            get: { !is24HourClock },
            set: { is24HourClock = !$0 }
        )
    }
    
    private func toggleOffset(_ offset: Int) {
        var current = Set(offsets)
        if current.contains(offset) {
            current.remove(offset)
        } else {
            current.insert(offset)
            NotificationManager.shared.requestAuthorization()
        }
        notificationOffsetsData = current.sorted().map(String.init).joined(separator: ",")
    }

    private func refreshAppleCalendarStatus() {
        appleCalendarStatus = CalendarManager.currentAuthorizationStatus()
    }

    private func refreshAppleRemindersStatus() {
        appleRemindersStatus = ReminderManager.currentAuthorizationStatus()
        if !ReminderManager.hasReminderAccess(status: appleRemindersStatus),
           appleRemindersStatus == .denied || appleRemindersStatus == .restricted {
            isAppleRemindersSyncEnabled = false
        }
    }

    private func toggleAppleCalendarConnection() {
        if isAppleConnected {
            activeCalendarSyncProvider = .none
            AnalyticsManager.shared.capture("apple_calendar_disconnected")
            return
        }

        guard !appleButtonBlockedByGoogle else { return }

        calendarManager.requestAccess { granted in
            refreshAppleCalendarStatus()

            guard granted else { return }

            activeCalendarSyncProvider = .apple
            AnalyticsManager.shared.capture("apple_calendar_connected")
        }
    }

    private func toggleGoogleCalendarConnection() {
        if isGoogleConnected {
            AnalyticsManager.shared.capture("google_signout_clicked")
            googleCalendarManager.signOut()
            activeCalendarSyncProvider = .none
            return
        }

        guard !googleButtonBlockedByApple else { return }

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            googleCalendarManager.signIn(presenting: rootVC) { didSignIn in
                guard didSignIn else { return }
                activeCalendarSyncProvider = .google
            }
        }
    }

    private func toggleAppleRemindersConnection() {
        if isAppleRemindersSyncEnabled {
            isAppleRemindersSyncEnabled = false
            AnalyticsManager.shared.capture("apple_reminders_disconnected")
            return
        }

        reminderManager.requestAccess { granted in
            refreshAppleRemindersStatus()

            guard granted else { return }

            isAppleRemindersSyncEnabled = true
            AnalyticsManager.shared.capture("apple_reminders_connected")
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Text("SETTINGS")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)

                if !isPro {
                    Button(action: { 
                        AnalyticsManager.shared.capture("upgrade_banner_clicked")
                        paywallFocusFeature = nil
                        showingPaywall = true
                    }) {
                        HStack {
                            Image(systemName: "crown.fill")
                                .foregroundStyle(goldColor)
                            Text("Upgrade to Haiku Pro")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(currentTheme.bg)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(currentTheme.bg.opacity(0.6))
                        }
                        .padding()
                        .background(goldColor)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: goldColor.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.horizontal, 40)
                    .buttonStyle(.plain)
                }

                VStack(spacing: 20) {
                    Toggle("12-Hour Clock", isOn: uses12HourClock)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                        .padding()
                        .tint(goldColor)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(currentTheme.fieldBg)
                                .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                        )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("NOTIFICATIONS")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        // Base options (5, 30) + Custom
                        let baseOptions = [5, 30]
                        let displayOptions = Array(Set(baseOptions + offsets)).sorted()
                        
                        VStack(spacing: 12) {
                            ForEach(displayOptions, id: \.self) { offset in
                                let isSelected = offsets.contains(offset)
                                Button(action: { toggleOffset(offset) }) {
                                    HStack {
                                        Text(offset == 0 ? "At time of event" : "\(offset) minutes before")
                                            .font(.system(size: 16, weight: .medium, design: .serif))
                                            .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                        Spacer()
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(goldColor)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(currentTheme.fieldBg)
                                            .shadow(color: currentTheme.shadowDark, radius: isSelected ? 2 : 5, x: isSelected ? 2 : 4, y: isSelected ? 2 : 4)
                                            .shadow(color: currentTheme.shadowLight, radius: isSelected ? 2 : 5, x: -4, y: -4)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Custom Button
                            Button(action: { 
                                if isPro {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        showingCustomOffsetAlert = true
                                    }
                                } else {
                                    AnalyticsManager.shared.capture("pro_feature_denied", properties: ["feature": "custom_notification"])
                                    AnalyticsManager.shared.capture("upgrade_custom_notification_clicked")
                                    paywallFocusFeature = "notifications"
                                    showingPaywall = true
                                }
                            }) {
                                HStack {
                                    Image(systemName: isPro ? "plus" : "lock.fill")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(goldColor)
                                    Text("Add Custom Time")
                                        .font(.system(size: 16, weight: .medium, design: .serif))
                                        .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                    Spacer()
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(currentTheme.fieldBg)
                                        .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("THEME")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(AppTheme.allCases) { theme in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            currentTheme = theme
                                        }
                                    }) {
                                        VStack(spacing: 8) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(theme.bg)
                                                
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(theme.fieldBg)
                                                    .frame(width: 24, height: 24)
                                                    .shadow(color: theme.shadowDark, radius: 2, x: 1, y: 1)
                                                    .shadow(color: theme.shadowLight, radius: 2, x: -1, y: -1)
                                            }
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(currentTheme == theme ? currentTheme.accent : Color.clear, lineWidth: 2)
                                            )
                                            .shadow(color: currentTheme.shadowDark, radius: currentTheme == theme ? 4 : 1, x: 1, y: 1)
                                            .scaleEffect(currentTheme == theme ? 1.05 : 1.0)
                                            
                                            Text(theme.name)
                                                .font(.system(size: 10, weight: currentTheme == theme ? .semibold : .regular, design: .serif))
                                                .foregroundStyle(currentTheme.textForeground.opacity(currentTheme == theme ? 0.9 : 0.5))
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 4)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CALENDARS")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        VStack(spacing: 8) {
                            // Apple Calendar Block
                            Button(action: {
                                if isPro {
                                    toggleAppleCalendarConnection()
                                } else {
                                    AnalyticsManager.shared.capture("pro_feature_denied", properties: ["feature": "apple_calendar"])
                                    AnalyticsManager.shared.capture("upgrade_apple_calendar_clicked")
                                    paywallFocusFeature = "calendar"
                                    showingPaywall = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isPro ? "apple.logo" : "lock.fill")
                                        .foregroundStyle(
                                            !isPro ? goldColor :
                                            (isAppleConnected ? Color.red : (appleButtonBlockedByGoogle ? currentTheme.textForeground.opacity(0.45) : goldColor))
                                        )
                                    Text(
                                        isAppleConnected
                                            ? "Disconnect Apple Calendar"
                                            : (appleButtonBlockedByGoogle ? "Disconnect Google Calendar First" : "Connect Apple Calendar")
                                    )
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                    Spacer()
                                    if isAppleConnected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.green)
                                    } else if isAppleAuthorized {
                                        Text("Ready")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(goldColor.opacity(0.8))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(currentTheme.fieldBg)
                                        .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(appleButtonBlockedByGoogle)

                            // Google Calendar Block
                            Button(action: {
                                if !isGoogleSignInEnabled {
                                    return
                                } else if isPro {
                                    toggleGoogleCalendarConnection()
                                } else {
                                    AnalyticsManager.shared.capture("pro_feature_denied", properties: ["feature": "google_calendar"])
                                    AnalyticsManager.shared.capture("upgrade_google_signin_clicked")
                                    paywallFocusFeature = "calendar"
                                    showingPaywall = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: !isGoogleSignInEnabled ? "clock.badge.exclamationmark" : (isPro ? "g.circle.fill" : "lock.fill"))
                                        .foregroundStyle(
                                            !isGoogleSignInEnabled ? currentTheme.textForeground.opacity(0.45) :
                                            (!isPro ? goldColor : (isGoogleConnected ? Color.red : (googleButtonBlockedByApple ? currentTheme.textForeground.opacity(0.45) : goldColor)))
                                        )
                                    Text(
                                        !isGoogleSignInEnabled
                                            ? "Google Calendar Unavailable"
                                            : (isGoogleConnected ? "Disconnect Google Calendar" : (googleButtonBlockedByApple ? "Disconnect Apple Calendar First" : (isPro ? "Connect Google Calendar" : "Google Calendar Sync")))
                                    )
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                    Spacer()
                                    if !isGoogleSignInEnabled {
                                        Text("Unavailable")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(goldColor)
                                    } else if isGoogleConnected {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color.green)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(currentTheme.fieldBg)
                                        .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(!isGoogleSignInEnabled || googleButtonBlockedByApple)

                            Text(
                                isGoogleSignInEnabled
                                    ? "Only one calendar can be connected at a time. Disconnect the current calendar before switching providers."
                                    : "Google sign-in is disabled in this build."
                            )
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .opacity(isPro ? 1.0 : 0.6)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("REMINDERS")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        Button(action: {
                            if isPro {
                                toggleAppleRemindersConnection()
                            } else {
                                AnalyticsManager.shared.capture("pro_feature_denied", properties: ["feature": "apple_reminders"])
                                AnalyticsManager.shared.capture("upgrade_apple_reminders_clicked")
                                paywallFocusFeature = "calendar"
                                showingPaywall = true
                            }
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: isPro ? "checklist" : "lock.fill")
                                    .foregroundStyle(
                                        !isPro ? goldColor : (isAppleRemindersConnected ? Color.red : goldColor)
                                    )
                                Text(
                                    isAppleRemindersConnected
                                        ? "Disconnect Apple Reminders"
                                        : (isPro ? "Connect Apple Reminders" : "Apple Reminders Sync")
                                )
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                Spacer()
                                if isAppleRemindersConnected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color.green)
                                } else if isAppleRemindersAuthorized {
                                    Text("Ready")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(goldColor.opacity(0.8))
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(currentTheme.fieldBg)
                                    .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                    .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .opacity(isPro ? 1.0 : 0.6)

                    if storeManager.allowsTesterUnlocks && AppConfiguration.isTestingMode {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TESTING")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                                .padding(.horizontal, 4)

                            Toggle("Testing Pro Access", isOn: testingProBinding)
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                .padding()
                                .tint(goldColor)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(currentTheme.fieldBg)
                                        .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                                )

                            Text("This toggle is only available in sandbox/testing mode and won’t appear in normal builds.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                    }

                    // Legal Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LEGAL")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        Link(destination: URL(string: "https://haikuapp.xyz/privacy.html")!) {
                            HStack {
                                Text("Privacy Policy")
                                    .font(.system(size: 16, weight: .medium, design: .serif))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                Spacer()
                                Image(systemName: "safari")
                                    .font(.system(size: 14))
                                    .foregroundStyle(goldColor)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(currentTheme.fieldBg)
                                    .shadow(color: currentTheme.shadowDark, radius: 5, x: 4, y: 4)
                                    .shadow(color: currentTheme.shadowLight, radius: 5, x: -4, y: -4)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // App Info
                    VStack(spacing: 8) {
                        Text("HAIKU")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(goldColor)
                        Text(appVersionText)
                            .font(.system(size: 10, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                    }
                    .padding(.top, 20)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .sheet(isPresented: $showingPaywall) {
            HaikuProView(focusFeature: paywallFocusFeature)
        }
        .onAppear {
            refreshAppleCalendarStatus()
            refreshAppleRemindersStatus()
        }
        .onChange(of: currentTheme) { oldTheme, newTheme in
            AnalyticsManager.shared.capture("theme_changed", properties: ["theme_name": newTheme.name])
        }
        .onChange(of: is24HourClock) { oldVal, newVal in
            AnalyticsManager.shared.capture("clock_format_toggled", properties: ["is_24_hour": newVal])
        }
        .onChange(of: googleCalendarManager.isSignedIn) { oldValue, newValue in
            if !newValue && activeCalendarSyncProvider == .google {
                activeCalendarSyncProvider = .none
            }
        }
        .onChange(of: reminderManager.eventsDidChange) { _, _ in
            refreshAppleRemindersStatus()
        }
    }
}
