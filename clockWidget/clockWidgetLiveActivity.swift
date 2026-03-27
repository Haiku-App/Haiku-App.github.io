//
//  clockWidgetLiveActivity.swift
//  clockWidget
//
//  Created by Reswin Kandathil on 3/17/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct clockWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HaikuLiveActivityAttributes.self) { context in
            HaikuLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(context.state.accentColor.color.opacity(0.18))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HaikuLiveActivityBadge(color: context.state.accentColor.color)
                }

                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.state.taskTitle)
                            .font(.system(size: 15, weight: .semibold, design: .serif))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text(context.attributes.sessionLabel.uppercased())
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.9)
                            .foregroundStyle(context.state.accentColor.color.opacity(0.9))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.leading, 4)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Starts")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(0.8)
                            .foregroundStyle(context.state.accentColor.color.opacity(0.9))

                        Text(context.state.startTimeText)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(context.state.reminderText.lowercased())
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(context.state.reminderText)
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            Image(systemName: "clock")
                                .foregroundStyle(context.state.accentColor.color)
                            Text("Scheduled for \(context.state.startTimeText)")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        
                        Text("A quiet heads-up so you can shift into the next block without checking the app.")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.82))
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(context.state.accentColor.color)

                    Text(compactTaskTitle(for: context.state.taskTitle))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text("\(context.state.minutesUntilStart)m")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(context.state.accentColor.color)
            } minimal: {
                ZStack {
                    Circle()
                        .fill(context.state.accentColor.color.opacity(0.18))
                    Text("\(context.state.minutesUntilStart)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(context.state.accentColor.color)
                }
            }
            .keylineTint(context.state.accentColor.color)
        }
    }
}

private struct HaikuLiveActivityLockScreenView: View {
    let context: ActivityViewContext<HaikuLiveActivityAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                HaikuLiveActivityBadge(color: context.state.accentColor.color)

                VStack(alignment: .leading, spacing: 8) {
                    Text(context.attributes.sessionLabel.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(context.state.accentColor.color)

                    Text(context.state.taskTitle)
                        .font(.system(size: 22, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(2)

                    Text(context.state.reminderText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.72))
                }

                Spacer(minLength: 12)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Starts \(context.state.startTimeText)")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(context.state.reminderText.lowercased())
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                }
            }
            
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(context.state.accentColor.color)
                Text(context.state.reminderText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}

private struct HaikuLiveActivityBadge: View {
    let color: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(color.opacity(0.18))
                .frame(width: 54, height: 54)

            VStack(spacing: 3) {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 18, weight: .bold))
                Text("NOW")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1)
            }
            .foregroundStyle(color)
        }
    }
}

private func compactTaskTitle(for title: String) -> String {
    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return "Now" }

    if let firstWord = trimmed.split(separator: " ").first, firstWord.count >= 3 {
        return String(firstWord.prefix(8))
    }

    return String(trimmed.prefix(8))
}

#Preview("Notification", as: .content, using: HaikuLiveActivityAttributes.preview) {
    clockWidgetLiveActivity()
} contentStates: {
    HaikuLiveActivityAttributes.ContentState.preview
}
