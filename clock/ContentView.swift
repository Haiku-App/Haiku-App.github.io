import SwiftUI
internal import Combine

struct ContentView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @State private var now = Date()
    // Slow down timer in Canvas to prevent update loop crashes
    private let timer = Timer.publish(
        every: ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" ? 1.0 : 0.05, 
        on: .main, 
        in: .common
    ).autoconnect()

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @StateObject private var calendarManager = CalendarManager()
    
    @State private var isFlowState = false
    
    @State private var tasksByDate: [Date: [ClockTask]] = {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            today: [
                ClockTask(title: "Matcha Tasting", startMinutes: 14*60, endMinutes: 15*60, color: AppTheme.sage.accent), // Gold
                ClockTask(title: "Garden Walk", startMinutes: 16*60, endMinutes: 17*60 + 30, color: Color(red: 0.75, green: 0.55, blue: 0.45)) // Muted Terracotta
            ]
        ]
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
        case clock, todo, analytics, profile
    }
    @State private var selectedTab: Tab = .clock
    @State private var showingAddTask = false
    @AppStorage("is24HourClock") private var is24HourClock = false

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("ATTENT")
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
                            
                            Text(formattedSelectedDate())
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                .frame(minWidth: 100, alignment: .center)
                                .id(selectedDate) // Forces animation on change
                                .transition(.opacity)
                            
                            Button(action: { changeDate(by: 1) }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(goldColor.opacity(0.8))
                            }
                        }
                        
                        // Right-aligned Plus Button
                        HStack {
                            Spacer()
                            Button(action: { showingAddTask = true }) {
                                Image(systemName: "plus")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(goldColor)
                            }
                            .padding(.trailing, 40)
                        }
                    }
                }
                .padding(.top, 20)
                .opacity(isFlowState ? 0 : 1)
                .animation(.easeInOut, value: isFlowState)

                Spacer()

                // Content Views
                Group {
                    if selectedTab == .clock {
                        clockContentView()
                            .id(selectedDate) // Animate view transition when date changes
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    } else if selectedTab == .todo {
                        TodoView()
                    } else if selectedTab == .analytics {
                        ProfileAnalyticsView(tasksByDate: tasksByDate)
                    } else if selectedTab == .profile {
                        ProfileSettingsView(is24HourClock: $is24HourClock)
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
            AddTaskView(tasks: currentTasksBinding)
        }
        .onAppear {
            syncCalendar(for: selectedDate)
        }
        .onChange(of: selectedDate) { newDate in
            syncCalendar(for: newDate)
        }
    }

    private func syncCalendar(for date: Date) {
        calendarManager.requestAccess { granted in
            if granted {
                let fetched = calendarManager.fetchEvents(for: date)
                if !fetched.isEmpty {
                    DispatchQueue.main.async {
                        var current = tasksByDate[date, default: []]
                        for fetchedTask in fetched {
                            if !current.contains(where: { $0.title == fetchedTask.title && $0.startMinutes == fetchedTask.startMinutes }) {
                                current.append(fetchedTask)
                            }
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
                            TaskRow(
                                time: timeString,
                                title: task.title,
                                color: task.color,
                                isCompleted: task.isCompleted,
                                onToggle: {
                                    if let index = tasksByDate[selectedDate]?.firstIndex(where: { $0.id == task.id }) {
                                        withAnimation {
                                            tasksByDate[selectedDate]?[index].isCompleted.toggle()
                                        }
                                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                    }
                                }
                            )
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        if let index = tasksByDate[selectedDate]?.firstIndex(where: { $0.id == task.id }) {
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
    @Binding var tasks: [ClockTask]
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    @StateObject private var categoryManager = CategoryManager()
    @State private var selectedCategoryId: UUID? = nil
    
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""
    
    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }
    
    private let themeRGBs: [RGB] = [
        RGB(r: 0.85, g: 0.78, b: 0.58), // Gold
        RGB(r: 0.75, g: 0.55, b: 0.45), // Muted Terracotta
        RGB(r: 0.45, g: 0.50, b: 0.35), // Olive
        RGB(r: 0.80, g: 0.72, b: 0.60), // Soft Sand
        RGB(r: 0.35, g: 0.42, b: 0.35)  // Pale Mint
    ]

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
                                    .fill(Color.white.opacity(0.1))
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
                            Text("Add to Agenda")
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
            .navigationTitle("New Task")
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
            .alert("New Category", isPresented: $showingNewCategory) {
                TextField("Category Name", text: $newCategoryName)
                Button("Cancel", role: .cancel) { newCategoryName = "" }
                Button("Save") {
                    guard !newCategoryName.isEmpty else { return }
                    let rgb = themeRGBs[categoryManager.categories.count % themeRGBs.count]
                    let newCat = Category(name: newCategoryName, icon: "folder.fill", rgb: rgb)
                    categoryManager.categories.append(newCat)
                    selectedCategoryId = newCat.id
                    newCategoryName = ""
                }
            }
        }
        .preferredColorScheme(.dark)
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
        } else {
            colorToUse = currentTheme.accent
        }
        
        let newTask = ClockTask(
            title: title.isEmpty ? "New Task" : title,
            startMinutes: sMin,
            endMinutes: eMin,
            color: colorToUse
        )
        tasks.append(newTask)
        tasks.sort { $0.startMinutes < $1.startMinutes }
        dismiss()
    }
}

struct TaskRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var time: String
    var title: String
    var color: Color
    var isCompleted: Bool
    var onToggle: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                let parts = time.components(separatedBy: " - ")
                if parts.count == 2 {
                    Text(parts[0])
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.3 : 0.8))
                        .strikethrough(isCompleted, color: currentTheme.textForeground.opacity(0.3))
                    Text(parts[1])
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.2 : 0.5))
                        .strikethrough(isCompleted, color: currentTheme.textForeground.opacity(0.2))
                } else {
                    Text(time)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.3 : 0.8))
                        .strikethrough(isCompleted, color: currentTheme.textForeground.opacity(0.3))
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // Vertical separator
            Rectangle()
                .fill(.white.opacity(isCompleted ? 0.1 : 0.3))
                .frame(width: 1)
                .frame(minHeight: 30)
            
            // Colored Leaf icon
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(isCompleted ? color.opacity(0.3) : color)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.4 : 0.9))
                .strikethrough(isCompleted, color: currentTheme.textForeground.opacity(0.4))
            
            Spacer()
            
            // Checkbox
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(isCompleted ? color.opacity(0.5) : color)
            }
            .buttonStyle(.plain)
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
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
                Text(text)
                    .font(.system(size: 10))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.5))
            }
        }
        .buttonStyle(.plain)
    }
}

