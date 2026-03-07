//
//  ClockTask.swift
//  clock
//
//  Defines the task/meeting model for the clock agenda.
//

import SwiftUI

/// A simple model representing a task/meeting on a clock.
/// Times are in minutes from midnight (0...1440). For a 12-hour clock, values wrap every 720 minutes.
struct ClockTask: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var startMinutes: Int   // minutes from midnight
    var endMinutes: Int     // minutes from midnight
    var color: Color
    var isCompleted: Bool = false

    /// Normalize to 12h range in minutes [0, 720)
    var start12h: Double { Double(startMinutes % 720) }
    var end12h: Double { Double(endMinutes % 720) }
}
