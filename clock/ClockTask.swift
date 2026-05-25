//
//  ClockTask.swift
//  clock
//
//  Defines the task/meeting model for the clock agenda.
//

import SwiftUI
import UIKit
import WidgetKit
import Foundation

enum CalendarSyncProvider: String, CaseIterable, Identifiable, Codable {
    case none
    case apple
    case google

    static let storageKey = "activeCalendarSyncProvider"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "None"
        case .apple:
            return "Apple Calendar"
        case .google:
            return "Google Calendar"
        }
    }
}

enum RepeatFrequency: String, CaseIterable, Codable, Identifiable {
    case never = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }
}

/// A simple model representing a task/meeting on a clock.
/// Times are in minutes from midnight (0...1440). For a 12-hour clock, values wrap every 720 minutes.
struct ClockTask: Identifiable, Hashable, Codable {
    var id = UUID()
    var title: String
    var startMinutes: Int   // minutes from midnight
    var endMinutes: Int     // minutes from midnight
    var color: Color
    var isCompleted: Bool = false
    var url: URL? = nil
    var externalEventId: String? = nil
    var categoryId: UUID? = nil
    var categoryName: String? = nil
    var repeatFrequency: RepeatFrequency = .never
    var routineSourceId: UUID? = nil
    var routineSourceStepId: UUID? = nil
    var routineSourceName: String? = nil
    var routineAnchorDate: Date? = nil
    var isRoutineAutoScheduled: Bool = false

    /// Normalize to 12h range in minutes [0, 720)
    var start12h: Double { Double(startMinutes % 720) }
    var end12h: Double { Double(endMinutes % 720) }
    
    /// Clock math expects tasks that cross midnight to extend past 1440.
    var normalizedEndMinutes: Int {
        if endMinutes < startMinutes {
            return endMinutes + 1440
        }
        return endMinutes
    }
    
    var normalizedForClock: ClockTask {
        var copy = self
        copy.endMinutes = normalizedEndMinutes
        return copy
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, startMinutes, endMinutes, color, isCompleted, url, externalEventId, categoryId, categoryName, repeatFrequency, routineSourceId, routineSourceStepId, routineSourceName, routineAnchorDate, isRoutineAutoScheduled
    }

    struct ColorData: Codable {
        let r, g, b, a: Double
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(startMinutes, forKey: .startMinutes)
        try container.encode(endMinutes, forKey: .endMinutes)
        try container.encode(isCompleted, forKey: .isCompleted)
        try container.encodeIfPresent(url, forKey: .url)
        try container.encodeIfPresent(externalEventId, forKey: .externalEventId)
        try container.encodeIfPresent(categoryId, forKey: .categoryId)
        try container.encodeIfPresent(categoryName, forKey: .categoryName)
        try container.encode(repeatFrequency, forKey: .repeatFrequency)
        try container.encodeIfPresent(routineSourceId, forKey: .routineSourceId)
        try container.encodeIfPresent(routineSourceStepId, forKey: .routineSourceStepId)
        try container.encodeIfPresent(routineSourceName, forKey: .routineSourceName)
        try container.encodeIfPresent(routineAnchorDate, forKey: .routineAnchorDate)
        try container.encode(isRoutineAutoScheduled, forKey: .isRoutineAutoScheduled)
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let cd = ColorData(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        try container.encode(cd, forKey: .color)
    }

