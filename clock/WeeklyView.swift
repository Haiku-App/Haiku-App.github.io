import SwiftUI

struct WeeklyView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage("is24HourClock") private var is24HourClock = false
    @State private var isCalendarLayout = false
    
    var tasksByDate: [Date: [ClockTask]]
    @Binding var selectedDate: Date
    @Binding var selectedTab: ContentView.Tab
    var onAppear: ((Date) -> Void)? = nil
    var onWeekChanged: ((Date) -> Void)? = nil
    
    @State private var displayWeek: Date = {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let weekday = cal.component(.weekday, from: today)
        return cal.date(byAdding: .day, value: 1 - weekday, to: today) ?? today
    }()
    
    private let daysOfWeek = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header for week range
            VStack(spacing: 20) {
                HStack {
                    Button(action: { changeWeek(by: -7) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(currentTheme.accent)
                            .padding(10)
                            .background(Circle().fill(currentTheme.fieldBg))
                    }
                    
                    Spacer()
                    
                    Text(weekRangeString(from: displayWeek))
                        .font(.system(size: 20, weight: .semibold, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                    
                    Spacer()
                    
                    Button(action: { changeWeek(by: 7) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(currentTheme.accent)
                            .padding(10)
                            .background(Circle().fill(currentTheme.fieldBg))
                    }
                }
                
                // Layout Toggle
                HStack(spacing: 0) {
                    Button(action: { withAnimation(.spring()) { isCalendarLayout = false } }) {
                        Text("Clocks")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(isCalendarLayout ? currentTheme.textForeground.opacity(0.5) : currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(isCalendarLayout ? Color.clear : currentTheme.accent)
                            .clipShape(Capsule())
                    }
                    
                    Button(action: { withAnimation(.spring()) { isCalendarLayout = true } }) {
                        Text("Calendar")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(!isCalendarLayout ? currentTheme.textForeground.opacity(0.5) : currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(!isCalendarLayout ? Color.clear : currentTheme.accent)
                            .clipShape(Capsule())
                    }
                }
                .background(currentTheme.fieldBg)
                .clipShape(Capsule())
                .padding(.horizontal, 40)
            }
            .padding(.horizontal, 24)
            .padding(.top, 40)
            .padding(.bottom, 20)
            
            if isCalendarLayout {
                StandardCalendarLayout(tasksByDate: tasksByDate, displayWeek: displayWeek, currentTheme: currentTheme, is24HourClock: is24HourClock, selectedDate: $selectedDate, selectedTab: $selectedTab)
                    .transition(.asymmetric(insertion: .opacity.combined(with: .move(edge: .trailing)), removal: .opacity))
            } else {
                // Grid of Large Clocks
                ScrollView {
                    VStack(spacing: 32) {
                        let days = getDaysInWeek()
                        ForEach(0..<days.count, id: \.self) { index in
                            if let date = days[index] {
                                let tasks = tasksByDate[date, default: []]
                                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                                let dayName = daysOfWeek[index]
                                let dayNum = Calendar.current.component(.day, from: date)
                                
                                HStack(spacing: 24) {
                                    // Left side: Day info
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(dayName)
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundStyle(isSelected ? currentTheme.accent : currentTheme.textForeground.opacity(0.4))
                                        Text("\(dayNum)")
                                            .font(.system(size: 32, weight: .light, design: .serif))
                                            .foregroundStyle(isSelected ? currentTheme.textForeground : currentTheme.textForeground.opacity(0.8))
                                    }
                                    .frame(width: 60, alignment: .leading)
                                    
                                    // Right side: Big Clock with tasks
                                    ZStack {
                                        StaticClockView(now: Date(), tasks: tasks, is24HourClock: is24HourClock, theme: currentTheme, showHands: true, showText: true)
                                            .frame(width: 140, height: 140)
                                            .background(
                                                Circle()
                                                    .fill(currentTheme.fieldBg)
                                                    .shadow(color: currentTheme.shadowDark, radius: 10, x: 6, y: 6)
                                                    .shadow(color: currentTheme.shadowLight, radius: 10, x: -6, y: -6)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(isSelected ? currentTheme.accent : Color.clear, lineWidth: 3)
                                                    .padding(-8)
                                            )
                                    }
                                    .onTapGesture {
                                        withAnimation {
                                            selectedDate = date
                                            selectedTab = .clock
                                        }
                                    }
                                    
                                    // Task summary
                                    VStack(alignment: .leading, spacing: 6) {
                                        if tasks.isEmpty {
                                            Text("No tasks")
                                                .font(.system(size: 12, weight: .light))
                                                .foregroundStyle(currentTheme.textForeground.opacity(0.3))
                                        } else {
                                            ForEach(tasks.prefix(3)) { task in
                                                HStack(spacing: 6) {
                                                    Circle()
                                                        .fill(task.color)
                                                        .frame(width: 6, height: 6)
                                                    Text(task.title)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                                                        .lineLimit(1)
                                                }
                                            }
                                            if tasks.count > 3 {
                                                Text("+ \(tasks.count - 3) more")
                                                    .font(.system(size: 10, weight: .light))
                                                    .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                                            }
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 24)
                                .background(
                                    RoundedRectangle(cornerRadius: 24)
                                        .fill(isSelected ? currentTheme.fieldBg.opacity(0.5) : Color.clear)
                                )
                            }
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .id(displayWeek)
        .onAppear {
            onAppear?(displayWeek)
        }
    }
    
    private func changeWeek(by days: Int) {
        withAnimation(.easeInOut(duration: 0.3)) {
            if let newWeek = Calendar.current.date(byAdding: .day, value: days, to: displayWeek) {
                displayWeek = newWeek
                onWeekChanged?(newWeek)
            }
        }
    }
    
    private func weekRangeString(from date: Date) -> String {
        let cal = Calendar.current
        let endDate = cal.date(byAdding: .day, value: 6, to: date) ?? date
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        let startStr = formatter.string(from: date)
        let endStr = formatter.string(from: endDate)
        
        formatter.dateFormat = "yyyy"
        let yearStr = formatter.string(from: endDate)
        
        return "\(startStr) - \(endStr), \(yearStr)"
    }
    
    private func getDaysInWeek() -> [Date?] {
        var days: [Date?] = []
        let cal = Calendar.current
        for i in 0..<7 {
            if let date = cal.date(byAdding: .day, value: i, to: displayWeek) {
                days.append(cal.startOfDay(for: date))
            }
        }
        return days
    }
}

struct StandardCalendarLayout: View {
    let tasksByDate: [Date: [ClockTask]]
    let displayWeek: Date
    let currentTheme: AppTheme
    let is24HourClock: Bool
    @Binding var selectedDate: Date
    @Binding var selectedTab: ContentView.Tab
    
    private let hourHeight: CGFloat = 60
    private let timeWidth: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 0) {
            // Day Headers
            HStack(spacing: 0) {
                Spacer().frame(width: timeWidth)
                let days = getDaysInWeek()
                ForEach(0..<7) { index in
                    if let date = days[index] {
                        let isToday = Calendar.current.isDateInToday(date)
                        VStack(spacing: 4) {
                            Text(["S", "M", "T", "W", "T", "F", "S"][index])
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(isToday ? currentTheme.accent : currentTheme.textForeground.opacity(0.4))
                            Text("\(Calendar.current.component(.day, from: date))")
                                .font(.system(size: 16, weight: .semibold, design: .serif))
                                .foregroundStyle(isToday ? currentTheme.accent : currentTheme.textForeground)
                        }
                        .frame(maxWidth: .infinity)
                        .onTapGesture {
                            withAnimation {
                                selectedDate = date
                                selectedTab = .clock
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 10)
            
            ScrollView {
                ZStack(alignment: .topLeading) {
                    // Grid Lines & Time Labels
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(0..<24) { hour in
                            HStack(spacing: 0) {
                                Text(formatHour(hour))
                                    .font(.system(size: 10))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.4))
                                    .frame(width: timeWidth, alignment: .trailing)
                                    .padding(.trailing, 8)
                                
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.05))
                                    .frame(height: 1)
                            }
                            .frame(height: hourHeight)
                        }
                    }
                    
                    // Task Blocks
                    HStack(spacing: 0) {
                        Spacer().frame(width: timeWidth)
                        let days = getDaysInWeek()
                        ForEach(0..<7) { dayIndex in
                            if let date = days[dayIndex] {
                                let tasks = tasksByDate[date, default: []]
                                ZStack(alignment: .topLeading) {
                                    Color.clear // Container for the day
                                    
                                    ForEach(tasks) { task in
                                        let start = CGFloat(task.startMinutes) / 60.0 * hourHeight
                                        let duration = CGFloat(task.endMinutes - task.startMinutes) / 60.0 * hourHeight
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(task.color.opacity(0.8))
                                            .overlay(
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(task.title)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .foregroundStyle(.white)
                                                        .lineLimit(1)
                                                }
                                                .padding(4),
                                                alignment: .topLeading
                                            )
                                            .frame(height: max(15, duration))
                                            .padding(.horizontal, 1)
                                            .offset(y: start)
                                            .onTapGesture {
                                                withAnimation {
                                                    selectedDate = date
                                                    selectedTab = .clock
                                                }
                                            }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                
                                // Vertical divider
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.05))
                                    .frame(width: 1)
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
    }
    
    private func getDaysInWeek() -> [Date?] {
        var days: [Date?] = []
        let cal = Calendar.current
        for i in 0..<7 {
            if let date = cal.date(byAdding: .day, value: i, to: displayWeek) {
                days.append(cal.startOfDay(for: date))
            }
        }
        return days
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
}
