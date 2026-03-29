import SwiftUI

struct ProfileAnalyticsView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @EnvironmentObject var storeManager: StoreManager
    private var isPro: Bool { storeManager.isPro }
    
    var tasksByDate: [Date: [ClockTask]]
    
    @StateObject private var categoryManager = CategoryManager()
    @State private var showingPaywall = false
    @State private var selectedMetricInfo: MetricInfo? = nil
    
    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }
    private let uncategorizedColor = Color(red: 0.60, green: 0.60, blue: 0.60)

    struct MetricInfo: Identifiable {
        let id = UUID()
        let title: String
        let description: String
    }

    struct CategoryStats: Identifiable {
        let id = UUID()
        let name: String
        let color: Color
        let minutes: Double
        let percentage: Double
    }

    private var stats: [CategoryStats] {
        var breakdown: [String: (color: Color, minutes: Double)] = [:]
        var totalMinutes: Double = 0
        
        for (_, tasks) in tasksByDate {
            for task in tasks {
                let duration = Double(task.endMinutes - task.startMinutes)
                if duration > 0 {
                    let resolved = resolvedCategory(for: task)
                    let current = breakdown[resolved.name, default: (resolved.color, 0)]
                    breakdown[resolved.name] = (resolved.color, current.minutes + duration)
                    totalMinutes += duration
                }
            }
        }
        
        if totalMinutes == 0 { return [] }

        let result = breakdown.map { (name, data) -> CategoryStats in
            let percentage = (data.minutes / totalMinutes) * 100
            return CategoryStats(name: name, color: data.color, minutes: data.minutes, percentage: percentage)
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
        let maxCount = hourlyDensity.values.max() ?? 0
        guard maxCount > 0 else { return 9 }

        return hourlyDensity
            .filter { $0.value == maxCount }
            .map(\.key)
            .min() ?? 9
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
    
    private func resolvedCategory(for task: ClockTask) -> (name: String, color: Color) {
        if let categoryId = task.categoryId,
           let category = categoryManager.categories.first(where: { $0.id == categoryId }) {
            return (category.name, category.color)
        }

        if let categoryName = task.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !categoryName.isEmpty {
            if let category = categoryManager.categories.first(where: { $0.name.caseInsensitiveCompare(categoryName) == .orderedSame }) {
                return (category.name, category.color)
            }

            return (categoryName, task.color)
        }

        if let category = categoryManager.categories.first(where: { $0.color == task.color }) {
            return (category.name, category.color)
        }

        return ("Custom", uncategorizedColor)
    }

    private func formatHour(_ hour: Int) -> String {
        let normalizedHour = ((hour % 24) + 24) % 24
        let displayHour = normalizedHour % 12 == 0 ? 12 : normalizedHour % 12
        let period = normalizedHour < 12 ? "am" : "pm"
        return "\(displayHour)\(period)"
    }

    var body: some View {
        ZStack {
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
                            HStack(spacing: 8) {
                                Text("PEAK FOCUS WINDOW")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .tracking(1)
                                
                                Button(action: {
                                    selectedMetricInfo = MetricInfo(
                                        title: "Peak Focus Window",
                                        description: "This identifies your 'Biological Prime Time'. We analyze the density of your scheduled tasks across all days to find the specific hour when you are most consistently active. Scheduling Deep Work during this window can significantly boost productivity."
                                    )
                                    AnalyticsManager.shared.capture("analytics_info_clicked", properties: ["metric": "peak_focus"])
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(goldColor.opacity(0.5))
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
                            
                            if isPro {
                                Text("Your rhythm peaks at \(formatHour(peakHour))")
                                    .font(.system(size: 16, weight: .bold, design: .serif))
                                    .foregroundStyle(currentTheme.textForeground)
                                    .padding(.horizontal, 4)
                            }
                            
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
                            HStack(spacing: 8) {
                                Text("FOCUS MOMENTUM")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .tracking(1)
                                
                                Button(action: {
                                    selectedMetricInfo = MetricInfo(
                                        title: "Focus Momentum",
                                        description: "This compares your total focus hours from the last 7 days against the previous 7 days. It helps you visualize if you are building positive momentum or if you're hitting a slump and need to adjust your workload."
                                    )
                                    AnalyticsManager.shared.capture("analytics_info_clicked", properties: ["metric": "focus_momentum"])
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(goldColor.opacity(0.5))
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
                            HStack(spacing: 8) {
                                Spacer()
                                Text("TIME DISTRIBUTION")
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.6))
                                    .tracking(1)
                                
                                Button(action: {
                                    selectedMetricInfo = MetricInfo(
                                        title: "Time Distribution",
                                        description: "A categorical breakdown of how you spend your time. We group tasks by their assigned category and calculate the percentage of your total 'Haiku time' each category occupies. This helps identify if your actions align with your true priorities."
                                    )
                                    AnalyticsManager.shared.capture("analytics_info_clicked", properties: ["metric": "time_distribution"])
                                }) {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 10))
                                        .foregroundStyle(goldColor.opacity(0.5))
                                }
                                Spacer()
                            }
                            
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
            
            if let info = selectedMetricInfo {
                MetricInfoOverlay(info: info, isPresented: Binding(
                    get: { selectedMetricInfo != nil },
                    set: { if !$0 { selectedMetricInfo = nil } }
                ))
            }
        }
        .sheet(isPresented: $showingPaywall) {
            HaikuProView()
        }
    }
}

struct MetricInfoOverlay: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    let info: ProfileAnalyticsView.MetricInfo
    @Binding var isPresented: Bool
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }
            
            VStack(spacing: 20) {
                HStack {
                    Text(info.title.uppercased())
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.accent)
                        .tracking(2)
                    Spacer()
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            isPresented = false
                        }
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.3))
                    }
                }
                
                Text(info.description)
                    .font(.system(size: 14, design: .serif))
                    .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isPresented = false
                    }
                }) {
                    Text("Got it")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(currentTheme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(currentTheme.accent)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(currentTheme.bg)
                    .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
            )
            .padding(.horizontal, 40)
            .transition(.asymmetric(
                insertion: .scale(scale: 0.9).combined(with: .opacity),
                removal: .scale(scale: 0.9).combined(with: .opacity)
            ))
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isPresented)
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
