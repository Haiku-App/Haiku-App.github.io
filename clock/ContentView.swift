import SwiftUI
internal import Combine
import WidgetKit
import PostHog

struct ContentView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
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
    @State private var saveDebounceTask: Task<Void, Never>? = nil

    @State private var isFlowState = false

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

    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    enum Tab {
        case clock, weekly, todo, analytics, profile
    }
    @State private var selectedTab: Tab = .clock
    @State private var showingAddTask = false
    @State private var showingDatePicker = false
    @State private var showingCustomOffsetAlert = false
    @State private var customOffsetString = ""
    @State private var prefilledTaskTitle: String? = nil
    @State private var prefilledTaskId: UUID? = nil
    @State private var taskToEdit: ClockTask? = nil
    @State private var deletedExternalIds = Set<String>()
    @AppStorage("is24HourClock") private var is24HourClock = false
    @AppStorage("notificationOffsetsData") private var notificationOffsetsData = ""

    private var notificationOffsets: [Int] {
        if notificationOffsetsData.isEmpty { return [] }
        return notificationOffsetsData.split(separator: ",").compactMap { Int($0) }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("HAIKU")
                        .font(.system(size: 26, weight: .regular, design: .serif))
                        .foregroundStyle(goldColor)
                        .tracking(2)

                    ZStack {
                        // Centered Date and Chevrons
                        HStack(spacing: 16) {
                            Button(action: { changeDate(by: -1) }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(goldColor.opacity(0.8))
                            }

                            Button(action: { showingDatePicker = true }) {
                                Text(formattedSelectedDate())
                                    .font(.system(size: 14, weight: .medium, design: .serif))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                    .frame(minWidth: 100, alignment: .center)
                                    .id(selectedDate) // Forces animation on change
                                    .transition(.opacity)
                            }

                            Button(action: { changeDate(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(goldColor.opacity(0.8))
                            }
                        }

                        // Right-aligned Plus Button
                        HStack {
                            Spacer()
                            Button(action: { 
                                prefilledTaskTitle = nil
                                taskToEdit = nil
                                showingAddTask = true 
                            }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(goldColor)
                            }
                            .padding(.trailing, 40)
                        }
                    }
                }
                .padding(.top, 20)
                .opacity(selectedTab == .clock && !isFlowState ? 1 : 0)
                .frame(height: selectedTab == .clock && !isFlowState ? nil : 0)
                .clipped()

                Spacer()

                // Content Views
                Group {
                    if selectedTab == .clock {
                        clockContentView()
                            .id(selectedDate) // Animate view transition when date changes
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
                    } else if selectedTab == .todo {                        TodoView(onSchedule: { title, id in
                            prefilledTaskTitle = title
                            prefilledTaskId = id
                            taskToEdit = nil
                            showingAddTask = true
                        })
                    } else if selectedTab == .analytics {
                        ProfileAnalyticsView(tasksByDate: tasksByDate)
                    } else if selectedTab == .profile {
                        ProfileSettingsView(is24HourClock: $is24HourClock, showingCustomOffsetAlert: $showingCustomOffsetAlert)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                // Bottom Tab Bar
                HStack {
                    TabBarButton(icon: "clock.fill", text: "Clock", isSelected: selectedTab == .clock) {
                        selectedTab = .clock
                    }
                    Spacer()
                    TabBarButton(icon: "calendar", text: "Weekly", isSelected: selectedTab == .weekly) {
                        selectedTab = .weekly
                    }
                    Spacer()
                    TabBarButton(icon: "list.bullet", text: "To-Do", isSelected: selectedTab == .todo) {
                        selectedTab = .todo
                    }
                    Spacer()
                    TabBarButton(icon: "chart.pie.fill", text: "Analytics", isSelected: selectedTab == .analytics) {
                        selectedTab = .analytics
                    }
                    Spacer()
                    TabBarButton(icon: "person.fill", text: "Profile", isSelected: selectedTab == .profile) {
                        selectedTab = .profile
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                .opacity(isFlowState ? 0 : 1)
                .animation(.easeInOut, value: isFlowState)
            }
            .environmentObject(storeManager)
            .blur(radius: showingCustomOffsetAlert ? 4 : 0)
            .disabled(showingCustomOffsetAlert)

            if showingCustomOffsetAlert {
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
        .onReceive(timer) { date in
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
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(tasksByDate: $tasksByDate, selectedDate: $selectedDate, prefilledTitle: prefilledTaskTitle, brainDumpTaskId: prefilledTaskId, taskToEdit: taskToEdit)
        }
        .sheet(isPresented: $showingDatePicker) {
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
        .onAppear {
            syncCalendar(for: selectedDate)
            SharedTaskManager.shared.save(is24HourClock: is24HourClock)
            SharedTaskManager.shared.save(theme: currentTheme)
            NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: tasksByDate, offsets: notificationOffsets)
        }
        .onChange(of: selectedTab) { oldTab, newTab in
            PostHogSDK.shared.capture("tab_changed", properties: ["target_tab": "\(newTab)"])
        }
        .onChange(of: selectedDate) { oldDate, newDate in
            syncCalendar(for: newDate)
        }
        .onChange(of: tasksByDate) { oldTasks, newTasks in
            saveDebounceTask?.cancel()
            saveDebounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
                if !Task.isCancelled {
                    SharedTaskManager.shared.save(tasksByDate: newTasks)
                    WidgetCenter.shared.reloadAllTimelines()
                    NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: newTasks, offsets: notificationOffsets)
                }
            }
        }
        .onChange(of: notificationOffsetsData) {
            NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: tasksByDate, offsets: notificationOffsets)
        }
        .onChange(of: is24HourClock) { oldVal, newVal in
            SharedTaskManager.shared.save(is24HourClock: newVal)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: currentTheme) { oldVal, newVal in
            SharedTaskManager.shared.save(theme: newVal)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: calendarManager.eventsDidChange) {
            syncCalendar(for: selectedDate)
        }
        .onChange(of: GoogleCalendarManager.shared.eventsDidChange) {
            syncCalendar(for: selectedDate)
        }
        .onChange(of: googleCalendarManager.isSignedIn) { oldVal, newVal in
            if newVal {
                syncCalendar(for: selectedDate)
            }
        }
    }

    private func syncCalendar(for date: Date) {
        syncCalendarRange(from: date, to: Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date)
    }

    private func syncCalendarRange(from startDate: Date, to endDate: Date) {
        // 2-way calendar sync is a Pro feature
        guard isPro else { return }

        var combinedFetched: [Date: [ClockTask]] = [:]
        let dispatchGroup = DispatchGroup()

        // 1. Fetch from Apple Calendar
        dispatchGroup.enter()
        calendarManager.requestAccess { granted in
            if granted {
                let appleEvents = self.calendarManager.fetchEvents(from: startDate, to: endDate, theme: self.currentTheme)
                for (date, tasks) in appleEvents {
                    combinedFetched[date, default: []].append(contentsOf: tasks)
                }
            }
            dispatchGroup.leave()
        }

        // 2. Fetch from Google Calendar
        dispatchGroup.enter()
        GoogleCalendarManager.shared.fetchEvents(from: startDate, to: endDate, theme: currentTheme) { googleEvents in
            for (date, tasks) in googleEvents {
                combinedFetched[date, default: []].append(contentsOf: tasks)
            }
            dispatchGroup.leave()
        }

        // 3. Process results when both are done
        dispatchGroup.notify(queue: .main) {
            self.processSyncedEventsRange(combinedFetched, from: startDate, to: endDate)
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

        // Update existing or add new
        for fetchedTask in uniqueFetched {
            if let index = current.firstIndex(where: { $0.externalEventId == fetchedTask.externalEventId }) {
                if current[index].title != fetchedTask.title ||
                   current[index].startMinutes != fetchedTask.startMinutes ||
                   current[index].endMinutes != fetchedTask.endMinutes {
                    current[index].title = fetchedTask.title
                    current[index].startMinutes = fetchedTask.startMinutes
                    current[index].endMinutes = fetchedTask.endMinutes
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
    @ViewBuilder
    private func clockContentView() -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)

            // Clock
            ClockView(
                now: now,
                tasks: currentTasksBinding,
                isFlowState: $isFlowState,
                is24HourClock: is24HourClock,
                theme: currentTheme,
                onTaskUpdated: { updatedTask in
                    if isPro {
                        let day = Calendar.current.startOfDay(for: selectedDate)
                        if let extId = updatedTask.externalEventId, extId.hasPrefix("google_") {
                            GoogleCalendarManager.shared.updateTask(updatedTask, date: day)
                        } else {
                            calendarManager.updateTask(updatedTask, date: day)
                        }
                    }
                }
            )
                .frame(width: 280, height: 280)
                .scaleEffect(isFlowState ? 1.15 : 1.0)

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
                if tasksByDate[selectedDate, default: []].isEmpty {
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
                        ForEach(tasksByDate[selectedDate, default: []]) { task in
                            let timeString = "\(formatTime(minutes: task.startMinutes)) - \(formatTime(minutes: task.endMinutes))"
                            Button(action: {
                                taskToEdit = task
                                showingAddTask = true
                            }) {
                                TaskRow(
                                    time: timeString,
                                    title: task.title,
                                    color: task.color
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
                                        PostHogSDK.shared.capture("task_deleted")
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
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .opacity(isFlowState ? 0 : 1)

            Spacer()
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    // Only trigger if the swipe is mostly horizontal
                    if abs(value.translation.width) > abs(value.translation.height) {
                        if value.translation.width < 0 {
                            // Swipe left -> Next day
                            changeDate(by: 1)
                        } else if value.translation.width > 0 {
                            // Swipe right -> Previous day
                            changeDate(by: -1)
                        }
                    }
                }
        )
    }

    private func changeDate(by days: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
                selectedDate = newDate
            }
        }
    }

    private func formattedSelectedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        return formatter.string(from: selectedDate)
    }

    private func formatTime(minutes: Int) -> String {
        let m = minutes % (24 * 60)
        let h = m / 60
        let min = m % 60
        var comps = DateComponents()
        comps.hour = h
        comps.minute = min
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = is24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
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

    private func timeQuote(for date: Date) -> String {
        // Use .day within .year to compute day-of-year (1-based). Fallback to 1 on failure.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % quotes.count
        return quotes[index]
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
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
}

