import Foundation
import EventKit
import SwiftUI
internal import Combine

class CalendarManager: ObservableObject {
    @Published var eventsDidChange: Bool = false

    static func currentAuthorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .event)
    }

    static func hasCalendarAccess(status: EKAuthorizationStatus = CalendarManager.currentAuthorizationStatus()) -> Bool {
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status.rawValue == 3
        }
    }

    private lazy var eventStore: EKEventStore = {
        return EKEventStore()
    }()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged(_:)),
            name: .EKEventStoreChanged,
            object: nil
        )
    }

    @objc private func storeChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            self.eventsDidChange.toggle()
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            completion(true)
            return
        }
        
        let status = EKEventStore.authorizationStatus(for: .event)
        if status == .denied || status == .restricted {
            completion(false)
            return
        }
        
        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .event) { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    func fetchEvents(from startDate: Date, to endDate: Date, theme: AppTheme) -> [Date: [ClockTask]] {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return [:]
        }
        
        let cal = Calendar.current
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        var result: [Date: [ClockTask]] = [:]
        
        let nonAllDayEvents = events.filter { !$0.isAllDay }
        
        for (index, event) in nonAllDayEvents.enumerated() {
            let eventDate = cal.startOfDay(for: event.startDate)
            let sComps = cal.dateComponents([.hour, .minute], from: event.startDate)
            let eComps = cal.dateComponents([.hour, .minute], from: event.endDate)
            
            let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
            var eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
            
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: event.startDate), to: cal.startOfDay(for: event.endDate)).day ?? 0
            if days > 0 {
                eMin += days * 1440
            }
            
            if eMin <= sMin {
                eMin = sMin + 60
            }
            
            let color = aestheticColors[index % aestheticColors.count].color
            
            var meetingUrl: URL? = event.url
            if meetingUrl == nil, let notes = event.notes {
                let types: NSTextCheckingResult.CheckingType = .link
                do {
                    let detector = try NSDataDetector(types: types.rawValue)
                    let matches = detector.matches(in: notes, options: [], range: NSRange(location: 0, length: notes.utf16.count))
                    if let match = matches.first, let matchUrl = match.url {
                        meetingUrl = matchUrl
                    }
                } catch {}
            }
            
            let task = ClockTask(
                title: event.title ?? "Event",
                startMinutes: sMin,
                endMinutes: eMin,
                color: color,
                url: meetingUrl,
                externalEventId: event.calendarItemIdentifier
            )
            
            result[eventDate, default: []].append(task)
        }
        
        for date in result.keys {
            result[date]?.sort { $0.startMinutes < $1.startMinutes }
        }
        
        return result
    }

    func fetchEvents(for date: Date, theme: AppTheme) -> [ClockTask] {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return [] // Return dummy or empty data for preview
        }
        
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: date)
        
        guard let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: nil)
        let events = eventStore.events(matching: predicate)
        
        return events.filter { !$0.isAllDay }.enumerated().map { index, event in
            let sComps = cal.dateComponents([.hour, .minute], from: event.startDate)
            let eComps = cal.dateComponents([.hour, .minute], from: event.endDate)
            
            let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
            var eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
            
            let days = cal.dateComponents([.day], from: cal.startOfDay(for: event.startDate), to: cal.startOfDay(for: event.endDate)).day ?? 0
            if days > 0 {
                eMin += days * 1440
            }
            
            if eMin <= sMin {
                eMin = sMin + 60 // fallback fallback
            }
            
            let color = aestheticColors[index % aestheticColors.count].color
            
            // Try to extract a URL from the event's URL property or notes
            var meetingUrl: URL? = event.url
            if meetingUrl == nil, let notes = event.notes {
                let types: NSTextCheckingResult.CheckingType = .link
                do {
                    let detector = try NSDataDetector(types: types.rawValue)
                    let matches = detector.matches(in: notes, options: [], range: NSRange(location: 0, length: notes.utf16.count))
                    if let match = matches.first, let matchUrl = match.url {
                        meetingUrl = matchUrl
                    }
                } catch {}
            }
            
            return ClockTask(
                title: event.title ?? "Event",
                startMinutes: sMin,
                endMinutes: eMin,
                color: color,
                url: meetingUrl,
                externalEventId: event.calendarItemIdentifier
            )
        }.sorted { $0.startMinutes < $1.startMinutes }
    }

    func saveTask(_ task: ClockTask, date: Date) -> String? {
        let event = EKEvent(eventStore: eventStore)
        event.title = task.title
        
        var safeEndMinutes = task.endMinutes
        if safeEndMinutes <= task.startMinutes {
            safeEndMinutes += 1440
        }
        
        event.startDate = dateFromMinutes(task.startMinutes, on: date)
        event.endDate = dateFromMinutes(safeEndMinutes, on: date)
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.calendarItemIdentifier
        } catch {
            print("Error saving event to Calendar: \(error)")
            return nil
        }
    }

    func updateTask(_ task: ClockTask, date: Date) {
        guard let externalId = task.externalEventId,
              let event = event(matching: externalId) else { return }
        
        event.title = task.title
        
        var safeEndMinutes = task.endMinutes
        if safeEndMinutes <= task.startMinutes {
            safeEndMinutes += 1440
        }
        
        event.startDate = dateFromMinutes(task.startMinutes, on: date)
        event.endDate = dateFromMinutes(safeEndMinutes, on: date)
        
        do {
            try eventStore.save(event, span: .thisEvent)
        } catch {
            print("Error updating event in Calendar: \(error)")
        }
    }

    func deleteTask(externalId: String) {
        guard let event = event(matching: externalId) else { return }
        do {
            try eventStore.remove(event, span: .thisEvent)
        } catch {
            print("Error deleting event from Calendar: \(error)")
        }
    }

    private func event(matching identifier: String) -> EKEvent? {
        if let event = eventStore.calendarItem(withIdentifier: identifier) as? EKEvent {
            return event
        }

        return eventStore.event(withIdentifier: identifier)
    }

    private func dateFromMinutes(_ minutes: Int, on date: Date) -> Date {
        let cal = Calendar.current
        var comps = cal.dateComponents([.year, .month, .day], from: date)
        comps.hour = minutes / 60
        comps.minute = minutes % 60
        return cal.date(from: comps) ?? date
    }
}

