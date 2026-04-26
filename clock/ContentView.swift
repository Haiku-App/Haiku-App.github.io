import SwiftUI
internal import Combine
import WidgetKit

struct ContentView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var storeManager: StoreManager
    private var isPro: Bool { storeManager.isPro }

    @State private var now = Date()
    // Slow down timer in Canvas to prevent update loop crashes
    private let timer = Timer.publish(
        every: 1.0, 
        on: .main, 
        in: .common
    ).autoconnect()

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @StateObject private var calendarManager = CalendarManager()
    @ObservedObject private var googleCalendarManager = GoogleCalendarManager.shared
    @ObservedObject private var categoryManager = CategoryManager.shared
    @ObservedObject private var routineManager = RoutineManager.shared
    @State private var saveDebounceTask: Task<Void, Never>? = nil
    @State private var liveClockTasks: [ClockTask]? = nil
    @State private var isApplyingCloudSnapshot = false

    @State private var isFlowState = false
    @State private var showingHourZoom = false
    @State private var zoomedHour: Int? = nil

    @State private var tasksByDate: [Date: [ClockTask]] = {
        if let saved = SharedTaskManager.shared.load() {
            return saved
        }
        return [:]
    }()

    private var currentTasksBinding: Binding<[ClockTask]> {
        Binding(
            get: { tasksByDate[selectedDate, default: []] },
            set: { tasksByDate[selectedDate] = $0 }
        )
    }

    private var displayedTasks: [ClockTask] {
        liveClockTasks ?? tasksByDate[selectedDate, default: []]
    }

    private var activeClockTask: ClockTask? {
        guard Calendar.current.isDateInToday(selectedDate) else { return nil }
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let minute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return displayedTasks.first { minute >= $0.startMinutes && minute < $0.normalizedEndMinutes }
    }

    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    @StateObject private var tabManager = TabManager.shared
    @State private var selectedTab: AppTab = .clock
    @State private var showingAddTask = false
    @State private var showingDatePicker = false
    @State private var showingCustomOffsetAlert = false
    @State private var customOffsetString = ""
    @State private var prefilledTaskTitle: String? = nil
    @State private var prefilledTaskId: UUID? = nil
    @State private var taskToEdit: ClockTask? = nil
    @State private var deletedExternalIds = Set<String>()
    @State private var clockFrame: CGRect = .zero
    @State private var taskListResetToken = UUID()
    @State private var lastGoogleCalendarRefreshAt: Date? = nil
    @AppStorage(CalendarSyncProvider.storageKey) private var activeCalendarSyncProvider: CalendarSyncProvider = .none
    @AppStorage("is24HourClock") private var is24HourClock = true
    @AppStorage("notificationOffsetsData") private var notificationOffsetsData = ""
    private let googleCalendarRefreshInterval: TimeInterval = 30
    private let routineAutoScheduleWindowDays = 28

    private var notificationOffsets: [Int] {
        if notificationOffsetsData.isEmpty { return [] }
        return notificationOffsetsData.split(separator: ",").compactMap { Int($0) }
    }

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasSeenTutorial") private var hasSeenTutorial = false
    @AppStorage("hasSeenTwelveHourTutorial") private var hasSeenTwelveHourTutorial = false
    @State private var showingTutorial = false

    private var shouldBlurContent: Bool {
        showingCustomOffsetAlert || showingTutorial
    }

    var body: some View {
        fullyConfiguredRootLayout
    }

    private var fullyConfiguredRootLayout: some View {
        syncObservedRootLayout
            .onChange(of: is24HourClock) { oldVal, newVal in
                handleClockFormatChange(oldVal: oldVal, newVal: newVal)
            }
            .onChange(of: currentTheme) { oldVal, newVal in
                SharedTaskManager.shared.save(theme: newVal)
                WidgetCenter.shared.reloadAllTimelines()
            }
            .onChange(of: calendarManager.eventsDidChange) {
                guard activeCalendarSyncProvider == .apple else { return }
                syncCalendar(for: selectedDate)
            }
            .onChange(of: GoogleCalendarManager.shared.eventsDidChange) {
                guard activeCalendarSyncProvider == .google else { return }
                syncCalendar(for: selectedDate)
            }
            .onChange(of: googleCalendarManager.isSignedIn) { oldVal, newVal in
                handleGoogleSignInChange(oldVal: oldVal, newVal: newVal)
            }
    }

    private var syncObservedRootLayout: some View {
        presentationConfiguredRootLayout
            .onChange(of: tabManager.hiddenTabs) { oldTabs, newTabs in
                if newTabs.contains(selectedTab) {
                    if let firstVisible = tabManager.visibleTabs.first {
                        selectedTab = firstVisible
                    }
                }
            }
            .onChange(of: selectedTab) { oldTab, newTab in
                handleSelectedTabChange(oldTab: oldTab, newTab: newTab)
            }
            .onChange(of: selectedDate) { oldDate, newDate in
                handleSelectedDateChange(oldDate: oldDate, newDate: newDate)
            }
            .onChange(of: activeCalendarSyncProvider) { oldProvider, newProvider in
                handleCalendarSyncProviderChange(oldProvider: oldProvider, newProvider: newProvider)
            }
            .onChange(of: tasksByDate) { oldTasks, newTasks in
                handleTasksChanged(oldTasks: oldTasks, newTasks: newTasks)
            }
            .onChange(of: scenePhase) { oldPhase, newPhase in
                handleScenePhaseChange(oldPhase: oldPhase, newPhase: newPhase)
            }
            .onChange(of: routineManager.routines) { oldRoutines, newRoutines in
                handleRoutinesChanged(oldRoutines: oldRoutines, newRoutines: newRoutines)
            }
            .onChange(of: notificationOffsetsData) {
                NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: tasksByDate, offsets: notificationOffsets)
            }
    }

    private var presentationConfiguredRootLayout: some View {
        rootLayout
            .onReceive(timer, perform: handleTimerTick)
            .sheet(isPresented: $showingAddTask, content: addTaskSheet)
            .sheet(isPresented: $showingDatePicker) {
                datePickerSheetContent
            }
            .onAppear(perform: handleOnAppear)
    }

    private var rootLayout: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView()
                
                Spacer()

                mainContentView()
                
                Spacer()

                tabBarView()
            }
            .environmentObject(storeManager)
            .blur(radius: shouldBlurContent ? 4 : 0)
            .disabled(shouldBlurContent)

            if showingCustomOffsetAlert {
                customNotificationAlertView()
            }
            
            if showingTutorial {
                TutorialOverlayView(isPresented: $showingTutorial)
                    .transition(.opacity)
            }
        }
    }

    private func addTaskSheet() -> some View {
        AddTaskView(
            tasksByDate: $tasksByDate,
            selectedDate: $selectedDate,
            prefilledTitle: prefilledTaskTitle,
            brainDumpTaskId: prefilledTaskId,
            taskToEdit: taskToEdit
        )
    }

    private var datePickerSheetContent: some View {
        NavigationStack {
            ZStack {
                currentTheme.bg.ignoresSafeArea()

                ScrollView {
                    VStack {
                        DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                            .datePickerStyle(.graphical)
                            .tint(currentTheme.accent)
                            .colorMultiply(currentTheme == .sakura ? currentTheme.textForeground : .white)
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 24)
                                    .fill(currentTheme.fieldBg)
                                    .shadow(color: currentTheme.shadowDark, radius: 10, x: 8, y: 8)
                                    .shadow(color: currentTheme.shadowLight, radius: 10, x: -8, y: -8)
                            )
                            .padding(24)
                            .padding(.top, 16)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(currentTheme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(currentTheme == .sakura ? .light : .dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Select Date")
                        .font(.system(size: 18, weight: .medium, design: .serif))
                        .foregroundStyle(currentTheme.textForeground)
                        .tracking(1)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        showingDatePicker = false
                    }
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(currentTheme.accent)
                }
            }
        }
        .presentationDetents([.height(520)])
        .preferredColorScheme(.dark)
    }

    private func handleTimerTick(_ date: Date) {
        // Stop rapid re-renders in Canvas which cause GroupRecordingError
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            let currentSecond = Calendar.current.component(.second, from: date)
            let lastSecond = Calendar.current.component(.second, from: now)
            if currentSecond != lastSecond {
                now = date
            }
        } else {
            now = date
        }

        pollGoogleCalendarIfNeeded(at: date)
    }

    private func handleOnAppear() {
        if tabManager.isHidden(selectedTab) {
            if let firstVisible = tabManager.visibleTabs.first {
                selectedTab = firstVisible
            }
        }
        migrateLegacyCalendarSyncProviderIfNeeded()
        BrainDumpManager.shared.reloadFromSharedStoreIfNeeded()
        if hasCompletedOnboarding && !hasSeenTutorial {
            withAnimation(.easeInOut(duration: 0.4)) {
                showingTutorial = true
                hasSeenTutorial = true
            }
        }
        SharedTaskManager.shared.save(is24HourClock: is24HourClock)
        SharedTaskManager.shared.save(theme: currentTheme)
        NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: tasksByDate, offsets: notificationOffsets)
        reconcileAutoScheduledRoutines()
        refreshVisibleCalendar(force: true)
        Task {
            await syncTasksWithCloud()
        }
    }

    private func handleSelectedTabChange(oldTab: AppTab, newTab: AppTab) {
        if oldTab == .clock || newTab == .clock {
            resetClockInteractionState()
        }
        if newTab == .clock || newTab == .weekly {
            refreshVisibleCalendar(force: true)
        }
        AnalyticsManager.shared.capture("tab_changed", properties: ["target_tab": "\(newTab)"])
    }

    private func handleSelectedDateChange(oldDate: Date, newDate: Date) {
        resetClockInteractionState()
        syncCalendar(for: newDate)
    }

    private func handleCalendarSyncProviderChange(oldProvider: CalendarSyncProvider, newProvider: CalendarSyncProvider) {
        guard oldProvider != newProvider else { return }

        purgeTasksForInactiveCalendarProviders()
        resetClockInteractionState()
        lastGoogleCalendarRefreshAt = nil

        if newProvider != .none {
            refreshVisibleCalendar(force: true)
        }
    }

    private func handleRoutinesChanged(oldRoutines: [Routine], newRoutines: [Routine]) {
        guard oldRoutines != newRoutines else { return }
        reconcileAutoScheduledRoutines()
    }

    private func handleTasksChanged(oldTasks: [Date: [ClockTask]], newTasks: [Date: [ClockTask]]) {
        let isCloudUpdate = isApplyingCloudSnapshot
        saveDebounceTask?.cancel()
        saveDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            if !Task.isCancelled {
                guard !isCloudUpdate else { return }

                let modifiedAt = SharedTaskManager.shared.save(tasksByDate: newTasks)
                WidgetCenter.shared.reloadAllTimelines()
                NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: newTasks, offsets: notificationOffsets)
                await TaskCloudSyncManager.shared.uploadLocalSnapshot(tasksByDate: newTasks, modifiedAt: modifiedAt)
            }
        }
    }

    private func handleScenePhaseChange(oldPhase: ScenePhase, newPhase: ScenePhase) {
        if newPhase == .active {
            BrainDumpManager.shared.reloadFromSharedStoreIfNeeded()
            reconcileAutoScheduledRoutines()
            refreshVisibleCalendar(force: true)
            Task {
                await syncTasksWithCloud()
            }
        } else {
            resetClockInteractionState()
        }
    }

    private func handleClockFormatChange(oldVal: Bool, newVal: Bool) {
        SharedTaskManager.shared.save(is24HourClock: newVal)
        WidgetCenter.shared.reloadAllTimelines()
        // Show the 12-hour ring tutorial the first time user switches to 12h mode
        if !newVal && !hasSeenTwelveHourTutorial {
            withAnimation(.easeInOut(duration: 0.4)) {
                hasSeenTwelveHourTutorial = true
                showingTutorial = true
            }
        }
    }

    private func handleGoogleSignInChange(oldVal: Bool, newVal: Bool) {
        if newVal && activeCalendarSyncProvider == .google {
            refreshVisibleCalendar(force: true)
        } else if !newVal && activeCalendarSyncProvider == .google {
            activeCalendarSyncProvider = .none
        }
    }

    @ViewBuilder
    private func headerView() -> some View {
        VStack(spacing: 6) {
            Text("HAIKU")
                .font(.system(size: 24, weight: .light, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(4)

            ZStack {
                HStack(spacing: 20) {
                    Button(action: { changeDate(by: -1, source: "chevron") }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(goldColor.opacity(0.6))
                    }

                    Button(action: { showingDatePicker = true }) {
                        Text(formattedSelectedDate().uppercased())
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                            .tracking(1.5)
                            .frame(minWidth: 120, alignment: .center)
                            .id(selectedDate)
                            .transition(.opacity)
                    }

                    Button(action: { changeDate(by: 1, source: "chevron") }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(goldColor.opacity(0.6))
                    }
                }

                HStack {
                    Button(action: {
                        withAnimation(.spring()) {
                            showingHourZoom.toggle()
                            if showingHourZoom {
                                let hour = Calendar.current.component(.hour, from: now)
                                zoomedHour = hour
                            }
                        }
                    }) {
                        Image(systemName: showingHourZoom ? "minus.magnifyingglass" : "plus.magnifyingglass")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(goldColor)
                    }
                    .padding(.leading, 32)

                    Spacer()
                    Button(action: { 
                        prefilledTaskTitle = nil
                        taskToEdit = nil
                        showingAddTask = true 
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 18, weight: .light))
                            .foregroundStyle(goldColor)
                    }
                    .padding(.trailing, 32)
                }
            }
        }
        .padding(.top, 24)
        .opacity(selectedTab == .clock && !isFlowState ? 1 : 0)
        .frame(height: selectedTab == .clock && !isFlowState ? nil : 0)
        .clipped()
    }

    @ViewBuilder
    private func mainContentView() -> some View {
        Group {
            if selectedTab == .clock {
                clockContentView()
                    .id(selectedDate)
                    .transition(.asymmetric(insertion: .opacity, removal: .opacity))
            } else if selectedTab == .weekly {
                WeeklyView(
                    tasksByDate: tasksByDate,
                    selectedDate: $selectedDate,
                    selectedTab: $selectedTab,
                    onAppear: { weekStart in
                        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                        syncCalendarRange(from: weekStart, to: weekEnd)
                    },
                    onWeekChanged: { weekStart in
                        let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
                        syncCalendarRange(from: weekStart, to: weekEnd)
                    }
                )
            } else if selectedTab == .todo {
                TodoView(onSchedule: { title, id in
                    prefilledTaskTitle = title
                    prefilledTaskId = id
                    taskToEdit = nil
                    showingAddTask = true
                })
            } else if selectedTab == .routines {
                RoutinesView(
                    selectedDate: $selectedDate,
                    onStartNow: { routine in
                        startRoutineNow(routine)
                    },
                    onApplyPreferredTime: { routine in
                        applyRoutineToSelectedDate(routine)
                    }
                )
            } else if selectedTab == .analytics {
                ProfileAnalyticsView(tasksByDate: tasksByDate)
            } else if selectedTab == .profile {
                ProfileSettingsView(is24HourClock: $is24HourClock, showingCustomOffsetAlert: $showingCustomOffsetAlert)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func tabBarView() -> some View {
        HStack(spacing: 8) {
            Spacer(minLength: 0)
            ForEach(tabManager.visibleTabs.indices, id: \.self) { index in
                let tab = tabManager.visibleTabs[index]
                TabBarButton(icon: tab.icon, text: tab.text, isSelected: selectedTab == tab) {
                    selectedTab = tab
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(
            Rectangle()
                .fill(currentTheme.bg.opacity(0.8))
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .foregroundStyle(currentTheme.textForeground.opacity(0.4))
        .opacity(isFlowState ? 0 : 1)
        .animation(.easeInOut, value: isFlowState)
    }

    @ViewBuilder
    private func customNotificationAlertView() -> some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        showingCustomOffsetAlert = false
                        customOffsetString = ""
                    }
                }

            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Custom Notification")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(goldColor)

                    Text("Enter how many minutes before the task you'd like to be notified.")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack {
                    TextField("0", text: $customOffsetString)
                        .keyboardType(.numberPad)
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(currentTheme.textForeground)

                    Text("minutes")
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(currentTheme.fieldBg)
                        .shadow(color: currentTheme.shadowDark, radius: 4, x: 2, y: 2)
                        .shadow(color: currentTheme.shadowLight, radius: 4, x: -2, y: -2)
                )

                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation(.easeInOut) {
                            showingCustomOffsetAlert = false
                            customOffsetString = ""
                        }
                    }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let customValue = Int(customOffsetString), customValue >= 0 {
                            var currentSet = Set(notificationOffsets)
                            currentSet.insert(customValue)
                            notificationOffsetsData = currentSet.sorted().map(String.init).joined(separator: ",")
                            NotificationManager.shared.requestAuthorization()
                        }
                        withAnimation(.easeInOut) {
                            showingCustomOffsetAlert = false
                            customOffsetString = ""
                        }
                    }) {
                        Text("Add")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundStyle(currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(goldColor)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(currentTheme.bg)
                    .shadow(color: currentTheme.shadowDark.opacity(0.3), radius: 20, x: 10, y: 10)
                    .shadow(color: currentTheme.shadowLight.opacity(0.3), radius: 20, x: -10, y: -10)
            )
            .padding(.horizontal, 40)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
        }
    }

    private func syncCalendar(for date: Date) {
        syncCalendarRange(from: date, to: Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date)
    }

    private func refreshVisibleCalendar(force: Bool) {
        guard isPro else { return }
        guard activeCalendarSyncProvider != .none else { return }

        if selectedTab == .weekly {
            let weekStart = startOfWeek(for: selectedDate)
            let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
            syncCalendarRange(from: weekStart, to: weekEnd)
        } else {
            syncCalendar(for: selectedDate)
        }

        if activeCalendarSyncProvider == .google, force {
            lastGoogleCalendarRefreshAt = Date()
        }
    }

    private func pollGoogleCalendarIfNeeded(at date: Date) {
        guard scenePhase == .active else { return }
        guard isPro else { return }
        guard activeCalendarSyncProvider == .google else { return }
        guard googleCalendarManager.isSignedIn else { return }

        if let lastRefresh = lastGoogleCalendarRefreshAt,
           date.timeIntervalSince(lastRefresh) < googleCalendarRefreshInterval {
            return
        }

        lastGoogleCalendarRefreshAt = date
        refreshVisibleCalendar(force: false)
    }

    private func startOfWeek(for date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        return calendar.date(byAdding: .day, value: 1 - weekday, to: startOfDay) ?? startOfDay
    }

    private func syncCalendarRange(from startDate: Date, to endDate: Date) {
        guard isPro else { return }

        switch activeCalendarSyncProvider {
        case .none:
            return
        case .apple:
            calendarManager.requestAccess { granted in
                guard granted else {
                    activeCalendarSyncProvider = .none
                    return
                }

                let appleEvents = self.calendarManager.fetchEvents(from: startDate, to: endDate, theme: self.currentTheme)
                self.processSyncedEventsRange(appleEvents, from: startDate, to: endDate)
            }
        case .google:
            GoogleCalendarManager.shared.fetchEvents(from: startDate, to: endDate, theme: currentTheme) { googleEvents in
                self.processSyncedEventsRange(googleEvents, from: startDate, to: endDate)
            }
        }
    }

    private func processSyncedEventsRange(_ fetchedByDate: [Date: [ClockTask]], from startDate: Date, to endDate: Date) {
        let cal = Calendar.current
        var currentDate = startDate
        
        while currentDate < endDate {
            let day = cal.startOfDay(for: currentDate)
            let fetchedForDay = fetchedByDate[day, default: []]
            processSyncedEvents(fetchedForDay, for: day)
            
            guard let nextDate = cal.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }
    }

    private func processSyncedEvents(_ fetched: [ClockTask], for date: Date) {
        var current = self.tasksByDate[date, default: []]
        
        // Filter out events the user just deleted in this session
        let filteredFetched = fetched.filter { event in
            guard let extId = event.externalEventId else { return true }
            return !deletedExternalIds.contains(extId)
        }
        
        // Clean up deletedExternalIds: if an ID we tracked as deleted is no longer in the fetch, 
        // it means the remote calendar has processed the deletion, and we can stop tracking it.
        let fetchedIds = Set(fetched.compactMap { $0.externalEventId })
        deletedExternalIds.formIntersection(fetchedIds)

        // Deduplicate by content (Title + Start + End)
        var uniqueFetched: [ClockTask] = []
        for event in filteredFetched {
            let isDuplicate = uniqueFetched.contains { 
                $0.title == event.title && 
                $0.startMinutes == event.startMinutes && 
                $0.endMinutes == event.endMinutes 
            }
            if !isDuplicate {
                uniqueFetched.append(event)
            } else if let extId = event.externalEventId, extId.hasPrefix("google_") {
                // Prefer Google API version if duplicate found
                if let idx = uniqueFetched.firstIndex(where: { 
                    $0.title == event.title && 
                    $0.startMinutes == event.startMinutes && 
                    $0.endMinutes == event.endMinutes 
                }) {
                    uniqueFetched[idx] = event
                }
            }
        }

        // Update existing tasks in place and collapse any duplicated local copies of the same fetched event.
        for fetchedTask in uniqueFetched {
            let matchingIndices = current.indices.filter { index in
                isSyncedMatch(current[index], fetchedTask: fetchedTask)
            }

            if let preferredIndex = preferredSyncedMatchIndex(from: matchingIndices, in: current, fetchedTask: fetchedTask) {
                if current[preferredIndex].title != fetchedTask.title ||
                   current[preferredIndex].startMinutes != fetchedTask.startMinutes ||
                   current[preferredIndex].endMinutes != fetchedTask.endMinutes {
                    current[preferredIndex].title = fetchedTask.title
                    current[preferredIndex].startMinutes = fetchedTask.startMinutes
                    current[preferredIndex].endMinutes = fetchedTask.endMinutes
                }

                if current[preferredIndex].externalEventId != fetchedTask.externalEventId {
                    current[preferredIndex].externalEventId = fetchedTask.externalEventId
                }

                if current[preferredIndex].url != fetchedTask.url {
                    current[preferredIndex].url = fetchedTask.url
                }

                for duplicateIndex in matchingIndices.sorted(by: >) where duplicateIndex != preferredIndex {
                    current.remove(at: duplicateIndex)
                }
            } else {
                current.append(fetchedTask)
            }
        }

        // Cleanup removed tasks
        let finalFetchedIds = Set(uniqueFetched.compactMap { $0.externalEventId })
        current.removeAll { task in
            guard let extId = task.externalEventId else { return false }
            
            if extId.hasPrefix("google_") {
                let didFetchGoogle = uniqueFetched.contains { $0.externalEventId?.hasPrefix("google_") == true }
                return didFetchGoogle && !finalFetchedIds.contains(extId)
            } else {
                let didFetchApple = uniqueFetched.contains { $0.externalEventId?.hasPrefix("google_") == false }
                return didFetchApple && !finalFetchedIds.contains(extId)
            }
        }

        current.sort { $0.startMinutes < $1.startMinutes }
        self.tasksByDate[date] = current
    }

    private func isSyncedMatch(_ currentTask: ClockTask, fetchedTask: ClockTask) -> Bool {
        if currentTask.externalEventId == fetchedTask.externalEventId && fetchedTask.externalEventId != nil {
            return true
        }

        let sameContent =
            currentTask.title == fetchedTask.title &&
            currentTask.startMinutes == fetchedTask.startMinutes &&
            currentTask.endMinutes == fetchedTask.endMinutes

        guard sameContent else { return false }

        let currentProvider = currentTask.calendarSyncProvider
        let fetchedProvider = fetchedTask.calendarSyncProvider
        return currentProvider == fetchedProvider || currentProvider == .none
    }

    private func preferredSyncedMatchIndex(
        from indices: [Int],
        in tasks: [ClockTask],
        fetchedTask: ClockTask
    ) -> Int? {
        if let exactIndex = indices.first(where: { tasks[$0].externalEventId == fetchedTask.externalEventId }) {
            return exactIndex
        }

        if let providerIndex = indices.first(where: { tasks[$0].calendarSyncProvider == fetchedTask.calendarSyncProvider }) {
            return providerIndex
        }

        return indices.first
    }

    @ViewBuilder
    private func clockContentView() -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            // Clock
            HStack(spacing: 15) {
                if showingHourZoom {
                    Button(action: {
                        withAnimation {
                            let currentH = zoomedHour ?? 0
                            zoomedHour = (currentH - 1 + 24) % 24
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(goldColor.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(currentTheme.bg).shadow(color: currentTheme.shadowDark, radius: 4, x: 2, y: 2))
                    }
                }

                ClockView(
                    now: now,
                    tasks: currentTasksBinding,
                    isFlowState: $isFlowState,
                    is24HourClock: is24HourClock,
                    zoomedHour: showingHourZoom ? zoomedHour : nil,
                    theme: currentTheme,
                    onTaskUpdated: { updatedTask in
                        if isPro {
                            let day = Calendar.current.startOfDay(for: selectedDate)
                            switch updatedTask.calendarSyncProvider {
                            case .google:
                                GoogleCalendarManager.shared.updateTask(updatedTask, date: day)
                            case .apple:
                                calendarManager.updateTask(updatedTask, date: day)
                            case .none:
                                syncTaskToActiveCalendarProvider(updatedTask, on: day)
                            }
                        }
                    },
                    onTasksPreviewUpdated: { previewTasks in
                        liveClockTasks = previewTasks
                    }
                )
                .frame(width: 280, height: 280)
                .scaleEffect(isFlowState ? 1.15 : 1.0)
                
                if showingHourZoom {
                    Button(action: {
                        withAnimation {
                            let currentH = zoomedHour ?? 0
                            zoomedHour = (currentH + 1) % 24
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(goldColor.opacity(0.6))
                            .padding(10)
                            .background(Circle().fill(currentTheme.bg).shadow(color: currentTheme.shadowDark, radius: 4, x: 2, y: 2))
                    }
                }
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .preference(
                            key: ClockFramePreferenceKey.self,
                            value: geometry.frame(in: .named("clockContentView"))
                        )
                }
            )

            if let activeTask = activeClockTask {
                VStack(spacing: 4) {
                    Text(activeTask.title)
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.85))
                        .lineLimit(1)

                    Text(activeTaskRemainingLabel(activeTask))
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(activeTask.color)
                }
                .padding(.top, 12)
                .padding(.bottom, 10)
            } else {
                Spacer()
                    .frame(height: 16)
            }

            // Daily Quote
            Text(timeQuote(for: selectedDate))
                .font(.system(size: 13, weight: .light, design: .serif))
                .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 24)
                .opacity(isFlowState ? 0 : 1)

            Spacer()
                .frame(height: 26)

            // Task List
            Group {
                if displayedTasks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 32))
                            .foregroundStyle(goldColor.opacity(0.5))
                        Text("No tasks scheduled")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                    }
                } else {
                    List {
                        ForEach(displayedTasks) { task in
                            let timeString = "\(formatTime(minutes: task.startMinutes)) - \(formatTime(minutes: task.endMinutes))"
                            Button(action: {
                                taskToEdit = task
                                showingAddTask = true
                            }) {
                                TaskRow(
                                    time: timeString,
                                    title: task.title,
                                    color: task.color,
                                    icon: categoryManager.categories.first { $0.id == task.categoryId }?.icon ?? "leaf.fill",
                                    isRepeating: task.repeatFrequency != .never
                                )
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = tasksByDate[selectedDate]?.firstIndex(where: { $0.id == task.id }) {
                                        if isPro, let extId = task.externalEventId {
                                            deletedExternalIds.insert(extId)
                                            if extId.hasPrefix("google_") {
                                                GoogleCalendarManager.shared.deleteTask(externalId: extId)
                                            } else {
                                                calendarManager.deleteTask(externalId: extId)
                                            }
                                        }
                                        // PostHog: Track task deletion
                                        AnalyticsManager.shared.capture("task_deleted")
                                        _ = withAnimation(.easeInOut) {
                                            tasksByDate[selectedDate]?.remove(at: index)
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .id(taskListResetToken)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .opacity(isFlowState ? 0 : 1)

            Spacer()
        }
        .coordinateSpace(name: "clockContentView")
        .onPreferenceChange(ClockFramePreferenceKey.self) { newFrame in
            if newFrame != .zero {
                clockFrame = newFrame
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    let protectedClockFrame = clockFrame.insetBy(dx: -24, dy: -24)
                    if protectedClockFrame.contains(value.startLocation) {
                        return
                    }

                    // Keep row swipe actions in the task list from changing the selected day.
                    let swipeRegionMaxY = clockFrame.maxY + 90
                    if clockFrame != .zero && value.startLocation.y > swipeRegionMaxY {
                        return
                    }

                    // Only trigger if the swipe is mostly horizontal
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width < 0 {
                            // Swipe left -> Next day
                            changeDate(by: 1, source: "swipe")
                        } else if value.translation.width > 0 {
                            // Swipe right -> Previous day
                            changeDate(by: -1, source: "swipe")
                        }
                    }
                }
        )
    }

    private func changeDate(by days: Int, source: String = "button") {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
                selectedDate = newDate
                AnalyticsManager.shared.capture("date_changed", properties: ["days_delta": days, "source": source])
            }
        }
    }

    private let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        return formatter
    }()

    private func formattedSelectedDate() -> String {
        return dayFormatter.string(from: selectedDate)
    }

    private func formatTime(minutes: Int) -> String {
        let m = minutes % (24 * 60)
        let h = m / 60
        let min = m % 60
        var comps = DateComponents()
        comps.hour = h
        comps.minute = min
        let date = Calendar.current.date(from: comps) ?? Date()
        
        timeFormatter.dateFormat = "h:mm a"
        return timeFormatter.string(from: date)
    }

    private let quotes: [String] = [
        "“A year from now you will wish you had started today.” — Karen Lamb",
        "“How we spend our days is, of course, how we spend our lives.” — Annie Dillard",
        "“The bad news is time flies. The good news is you're the pilot.” — Michael Altshuler",
        "“Do not wait: the time will never be 'just right'. Start where you stand.” — Napoleon Hill",
        "“We must use time as a tool, not as a couch.” — John F. Kennedy",
        "“If you spend too much time thinking about a thing, you'll never get it done.” — Bruce Lee",
        "“It is not that we have a short time to live, but that we waste a lot of it.” — Seneca",
        "“The common man is not concerned about the passage of time, the man of talent is driven by it.” — Arthur Schopenhauer",
        "“You don't have to see the whole staircase, just take the first step.” — Martin Luther King Jr.",
        "“The two most powerful warriors are patience and time.” — Leo Tolstoy",
        "“You are what you do, not what you say you'll do.” — C.G. Jung",
        "“There are seven days in the week and 'someday' isn't one of them.” — Shaquille O'Neal",
        "“If it is important to you, you will find a way. If not, you'll find an excuse.” — Ryan Blair",
        "“The future depends on what you do today.” — Mahatma Gandhi",
        "“Discipline is choosing between what you want now and what you want most.” — Abraham Lincoln",
        "“You don't have to be great to start, but you have to start to be great.” — Zig Ziglar"
    ]

    private func activeTaskRemainingLabel(_ task: ClockTask) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: now)
        let currentMinute = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        let remaining = max(0, task.normalizedEndMinutes - currentMinute)
        let hours = remaining / 60
        let minutes = remaining % 60

        if hours > 0 {
            return "\(hours)h \(minutes)m left"
        } else {
            return "\(minutes)m left"
        }
    }

    private func timeQuote(for date: Date) -> String {
        // Use .day within .year to compute day-of-year (1-based). Fallback to 1 on failure.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % quotes.count
        return quotes[index]
    }

    private func migrateLegacyCalendarSyncProviderIfNeeded() {
        guard UserDefaults.standard.object(forKey: CalendarSyncProvider.storageKey) == nil else { return }

        if googleCalendarManager.hasPreviousSignIn {
            activeCalendarSyncProvider = .google
        } else if CalendarManager.hasCalendarAccess() {
            activeCalendarSyncProvider = .apple
        } else {
            activeCalendarSyncProvider = .none
        }

        purgeTasksForInactiveCalendarProviders()
    }

    private func purgeTasksForInactiveCalendarProviders() {
        var filteredTasksByDate: [Date: [ClockTask]] = [:]

        for (date, tasks) in tasksByDate {
            let filteredTasks = tasks.filter { task in
                task.calendarSyncProvider == .none || task.calendarSyncProvider == activeCalendarSyncProvider
            }

            if !filteredTasks.isEmpty {
                filteredTasksByDate[date] = filteredTasks
            }
        }

        if filteredTasksByDate != tasksByDate {
            tasksByDate = filteredTasksByDate
        }
    }

    private func syncTaskToActiveCalendarProvider(_ task: ClockTask, on day: Date) {
        guard isPro else { return }

        switch activeCalendarSyncProvider {
        case .none:
            return
        case .apple:
            if let externalEventId = calendarManager.saveTask(task, date: day) {
                attachExternalEventId(externalEventId, to: task.id, on: day)
            }
        case .google:
            GoogleCalendarManager.shared.saveTask(task, date: day) { externalEventId in
                guard let externalEventId else { return }

                DispatchQueue.main.async {
                    attachExternalEventId(externalEventId, to: task.id, on: day)
                }
            }
        }
    }

    private func attachExternalEventId(_ externalEventId: String, to taskId: UUID, on day: Date) {
        guard let taskIndex = tasksByDate[day]?.firstIndex(where: { $0.id == taskId }) else { return }
        tasksByDate[day]?[taskIndex].externalEventId = externalEventId
    }

    private func startRoutineNow(_ routine: Routine) {
        let today = Calendar.current.startOfDay(for: now)
        let startMinutes = roundedCurrentRoutineStartMinutes()

        resetClockInteractionState()
        replaceTodaysAutoScheduledRoutineOccurrenceIfNeeded(for: routine, anchorDay: today)
        applyRoutine(routine, anchorDay: today, startMinutes: startMinutes, autoScheduled: false)

        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
            selectedDate = today
            selectedTab = .todo
            isFlowState = false
        }

        AnalyticsManager.shared.capture("routine_started_now", properties: [
            "routine_name": routine.name,
            "step_count": routine.steps.count
        ])
    }

    private func applyRoutineToSelectedDate(_ routine: Routine) {
        let day = Calendar.current.startOfDay(for: selectedDate)

        resetClockInteractionState()
        applyRoutine(routine, anchorDay: day, startMinutes: routine.preferredStartMinutes, autoScheduled: false)

        withAnimation(.easeInOut(duration: 0.3)) {
            selectedDate = day
            selectedTab = .clock
        }

        AnalyticsManager.shared.capture("routine_applied_to_day", properties: [
            "routine_name": routine.name,
            "step_count": routine.steps.count
        ])
    }

    private func applyRoutine(_ routine: Routine, anchorDay: Date, startMinutes: Int, autoScheduled: Bool) {
        let entries = plannedRoutineEntries(for: routine, anchorDay: anchorDay, startMinutes: startMinutes, autoScheduled: autoScheduled)

        for (day, task) in entries {
            upsertRoutineTask(task, on: day, allowManagedUpdate: autoScheduled)
        }
    }

    private func reconcileAutoScheduledRoutines() {
        let calendar = Calendar.current
        let windowStart = calendar.startOfDay(for: now)
        guard let windowEnd = calendar.date(byAdding: .day, value: routineAutoScheduleWindowDays, to: windowStart),
              let cleanupEnd = calendar.date(byAdding: .day, value: routineAutoScheduleWindowDays + 2, to: windowStart) else {
            return
        }

        var expectedTasksByDay: [Date: [ClockTask]] = [:]
        var expectedKeys = Set<String>()

        var anchorDay = windowStart
        while anchorDay < windowEnd {
            let weekdayValue = calendar.component(.weekday, from: anchorDay)
            let weekday = RoutineWeekday(rawValue: weekdayValue)

            for routine in routineManager.routines where weekday.map(routine.autoScheduleDays.contains) == true {
                let entries = plannedRoutineEntries(
                    for: routine,
                    anchorDay: anchorDay,
                    startMinutes: routine.preferredStartMinutes,
                    autoScheduled: true
                )

                for (taskDay, task) in entries {
                    let normalizedTaskDay = calendar.startOfDay(for: taskDay)
                    guard normalizedTaskDay < cleanupEnd else { continue }
                    expectedTasksByDay[normalizedTaskDay, default: []].append(task)
                    expectedKeys.insert(routineTaskKey(for: task, on: normalizedTaskDay))
                }
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: anchorDay) else { break }
            anchorDay = nextDay
        }

        var day = windowStart
        while day < cleanupEnd {
            let normalizedDay = calendar.startOfDay(for: day)
            var dayTasks = tasksByDate[normalizedDay, default: []]

            let obsoleteTasks = dayTasks.filter { task in
                task.isRoutineAutoScheduled && !expectedKeys.contains(routineTaskKey(for: task, on: normalizedDay))
            }

            if !obsoleteTasks.isEmpty {
                for task in obsoleteTasks {
                    deleteTaskFromCalendarIfNeeded(task)
                }

                dayTasks.removeAll { task in
                    task.isRoutineAutoScheduled && !expectedKeys.contains(routineTaskKey(for: task, on: normalizedDay))
                }
                dayTasks.sort { $0.startMinutes < $1.startMinutes }
                tasksByDate[normalizedDay] = dayTasks.isEmpty ? nil : dayTasks
            }

            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: normalizedDay) else { break }
            day = nextDay
        }

        for (day, tasks) in expectedTasksByDay {
            for task in tasks.sorted(by: { $0.startMinutes < $1.startMinutes }) {
                upsertRoutineTask(task, on: day, allowManagedUpdate: true)
            }
        }
    }

    private func plannedRoutineEntries(
        for routine: Routine,
        anchorDay: Date,
        startMinutes: Int,
        autoScheduled: Bool
    ) -> [(Date, ClockTask)] {
        let calendar = Calendar.current
        let normalizedAnchorDay = calendar.startOfDay(for: anchorDay)
        var runningMinutes = max(startMinutes, 0)
        var entries: [(Date, ClockTask)] = []

        for step in routine.steps {
            let dayOffset = max(0, runningMinutes / 1440)
            let taskDay = calendar.date(byAdding: .day, value: dayOffset, to: normalizedAnchorDay) ?? normalizedAnchorDay
            let taskStart = runningMinutes % 1440
            let taskEnd = taskStart + step.durationMinutes

            let task = ClockTask(
                title: step.title,
                startMinutes: taskStart,
                endMinutes: taskEnd,
                color: step.color,
                categoryId: step.categoryId,
                categoryName: step.categoryName,
                routineSourceId: routine.id,
                routineSourceStepId: step.id,
                routineSourceName: routine.name,
                routineAnchorDate: normalizedAnchorDay,
                isRoutineAutoScheduled: autoScheduled
            )

            entries.append((taskDay, task))
            runningMinutes += step.durationMinutes
        }

        return entries
    }

    private func upsertRoutineTask(_ task: ClockTask, on day: Date, allowManagedUpdate: Bool) {
        let normalizedDay = Calendar.current.startOfDay(for: day)
        var dayTasks = tasksByDate[normalizedDay, default: []]

        if allowManagedUpdate,
           let existingIndex = dayTasks.firstIndex(where: { routineTasksShareIdentity($0, task) && $0.isRoutineAutoScheduled }) {
            var existing = dayTasks[existingIndex]
            let needsUpdate = routineTaskNeedsUpdate(existing, comparedTo: task)

            existing.title = task.title
            existing.startMinutes = task.startMinutes
            existing.endMinutes = task.endMinutes
            existing.color = task.color
            existing.categoryId = task.categoryId
            existing.categoryName = task.categoryName
            existing.routineSourceName = task.routineSourceName
            existing.routineAnchorDate = task.routineAnchorDate
            existing.isRoutineAutoScheduled = true

            dayTasks[existingIndex] = existing
            dayTasks.sort { $0.startMinutes < $1.startMinutes }
            tasksByDate[normalizedDay] = dayTasks

            if needsUpdate {
                updateTaskOnCalendarIfNeeded(existing, on: normalizedDay)
            } else if existing.externalEventId == nil {
                syncTaskToActiveCalendarProvider(existing, on: normalizedDay)
            }
            return
        }

        let alreadyExists = dayTasks.contains { existingTask in
            routineTasksShareIdentity(existingTask, task) &&
            existingTask.startMinutes == task.startMinutes &&
            existingTask.endMinutes == task.endMinutes
        }

        guard !alreadyExists else { return }

        dayTasks.append(task)
        dayTasks.sort { $0.startMinutes < $1.startMinutes }
        tasksByDate[normalizedDay] = dayTasks
        syncTaskToActiveCalendarProvider(task, on: normalizedDay)
    }

    private func updateTaskOnCalendarIfNeeded(_ task: ClockTask, on day: Date) {
        guard isPro else { return }

        switch task.calendarSyncProvider {
        case .google:
            GoogleCalendarManager.shared.updateTask(task, date: day)
        case .apple:
            calendarManager.updateTask(task, date: day)
        case .none:
            syncTaskToActiveCalendarProvider(task, on: day)
        }
    }

    private func deleteTaskFromCalendarIfNeeded(_ task: ClockTask) {
        guard isPro, let externalEventId = task.externalEventId else { return }

        deletedExternalIds.insert(externalEventId)
        if externalEventId.hasPrefix("google_") {
            GoogleCalendarManager.shared.deleteTask(externalId: externalEventId)
        } else {
            calendarManager.deleteTask(externalId: externalEventId)
        }
    }

    private func routineTasksShareIdentity(_ lhs: ClockTask, _ rhs: ClockTask) -> Bool {
        lhs.routineSourceId == rhs.routineSourceId &&
        lhs.routineSourceStepId == rhs.routineSourceStepId &&
        lhs.routineAnchorDate == rhs.routineAnchorDate
    }

    private func routineTaskNeedsUpdate(_ current: ClockTask, comparedTo expected: ClockTask) -> Bool {
        current.title != expected.title ||
        current.startMinutes != expected.startMinutes ||
        current.endMinutes != expected.endMinutes ||
        current.categoryId != expected.categoryId ||
        current.categoryName != expected.categoryName ||
        current.color != expected.color ||
        current.isRoutineAutoScheduled != expected.isRoutineAutoScheduled
    }

    private func routineTaskKey(for task: ClockTask, on day: Date) -> String {
        let anchorTime = Int((task.routineAnchorDate ?? day).timeIntervalSince1970)
        let dayTime = Int(day.timeIntervalSince1970)
        return [
            String(dayTime),
            task.routineSourceId?.uuidString ?? "none",
            task.routineSourceStepId?.uuidString ?? "none",
            String(anchorTime)
        ].joined(separator: "|")
    }

    private func roundedCurrentRoutineStartMinutes() -> Int {
        let components = Calendar.current.dateComponents([.hour, .minute], from: now)
        let rawMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let remainder = rawMinutes % 5
        if remainder == 0 { return rawMinutes }
        return min(rawMinutes + (5 - remainder), 1435)
    }

    private func replaceTodaysAutoScheduledRoutineOccurrenceIfNeeded(for routine: Routine, anchorDay: Date) {
        let calendar = Calendar.current
        let normalizedAnchorDay = calendar.startOfDay(for: anchorDay)

        var datesToUpdate = Set<Date>()
        for (date, tasks) in tasksByDate {
            let matches = tasks.filter {
                $0.isRoutineAutoScheduled &&
                $0.routineSourceId == routine.id &&
                calendar.startOfDay(for: $0.routineAnchorDate ?? date) == normalizedAnchorDay
            }

            guard !matches.isEmpty else { continue }

            for task in matches {
                deleteTaskFromCalendarIfNeeded(task)
            }

            let remainingTasks = tasks.filter {
                !($0.isRoutineAutoScheduled &&
                  $0.routineSourceId == routine.id &&
                  calendar.startOfDay(for: $0.routineAnchorDate ?? date) == normalizedAnchorDay)
            }

            tasksByDate[date] = remainingTasks.isEmpty ? nil : remainingTasks
            datesToUpdate.insert(date)
        }

        if !datesToUpdate.isEmpty {
            taskListResetToken = UUID()
        }
    }

    private func resetClockInteractionState() {
        liveClockTasks = nil
        isFlowState = false
        taskListResetToken = UUID()
    }

    @MainActor
    private func applyCloudSnapshot(_ snapshot: TaskCloudSnapshot) {
        isApplyingCloudSnapshot = true
        tasksByDate = snapshot.tasksByDate
        _ = SharedTaskManager.shared.save(tasksByDate: snapshot.tasksByDate, modifiedAt: snapshot.modifiedAt)
        WidgetCenter.shared.reloadAllTimelines()
        NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: snapshot.tasksByDate, offsets: notificationOffsets)
        isApplyingCloudSnapshot = false
        reconcileAutoScheduledRoutines()
    }

    private func syncTasksWithCloud() async {
        let localTasks = tasksByDate
        var localModifiedAt = SharedTaskManager.shared.loadTasksLastModifiedAt()

        if localModifiedAt == nil && !localTasks.isEmpty {
            localModifiedAt = SharedTaskManager.shared.save(tasksByDate: localTasks)
        }

        guard let snapshot = await TaskCloudSyncManager.shared.synchronize(
            localTasksByDate: localTasks,
            localModifiedAt: localModifiedAt
        ) else {
            return
        }

        await MainActor.run {
            applyCloudSnapshot(snapshot)
        }
    }
}

private struct ClockFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

struct TabBarButton: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var icon: String
    var text: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? currentTheme.textForeground : currentTheme.textForeground.opacity(0.5))
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? currentTheme.textForeground : currentTheme.textForeground.opacity(0.5))
            }
            .frame(minWidth: 50, maxWidth: 80)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
}
