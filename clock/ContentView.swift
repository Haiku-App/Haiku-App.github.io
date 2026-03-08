import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    @StateObject private var calendarManager = CalendarManager()
    
    @State private var isFlowState = false
    
    @State private var tasksByDate: [Date: [ClockTask]] = {
        let today = Calendar.current.startOfDay(for: Date())
        return [
            today: [
                ClockTask(title: "Matcha Tasting", startMinutes: 14*60, endMinutes: 15*60, color: Color(red: 0.85, green: 0.78, blue: 0.58)), // Gold
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

    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)

    enum Tab {
        case clock, week, analytics, profile
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
                            
                            Text(formattedSelectedDate())
                                .font(.system(size: 14, weight: .medium, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
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
                    } else if selectedTab == .week {
                        Text("Week View").font(.title).foregroundStyle(goldColor)
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
                    TabBarButton(icon: "calendar", text: "Week", isSelected: selectedTab == .week) {
                        selectedTab = .week
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
                .foregroundStyle(.white.opacity(0.6))
                .opacity(isFlowState ? 0 : 1)
                .animation(.easeInOut, value: isFlowState)
            }
        }
        .onReceive(timer) { date in
            now = date
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
            ClockView(now: now, tasks: currentTasksBinding, isFlowState: $isFlowState, is24HourClock: is24HourClock)
                .frame(width: 280, height: 280)
                .scaleEffect(isFlowState ? 1.15 : 1.0)
                
            // Daily Quote
            Text(timeQuote(for: selectedDate))
                .font(.system(size: 13, weight: .light, design: .serif))
                .foregroundStyle(.white.opacity(0.4))
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
                            .foregroundStyle(.white.opacity(0.5))
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

    private func timeQuote(for date: Date) -> String {
        let quotes = [
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

        // Use .day within .year to compute day-of-year (1-based). Fallback to 1 on failure.
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % quotes.count
        return quotes[index]
    }
}

struct AddTaskView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var tasks: [ClockTask]
    
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let fieldBgColor = Color(red: 0.15, green: 0.20, blue: 0.15)
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)
    private let shadowLight = Color(red: 0.22, green: 0.28, blue: 0.22)
    private let shadowDark = Color(red: 0.12, green: 0.16, blue: 0.12)
    
    private let themeColors: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 0.58), // Gold
        Color(red: 0.75, green: 0.55, blue: 0.45), // Muted Terracotta
        Color(red: 0.45, green: 0.50, blue: 0.35), // Olive
        Color(red: 0.80, green: 0.72, blue: 0.60), // Soft Sand
        Color(red: 0.35, green: 0.42, blue: 0.35)  // Pale Mint
    ]

    struct Template {
        var name: String
        var icon: String
        var duration: Int
        var color: Color
    }
    
    private let templates = [
        Template(name: "Deep Work", icon: "brain.head.profile", duration: 90, color: Color(red: 0.75, green: 0.55, blue: 0.45)),
        Template(name: "Meeting", icon: "person.2.fill", duration: 30, color: Color(red: 0.85, green: 0.78, blue: 0.58)),
        Template(name: "Admin", icon: "tray.fill", duration: 60, color: Color(red: 0.80, green: 0.72, blue: 0.60)),
        Template(name: "Break", icon: "cup.and.saucer.fill", duration: 15, color: Color(red: 0.35, green: 0.42, blue: 0.35))
    ]
    
    @State private var selectedTemplate: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
                        // Templates
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TEMPLATES")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(templates, id: \.name) { tmpl in
                                        Button(action: {
                                            applyTemplate(tmpl)
                                        }) {
                                            VStack(spacing: 12) {
                                                Image(systemName: tmpl.icon)
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(tmpl.color)
                                                Text(tmpl.name)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(.white.opacity(0.8))
                                            }
                                            .frame(width: 100, height: 100)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(fieldBgColor)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(selectedTemplate == tmpl.name ? tmpl.color : Color.clear, lineWidth: 2)
                                                    )
                                                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                            )
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
                                .foregroundStyle(.white)
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
                                    .foregroundStyle(.white.opacity(0.9))
                                
                                Rectangle()
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                
                                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(.white.opacity(0.9))
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
        }
        .preferredColorScheme(.dark) // Keeps picker popups dark
    }
    
    private func applyTemplate(_ tmpl: Template) {
        selectedTemplate = tmpl.name
        title = tmpl.name
        endTime = startTime.addingTimeInterval(TimeInterval(tmpl.duration * 60))
    }
    
    private func saveTask() {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: endTime)
        let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        
        let colorToUse: Color
        if let st = selectedTemplate, let tmpl = templates.first(where: { $0.name == st }) {
            colorToUse = tmpl.color
        } else {
            colorToUse = themeColors[tasks.count % themeColors.count]
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
                        .foregroundStyle(.white.opacity(isCompleted ? 0.3 : 0.8))
                        .strikethrough(isCompleted, color: .white.opacity(0.3))
                    Text(parts[1])
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(isCompleted ? 0.2 : 0.5))
                        .strikethrough(isCompleted, color: .white.opacity(0.2))
                } else {
                    Text(time)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(isCompleted ? 0.3 : 0.8))
                        .strikethrough(isCompleted, color: .white.opacity(0.3))
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
                .foregroundStyle(.white.opacity(isCompleted ? 0.4 : 0.9))
                .strikethrough(isCompleted, color: .white.opacity(0.4))
            
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
    var tasksByDate: [Date: [ClockTask]]
    
    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)

    // Calculate time spent per color in minutes
    private var colorBreakdown: [(Color, Double, String)] {
        var breakdown: [Color: Double] = [:]
        var totalMinutes: Double = 0
        
        for (_, tasks) in tasksByDate {
            for task in tasks {
                // Approximate template matching by color
                let duration = Double(task.endMinutes - task.startMinutes)
                breakdown[task.color, default: 0] += duration
                totalMinutes += duration
            }
        }
        
        if totalMinutes == 0 { return [] }
        
        let result = breakdown.map { (color, minutes) -> (Color, Double, String) in
            let percentage = (minutes / totalMinutes) * 100
            var name = "Custom"
            if color == Color(red: 0.75, green: 0.55, blue: 0.45) { name = "Deep Work" }
            else if color == Color(red: 0.85, green: 0.78, blue: 0.58) { name = "Meetings" }
            else if color == Color(red: 0.80, green: 0.72, blue: 0.60) { name = "Admin" }
            else if color == Color(red: 0.35, green: 0.42, blue: 0.35) { name = "Break" }
            else if color == Color(red: 0.45, green: 0.50, blue: 0.35) { name = "Creative" }
            
            return (color, percentage, name)
        }
        
        return result.sorted { $0.1 > $1.1 } // Sort by largest percentage
    }
    
    var body: some View {
        VStack(spacing: 40) {
            Text("YOUR WEEK IN COLOR")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(2)
            
            let breakdown = colorBreakdown
            if breakdown.isEmpty {
                Text("No data to analyze yet.")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
            } else {
                // Color Bar
                GeometryReader { proxy in
                    HStack(spacing: 0) {
                        ForEach(breakdown, id: \.2) { item in
                            Rectangle()
                                .fill(item.0)
                                .frame(width: proxy.size.width * (item.1 / 100))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 5, x: 2, y: 4)
                }
                .frame(height: 30)
                .padding(.horizontal, 40)
                
                // Legend
                VStack(spacing: 20) {
                    ForEach(breakdown, id: \.2) { item in
                        HStack {
                            Circle()
                                .fill(item.0)
                                .frame(width: 12, height: 12)
                            Text(item.2)
                                .font(.system(size: 14, weight: .regular, design: .serif))
                                .foregroundStyle(.white.opacity(0.9))
                            Spacer()
                            Text("\(String(format: "%.0f", item.1))%")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(item.0)
                        }
                        .padding(.horizontal, 60)
                    }
                }
            }
        }
    }
}

struct ProfileSettingsView: View {
    @Binding var is24HourClock: Bool
    
    private let bgColor = Color(red: 0.18, green: 0.23, blue: 0.18) // Muted Sage Green
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)

    var body: some View {
        VStack(spacing: 40) {
            Text("SETTINGS")
                .font(.system(size: 14, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(2)
            
            Toggle("24-Hour Clock", isOn: $is24HourClock)
                .font(.system(size: 16, weight: .medium, design: .serif))
                .foregroundStyle(.white.opacity(0.9))
                .padding()
                .tint(goldColor)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(red: 0.15, green: 0.20, blue: 0.15))
                        .shadow(color: Color(red: 0.12, green: 0.16, blue: 0.12), radius: 5, x: 4, y: 4)
                        .shadow(color: Color(red: 0.22, green: 0.28, blue: 0.22), radius: 5, x: -4, y: -4)
                )
                .padding(.horizontal, 40)
        }
    }
}

#Preview {
    ContentView()
}

