import SwiftUI
internal import Combine

struct ContentView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    @State private var selectedDate = Calendar.current.startOfDay(for: Date())
    
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
        case clock, week, today, profile
    }
    @State private var selectedTab: Tab = .clock
    @State private var showingAddTask = false

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

                Spacer()

                // Content Views
                Group {
                    if selectedTab == .clock {
                        clockContentView()
                            .id(selectedDate) // Animate view transition when date changes
                            .transition(.asymmetric(insertion: .opacity, removal: .opacity))
                    } else if selectedTab == .week {
                        Text("Week View").font(.title).foregroundStyle(goldColor)
                    } else if selectedTab == .today {
                        Text("Today's Agenda").font(.title).foregroundStyle(goldColor)
                    } else if selectedTab == .profile {
                        Text("User Profile").font(.title).foregroundStyle(goldColor)
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
                    TabBarButton(icon: "calendar.day.timeline.left", text: "Today", isSelected: selectedTab == .today) {
                        selectedTab = .today
                    }
                    Spacer()
                    TabBarButton(icon: "person.fill", text: "Profile", isSelected: selectedTab == .profile) {
                        selectedTab = .profile
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
                .foregroundStyle(.white.opacity(0.6))
            }
        }
        .onReceive(timer) { date in
            now = date
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskView(tasks: currentTasksBinding)
        }
    }

    @ViewBuilder
    private func clockContentView() -> some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 20)
                
            // Clock
            ClockView(now: now, tasks: currentTasksBinding)
                .frame(width: 280, height: 280)
                
            // Daily Quote
            Text(timeQuote(for: selectedDate))
                .font(.system(size: 13, weight: .light, design: .serif))
                .foregroundStyle(.white.opacity(0.4))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.top, 24)

            Spacer()
                .frame(height: 26)

            // Task List
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
                        TaskRow(time: timeString, title: task.title, color: task.color)
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
            
            Spacer()
        }
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
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    private func timeQuote(for date: Date) -> String {
        let quotes = [
            "“Time is the longest distance between two places.” — Tennessee Williams",
            "“The two most powerful warriors are patience and time.” — Leo Tolstoy",
            "“Time you enjoy wasting is not wasted time.” — Marthe Troly-Curtin",
            "“Punctuality is the thief of time.” — Oscar Wilde",
            "“Time flies over us, but leaves its shadow behind.” — Nathaniel Hawthorne",
            "“There is never enough time to do everything, but there is always enough time to do the most important thing.” — Brian Tracy",
            "“Lost time is never found again.” — Benjamin Franklin",
            "“Time changes everything except something within us which is always surprised by change.” — Thomas Hardy"
        ]
        
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 0
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

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        
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
    
    private func saveTask() {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: endTime)
        let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        
        let nextColor = themeColors[tasks.count % themeColors.count]
        
        let newTask = ClockTask(
            title: title.isEmpty ? "New Task" : title,
            startMinutes: sMin,
            endMinutes: eMin,
            color: nextColor
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
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                let parts = time.components(separatedBy: " - ")
                if parts.count == 2 {
                    Text(parts[0])
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                    Text(parts[1])
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text(time)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // Vertical separator
            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(width: 1)
                .frame(minHeight: 30)
            
            // Colored Leaf icon
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(.white.opacity(0.9))
            
            Spacer()
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

#Preview {
    ContentView()
}