    init(id: UUID = UUID(), title: String, startMinutes: Int, endMinutes: Int, color: Color, isCompleted: Bool = false, url: URL? = nil, externalEventId: String? = nil, categoryId: UUID? = nil, categoryName: String? = nil, repeatFrequency: RepeatFrequency = .never, routineSourceId: UUID? = nil, routineSourceStepId: UUID? = nil, routineSourceName: String? = nil, routineAnchorDate: Date? = nil, isRoutineAutoScheduled: Bool = false) {
        self.id = id
        self.title = title
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.color = color
        self.isCompleted = isCompleted
        self.url = url
        self.externalEventId = externalEventId
        self.categoryId = categoryId
        self.categoryName = categoryName
        self.repeatFrequency = repeatFrequency
        self.routineSourceId = routineSourceId
        self.routineSourceStepId = routineSourceStepId
        self.routineSourceName = routineSourceName
        self.routineAnchorDate = routineAnchorDate
        self.isRoutineAutoScheduled = isRoutineAutoScheduled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.title = try container.decode(String.self, forKey: .title)
        self.startMinutes = try container.decode(Int.self, forKey: .startMinutes)
        self.endMinutes = try container.decode(Int.self, forKey: .endMinutes)
        self.isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        self.url = try container.decodeIfPresent(URL.self, forKey: .url)
        self.externalEventId = try container.decodeIfPresent(String.self, forKey: .externalEventId)
        self.categoryId = try container.decodeIfPresent(UUID.self, forKey: .categoryId)
        self.categoryName = try container.decodeIfPresent(String.self, forKey: .categoryName)
        self.repeatFrequency = try container.decodeIfPresent(RepeatFrequency.self, forKey: .repeatFrequency) ?? .never
        self.routineSourceId = try container.decodeIfPresent(UUID.self, forKey: .routineSourceId)
        self.routineSourceStepId = try container.decodeIfPresent(UUID.self, forKey: .routineSourceStepId)
        self.routineSourceName = try container.decodeIfPresent(String.self, forKey: .routineSourceName)
        self.routineAnchorDate = try container.decodeIfPresent(Date.self, forKey: .routineAnchorDate)
        self.isRoutineAutoScheduled = try container.decodeIfPresent(Bool.self, forKey: .isRoutineAutoScheduled) ?? false
        
        if let cd = try? container.decode(ColorData.self, forKey: .color) {
            self.color = Color(red: cd.r, green: cd.g, blue: cd.b, opacity: cd.a)
        } else {
            self.color = Color.blue
        }
    }
}

extension ClockTask {
    var calendarSyncProvider: CalendarSyncProvider {
        guard let externalEventId else { return .none }
        return externalEventId.hasPrefix("google_") ? .google : .apple
    }

    var isRoutineDisplayGroup: Bool {
        routineSourceId != nil && routineSourceStepId == nil
    }
}

private struct RoutineDisplayGroupKey: Hashable {
    let routineId: UUID
    let anchorDate: Date
}

extension Array where Element == ClockTask {
    func collapsedForRoutineDisplay() -> [ClockTask] {
        var groupedRoutineTasks: [RoutineDisplayGroupKey: [ClockTask]] = [:]
        var displayTasks: [ClockTask] = []

        for task in self {
            if let routineId = task.routineSourceId,
               let routineName = task.routineSourceName?.trimmingCharacters(in: .whitespacesAndNewlines),
               !routineName.isEmpty {
                let anchorDate = task.routineAnchorDate ?? Date.distantPast
                let key = RoutineDisplayGroupKey(routineId: routineId, anchorDate: anchorDate)
                groupedRoutineTasks[key, default: []].append(task)
            } else {
                displayTasks.append(task)
            }
        }

        for routineTasks in groupedRoutineTasks.values {
            guard let firstTask = routineTasks.sorted(by: { $0.startMinutes < $1.startMinutes }).first else { continue }
            let startMinutes = routineTasks.map(\.startMinutes).min() ?? firstTask.startMinutes
            let endMinutes = routineTasks.map(\.normalizedEndMinutes).max() ?? firstTask.normalizedEndMinutes

            var displayTask = firstTask
            displayTask.title = firstTask.routineSourceName ?? firstTask.title
            displayTask.startMinutes = startMinutes
            displayTask.endMinutes = endMinutes
            displayTask.externalEventId = nil
            displayTask.routineSourceStepId = nil
            displayTasks.append(displayTask)
        }

        return displayTasks.sorted {
            if $0.startMinutes != $1.startMinutes {
                return $0.startMinutes < $1.startMinutes
            }

            if $0.endMinutes != $1.endMinutes {
                return $0.endMinutes < $1.endMinutes
            }

            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }
}

struct TaskGroup: Codable {
    let date: Date
    let tasks: [ClockTask]
}

class SharedTaskManager {
    static let shared = SharedTaskManager()
    
