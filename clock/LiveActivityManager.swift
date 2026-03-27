import ActivityKit
import Foundation
import SwiftUI
import UIKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private let triggerMinutes: Set<Int> = [10, 5, 4, 3, 2, 1]
    private let reminderDisplayDurationNanoseconds: UInt64 = 4_000_000_000

    private struct Snapshot: Equatable {
        var attributes: HaikuLiveActivityAttributes
        var state: HaikuLiveActivityAttributes.ContentState
        var staleDate: Date
    }

    private struct ReminderKey: Hashable {
        var taskID: UUID
        var minutesUntilStart: Int
        var dayStart: Date
    }

    private var currentActivity: Activity<HaikuLiveActivityAttributes>?
    private var lastSnapshot: Snapshot?
    private var lastPresentedReminderKey: ReminderKey?
    private var dismissalTask: Task<Void, Never>?
    private let calendar = Calendar.current
    private let dayLabelFormatter: DateFormatter
    private let timeFormatter12Hour: DateFormatter
    private let timeFormatter24Hour: DateFormatter

    private init() {
        let dayFormatter = DateFormatter()
        dayFormatter.dateFormat = "EEE, MMM d"
        self.dayLabelFormatter = dayFormatter

        let twelveHour = DateFormatter()
        twelveHour.dateFormat = "h:mm a"
        self.timeFormatter12Hour = twelveHour

        let twentyFourHour = DateFormatter()
        twentyFourHour.dateFormat = "HH:mm"
        self.timeFormatter24Hour = twentyFourHour
    }

    func sync(tasks: [ClockTask], now: Date, is24HourClock: Bool) {
        let snapshot = snapshot(for: tasks, now: now, is24HourClock: is24HourClock)
        let hasExistingActivity = currentActivity != nil || !Activity<HaikuLiveActivityAttributes>.activities.isEmpty

        if let snapshot {
            let reminderKey = ReminderKey(
                taskID: snapshot.state.taskID,
                minutesUntilStart: snapshot.state.minutesUntilStart,
                dayStart: calendar.startOfDay(for: now)
            )

            if reminderKey == lastPresentedReminderKey {
                if snapshot == lastSnapshot || !hasExistingActivity {
                    return
                }
                lastSnapshot = snapshot
                return
            }

            lastPresentedReminderKey = reminderKey
            lastSnapshot = snapshot

            Task {
                await apply(snapshot)
            }
        } else {
            lastSnapshot = nil
            Task {
                await endCurrentActivity(dismissalPolicy: .immediate)
            }
        }
    }

    private func snapshot(for tasks: [ClockTask], now: Date, is24HourClock: Bool) -> Snapshot? {
        let sortedTasks = tasks
            .filter { !$0.isCompleted }
            .sorted { $0.startMinutes < $1.startMinutes }

        guard let upcomingTask = sortedTasks.first(where: {
            makeDate(minutesFromStartOfDay: $0.startMinutes, referenceDate: now) > now
        }) else {
            return nil
        }

        let startDate = makeDate(minutesFromStartOfDay: upcomingTask.startMinutes, referenceDate: now)
        let secondsUntilStart = startDate.timeIntervalSince(now)
        guard secondsUntilStart > 0 else {
            return nil
        }

        let minutesUntilStart = Int(ceil(secondsUntilStart / 60))
        guard triggerMinutes.contains(minutesUntilStart) else {
            return nil
        }

        let reminderText = minutesUntilStart == 1
            ? "Starts in 1 min"
            : "Starts in \(minutesUntilStart) min"

        let minuteBoundary = calendar.date(
            bySetting: .second,
            value: 0,
            of: calendar.date(byAdding: .minute, value: 1, to: now) ?? now
        ) ?? now.addingTimeInterval(60)

        let state = HaikuLiveActivityAttributes.ContentState(
            taskID: upcomingTask.id,
            taskTitle: upcomingTask.title,
            scheduledStartDate: startDate,
            minutesUntilStart: minutesUntilStart,
            reminderText: reminderText,
            startTimeText: format(minutesFromStartOfDay: upcomingTask.startMinutes, referenceDate: now, is24HourClock: is24HourClock),
            accentColor: .init(swiftUIColor: upcomingTask.color)
        )

        let attributes = HaikuLiveActivityAttributes(
            sessionLabel: "Up Next · \(dayLabelFormatter.string(from: now))"
        )

        return Snapshot(
            attributes: attributes,
            state: state,
            staleDate: minuteBoundary
        )
    }

    private func apply(_ snapshot: Snapshot) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endCurrentActivity(dismissalPolicy: .immediate)
            return
        }

        await resolveCurrentActivity()

        let content = ActivityContent(state: snapshot.state, staleDate: snapshot.staleDate)

        if let currentActivity {
            if currentActivity.attributes != snapshot.attributes {
                await currentActivity.end(nil, dismissalPolicy: .immediate)
                self.currentActivity = nil
                await requestActivity(snapshot, content: content)
            } else {
                await currentActivity.update(content)
            }
        } else {
            await requestActivity(snapshot, content: content)
        }

        scheduleDismissal()
    }

    private func requestActivity(
        _ snapshot: Snapshot,
        content: ActivityContent<HaikuLiveActivityAttributes.ContentState>
    ) async {
        do {
            currentActivity = try Activity.request(
                attributes: snapshot.attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("LiveActivity: Failed to request activity: \(error.localizedDescription)")
        }
    }

    private func resolveCurrentActivity() async {
        let existingActivities = Activity<HaikuLiveActivityAttributes>.activities
        currentActivity = existingActivities.first

        if existingActivities.count > 1 {
            for extraActivity in existingActivities.dropFirst() {
                await extraActivity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private func endCurrentActivity(dismissalPolicy: ActivityUIDismissalPolicy) async {
        dismissalTask?.cancel()
        dismissalTask = nil
        await resolveCurrentActivity()

        guard let currentActivity else {
            return
        }

        await currentActivity.end(nil, dismissalPolicy: dismissalPolicy)
        self.currentActivity = nil
    }

    private func makeDate(minutesFromStartOfDay: Int, referenceDate: Date) -> Date {
        let dayStart = calendar.startOfDay(for: referenceDate)
        return calendar.date(byAdding: .minute, value: minutesFromStartOfDay, to: dayStart) ?? referenceDate
    }

    private func format(
        minutesFromStartOfDay: Int,
        referenceDate: Date,
        is24HourClock: Bool
    ) -> String {
        let formatter = is24HourClock ? timeFormatter24Hour : timeFormatter12Hour
        return formatter.string(from: makeDate(minutesFromStartOfDay: minutesFromStartOfDay, referenceDate: referenceDate))
    }

    private func scheduleDismissal() {
        dismissalTask?.cancel()
        dismissalTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: reminderDisplayDurationNanoseconds)
            await self.endCurrentActivity(dismissalPolicy: .immediate)
        }
    }
}

private extension HaikuLiveActivityColor {
    init(swiftUIColor: Color) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        if UIColor(swiftUIColor).getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            self.init(
                red: Double(red),
                green: Double(green),
                blue: Double(blue),
                opacity: Double(alpha)
            )
        } else {
            self = .fallback
        }
    }
}
