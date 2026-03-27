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
        case id, title, startMinutes, endMinutes, color, isCompleted, url, externalEventId, categoryId, categoryName
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
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let cd = ColorData(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        try container.encode(cd, forKey: .color)
    }

    init(id: UUID = UUID(), title: String, startMinutes: Int, endMinutes: Int, color: Color, isCompleted: Bool = false, url: URL? = nil, externalEventId: String? = nil, categoryId: UUID? = nil, categoryName: String? = nil) {
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
        
        if let cd = try? container.decode(ColorData.self, forKey: .color) {
            self.color = Color(red: cd.r, green: cd.g, blue: cd.b, opacity: cd.a)
        } else {
            self.color = Color.blue
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
        return userDefaults.bool(forKey: is24HourKey)
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
