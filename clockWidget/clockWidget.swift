import WidgetKit
import SwiftUI
import EventKit

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date())
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date())
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        var entries: [SimpleEntry] = []

        // To make it a real clock, we generate a timeline entry for every second
        // Note: iOS heavily batches widget updates. A standard widget won't update every second.
        // But since iOS 14, to make a live-updating clock face in a widget, we must rely on specific 
        // SwiftUI views (like Text(Date(), style: .timer)), OR for custom drawn hands, we provide an entry 
        // per minute, and iOS animates/interpolates it if possible. 
        // However, we will generate the next 60 minutes, updated every minute exactly on the minute mark.
        
        let currentDate = Date()
        let startOfNextMinute = Calendar.current.date(bySetting: .second, value: 0, of: Calendar.current.date(byAdding: .minute, value: 1, to: currentDate)!) ?? currentDate
        
        for minuteOffset in 0 ..< 60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: startOfNextMinute)!
            let entry = SimpleEntry(date: entryDate)
            entries.append(entry)
        }

        // Tell the system to ask for a new timeline when this one runs out (in an hour)
        let timeline = Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
}

private struct WidgetTaskContext {
    let tasks: [ClockTask]
    let currentTask: ClockTask?
    let nextTask: ClockTask?
    let nextTaskStartDate: Date?
    let is24HourClock: Bool
    let theme: AppTheme

    init(date: Date, tasks: [ClockTask], is24HourClock: Bool, theme: AppTheme) {
        self.tasks = tasks
        self.is24HourClock = is24HourClock
        self.theme = theme

        let calendar = Calendar.current
        let nowMinutes = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let sortedTasks = tasks.sorted { $0.startMinutes < $1.startMinutes }

        self.currentTask = sortedTasks.first {
            !$0.isCompleted && nowMinutes >= $0.startMinutes && nowMinutes < $0.normalizedEndMinutes
        }

        self.nextTask = sortedTasks.first {
            !$0.isCompleted && $0.startMinutes > nowMinutes
        }

        if let nextTask {
            let startOfDay = calendar.startOfDay(for: date)
            self.nextTaskStartDate = calendar.date(byAdding: .minute, value: nextTask.startMinutes, to: startOfDay)
        } else {
            self.nextTaskStartDate = nil
        }
    }

    var headlineTask: ClockTask? {
        currentTask ?? nextTask
    }

    var headlineLabel: String {
        if currentTask != nil {
            return "Now"
        } else if nextTask != nil {
            return "Next"
        } else {
            return "Open"
        }
    }

    var statusLine: String {
        if let currentTask {
            return "Until \(formattedTime(minutes: currentTask.endMinutes))"
        }

        if let nextTaskStartDate {
            let minutes = max(0, Int(nextTaskStartDate.timeIntervalSinceNow / 60))
            if minutes < 60 {
                return "Starts in \(minutes)m"
            }
            return formattedTime(minutes: nextTask?.startMinutes ?? 0)
        }

        return "Free canvas"
    }

    var inlineStatusLine: String {
        if currentTask != nil {
            return statusLine
        }

        if let nextTaskStartDate {
            let minutes = max(1, Int(ceil(nextTaskStartDate.timeIntervalSinceNow / 60)))
            if minutes <= 60 {
                return "\(minutes)m"
            }
        }

        return statusLine
    }

    var timeLine: String {
        guard let task = headlineTask else { return formattedCurrentTime }
        return "\(formattedTime(minutes: task.startMinutes)) - \(formattedTime(minutes: task.endMinutes))"
    }

    var compactTitle: String {
        guard let title = headlineTask?.title.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else {
            return "Haiku"
        }

        let words = title.split(separator: " ").prefix(2)
        let compact = words.joined(separator: " ")
        return compact.count > 18 ? String(compact.prefix(18)) : compact
    }

    var accentColor: Color {
        headlineTask?.color ?? theme.accent
    }

    var remainingFraction: Double {
        guard let nextTaskStartDate else { return 0.0 }
        let seconds = nextTaskStartDate.timeIntervalSinceNow
        let clamped = min(max(seconds, 0), 60 * 60)
        return 1.0 - (clamped / (60 * 60))
    }

    var circularProgress: Double {
        if currentTask != nil {
            return 0.85
        }

        return remainingFraction
    }

    private var formattedCurrentTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = is24HourClock ? "HH:mm" : "h:mm"
        return formatter.string(from: Date())
    }

    private func formattedTime(minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = is24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}

