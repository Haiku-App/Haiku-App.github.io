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
    
    func scheduleSpamNotifications(tasksByDate: [Date: [ClockTask]], isEnabled: Bool) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        
        guard isEnabled else { return }
        
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
                    // Schedule spam: 10 notifications exactly 1 minute before
                    let notificationTime = startTime.addingTimeInterval(-60) // 1 minute before
                    
                    if notificationTime > now {
                        for i in 1...10 {
                            let content = UNMutableNotificationContent()
                            content.title = "ALARM: Task Starting!"
                            content.body = "Your task '\(task.title)' starts in 1 minute!"
                            content.sound = .default
                            
                            // Stagger by 1 second to ensure they trigger reliably
                            let specificTime = notificationTime.addingTimeInterval(TimeInterval(i))
                            let triggerDate = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .nanosecond], from: specificTime)
                            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
                            
                            let request = UNNotificationRequest(identifier: "\(task.id.uuidString)-spam-\(i)", content: content, trigger: trigger)
                            
                            center.add(request)
                        }
                    }
                }
            }
        }
    }
}
