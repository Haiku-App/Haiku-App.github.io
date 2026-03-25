import SwiftUI
import EventKit

struct ProfileSettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("notificationOffsetsData") private var notificationOffsetsData = ""
    @EnvironmentObject var storeManager: StoreManager
    private var isPro: Bool { storeManager.isPro }
    @ObservedObject var googleCalendarManager = GoogleCalendarManager.shared
    @StateObject private var calendarManager = CalendarManager()
    @State private var appleCalendarStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    
    @Binding var is24HourClock: Bool
    @Binding var showingCustomOffsetAlert: Bool
    @State private var showingPaywall = false

    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    private var offsets: [Int] {
        if notificationOffsetsData.isEmpty { return [] }
        return notificationOffsetsData.split(separator: ",").compactMap { Int($0) }
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
                    Toggle("24-Hour Clock", isOn: $is24HourClock)
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
                                    AnalyticsManager.shared.capture("upgrade_custom_notification_clicked")
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
                                    calendarManager.requestAccess { granted in
                                        appleCalendarStatus = EKEventStore.authorizationStatus(for: .event)
                                    }
                                } else {
                                    AnalyticsManager.shared.capture("upgrade_apple_calendar_clicked")
                                    showingPaywall = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    let isAuthorized: Bool = {
                                        if #available(iOS 17.0, *) {
                                            return appleCalendarStatus == .fullAccess
                                        } else {
                                            // Fallback for older iOS versions where .authorized is not deprecated
                                            return appleCalendarStatus.rawValue == 3
                                        }
                                    }()
                                    
                                    Image(systemName: isPro ? "apple.logo" : "lock.fill")
                                        .foregroundStyle(goldColor)
                                    Text(isAuthorized ? "Apple Calendar Connected" : "Sync with Apple Calendar")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                    Spacer()
                                    if isAuthorized {
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

                            // Google Calendar Block
                            Button(action: {
                                if isPro {
                                    if googleCalendarManager.isSignedIn {
                                        googleCalendarManager.signOut()
                                    } else {
                                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                           let rootVC = windowScene.windows.first?.rootViewController {
                                            googleCalendarManager.signIn(presenting: rootVC)
                                        }
                                    }
                                } else {
                                    AnalyticsManager.shared.capture("upgrade_google_signin_clicked")
                                    showingPaywall = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isPro ? "g.circle.fill" : "lock.fill")
                                        .foregroundStyle(googleCalendarManager.isSignedIn ? Color.red : goldColor)
                                    Text(googleCalendarManager.isSignedIn ? "Sign Out of Google" : "Sign In with Google")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                    Spacer()
                                    if googleCalendarManager.isSignedIn {
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

                            Text("Connect Google, Microsoft, or iCloud.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 8)
                        }
                        .opacity(isPro ? 1.0 : 0.6)
                    }
                    // Legal Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("LEGAL")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)

                        Link(destination: URL(string: "https://haiku-app.github.io/haiku/privacy.html")!) {
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
                        Text("Version 1.0.0")
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
            HaikuProView()
        }
        .onChange(of: currentTheme) { oldTheme, newTheme in
            AnalyticsManager.shared.capture("theme_changed", properties: ["theme_name": newTheme.name])
        }
        .onChange(of: is24HourClock) { oldVal, newVal in
            AnalyticsManager.shared.capture("clock_format_toggled", properties: ["is_24_hour": newVal])
        }
    }
}

