//
//  ClockTask.swift
//  clock
//
//  Defines the task/meeting model for the clock agenda.
//

import SwiftUI
import UIKit
import WidgetKit

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

    /// Normalize to 12h range in minutes [0, 720)
    var start12h: Double { Double(startMinutes % 720) }
    var end12h: Double { Double(endMinutes % 720) }
    
    enum CodingKeys: String, CodingKey {
        case id, title, startMinutes, endMinutes, color, isCompleted, url, externalEventId
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
        
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let cd = ColorData(r: Double(r), g: Double(g), b: Double(b), a: Double(a))
        try container.encode(cd, forKey: .color)
    }

    init(id: UUID = UUID(), title: String, startMinutes: Int, endMinutes: Int, color: Color, isCompleted: Bool = false, url: URL? = nil, externalEventId: String? = nil) {
        self.id = id
        self.title = title
        self.startMinutes = startMinutes
        self.endMinutes = endMinutes
        self.color = color
        self.isCompleted = isCompleted
        self.url = url
        self.externalEventId = externalEventId
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
    private let is24HourKey = "is24HourClockSetting"
    private let isProKey = "isProSetting"

    init() {
        self.userDefaults = UserDefaults(suiteName: "group.reswin.clock") ?? UserDefaults.standard
    }

    func save(isPro: Bool) {
        userDefaults.set(isPro, forKey: isProKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    func loadIsPro() -> Bool {
        return userDefaults.bool(forKey: isProKey)
    }

    func save(tasksByDate: [Date: [ClockTask]]) {        let groups = tasksByDate.map { TaskGroup(date: $0.key, tasks: $0.value) }
        if let data = try? JSONEncoder().encode(groups) {
            userDefaults.set(data, forKey: key)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }
    
    func load() -> [Date: [ClockTask]]? {
        guard let data = userDefaults.data(forKey: key),
              let groups = try? JSONDecoder().decode([TaskGroup].self, from: data) else {
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