struct clockWidgetEntryView : View {
    @Environment(\.widgetFamily) var family
    var entry: Provider.Entry
    var showLegend: Bool = true // Added parameter to control legend
    
    var theme: AppTheme {
        return SharedTaskManager.shared.loadTheme()
    }

    var body: some View {
        let isPro = SharedTaskManager.shared.loadIsPro()
        
        if !isPro {
            VStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(theme.accent)
                Text("Haiku Pro")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundStyle(theme.textForeground)
                Text("Widget is a Pro feature")
                    .font(.system(size: 10))
                    .foregroundStyle(theme.textForeground.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding()
        } else {
            let tasks = fetchWidgetTasks()
            
            if family == .systemSmall {
                // Small square: just the clock
                StaticClockView(
                    now: entry.date,
                    tasks: tasks,
                    is24HourClock: fetchIs24HourClock(),
                    theme: theme,
                    showHands: true,
                    showText: true,
                    showCenterText: false
                )
                .padding(12)
            } else if !showLegend {
                // Big size but explicit 'no legend' -> just a big clock
                StaticClockView(
                    now: entry.date,
                    tasks: tasks,
                    is24HourClock: fetchIs24HourClock(),
                    theme: theme,
                    showHands: true,
                    showText: true,
                    showCenterText: false
                )
                .padding(16)
            } else {
                // Medium/Large with Legend
                GeometryReader { geo in
                    HStack(spacing: 20) {
                        // The clock on the left - takes up ~55% of the space
                        StaticClockView(
                            now: entry.date,
                            tasks: tasks,
                            is24HourClock: fetchIs24HourClock(),
                            theme: theme,
                            showHands: true,
                            showText: true,
                            showCenterText: false
                        )
                        .frame(width: geo.size.width * 0.55)
                        
                        // The legend on the right
                        if tasks.isEmpty {
                            VStack {
                                Image(systemName: "cup.and.saucer")
                                    .font(.system(size: 24))
                                    .foregroundStyle(theme.accent.opacity(0.5))
                                    .padding(.bottom, 4)
                                Text("No tasks")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundStyle(theme.textForeground.opacity(0.5))
                            }
                            .frame(width: geo.size.width * 0.45 - 20, alignment: .center)
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(tasks.prefix(6)) { task in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(task.color)
                                            .frame(width: 8, height: 8)
                                        
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                                .font(.system(size: 12, weight: .medium, design: .serif))
                                                .foregroundStyle(theme.textForeground)
                                                .lineLimit(1)
                                                .truncationMode(.tail)
                                            
                                            Text("\(formatTime(minutes: task.startMinutes)) - \(formatTime(minutes: task.endMinutes))")
                                                .font(.system(size: 10, weight: .regular))
                                                .foregroundStyle(theme.textForeground.opacity(0.6))
                                        }
                                    }
                                }
                                
                                if tasks.count > 6 {
                                    Text("+\(tasks.count - 6) more")
                                        .font(.system(size: 10, weight: .medium, design: .serif))
                                        .foregroundStyle(theme.accent)
                                        .padding(.top, 2)
                                }
                            }
                            .frame(width: geo.size.width * 0.45 - 20, alignment: .leading)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .padding(16)
            }
        }
    }

    private func formatTime(minutes: Int) -> String {
        let is24Hour = fetchIs24HourClock()
        let h = minutes / 60
        let m = minutes % 60
        
        let date = Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = is24Hour ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }

    private func fetchIs24HourClock() -> Bool {
        return SharedTaskManager.shared.loadIs24HourClock()
    }
    
    // Fetch today's tasks from the App Group, falling back to EventKit if not found
    private func fetchWidgetTasks() -> [ClockTask] {
        let today = Calendar.current.startOfDay(for: Date())
        if let savedTasks = SharedTaskManager.shared.load(), let todaysTasks = savedTasks[today] {
            return todaysTasks
        }
        
        let manager = CalendarManager()
        // Check if we actually have permission. In widgets, we can't prompt, we just have to check.
        let status = EKEventStore.authorizationStatus(for: .event)
        
        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = status == .fullAccess || status == .writeOnly
        } else {
            isAuthorized = status == .authorized
        }
        
        if isAuthorized {
            return manager.fetchEvents(for: Date(), theme: theme)
        } else {
            // If the main app hasn't gotten permission yet, return nothing.
            return []
        }
    }
}

