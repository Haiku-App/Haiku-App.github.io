import Foundation
import EventKit
import SwiftUI
internal import Combine

class CalendarManager: ObservableObject {
    private lazy var eventStore: EKEventStore = {
        return EKEventStore()
    }()
    
    // Convert EKEvent to ClockTask
    private let themeColors: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 0.58), // Gold
        Color(red: 0.75, green: 0.55, blue: 0.45), // Muted Terracotta
        Color(red: 0.45, green: 0.50, blue: 0.35), // Olive
        Color(red: 0.80, green: 0.72, blue: 0.60), // Soft Sand
        Color(red: 0.35, green: 0.42, blue: 0.35)  // Pale Mint
    ]

    func requestAccess(completion: @escaping (Bool) -> Void) {
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            completion(true)
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

    func fetchEvents(for date: Date) -> [ClockTask] {
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
            let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
            
            let color = themeColors[index % themeColors.count]
            
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
                url: meetingUrl
            )
        }.sorted { $0.startMinutes < $1.startMinutes }
    }
}