class ReminderManager: ObservableObject {
    static let shared = ReminderManager()
    static let syncEnabledKey = "isAppleRemindersSyncEnabled"

    @Published var eventsDidChange: Bool = false

    static func currentAuthorizationStatus() -> EKAuthorizationStatus {
        EKEventStore.authorizationStatus(for: .reminder)
    }

    static func hasReminderAccess(status: EKAuthorizationStatus = ReminderManager.currentAuthorizationStatus()) -> Bool {
        if #available(iOS 17.0, *) {
            return status == .fullAccess
        } else {
            return status.rawValue == 3
        }
    }

    private lazy var eventStore: EKEventStore = {
        EKEventStore()
    }()

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged(_:)),
            name: .EKEventStoreChanged,
            object: nil
        )
    }

    @objc private func storeChanged(_ notification: Notification) {
        DispatchQueue.main.async {
            self.eventsDidChange.toggle()
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            completion(true)
            return
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        if status == .denied || status == .restricted {
            completion(false)
            return
        }

        if #available(iOS 17.0, *) {
            eventStore.requestFullAccessToReminders { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        } else {
            eventStore.requestAccess(to: .reminder) { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        }
    }

    func fetchTasks(completion: @escaping ([BrainDumpTask]) -> Void) {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            completion([])
            return
        }

        let calendars = eventStore.calendars(for: .reminder)
        let predicate = eventStore.predicateForReminders(in: calendars)

        eventStore.fetchReminders(matching: predicate) { reminders in
            let tasks = (reminders ?? []).map { reminder in
                BrainDumpTask(
                    title: reminder.title,
                    isCompleted: reminder.isCompleted,
                    completedDate: reminder.completionDate,
                    reminderDueDate: self.date(from: reminder.dueDateComponents),
                    externalReminderId: reminder.calendarItemIdentifier
                )
            }

            DispatchQueue.main.async {
                completion(tasks)
            }
        }
    }

    func saveTask(_ task: BrainDumpTask, completion: @escaping (String?, Date?) -> Void) {
        guard let calendar = defaultReminderCalendar() else {
            completion(nil, nil)
            return
        }

        let reminder = EKReminder(eventStore: eventStore)
        reminder.calendar = calendar
        apply(task, to: reminder)

        do {
            try eventStore.save(reminder, commit: true)
            completion(reminder.calendarItemIdentifier, date(from: reminder.dueDateComponents))
        } catch {
            print("Error saving reminder: \(error)")
            completion(nil, nil)
        }
    }

    func updateTask(_ task: BrainDumpTask) {
        guard let externalReminderId = task.externalReminderId,
              let reminder = reminder(matching: externalReminderId) else { return }

        apply(task, to: reminder)

        do {
            try eventStore.save(reminder, commit: true)
        } catch {
            print("Error updating reminder: \(error)")
        }
    }

    func deleteTask(externalId: String) {
        guard let reminder = reminder(matching: externalId) else { return }

        do {
            try eventStore.remove(reminder, commit: true)
        } catch {
            print("Error deleting reminder: \(error)")
        }
    }

    private func reminder(matching identifier: String) -> EKReminder? {
        eventStore.calendarItem(withIdentifier: identifier) as? EKReminder
    }

    private func defaultReminderCalendar() -> EKCalendar? {
        eventStore.defaultCalendarForNewReminders() ?? eventStore.calendars(for: .reminder).first
    }

    private func apply(_ task: BrainDumpTask, to reminder: EKReminder) {
        reminder.title = task.title
        reminder.isCompleted = task.isCompleted
        reminder.completionDate = task.isCompleted ? (task.completedDate ?? Date()) : nil
        reminder.dueDateComponents = dueDateComponents(from: task.reminderDueDate)
    }

    private func dueDateComponents(from date: Date?) -> DateComponents? {
        guard let date else { return nil }
        return Calendar.current.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute],
            from: date
        )
    }

    private func date(from components: DateComponents?) -> Date? {
        guard let components else { return nil }
        return components.calendar?.date(from: components) ?? Calendar.current.date(from: components)
    }
}
