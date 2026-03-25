import Foundation
import UserNotifications

class NotificationManager {
    static let shared = NotificationManager()
    
    func requestAuthorization() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }
    
    func scheduleEarlyNotifications(tasksByDate: [Date: [ClockTask]], offsets: [Int]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        guard !offsets.isEmpty else { return }
        
        let calendar = Calendar.current
        let now = Date()
        
        for (date, tasks) in tasksByDate {
            for task in tasks {
                if task.isCompleted { continue }
                
                // Calculate task start time
                var comps = calendar.dateComponents([.year, .month, .day], from: date)
                let m = task.startMinutes % (24 * 60)
                let h = task.startMinutes / 60
                comps.hour = h
                comps.minute = m
                
                guard let startTime = calendar.date(from: comps) else { continue }
                
                // Only schedule if the task is in the future
                if startTime > now {
                    for offset in offsets {
                        let notificationTime = startTime.addingTimeInterval(-TimeInterval(offset * 60))
                        
                        if notificationTime > now {
                            let content = UNMutableNotificationContent()
                            content.title = task.title
                            if offset == 0 {
                                content.body = "Starting now!"
                            } else {
                                content.body = "Starts in \(offset) minute\(offset == 1 ? "" : "s")"
                            }
                            content.sound = .default
                            
                            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: notificationTime)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                            
                            let request = UNNotificationRequest(identifier: "\(task.id.uuidString)-offset-\(offset)", content: content, trigger: trigger)
                            
                            center.add(request)
                        }
                    }
                }
            }
        }
    }
}
