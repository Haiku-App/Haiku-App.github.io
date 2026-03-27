import ActivityKit
import Foundation
import SwiftUI

struct HaikuLiveActivityColor: Codable, Hashable {
    var red: Double
    var green: Double
    var blue: Double
    var opacity: Double

    var color: Color {
        Color(red: red, green: green, blue: blue, opacity: opacity)
    }

    static let fallback = HaikuLiveActivityColor(
        red: 0.80,
        green: 0.69,
        blue: 0.47,
        opacity: 1.0
    )
}

struct HaikuLiveActivityAttributes: ActivityAttributes, Hashable {
    struct ContentState: Codable, Hashable {
        var taskID: UUID
        var taskTitle: String
        var scheduledStartDate: Date
        var minutesUntilStart: Int
        var reminderText: String
        var startTimeText: String
        var accentColor: HaikuLiveActivityColor
    }

    var sessionLabel: String
}

extension HaikuLiveActivityAttributes {
    static let preview = HaikuLiveActivityAttributes(sessionLabel: "Current Focus")
}

extension HaikuLiveActivityAttributes.ContentState {
    static let preview = HaikuLiveActivityAttributes.ContentState(
        taskID: UUID(),
        taskTitle: "Morning Yoga",
        scheduledStartDate: Date().addingTimeInterval(10 * 60),
        minutesUntilStart: 10,
        reminderText: "Starts in 10 min",
        startTimeText: "8:00 AM",
        accentColor: .fallback
    )
}
