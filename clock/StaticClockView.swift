import SwiftUI

struct StaticClockView: View {
    var now: Date
    var tasks: [ClockTask]
    var is24HourClock: Bool = false
    var theme: AppTheme = .sage
    var showHands: Bool = true
    var showText: Bool = true
    var showCenterText: Bool = true
    var animationProgress: Double = 1.0

    // Themed Palette
    private var clockFaceColor: Color { theme.bg }
    private var shadowLight: Color { theme.shadowLight }
    private var shadowDark: Color { theme.shadowDark }
    private var goldColor: Color { theme.accent }
    private var textForeground: Color { theme.textForeground }
    private var taskTrackColor: Color { theme.taskTrack }
    
    // Helper to get current minutes from midnight
    private var currentMinute: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let totalMins = Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) + Double(comps.second ?? 0) / 60.0
        return totalMins * animationProgress
    }
    
    private var activeTask: ClockTask? {
        let min = Int(currentMinute)
        return tasks.first { !($0.isCompleted) && min >= $0.startMinutes && min < $0.endMinutes }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width/2, y: proxy.size.height/2)
            let radius = size / 2

            ZStack {
                // Task Tracks (Concentric AM/PM Rings)
                let ringWidth: CGFloat = is24HourClock ? (size * 0.075) : (size * 0.056)
                let pmRingRadius = radius - (ringWidth/2)
                let amRingRadius = pmRingRadius - ringWidth - 4
                
                // Neumorphic Base
                let faceRadius = is24HourClock ? (pmRingRadius - (ringWidth/2) - 4) : (amRingRadius - (ringWidth/2) - 4)
                
                Circle()
                    .fill(clockFaceColor)
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .shadow(color: shadowDark, radius: size * 0.03, x: size * 0.025, y: size * 0.025)
                    .shadow(color: shadowLight, radius: size * 0.03, x: -size * 0.025, y: -size * 0.025)
                    .overlay(
                        Circle().stroke(textForeground.opacity(0.05), lineWidth: 1)
                    )
                
                if is24HourClock {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [shadowDark.opacity(0.7), shadowLight.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: ringWidth
                        )
                        .frame(width: pmRingRadius * 2, height: pmRingRadius * 2)
                } else {
                    Group {
                        // AM Track
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [shadowDark.opacity(0.7), shadowLight.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: ringWidth
                            )
                            .frame(width: amRingRadius * 2, height: amRingRadius * 2)
                        
                        // PM Track
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [shadowDark.opacity(0.7), shadowLight.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: ringWidth
                            )
                            .frame(width: pmRingRadius * 2, height: pmRingRadius * 2)
                    }

                    // AM/PM Labels
                    Group {
                        Text("AM")
                            .font(.system(size: size * 0.025, weight: .heavy, design: .monospaced))
                            .foregroundStyle(goldColor.opacity(0.4))
                            .position(x: center.x, y: center.y - amRingRadius)
                        
                        Text("PM")
                            .font(.system(size: size * 0.025, weight: .heavy, design: .monospaced))
                            .foregroundStyle(goldColor.opacity(0.4))
                            .position(x: center.x, y: center.y - pmRingRadius)
                    }
                }
                
                // Scheduled Tasks
                ForEach(tasks) { task in
                    let isPast = task.endMinutes <= Int(currentMinute)
                    let opacity: Double = task.isCompleted ? 0.2 : (isPast ? 0.3 : 1.0)

                    let frags = is24HourClock ? [TaskFragment(isAM: false, startMinutes: Double(task.startMinutes), endMinutes: Double(task.endMinutes), task: task)] : getFragments(for: task)
                    ForEach(Array(frags.enumerated()), id: \.offset) { index, frag in
                        let r = is24HourClock ? pmRingRadius : (frag.isAM ? amRingRadius : pmRingRadius)

                        TaskArc(startMinutes: frag.startMinutes, endMinutes: frag.endMinutes, is24HourClock: is24HourClock)
                            .trim(from: 0, to: animationProgress)
                            .stroke(task.color.opacity(opacity), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                            .frame(width: r * 2, height: r * 2)
                    }
                }

                // Clock Dots and Numbers
                if showText {
                    let numDots = is24HourClock ? 24 : 12
                    ForEach(0..<numDots, id: \.self) { i in
                        let angleDeg = is24HourClock ? (Double(i) * 15 - 90) : (Double(i) * 30 - 90)
                        let angle = Angle.degrees(angleDeg)
                        let dotDistance = faceRadius - (size * 0.06)
                        
                        let x = cos(CGFloat(angle.radians)) * dotDistance
                        let y = sin(CGFloat(angle.radians)) * dotDistance
                        
                        if is24HourClock {
                            if i % 6 == 0 {
                                let hourNumber = i == 0 ? 24 : i
                                Text("\(hourNumber)")
                                    .font(.system(size: size * 0.045, weight: .light, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .position(x: center.x + x, y: center.y + y)
                            } else if i % 2 == 0 {
                                Circle()
                                    .fill(goldColor.opacity(0.6))
                                    .frame(width: 2, height: 2)
                                    .position(x: center.x + x, y: center.y + y)
                            }
                        } else {
                            if i % 3 == 0 {
                                let hourNumber = i == 0 ? 12 : i
                                Text("\(hourNumber)")
                                    .font(.system(size: size * 0.045, weight: .light, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .position(x: center.x + x, y: center.y + y)
                            } else {
                                Circle()
                                    .fill(goldColor.opacity(0.6))
                                    .frame(width: 2, height: 2)
                                    .position(x: center.x + x, y: center.y + y)
                            }
                        }
                    }
                }

                // Central Status Text
                if showCenterText {
                    if let active = activeTask {
                        let minsRemaining = active.endMinutes - Int(currentMinute)
                        VStack(spacing: 2) {
                            Text("\(minsRemaining)m")
                                .font(.system(size: size * 0.04, weight: .bold))
                                .foregroundStyle(active.color)
                        }
                        .position(x: center.x, y: center.y + faceRadius - (size * 0.12))
                    } else {
                        Text(formatTime(now))
                            .font(.system(size: size * 0.04, weight: .light))
                            .foregroundStyle(textForeground.opacity(0.5))
                            .position(x: center.x, y: center.y + faceRadius - (size * 0.12))
                    }
                }

                // Hands
                if showHands {
                    let hourHandLength = faceRadius * 0.45
                    let minuteHandLength = faceRadius * 0.75

                    TimeHand(now: now, is24HourClock: is24HourClock)
                        .stroke(goldColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: hourHandLength * 2, height: hourHandLength * 2)

                    MinuteHand(now: now)
                        .stroke(goldColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .frame(width: minuteHandLength * 2, height: minuteHandLength * 2)

                    // Center dot
                    Circle()
                        .fill(goldColor)
                        .frame(width: 4, height: 4)
                }
            }
            .position(center)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = is24HourClock ? "HH:mm" : "h:mm a"
        return formatter.string(from: date)
    }
}
