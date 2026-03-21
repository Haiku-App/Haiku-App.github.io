import SwiftUI
internal import Combine
import WidgetKit
import StoreKit

struct ContentView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @StateObject private var storeManager = StoreManager()
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
                            
                            Button(action: { showingDatePicker = true }) {
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
                .animation(nil, value: selectedTab)
                .animation(nil, value: isFlowState)

                Spacer()

                // Content Views
                Group {
                    if selectedTab == .clock {
                        clockContentView()
                            .id(selectedDate) // Animate view transition when date changes
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    } else if selectedTab == .weekly {
                        WeeklyView(tasksByDate: tasksByDate, selectedDate: $selectedDate, selectedTab: $selectedTab)
                    } else if selectedTab == .todo {
                        TodoView(onSchedule: { title, id in
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
                        withAnimation {
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
                            withAnimation {
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
                            withAnimation {
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
        .onChange(of: selectedDate) { newDate in
            syncCalendar(for: newDate)
        }
        .onChange(of: tasksByDate) { _ in
            SharedTaskManager.shared.save(tasksByDate: tasksByDate)
            WidgetCenter.shared.reloadAllTimelines()
            NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: tasksByDate, offsets: notificationOffsets)
        }
        .onChange(of: notificationOffsetsData) { _ in
            NotificationManager.shared.scheduleEarlyNotifications(tasksByDate: tasksByDate, offsets: notificationOffsets)
        }
        .onChange(of: is24HourClock) { newValue in
            SharedTaskManager.shared.save(is24HourClock: newValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
        .onChange(of: currentTheme) { newValue in
            SharedTaskManager.shared.save(theme: newValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private func syncCalendar(for date: Date) {
        // Multi-calendar sync is a Pro feature
        if isPro {
            calendarManager.requestAccess { granted in
                if granted {
                    let fetched = calendarManager.fetchEvents(for: date, theme: currentTheme)
                    
                    DispatchQueue.main.async {
                        var current = tasksByDate[date, default: []]
                        
                        for fetchedTask in fetched {
                            if let index = current.firstIndex(where: { $0.externalEventId == fetchedTask.externalEventId }) {
                                // Update existing task if properties changed
                                if current[index].title != fetchedTask.title ||
                                   current[index].startMinutes != fetchedTask.startMinutes ||
                                   current[index].endMinutes != fetchedTask.endMinutes {
                                    current[index].title = fetchedTask.title
                                    current[index].startMinutes = fetchedTask.startMinutes
                                    current[index].endMinutes = fetchedTask.endMinutes
                                }
                            } else {
                                // Add new task from external calendar
                                current.append(fetchedTask)
                            }
                        }
                        
                        // Remove tasks that no longer exist in Apple Calendar but have an external ID
                        current.removeAll { task in
                            task.externalEventId != nil && !fetched.contains(where: { $0.externalEventId == task.externalEventId })
                        }
                        
                        current.sort { $0.startMinutes < $1.startMinutes }
                        tasksByDate[date] = current
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func clockContentView() -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)
                
            // Clock
            ClockView(now: now, tasks: currentTasksBinding, isFlowState: $isFlowState, is24HourClock: is24HourClock, theme: currentTheme)
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
                                            calendarManager.deleteTask(externalId: extId)
                                        }
                                        withAnimation {
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

struct AddTaskView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @Environment(\.dismiss) var dismiss
    @Binding var tasksByDate: [Date: [ClockTask]]
    @Binding var selectedDate: Date
    
    var prefilledTitle: String?
    var brainDumpTaskId: UUID?
    var taskToEdit: ClockTask?
    
    @State private var taskDate: Date
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    @StateObject private var categoryManager = CategoryManager()
    @ObservedObject private var brainDumpManager = BrainDumpManager()
    @StateObject private var calendarManager = CalendarManager()
    @State private var selectedCategoryId: UUID? = nil
    
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""
    
    @State private var selectedColorIndex: Int = Int.random(in: 0..<aestheticColors.count)
    
    init(tasksByDate: Binding<[Date: [ClockTask]]>, selectedDate: Binding<Date>, prefilledTitle: String? = nil, brainDumpTaskId: UUID? = nil, taskToEdit: ClockTask? = nil) {
        self._tasksByDate = tasksByDate
        self._selectedDate = selectedDate
        self.prefilledTitle = prefilledTitle
        self.brainDumpTaskId = brainDumpTaskId
        self.taskToEdit = taskToEdit
        
        let initialDate = taskToEdit != nil ? selectedDate.wrappedValue : selectedDate.wrappedValue
        self._taskDate = State(initialValue: initialDate)
        
        if let toEdit = taskToEdit {
            self._title = State(initialValue: toEdit.title)
            
            let cal = Calendar.current
            var sComps = cal.dateComponents([.year, .month, .day], from: initialDate)
            sComps.hour = toEdit.startMinutes / 60
            sComps.minute = toEdit.startMinutes % 60
            self._startTime = State(initialValue: cal.date(from: sComps) ?? Date())
            
            var eComps = cal.dateComponents([.year, .month, .day], from: initialDate)
            eComps.hour = toEdit.endMinutes / 60
            eComps.minute = toEdit.endMinutes % 60
            self._endTime = State(initialValue: cal.date(from: eComps) ?? Date())
        } else {
            self._title = State(initialValue: prefilledTitle ?? "")
        }
    }
    
    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Categories
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CATEGORIES")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(categoryManager.categories) { cat in
                                        Button(action: {
                                            selectedCategoryId = cat.id
                                            if let idx = aestheticColors.firstIndex(where: { $0 == cat.rgb }) {
                                                selectedColorIndex = idx
                                            }
                                        }) {
                                            VStack(spacing: 12) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(cat.color)
                                                Text(cat.name)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                                            }
                                            .frame(width: 100, height: 100)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(fieldBgColor)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(selectedCategoryId == cat.id ? cat.color : Color.clear, lineWidth: 2)
                                                    )
                                                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                if let index = categoryManager.categories.firstIndex(where: { $0.id == cat.id }) {
                                                    categoryManager.categories.remove(at: index)
                                                    if selectedCategoryId == cat.id {
                                                        selectedCategoryId = nil
                                                    }
                                                }
                                            }) {
                                                Label("Delete Category", systemImage: "trash")
                                            }
                                        }
                                    }
                                    
                                    // Add new category button
                                    Button(action: {
                                        showingNewCategory = true
                                    }) {
                                        VStack(spacing: 12) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 24))
                                                .foregroundStyle(goldColor)
                                            Text("New")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                                        }
                                        .frame(width: 100, height: 100)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(fieldBgColor)
                                                .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                                .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TASK COLOR")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<aestheticColors.count, id: \.self) { index in
                                        Button(action: {
                                            selectedColorIndex = index
                                            selectedCategoryId = nil
                                        }) {
                                            Circle()
                                                .fill(aestheticColors[index].color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColorIndex == index ? currentTheme.textForeground : Color.clear, lineWidth: 3)
                                                )
                                                .shadow(color: shadowDark, radius: 3, x: 2, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }

                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TASK NAME")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            TextField("Enter title...", text: $title)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(currentTheme.textForeground)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(fieldBgColor)
                                        .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }
                        
                        // Date Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATE")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            DatePicker("Date", selection: $taskDate, displayedComponents: .date)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(fieldBgColor)
                                        .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }

                        // Time Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SCHEDULE")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            VStack(spacing: 0) {
                                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                
                                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(fieldBgColor)
                                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                            )
                        }
                        
                        // Add Button
                        Button(action: saveTask) {
                            Text(taskToEdit == nil ? "Add to Agenda" : "Update Task")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(goldColor)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 4)
                                )
                        }
                        .padding(.top, 16)
                    }
                    .padding(32)
                }
            }
            .navigationTitle(taskToEdit == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(goldColor)
                }
            }
            .onAppear {
                if taskToEdit == nil {
                    pickDistinctColor()
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                NewCategoryView(categoryManager: categoryManager, selectedCategoryId: $selectedCategoryId, theme: currentTheme)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func pickDistinctColor() {
        // Get all currently used colors in the day
        let day = Calendar.current.startOfDay(for: taskDate)
        let dayTasks = tasksByDate[day, default: []]
        let usedColors = Set(dayTasks.map { $0.color })
        
        // Find indices of colors not yet used
        let availableIndices = aestheticColors.indices.filter { idx in
            !usedColors.contains(aestheticColors[idx].color)
        }
        
        if !availableIndices.isEmpty {
            selectedColorIndex = availableIndices.randomElement() ?? 0
        } else {
            selectedColorIndex = Int.random(in: 0..<aestheticColors.count)
        }
    }
    
    private func saveTask() {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: endTime)
        let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        
        let colorToUse: Color
        if let id = selectedCategoryId, let cat = categoryManager.categories.first(where: { $0.id == id }) {
            colorToUse = cat.color
        } else if let toEdit = taskToEdit {
            colorToUse = toEdit.color
        } else {
            colorToUse = aestheticColors[selectedColorIndex].color
        }
        
        let day = cal.startOfDay(for: taskDate)
        
        @AppStorage("isPro") var isPro = false
        
        if let toEdit = taskToEdit {
            // Remove old version if date changed
            if cal.startOfDay(for: selectedDate) != day {
                tasksByDate[selectedDate]?.removeAll { $0.id == toEdit.id }
            }
            
            var updatedTask = toEdit
            updatedTask.title = title.isEmpty ? "Updated Task" : title
            updatedTask.startMinutes = sMin
            updatedTask.endMinutes = eMin
            updatedTask.color = colorToUse
            
            // Sync update to Apple Calendar if Pro
            if isPro {
                if updatedTask.externalEventId != nil {
                    calendarManager.updateTask(updatedTask, date: day)
                } else if let extId = calendarManager.saveTask(updatedTask, date: day) {
                    updatedTask.externalEventId = extId
                }
            }
            
            var dayTasks = tasksByDate[day, default: []]
            if let idx = dayTasks.firstIndex(where: { $0.id == toEdit.id }) {
                dayTasks[idx] = updatedTask
            } else {
                dayTasks.append(updatedTask)
            }
            dayTasks.sort { $0.startMinutes < $1.startMinutes }
            tasksByDate[day] = dayTasks
            
        } else {
            var newTask = ClockTask(
                title: title.isEmpty ? "New Task" : title,
                startMinutes: sMin,
                endMinutes: eMin,
                color: colorToUse
            )
            
            // Push to Apple Calendar if Pro
            if isPro {
                if let extId = calendarManager.saveTask(newTask, date: day) {
                    newTask.externalEventId = extId
                }
            }
            
            var dayTasks = tasksByDate[day, default: []]
            dayTasks.append(newTask)
            dayTasks.sort { $0.startMinutes < $1.startMinutes }
            tasksByDate[day] = dayTasks
            
            // Update BrainDumpTask if needed
            if let bdtid = brainDumpTaskId {
                if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == bdtid }) {
                    brainDumpManager.tasks[index].scheduledDate = day
                    brainDumpManager.sortTasks()
                }
            }
        }
        
        // Update selected date so user sees the new task
        withAnimation {
            selectedDate = day
        }
        
        dismiss()
    }
}

