import WidgetKit
import SwiftUI
import EventKit
import AppIntents

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
        for secondOffset in 0 ... 3 {
            let entryDate = Calendar.current.date(byAdding: .second, value: secondOffset, to: currentDate) ?? currentDate
            entries.append(SimpleEntry(date: entryDate))
        }

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
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.dateFormat = "h:mm"
        return formatter.string(from: Date())
    }

    private func formattedTime(minutes: Int) -> String {
        let hour = minutes / 60
        let minute = minutes % 60
        let date = Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? Date()
        let formatter = DateFormatter()
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.dateFormat = "h:mm a"
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
                    let legendLimit = family == .systemMedium ? 4 : 5
                    let legendSpacing: CGFloat = family == .systemMedium ? 9 : 11
                    let clockWidthRatio = family == .systemMedium ? 0.5 : 0.55
                    let legendWidth = geo.size.width * (1 - clockWidthRatio) - 16
                    let contentAlignment: Alignment = family == .systemMedium ? .top : .center
                    let clockHeight = family == .systemMedium ? geo.size.height - 18 : geo.size.height
                    let effectiveLegendLimit = family == .systemMedium ? 3 : legendLimit

                    HStack(spacing: 16) {
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
                        .frame(width: geo.size.width * clockWidthRatio)
                        .frame(height: clockHeight, alignment: .top)
                        
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
                            .frame(width: legendWidth, alignment: .center)
                            .frame(maxHeight: .infinity, alignment: contentAlignment)
                        } else {
                            VStack(alignment: .leading, spacing: legendSpacing) {
                                ForEach(tasks.prefix(effectiveLegendLimit)) { task in
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
                                                .lineLimit(1)
                                        }
                                    }
                                }
                                
                                if tasks.count > effectiveLegendLimit {
                                    Text("+\(tasks.count - effectiveLegendLimit) more")
                                        .font(.system(size: 10, weight: .medium, design: .serif))
                                        .foregroundStyle(theme.accent)
                                        .padding(.top, 2)
                                }
                            }
                            .frame(width: legendWidth, alignment: .leading)
                            .frame(maxHeight: .infinity, alignment: contentAlignment)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: contentAlignment)
                }
                .padding(16)
            }
        }
    }

    private func formatTime(minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        
        let date = Calendar.current.date(from: DateComponents(hour: h, minute: m)) ?? Date()
        let formatter = DateFormatter()
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.dateFormat = "h:mm a"
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

private struct WidgetSupportDataLoader {
    func brainDumpTasks() -> [BrainDumpTask] {
        AppSupportPersistence.loadBrainDumpTasks()
    }

    func activeRoutineSessions() -> [RoutineSession] {
        AppSupportPersistence.loadActiveRoutineSessions().sorted { lhs, rhs in
            if lhs.progress != rhs.progress {
                return lhs.progress < rhs.progress
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

private struct WidgetLockedStateView: View {
    let theme: AppTheme
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "crown.fill")
                .font(.system(size: 22))
                .foregroundStyle(theme.accent)

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundStyle(theme.textForeground)

            Label(message, systemImage: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(theme.textForeground.opacity(0.68))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct WidgetEmptyStateView: View {
    let theme: AppTheme
    let title: String
    let message: String
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(theme.accent.opacity(0.82))

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .foregroundStyle(theme.textForeground)

            Text(message)
                .font(.system(size: 11, weight: .regular))
                .foregroundStyle(theme.textForeground.opacity(0.62))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct ToDoWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private let dataLoader = WidgetSupportDataLoader()

    private var theme: AppTheme {
        SharedTaskManager.shared.loadTheme()
    }

    private var remindersAccent: Color {
        theme.accent
    }

    private var remindersPrimaryText: Color {
        theme.textForeground
    }

    private var remindersSecondaryText: Color {
        theme.textForeground.opacity(0.58)
    }

    private var remindersSeparator: Color {
        theme.textForeground.opacity(0.12)
    }

    private var isPro: Bool {
        SharedTaskManager.shared.loadIsPro()
    }

    private var inboxTasks: [BrainDumpTask] {
        brainDumpInboxTasks(from: dataLoader.brainDumpTasks(), now: entry.date)
    }

    private var visibleInboxTasks: [BrainDumpTask] {
        inboxTasks.filter { task in
            guard task.isCompleted else { return true }
            guard let completedDate = task.completedDate else { return false }
            return entry.date.timeIntervalSince(completedDate) < 1.0
        }
    }

    private var remainingCount: Int {
        inboxTasks.filter { !$0.isCompleted }.count
    }

    var body: some View {
        Group {
            if !isPro {
                WidgetLockedStateView(
                    theme: theme,
                    title: "Haiku Pro",
                    message: "To-Do widgets are a Pro feature.",
                    icon: "checklist"
                )
            } else if visibleInboxTasks.isEmpty {
                WidgetEmptyStateView(
                    theme: theme,
                    title: "Inbox Clear",
                    message: "Nothing needs your attention right now.",
                    icon: "checkmark.circle"
                )
            } else {
                switch family {
                case .systemSmall:
                    remindersLayout(limit: 2, titleSize: 14, countSize: 26, rowSpacing: 10, rowFont: 13, iconSize: 24)
                        .padding(14)
                case .systemMedium:
                    remindersLayout(limit: 3, titleSize: 15, countSize: 28, rowSpacing: 12, rowFont: 14, iconSize: 25)
                        .padding(16)
                default:
                    remindersLayout(limit: 5, titleSize: 16, countSize: 32, rowSpacing: 13, rowFont: 15, iconSize: 26)
                        .padding(18)
                }
            }
        }
    }

    @ViewBuilder
    private func remindersLayout(
        limit: Int,
        titleSize: CGFloat,
        countSize: CGFloat,
        rowSpacing: CGFloat,
        rowFont: CGFloat,
        iconSize: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(remainingCount)")
                        .font(.system(size: countSize, weight: .bold, design: .rounded))
                        .foregroundStyle(remindersPrimaryText)

                    Text("Inbox")
                        .font(.system(size: titleSize, weight: .semibold))
                        .foregroundStyle(remindersAccent)
                }

                Spacer()

                Image(systemName: "list.bullet.circle.fill")
                    .font(.system(size: iconSize, weight: .regular))
                    .foregroundStyle(remindersAccent)
            }

            Divider()
                .overlay(remindersSeparator)
                .padding(.top, 8)
                .padding(.bottom, 10)

            VStack(alignment: .leading, spacing: rowSpacing) {
                ForEach(visibleInboxTasks.prefix(limit)) { task in
                    remindersRow(task, rowFont: rowFont)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func remindersRow(_ task: BrainDumpTask, rowFont: CGFloat) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Button(intent: ToggleBrainDumpTaskIntent(taskID: task.id.uuidString)) {
                remindersCheckGlyph(for: task)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .font(.system(size: rowFont, weight: .medium))
                .foregroundStyle(remindersPrimaryText)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func remindersCheckGlyph(for task: BrainDumpTask) -> some View {
        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 18, weight: .regular))
            .foregroundStyle(task.isCompleted ? remindersAccent : remindersSecondaryText.opacity(0.55))
            .frame(width: 22, height: 22)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: task.isCompleted)
    }
}

private struct RoutineWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private let dataLoader = WidgetSupportDataLoader()

    private var theme: AppTheme {
        SharedTaskManager.shared.loadTheme()
    }

    private var isPro: Bool {
        SharedTaskManager.shared.loadIsPro()
    }

    private var sessions: [RoutineSession] {
        dataLoader.activeRoutineSessions()
    }

    var body: some View {
        Group {
            if !isPro {
                WidgetLockedStateView(
                    theme: theme,
                    title: "Haiku Pro",
                    message: "Routine widgets are a Pro feature.",
                    icon: "arrow.clockwise"
                )
            } else if sessions.isEmpty {
                WidgetEmptyStateView(
                    theme: theme,
                    title: "No Active Routine",
                    message: "Start a routine in Haiku and it will appear here.",
                    icon: "figure.run"
                )
            } else {
                switch family {
                case .systemSmall:
                    smallView
                case .systemMedium:
                    mediumView
                default:
                    largeView
                }
            }
        }
    }

    private var smallView: some View {
        let session = sessions[0]

        return VStack(alignment: .leading, spacing: 10) {
            routineHeader(title: "ROUTINE", detail: progressLabel(for: session))

            Text(session.name)
                .font(.system(size: 15, weight: .bold, design: .serif))
                .foregroundStyle(theme.textForeground)
                .lineLimit(2)

            progressBar(for: session)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(session.items.prefix(2)) { item in
                    routineItemRow(item, in: session)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 14) {
            routineHeader(title: "ROUTINES", detail: "\(sessions.count) active")

            Text("Live checklists from To-Do.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textForeground.opacity(0.56))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(sessions.prefix(2)) { session in
                    routineSessionCard(session)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
    }

    private var largeView: some View {
        VStack(alignment: .leading, spacing: 14) {
            routineHeader(title: "ROUTINES", detail: "\(sessions.count) active")

            Text("The checklists you are moving through right now.")
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(theme.textForeground.opacity(0.56))

            VStack(alignment: .leading, spacing: 12) {
                ForEach(sessions.prefix(3)) { session in
                    routineSessionCard(session)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(20)
    }

    private func routineSessionCard(_ session: RoutineSession) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(session.name)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundStyle(theme.textForeground)
                    .lineLimit(1)

                Spacer()

                Text(progressLabel(for: session))
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(theme.textForeground.opacity(0.52))
            }

            progressBar(for: session)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(session.items.prefix(2)) { item in
                    routineItemRow(item, in: session)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.fieldBg.opacity(theme == .sakura ? 0.84 : 0.92))
        )
    }

    private func routineItemRow(_ item: SessionItem, in session: RoutineSession) -> some View {
        HStack(spacing: 8) {
            Button(intent: ToggleRoutineSessionItemIntent(
                sessionID: session.id.uuidString,
                itemID: item.id.uuidString
            )) {
                routineItemGlyph(item)
            }
            .buttonStyle(.plain)

            Text(item.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(item.isCompleted ? theme.textForeground.opacity(0.52) : theme.textForeground)
                .strikethrough(item.isCompleted, color: theme.textForeground.opacity(0.32))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
    }

    private func progressBar(for session: RoutineSession) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(theme.textForeground.opacity(0.12))

                Capsule()
                    .fill(theme.accent)
                    .frame(width: max(8, geometry.size.width * session.progress))
            }
        }
        .frame(height: 7)
    }

    private func completedCount(for session: RoutineSession) -> Int {
        session.items.filter(\.isCompleted).count
    }

    private func routineItemGlyph(_ item: SessionItem) -> some View {
        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(item.isCompleted ? theme.accent : theme.textForeground.opacity(0.32))
            .frame(width: 18, height: 18)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: item.isCompleted)
    }

    private func progressLabel(for session: RoutineSession) -> String {
        "\(completedCount(for: session))/\(session.items.count)"
    }

    private func routineHeader(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .serif))
                .foregroundStyle(theme.accent)
                .tracking(1.4)

            Spacer()

            Text(detail)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(theme.textForeground.opacity(0.58))
        }
    }
}

struct brainDumpWidget: Widget {
    let kind: String = "brainDumpWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                ToDoWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        SharedTaskManager.shared.loadTheme().bg
                    }
            } else {
                ToDoWidgetEntryView(entry: entry)
                    .background(SharedTaskManager.shared.loadTheme().bg)
            }
        }
        .configurationDisplayName("To-Do List")
        .description("See your Brain Dump tasks at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct routineChecklistWidget: Widget {
    let kind: String = "routineChecklistWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            if #available(iOS 17.0, *) {
                RoutineWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        SharedTaskManager.shared.loadTheme().bg
                    }
            } else {
                RoutineWidgetEntryView(entry: entry)
                    .background(SharedTaskManager.shared.loadTheme().bg)
            }
        }
        .configurationDisplayName("Routine Checklist")
        .description("Track the routines you have started from To-Do.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