struct lockscreenWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var theme: AppTheme {
        SharedTaskManager.shared.loadTheme()
    }

    private var context: WidgetTaskContext {
        WidgetTaskContext(
            date: entry.date,
            tasks: fetchWidgetTasks(),
            is24HourClock: fetchIs24HourClock(),
            theme: theme
        )
    }

    var body: some View {
        switch family {
        case .accessoryInline:
            inlineView
        case .accessoryCircular:
            circularView
        case .accessoryRectangular:
            rectangularView
        default:
            rectangularView
        }
    }

    private var inlineView: some View {
        HStack(spacing: 4) {
            Image(systemName: context.currentTask == nil ? "sparkles" : "leaf.fill")
                .widgetAccentable()
            Text(context.compactTitle)
            Text("• \(context.inlineStatusLine)")
                .foregroundStyle(.secondary)
        }
    }

    private var circularView: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.14), lineWidth: 6)

            Circle()
                .trim(from: 0, to: max(context.circularProgress, 0.12))
                .stroke(context.accentColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .widgetAccentable()

            VStack(spacing: 2) {
                Image(systemName: context.currentTask == nil ? "sparkles" : "leaf.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .widgetAccentable()
                Text(context.currentTask == nil ? "UP" : "NOW")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                Text(shortCircularText)
                    .font(.system(size: 11, weight: .semibold, design: .serif))
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            .padding(8)
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.10))
                    Text(context.headlineLabel.uppercased())
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(context.accentColor)
                        .widgetAccentable()
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.compactTitle)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .lineLimit(1)
                    Text(context.timeLine)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Text(context.statusLine)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.accentColor)
                    .widgetAccentable()
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                miniDial
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.statusLine)
                        .font(.system(size: 13, weight: .medium, design: .serif))
                        .lineLimit(1)
                    Text(context.currentTask == nil ? "A soft nudge before the day shifts." : "Living on the clock, not in a list.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var miniDial: some View {
        ZStack {
            Circle()
                .fill(Color.primary.opacity(0.07))

            Circle()
                .stroke(Color.primary.opacity(0.10), lineWidth: 1)

            Circle()
                .trim(from: 0, to: max(context.circularProgress, 0.12))
                .stroke(context.accentColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(4)

            VStack(spacing: 1) {
                Image(systemName: context.currentTask == nil ? "sparkles" : "leaf.fill")
                    .font(.system(size: 9, weight: .bold))
                    .widgetAccentable()
                Text(shortCircularText)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .lineLimit(1)
            }
        }
    }

    private var shortCircularText: String {
        let title = context.compactTitle
        if title.count <= 4 {
            return title
        }
        return String(title.prefix(4))
    }

    private func fetchIs24HourClock() -> Bool {
        SharedTaskManager.shared.loadIs24HourClock()
    }

    private func fetchWidgetTasks() -> [ClockTask] {
        let today = Calendar.current.startOfDay(for: Date())
        if let savedTasks = SharedTaskManager.shared.load(), let todaysTasks = savedTasks[today] {
            return todaysTasks
        }

        let manager = CalendarManager()
        let status = EKEventStore.authorizationStatus(for: .event)

        let isAuthorized: Bool
        if #available(iOS 17.0, *) {
            isAuthorized = status == .fullAccess || status == .writeOnly
        } else {
            isAuthorized = status == .authorized
        }

        if isAuthorized {
            return manager.fetchEvents(for: Date(), theme: theme)
        } else {
            return []
        }
    }
}

struct clockWidget: Widget {
    let kind: String = "clockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                clockWidgetEntryView(entry: entry, showLegend: true)
                    .containerBackground(for: .widget) {
                        SharedTaskManager.shared.loadTheme().bg
                    }
            } else {
                clockWidgetEntryView(entry: entry, showLegend: true)
                    .background(SharedTaskManager.shared.loadTheme().bg)
            }
        }
        .configurationDisplayName("Clock with Tasks")
        .description("Your beautifully minimal clock with your agenda.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct largeClockWidget: Widget {
    let kind: String = "largeClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                clockWidgetEntryView(entry: entry, showLegend: false)
                    .containerBackground(for: .widget) {
                        SharedTaskManager.shared.loadTheme().bg
                    }
            } else {
                clockWidgetEntryView(entry: entry, showLegend: false)
                    .background(SharedTaskManager.shared.loadTheme().bg)
            }
        }
        .configurationDisplayName("Large Aesthetic Clock")
        .description("A larger view of just the minimal clock face.")
        .supportedFamilies([.systemLarge])
    }
}

struct lockscreenClockWidget: Widget {
    let kind: String = "lockscreenClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                lockscreenWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                lockscreenWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("Haiku Lock Screen")
        .description("A calm lock screen glance for what matters next.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryRectangular])
    }
}