struct TaskRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var time: String
    var title: String
    var color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                let parts = time.components(separatedBy: " - ")
                if parts.count == 2 {
                    Text(parts[0])
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                    Text(parts[1])
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                } else {
                    Text(time)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // Vertical separator
            Rectangle()
                .fill(currentTheme.textForeground.opacity(0.3))
                .frame(width: 1)
                .frame(minHeight: 30)
            
            // Colored Leaf icon
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(currentTheme.textForeground.opacity(0.9))
            
            Spacer()
        }
    }
}

struct NewCategoryView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var categoryManager: CategoryManager
    @Binding var selectedCategoryId: UUID?
    var theme: AppTheme
    
    @State private var name = ""
    @State private var selectedIcon = "folder.fill"
    @State private var selectedColorIndex = 0
    
    let icons = [
        "folder.fill", "briefcase.fill", "doc.text.fill", "book.fill", "graduationcap.fill",
        "pencil.and.outline", "paintbrush.fill", "scissors", "hammer.fill", "wrench.and.screwdriver.fill",
        "car.fill", "airplane", "bus.fill", "tram.fill", "bicycle",
        "cart.fill", "bag.fill", "creditcard.fill", "gift.fill", "tag.fill",
        "house.fill", "building.2.fill", "tent.fill", "tree.fill", "leaf.fill",
        "pawprint.fill", "sun.max.fill", "moon.fill", "cloud.fill", "sparkles",
        "heart.fill", "star.fill", "bolt.fill", "flame.fill", "drop.fill",
        "person.fill", "person.2.fill", "figure.walk", "figure.run", "figure.dance",
        "headphones", "tv.fill", "display", "gamecontroller.fill", "music.note"
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                theme.bg.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Preview
                        VStack(spacing: 12) {
                            Image(systemName: selectedIcon)
                                .font(.system(size: 40))
                                .foregroundStyle(aestheticColors[selectedColorIndex].color)
                            
                            Text(name.isEmpty ? "New Category" : name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(theme.textForeground.opacity(0.8))
                        }
                        .frame(width: 140, height: 140)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(theme.fieldBg)
                                .shadow(color: theme.shadowDark, radius: 8, x: 4, y: 4)
                                .shadow(color: theme.shadowLight, radius: 8, x: -4, y: -4)
                        )
                        .padding(.top, 20)
                        
                        // Name Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY NAME")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(theme.accent)
                                .tracking(1)
                            
                            TextField("Enter name...", text: $name)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(theme.textForeground)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.fieldBg)
                                        .shadow(color: theme.shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: theme.shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("COLOR")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(theme.accent)
                                .tracking(1)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<aestheticColors.count, id: \.self) { index in
                                        Button(action: {
                                            selectedColorIndex = index
                                        }) {
                                            Circle()
                                                .fill(aestheticColors[index].color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColorIndex == index ? theme.textForeground : Color.clear, lineWidth: 3)
                                                )
                                                .shadow(color: theme.shadowDark, radius: 3, x: 2, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Icon Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("ICON")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(theme.accent)
                                .tracking(1)
                            
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: 20) {
                                ForEach(icons, id: \.self) { icon in
                                    Button(action: {
                                        selectedIcon = icon
                                    }) {
                                        Image(systemName: icon)
                                            .font(.system(size: 24))
                                            .foregroundStyle(selectedIcon == icon ? aestheticColors[selectedColorIndex].color : theme.textForeground.opacity(0.4))
                                            .frame(width: 50, height: 50)
                                            .background(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(selectedIcon == icon ? theme.fieldBg : Color.clear)
                                                    .shadow(color: selectedIcon == icon ? theme.shadowDark : Color.clear, radius: 3, x: 2, y: 2)
                                                    .shadow(color: selectedIcon == icon ? theme.shadowLight : Color.clear, radius: 3, x: -2, y: -2)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        
                        // Add Button
                        Button(action: {
                            guard !name.isEmpty else { return }
                            let newCat = Category(name: name, icon: selectedIcon, rgb: aestheticColors[selectedColorIndex])
                            categoryManager.categories.append(newCat)
                            selectedCategoryId = newCat.id
                            dismiss()
                        }) {
                            Text("Create Category")
                                .font(.system(size: 16, weight: .medium, design: .serif))
                                .foregroundStyle(theme.bg)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(theme.accent)
                                        .shadow(color: .black.opacity(0.3), radius: 5, x: 2, y: 4)
                                )
                                .opacity(name.isEmpty ? 0.5 : 1.0)
                        }
                        .disabled(name.isEmpty)
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .padding(32)
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(theme.bg, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(theme.accent)
                }
            }
        }
        .preferredColorScheme(.dark)
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

struct ProfileAnalyticsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @EnvironmentObject var storeManager: StoreManager
    private var isPro: Bool { storeManager.isPro }
    
    @AppStorage("is24HourClock") private var is24HourClock = false
    var tasksByDate: [Date: [ClockTask]]
    
    @StateObject private var categoryManager = CategoryManager()
    @State private var showingPaywall = false
    
    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }

    struct CategoryStats: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let minutes: Double
        let percentage: Double
    }

    private var stats: [CategoryStats] {
        var breakdown: [Color: Double] = [:]
        var totalMinutes: Double = 0
        
        for (_, tasks) in tasksByDate {
            for task in tasks {
                let duration = Double(task.endMinutes - task.startMinutes)
                if duration > 0 {
                    breakdown[task.color, default: 0] += duration
                    totalMinutes += duration
                }
            }
        }
        
        if totalMinutes == 0 { return [] }
        
        let result = breakdown.map { (color, minutes) -> CategoryStats in
            let percentage = (minutes / totalMinutes) * 100
            
            // Try to find the category name from saved categories
            var name = "Custom"
            if let cat = categoryManager.categories.first(where: { $0.color == color }) {
                name = cat.name
            }
            
            return CategoryStats(name: name, color: color, minutes: minutes, percentage: percentage)
        }
        
        return result.sorted { $0.minutes > $1.minutes }
    }
    
    private var totalHours: Double {
        stats.reduce(0) { $0 + $1.minutes } / 60.0
    }
    
    // Pro Data: Weekly comparison
    private var momentumData: (current: [Double], previous: [Double]) {
        let cal = Calendar.current
        var current: [Double] = []
        var previous: [Double] = []
        let today = cal.startOfDay(for: Date())
        
        for i in (0..<7).reversed() {
            if let date = cal.date(byAdding: .day, value: -i, to: today) {
                let total = tasksByDate[date, default: []].reduce(0.0) { $0 + Double($1.endMinutes - $1.startMinutes) }
                current.append(total / 60.0)
            }
            if let date = cal.date(byAdding: .day, value: -(i + 7), to: today) {
                let total = tasksByDate[date, default: []].reduce(0.0) { $0 + Double($1.endMinutes - $1.startMinutes) }
                previous.append(total / 60.0)
            }
        }
        return (current, previous)
    }
    
    // Pro Data: Peak Focus (Hourly Density)
    private var hourlyDensity: [Int: Int] {
        var counts = [Int: Int]()
        for i in 0..<24 { counts[i] = 0 }
        
        for (_, tasks) in tasksByDate {
            for task in tasks {
                let startHour = task.startMinutes / 60
                let endHour = task.endMinutes / 60
                // Use exclusive range for endHour to be more accurate (a 1h task doesn't span 2 hours)
                for h in startHour..<max(startHour + 1, endHour) {
                    if h < 24 { counts[h, default: 0] += 1 }
                }
            }
        }
        return counts
    }
    
    private var peakHour: Int {
        hourlyDensity.max { $0.value < $1.value }?.key ?? 9
    }
    
    private var deepWorkRatio: (deep: Double, shallow: Double) {
        var deep: Double = 0
        var shallow: Double = 0
        for (_, tasks) in tasksByDate {
            for task in tasks {
                let duration = task.endMinutes - task.startMinutes
                if duration >= 60 {
                    deep += Double(duration)
                } else {
                    shallow += Double(duration)
                }
            }
        }
        let total = deep + shallow
        if total == 0 { return (0, 0) }
        return (deep / total, shallow / total)
    }
    
    private func formatDuration(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
    }
    
    private func formatHour(_ hour: Int) -> String {
        if is24HourClock {
            return String(format: "%02d:00", hour)
        } else {
            let h = hour % 12
            let period = hour < 12 ? "AM" : "PM"
            return "\(h == 0 ? 12 : h) \(period)"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Text("INSIGHTS")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)
                
                let currentStats = stats
                if currentStats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.pie.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(goldColor.opacity(0.3))
                        Text("No data to analyze yet.")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                    }
                    .padding(.top, 100)
                } else {
                    // 1. Basic Stats
                    HStack(spacing: 16) {
                        StatCard(title: "Total Time", value: String(format: "%.1fh", totalHours), icon: "clock.fill", color: goldColor)
                        
                        if let top = currentStats.first {
                            StatCard(title: "Top Activity", value: top.name, icon: "trophy.fill", color: top.color)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // 2. PRO SECTION: Peak Focus Window (VITAL)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("PEAK FOCUS WINDOW")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .tracking(1)
                                
                                if isPro {
                                    Text("Your rhythm peaks at \(formatHour(peakHour))")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundStyle(currentTheme.textForeground)
                                }
                            }
                            
                            Spacer()
                            
                            if !isPro {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(goldColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(goldColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        ZStack {
                            PeakFocusChart(density: isPro ? hourlyDensity : [9: 2, 10: 5, 11: 4, 12: 1], theme: currentTheme)
                                .frame(height: 100)
                                .blur(radius: isPro ? 0 : 8)
                            
                            if !isPro {
                                Button(action: { showingPaywall = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                        Text("Unlock Power Hours")
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(fieldBgColor)
                                    .clipShape(Capsule())
                                    .shadow(radius: 5)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(fieldBgColor)
                                .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                        )
                        
                        if isPro {
                            Text("Insight: You are most productive in the \(peakHour < 12 ? "morning" : "afternoon"). Try scheduling your highest-priority 'Deep Work' during this window.")
                                .font(.system(size: 12, design: .serif))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                                .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 32)

                    // 3. PRO SECTION: Focus Momentum (VITAL)
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("FOCUS MOMENTUM")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            Spacer()
                            
                            if !isPro {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(goldColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(goldColor.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        ZStack {
                            let data = momentumData
                            MomentumChart(current: isPro ? data.current : [2, 4, 3, 5, 4, 6, 4], 
                                         previous: isPro ? data.previous : [3, 3, 4, 4, 3, 5, 3], 
                                         theme: currentTheme)
                                .frame(height: 120)
                                .blur(radius: isPro ? 0 : 8)
                            
                            if !isPro {
                                Button(action: { showingPaywall = true }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "lock.fill")
                                        Text("Unlock Momentum")
                                    }
                                    .font(.system(size: 12, weight: .bold, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(fieldBgColor)
                                    .clipShape(Capsule())
                                    .shadow(radius: 5)
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(fieldBgColor)
                                .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                        )
                        
                        if isPro {
                            let curTotal = momentumData.current.reduce(0, +)
                            let prevTotal = momentumData.previous.reduce(0, +)
                            let diff = curTotal - prevTotal
                            
                            HStack {
                                Image(systemName: diff >= 0 ? "arrow.up.right.circle.fill" : "arrow.down.right.circle.fill")
                                    .foregroundStyle(diff >= 0 ? .green : .red)
                                Text(diff >= 0 ? "You've focused \(String(format: "%.1f", diff))h more than last week. Great work!" : "Your focus is down by \(String(format: "%.1f", abs(diff)))h this week. Time to reset?")
                                    .font(.system(size: 12, design: .serif))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // 4. Donut Chart
                    VStack(spacing: 24) {
                        Text("TIME DISTRIBUTION")
                            .font(.system(size: 12, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                            .tracking(1)
                        
                        ZStack {
                            Circle()
                                .stroke(fieldBgColor, lineWidth: 24)
                                .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                            
                            DonutChart(stats: currentStats)
                            
                            VStack {
                                Text("\(currentStats.count)")
                                    .font(.system(size: 36, weight: .light, design: .serif))
                                    .foregroundStyle(goldColor)
                                Text("Categories")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                            }
                        }
                        .frame(width: 200, height: 200)
                    }
                    .padding(.vertical, 16)
                    
                    // 5. Detailed Breakdown
                    VStack(alignment: .leading, spacing: 16) {
                        Text("BREAKDOWN")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)
                            .padding(.horizontal, 4)
                        
                        VStack(spacing: 12) {
                            ForEach(currentStats) { stat in
                                HStack(spacing: 16) {
                                    Circle()
                                        .fill(stat.color)
                                        .frame(width: 12, height: 12)
                                        .shadow(color: stat.color.opacity(0.5), radius: 4)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(stat.name)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                        
                                        // Progress Bar
                                        GeometryReader { proxy in
                                            ZStack(alignment: .leading) {
                                                Capsule()
                                                    .fill(fieldBgColor)
                                                    .frame(height: 6)
                                                
                                                Capsule()
                                                    .fill(stat.color)
                                                    .frame(width: proxy.size.width * (stat.percentage / 100), height: 6)
                                            }
                                        }
                                        .frame(height: 6)
                                    }
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(formatDuration(stat.minutes))
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(stat.color)
                                        Text("\(String(format: "%.0f", stat.percentage))%")
                                            .font(.system(size: 12, weight: .light))
                                            .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(fieldBgColor)
                                        .shadow(color: shadowDark, radius: 4, x: 2, y: 2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 60)
                }
            }
        }
        .scrollIndicators(.hidden)
        .sheet(isPresented: $showingPaywall) {
            HaikuProView()
        }
    }
}

struct StatCard: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var value: String
    var icon: String
    var color: Color
    
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.system(size: 20, weight: .medium, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                
                Text(title)
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.5))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(fieldBgColor)
                .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
        )
    }
}

struct DonutChart: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var stats: [ProfileAnalyticsView.CategoryStats]
    
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = (min(size.width, size.height) / 2) - 12 // Account for stroke width
            
            var startAngle = Angle.degrees(-90)
            
            for stat in stats {
                let angle = Angle.degrees((stat.percentage / 100) * 360)
                let endAngle = startAngle + angle
                
                var path = Path()
                path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                
                // Add a small gap between segments
                context.stroke(
                    path,
                    with: .color(stat.color),
                    style: StrokeStyle(lineWidth: 24, lineCap: .butt)
                )
                
                // Advance start angle, adding 2 degrees for spacing
                startAngle = endAngle + .degrees(2)
            }
        }
        .rotationEffect(.degrees(0)) // Canvas animations can be tricky, keep it static for stability
    }
}

struct WeeklyTrendChart: View {
    let data: [Double]
    let theme: AppTheme
    
    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let step = proxy.size.width / CGFloat(max(1, data.count - 1))
                let maxVal = max(1, data.max() ?? 1)
                let height = proxy.size.height
                
                for i in data.indices {
                    let x = step * CGFloat(i)
                    let y = height - (CGFloat(data[i] / maxVal) * height)
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(theme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .shadow(color: theme.accent.opacity(0.3), radius: 4, y: 4)
        }
    }
}

struct PeakFocusChart: View {
    let density: [Int: Int]
    let theme: AppTheme
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 4) {
            let maxVal = max(1, density.values.max() ?? 1)
            ForEach(0..<24) { hour in
                let val = density[hour] ?? 0
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent.opacity(val == 0 ? 0.1 : Double(val) / Double(maxVal)))
                    .frame(height: CGFloat(val) / CGFloat(maxVal) * 80 + 5)
            }
        }
    }
}

struct MomentumChart: View {
    let current: [Double]
    let previous: [Double]
    let theme: AppTheme
    
    var body: some View {
        ZStack {
            // Previous week (ghost line)
            GeometryReader { proxy in
                Path { path in
                    let step = proxy.size.width / CGFloat(max(1, previous.count - 1))
                    let maxVal = max(1, (current + previous).max() ?? 1)
                    let height = proxy.size.height
                    
                    for i in previous.indices {
                        let x = step * CGFloat(i)
                        let y = height - (CGFloat(previous[i] / maxVal) * height)
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(theme.textForeground.opacity(0.1), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))
            }
            
            // Current week (bold line)
            WeeklyTrendChart(data: current, theme: theme)
        }
    }
}

struct ProfileSettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("notificationOffsetsData") private var notificationOffsetsData = ""
    @EnvironmentObject var storeManager: StoreManager
    private var isPro: Bool { storeManager.isPro }
    
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
                    Button(action: { showingPaywall = true }) {
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
                            Button(action: {
                                if isPro {
                                    if let url = URL(string: "App-Prefs:root=CALENDAR"), UIApplication.shared.canOpenURL(url) {
                                        UIApplication.shared.open(url)
                                    } else if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                } else {
                                    showingPaywall = true
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: isPro ? "calendar" : "lock.fill")
                                        .foregroundStyle(goldColor)
                                    Text("Open Calendar Settings")
                                        .font(.system(size: 16, weight: .medium))
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

                        Link(destination: URL(string: "https://yourwebsite.com/privacy")!) {
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
                        
                        if !isPro {
                            Text("Note: Use StoreKit for production billing.")
                                .font(.system(size: 10, weight: .regular, design: .serif))
                                .foregroundStyle(Color.red.opacity(0.5))
                                .padding(.top, 4)
                        }
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
    }
}


struct TodoView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @StateObject private var brainDumpManager = BrainDumpManager()
    @State private var newTaskTitle: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingBulkImport = false
    
    // Selection for scheduling
    @State private var isSelectionMode = false
    @State private var selectedTaskIds = Set<UUID>()
    
    var onSchedule: (String, UUID) -> Void
    
    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 20) {
                Text("BRAIN DUMP")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)
                
                if !isSelectionMode {
                    // Quick Add Input
                    HStack(spacing: 12) {
                        TextField("Quick task...", text: $newTaskTitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(currentTheme.textForeground)
                            .tint(goldColor)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                addTask()
                            }
                        
                        Button(action: { showingBulkImport = true }) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(goldColor)
                        }

                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(newTaskTitle.isEmpty ? currentTheme.textForeground.opacity(0.3) : goldColor)
                        }
                        .disabled(newTaskTitle.isEmpty)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentTheme.fieldBg)
                    )
                    .padding(.horizontal, 40)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if brainDumpManager.tasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 32))
                            .foregroundStyle(goldColor.opacity(0.5))
                        Text("Clear your mind")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(brainDumpManager.tasks) { task in
                            BrainDumpRow(
                                title: task.title,
                                isCompleted: task.isCompleted,
                                scheduledDate: task.scheduledDate,
                                isSelected: selectedTaskIds.contains(task.id),
                                isSelectionMode: isSelectionMode,
                                onToggle: {
                                    if isSelectionMode {
                                        if selectedTaskIds.contains(task.id) {
                                            selectedTaskIds.remove(task.id)
                                        } else {
                                            selectedTaskIds.insert(task.id)
                                        }
                                    } else {
                                        if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                            withAnimation {
                                                brainDumpManager.tasks[index].isCompleted.toggle()
                                            }
                                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                        }
                                    }
                                }
                            )
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                        withAnimation {
                                            brainDumpManager.tasks.remove(at: index)
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveTask)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            // Bottom Action Bar
            HStack(alignment: .bottom, spacing: 16) {
                if isSelectionMode && !selectedTaskIds.isEmpty {
                    Button(action: {
                        if let firstId = selectedTaskIds.first,
                           let task = brainDumpManager.tasks.first(where: { $0.id == firstId }) {
                            onSchedule(task.title, task.id)
                            withAnimation {
                                isSelectionMode = false
                                selectedTaskIds.removeAll()
                            }
                        }
                    }) {
                        Text("Schedule Selected")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 35)
                                    .fill(goldColor)
                                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                            )
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    Spacer()
                }

                // Floating Action Button (Toggle)
                Button(action: { 
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedTaskIds.removeAll()
                        }
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(goldColor)
                            .frame(width: 70, height: 70)
                            .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isSelectionMode ? "xmark" : "calendar.badge.plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(currentTheme.bg)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(isPresented: $showingBulkImport, manager: brainDumpManager)
        }
    }
    
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        withAnimation {
            brainDumpManager.tasks.insert(BrainDumpTask(title: newTaskTitle), at: 0)
        }
        newTaskTitle = ""
        isFocused = true
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        brainDumpManager.tasks.move(fromOffsets: source, toOffset: destination)
    }
}