struct ProfileAnalyticsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var tasksByDate: [Date: [ClockTask]]
    
    @StateObject private var categoryManager = CategoryManager()
    
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
    
    private func formatDuration(_ minutes: Double) -> String {
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        if h > 0 {
            return "\(h)h \(m)m"
        }
        return "\(m)m"
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
                    // Top Stat Cards
                    HStack(spacing: 16) {
                        StatCard(title: "Total Time", value: String(format: "%.1fh", totalHours), icon: "clock.fill", color: goldColor)
                        
                        if let top = currentStats.first {
                            StatCard(title: "Top Activity", value: top.name, icon: "trophy.fill", color: top.color)
                        }
                    }
                    .padding(.horizontal, 32)
                    
                    // Donut Chart
                    VStack(spacing: 24) {
                        Text("Time Distribution")
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
                    
                    // Detailed Breakdown
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

struct ProfileSettingsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @Binding var is24HourClock: Bool
    
    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    var body: some View {
        ScrollView {
            VStack(spacing: 40) {
                Text("SETTINGS")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)

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

                        Button(action: { /* mock connect */ }) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(goldColor)
                                Text("Connect Google Calendar")
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

                        Button(action: { /* mock connect */ }) {
                            HStack(spacing: 12) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(goldColor)
                                Text("Connect Microsoft Calendar")
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
                    }
                }
                .padding(.horizontal, 40)
            }
        }
    }}


struct TodoView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @StateObject private var brainDumpManager = BrainDumpManager()
    @State private var newTaskTitle: String = ""
    @FocusState private var isFocused: Bool
    
    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }

    var body: some View {
        VStack(spacing: 20) {
            Text("BRAIN DUMP")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(2)
                .padding(.top, 40)
            
            // Quick Add Input
            HStack {
                TextField("Quick task...", text: $newTaskTitle)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(currentTheme.textForeground)
                    .tint(goldColor)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        addTask()
                    }
                
                Button(action: addTask) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(newTaskTitle.isEmpty ? .white.opacity(0.3) : goldColor)
                }
                .disabled(newTaskTitle.isEmpty)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(currentTheme.fieldBg)
            )
            .padding(.horizontal, 40)
            
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
                            onToggle: {
                                if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                    withAnimation {
                                        brainDumpManager.tasks[index].isCompleted.toggle()
                                    }
                                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
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
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
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
}

struct BrainDumpRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var isCompleted: Bool
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onToggle) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22, weight: .light))
                    .foregroundStyle(isCompleted ? .white.opacity(0.3) : currentTheme.accent)
            }

            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.4 : 0.9))
                .strikethrough(isCompleted, color: currentTheme.textForeground.opacity(0.4))

            Spacer()
        }
    }
}


#Preview {
    ContentView()
}