    let userDefaults: UserDefaults
    private let key = "savedTasksByDate"
    private let tasksLastModifiedKey = "savedTasksByDateLastModified"
    private let is24HourKey = "is24HourClockSetting"
    private let isProKey = "isProSetting"
    private let hasUnlockedFreeProKey = "hasUnlockedFreeProSetting"
    private let taskDisplayStyleKey = ClockTaskDisplayStyle.sharedStorageKey

    init() {
        self.userDefaults = UserDefaults(suiteName: "group.reswink.haiku") ?? UserDefaults.standard
    }

    func save(isPro: Bool) {
        userDefaults.set(isPro, forKey: isProKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadIsPro() -> Bool {
        return userDefaults.bool(forKey: isProKey)
    }
    
    func saveHasUnlockedFreePro(_ value: Bool) {
        userDefaults.set(value, forKey: hasUnlockedFreeProKey)
    }
    
    func loadHasUnlockedFreePro() -> Bool {
        return userDefaults.bool(forKey: hasUnlockedFreeProKey)
    }

    @discardableResult
    func save(tasksByDate: [Date: [ClockTask]], modifiedAt: Date = Date()) -> Date {
        guard let data = encode(tasksByDate: tasksByDate) else {
            return modifiedAt
        }

        userDefaults.set(data, forKey: key)
        userDefaults.set(modifiedAt, forKey: tasksLastModifiedKey)
        WidgetCenter.shared.reloadAllTimelines()
        return modifiedAt
    }
    
    func load() -> [Date: [ClockTask]]? {
        guard let data = userDefaults.data(forKey: key),
              let dict = decodeTasks(from: data) else {
            return nil
        }
        return dict
    }

    func loadTasksLastModifiedAt() -> Date? {
        userDefaults.object(forKey: tasksLastModifiedKey) as? Date
    }

    func encode(tasksByDate: [Date: [ClockTask]]) -> Data? {
        Self.encodeTaskGroups(tasksByDate: tasksByDate)
    }

    func decodeTasks(from data: Data) -> [Date: [ClockTask]]? {
        Self.decodeTaskGroups(from: data)
    }

    nonisolated static func encodeTaskGroups(tasksByDate: [Date: [ClockTask]]) -> Data? {
        let groups = tasksByDate.map { TaskGroup(date: $0.key, tasks: $0.value) }
        return try? JSONEncoder().encode(groups)
    }

    nonisolated static func decodeTaskGroups(from data: Data) -> [Date: [ClockTask]]? {
        guard let groups = try? JSONDecoder().decode([TaskGroup].self, from: data) else {
            return nil
        }

        var dict: [Date: [ClockTask]] = [:]
        for group in groups {
            dict[group.date] = group.tasks
        }
        return dict
    }

    func save(is24HourClock: Bool) {
        userDefaults.set(is24HourClock, forKey: is24HourKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadIs24HourClock() -> Bool {
        if userDefaults.object(forKey: is24HourKey) == nil {
            return true
        }
        return userDefaults.bool(forKey: is24HourKey)
    }

    func save(taskDisplayStyle: ClockTaskDisplayStyle) {
        userDefaults.set(taskDisplayStyle.rawValue, forKey: taskDisplayStyleKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadTaskDisplayStyle() -> ClockTaskDisplayStyle {
        guard let rawValue = userDefaults.string(forKey: taskDisplayStyleKey),
              let style = ClockTaskDisplayStyle(rawValue: rawValue) else {
            return .rings
        }
        return style
    }

    func save(theme: AppTheme) {
        userDefaults.set(theme.rawValue, forKey: "appThemeSetting")
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadTheme() -> AppTheme {
        guard let rawValue = userDefaults.string(forKey: "appThemeSetting"),
              let theme = AppTheme(rawValue: rawValue) else {
            return .sage
        }
        return theme
    }
}