struct BrainDumpRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var isCompleted: Bool
    var scheduledDate: Date? = nil
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var onToggle: () -> Void

    private func formatScheduledDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        // Friday on March 19
        formatter.dateFormat = "EEEE 'on' MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 16) {
                if isSelectionMode {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isSelected ? currentTheme.accent : currentTheme.textForeground.opacity(0.3))
                } else {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isCompleted ? currentTheme.textForeground.opacity(0.3) : currentTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.4 : 0.9))
                        .strikethrough(isCompleted && !isSelectionMode, color: currentTheme.textForeground.opacity(0.4))
                    
                    if let scheduledDate = scheduledDate {
                        Text("\(formatScheduledDate(scheduledDate))")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    ContentView()
}

struct HaikuProView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) var dismiss
    @State private var isPurchasing = false
    
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
                        ProFeatureRow(icon: "calendar.badge.plus", title: "Multi-Calendar Sync", description: "Connect all your Google, iCloud, and Outlook calendars.")
                        ProFeatureRow(icon: "sparkles", title: "Future Updates", description: "Get early access to all new premium features.")
                    }
                    .padding(.horizontal, 40)
                    
                    // Pricing Tiers (Dynamic from StoreKit)
                    VStack(spacing: 16) {
                        if let proProduct = storeManager.products.first(where: { $0.id == storeManager.proID }) {
                            PricingButton(
                                title: proProduct.displayName,
                                price: proProduct.displayPrice,
                                subtitle: proProduct.description,
                                theme: currentTheme
                            ) {
                                buyPro()
                            }
                            .disabled(isPurchasing)
                        } else {
                            // Fallback if products haven't loaded yet
                            ProgressView()
                                .tint(currentTheme.accent)
                                .onAppear {
                                    Task { await storeManager.refresh() }
                                }
                        }
                        
                        Button(action: {
                            Task {
                                await storeManager.restore()
                                if storeManager.isPro {
                                    dismiss()
                                }
                            }
                        }) {
                            Text("Restore Purchases")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(currentTheme.accent.opacity(0.8))
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
                        ProgressView("Contacting App Store...")
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
        .onChange(of: storeManager.isPro) { newValue in
            if newValue { dismiss() }
        }
    }
    
    private func buyPro() {
        isPurchasing = true
        Task {
            do {
                try await storeManager.purchase()
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
