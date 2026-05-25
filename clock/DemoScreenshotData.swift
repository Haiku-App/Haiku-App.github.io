import Foundation
import SwiftUI

enum DemoScreenshotData {
    static let storageKey = "demoScreenshotDataEnabled"
    private static let workListId = uuid("00000000-0000-0000-0000-00000000BB01")
    private static let schoolListId = uuid("00000000-0000-0000-0000-00000000BB02")
    private static let personalListId = uuid("00000000-0000-0000-0000-00000000BB03")

    static func tasksByDate(relativeTo referenceDate: Date) -> [Date: [ClockTask]] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let routineId = uuid("00000000-0000-0000-0000-00000000AA00")

        var tasksByDate: [Date: [ClockTask]] = [:]

        for dayOffset in -7...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            tasksByDate[day] = demoTasks(for: dayOffset, on: day, routineId: routineId)
        }

        return tasksByDate
    }

    static func brainDumpLists() -> [BrainDumpList] {
        [
            brainDumpList("Work", id: workListId, offset: 0),
            brainDumpList("School", id: schoolListId, offset: 1),
            brainDumpList("Personal", id: personalListId, offset: 2)
        ]
    }

    static func brainDumpTasks(relativeTo referenceDate: Date) -> [BrainDumpTask] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: referenceDate)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today) ?? today

        return [
            brainDumpTask("Plan tomorrow's schedule", seed: 1),
            brainDumpTask("Reply to important messages", seed: 2),
            brainDumpTask("Review weekly goals", seed: 3, repeatFrequency: .weekly),
            brainDumpTask("Pick tomorrow's top 3", seed: 4, reminderDueDate: today),
            brainDumpTask("Prep meeting notes", seed: 5, listId: workListId),
            brainDumpTask("Send project update", seed: 6, listId: workListId),
            brainDumpTask("Review class notes", seed: 7, scheduledDate: today, listId: schoolListId),
            brainDumpTask("Submit assignment", seed: 8, listId: schoolListId),
            brainDumpTask("Buy groceries", seed: 9, listId: personalListId),
            brainDumpTask("Schedule appointment", seed: 10, reminderDueDate: today, listId: personalListId),
            brainDumpTask("Finished weekly reset", seed: 11, isCompleted: true, completedDate: yesterday),
            brainDumpTask("Organized desk", seed: 12, isCompleted: true, completedDate: twoDaysAgo, listId: workListId),
            brainDumpTask("Cleaned up inbox", seed: 13, isCompleted: true, completedDate: yesterday, listId: personalListId)
        ]
    }

    static func routineSessions(relativeTo referenceDate: Date) -> [RoutineSession] {
        [
            RoutineSession(
                id: uuid("00000000-0000-0000-0000-00000000CC01"),
                routineId: uuid("00000000-0000-0000-0000-00000000AA00"),
                name: "Morning Routine",
                items: [
                    sessionItem("Stretch", seed: 1, isCompleted: true),
                    sessionItem("Breakfast", seed: 2, isCompleted: true),
                    sessionItem("Review today's map", seed: 3),
                    sessionItem("Start first block", seed: 4)
                ],
                createdAt: referenceDate
            )
        ]
    }

    private static func demoTasks(
        for dayOffset: Int,
        on day: Date,
        routineId: UUID
    ) -> [ClockTask] {
        switch dayOffset {
        case -2:
            return [
                task("Project Planning", 9 * 60, 10 * 60 + 15, palette.terracotta, 1, "Work"),
                task("Study Session", 13 * 60, 14 * 60, palette.blue, 2, "School"),
                task("Workout", 18 * 60, 19 * 60, palette.sage, 3, "Health")
            ]
        case -1:
            return [
                task("Morning Routine", 7 * 60, 8 * 60 + 15, palette.sage, 4, "Routine"),
                task("Deep Work", 10 * 60, 11 * 60 + 30, palette.gold, 5, "Work"),
                task("Dinner Plans", 19 * 60, 20 * 60 + 30, palette.rose, 6, "Personal")
            ]
        case 0:
            return [
                routineStep("Stretch", 7 * 60, 7 * 60 + 20, routineId, day, 7, palette.sage),
                routineStep("Breakfast", 7 * 60 + 20, 7 * 60 + 50, routineId, day, 8, palette.sage),
                routineStep("Review plan", 7 * 60 + 50, 8 * 60 + 15, routineId, day, 9, palette.sage),
                task("Focus Block", 9 * 60 + 30, 11 * 60, palette.terracotta, 10, "Work"),
                task("Lunch Break", 12 * 60 + 15, 13 * 60, palette.rose, 11, "Personal"),
                task("Study Review", 14 * 60 + 30, 16 * 60, palette.blue, 12, "School"),
                task("Workout", 17 * 60 + 30, 18 * 60 + 30, palette.sage, 13, "Health"),
                task("Wind Down", 21 * 60, 21 * 60 + 45, palette.lavender, 14, "Personal")
            ]
        case 1:
            return [
                task("Morning Routine", 7 * 60, 8 * 60, palette.sage, 15, "Routine"),
                task("Team Call", 9 * 60, 9 * 60 + 45, palette.gold, 16, "Work"),
                task("Deep Work", 10 * 60, 12 * 60, palette.terracotta, 17, "Work"),
                task("Creative Block", 15 * 60, 16 * 60 + 15, palette.blue, 18, "Creative")
            ]
        case 2:
            return [
                task("Class", 8 * 60 + 30, 10 * 60, palette.blue, 19, "School"),
                task("Study Block", 11 * 60, 12 * 60 + 30, palette.lavender, 20, "School"),
                task("Team Sync", 14 * 60, 14 * 60 + 45, palette.gold, 21, "Work"),
                task("Dinner Prep", 18 * 60, 19 * 60, palette.rose, 22, "Personal")
            ]
        case 3:
            return [
                task("Quiet Planning", 8 * 60, 9 * 60, palette.sage, 23, "Personal"),
                task("Project Work", 10 * 60 + 30, 12 * 60, palette.terracotta, 24, "Work"),
                task("Walk", 16 * 60 + 30, 17 * 60, palette.blue, 25, "Health")
            ]
        case 4:
            return [
                task("Weekly Reset", 9 * 60, 10 * 60, palette.sage, 26, "Routine"),
                task("Coffee Catch-up", 11 * 60, 12 * 60, palette.rose, 27, "Personal"),
                task("Project Polish", 14 * 60, 16 * 60, palette.gold, 28, "Work")
            ]
        default:
            let baseSeed = 200 + ((dayOffset + 14) * 10)
            return [
                task("Morning Routine", 8 * 60, 9 * 60, palette.sage, baseSeed, "Routine"),
                task("Focus Block", 10 * 60, 11 * 60 + 30, palette.terracotta, baseSeed + 1, "Work")
            ]
        }
    }

    private static func task(
        _ title: String,
        _ start: Int,
        _ end: Int,
        _ color: Color,
        _ idSeed: Int,
        _ categoryName: String
    ) -> ClockTask {
        ClockTask(
            id: uuid("00000000-0000-0000-0000-\(String(format: "%012d", idSeed))"),
            title: title,
            startMinutes: start,
            endMinutes: end,
            color: color,
            categoryName: categoryName
        )
    }

    private static func brainDumpList(_ name: String, id: UUID, offset: TimeInterval) -> BrainDumpList {
        var list = BrainDumpList(name: name)
        list.id = id
        list.createdAt = Date(timeIntervalSince1970: offset)
        return list
    }

    private static func brainDumpTask(
        _ title: String,
        seed: Int,
        isCompleted: Bool = false,
        scheduledDate: Date? = nil,
        completedDate: Date? = nil,
        reminderDueDate: Date? = nil,
        repeatFrequency: RepeatFrequency = .never,
        listId: UUID? = nil
    ) -> BrainDumpTask {
        var task = BrainDumpTask(title: title)
        task.id = uuid("00000000-0000-0000-0000-\(String(format: "%012d", 7000 + seed))")
        task.isCompleted = isCompleted
        task.scheduledDate = scheduledDate
        task.completedDate = completedDate
        task.reminderDueDate = reminderDueDate
        task.repeatFrequency = repeatFrequency
        task.listId = listId
        return task
    }

    private static func sessionItem(_ title: String, seed: Int, isCompleted: Bool = false) -> SessionItem {
        var item = SessionItem(title: title)
        item.id = uuid("00000000-0000-0000-0000-\(String(format: "%012d", 8000 + seed))")
        item.isCompleted = isCompleted
        return item
    }

    private static func routineStep(
        _ title: String,
        _ start: Int,
        _ end: Int,
        _ routineId: UUID,
        _ anchorDate: Date,
        _ idSeed: Int,
        _ color: Color
    ) -> ClockTask {
        ClockTask(
            id: uuid("00000000-0000-0000-0000-\(String(format: "%012d", idSeed))"),
            title: title,
            startMinutes: start,
            endMinutes: end,
            color: color,
            categoryName: "Routine",
            routineSourceId: routineId,
            routineSourceStepId: uuid("00000000-0000-0000-0000-\(String(format: "%012d", idSeed + 1000))"),
            routineSourceName: "Morning Routine",
            routineAnchorDate: anchorDate
        )
    }

    private static let palette = (
        sage: Color(red: 0.55, green: 0.72, blue: 0.55),
        terracotta: Color(red: 0.78, green: 0.50, blue: 0.40),
        blue: Color(red: 0.40, green: 0.60, blue: 0.74),
        gold: Color(red: 0.76, green: 0.62, blue: 0.35),
        rose: Color(red: 0.78, green: 0.48, blue: 0.58),
        lavender: Color(red: 0.62, green: 0.55, blue: 0.78)
    )

    private static func uuid(_ value: String) -> UUID {
        UUID(uuidString: value) ?? UUID()
    }
}
