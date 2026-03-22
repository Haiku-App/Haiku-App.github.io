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
        
        if status == .authorized || status == .fullAccess {
            return manager.fetchEvents(for: Date(), theme: theme)
        } else {
            // If the main app hasn't gotten permission yet, return nothing.
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
