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
                let ringWidth: CGFloat = is24HourClock ? 24 : 18
                let pmRingRadius = radius - (ringWidth/2)
                let amRingRadius = pmRingRadius - ringWidth - 4
                
                // Neumorphic Base
                let faceRadius = is24HourClock ? (pmRingRadius - (ringWidth/2) - 4) : (amRingRadius - (ringWidth/2) - 4)
                
                Circle()
                    .fill(
                        RadialGradient(colors: [clockFaceColor.opacity(0.9), clockFaceColor], center: .center, startRadius: 0, endRadius: faceRadius)
                    )
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .shadow(color: shadowDark.opacity(0.4), radius: size * 0.03, x: size * 0.02, y: size * 0.02)
                    .shadow(color: shadowLight.opacity(0.3), radius: size * 0.03, x: -size * 0.02, y: -size * 0.02)
                    .overlay(
                        Circle().stroke(textForeground.opacity(0.1), lineWidth: 1)
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
                    
                    // Sun/Moon indicators
                    Group {
                        Image(systemName: "moon.fill")
                            .font(.system(size: size * 0.05))
                            .foregroundStyle(goldColor.opacity(0.8))
                            .position(x: center.x, y: center.y - faceRadius + (size * 0.20))
                        
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: size * 0.05))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .position(x: center.x, y: center.y + faceRadius - (size * 0.20))
                    }
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
                        VStack(spacing: 2) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: size * 0.025))
                            Text("AM")
                                .font(.system(size: size * 0.022, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(goldColor.opacity(0.4))
                        .position(x: center.x, y: center.y - amRingRadius)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: size * 0.025))
                            Text("PM")
                                .font(.system(size: size * 0.022, weight: .heavy, design: .monospaced))
                        }
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

                        ZStack {
                            // Depth shadow
                            TaskArc(startMinutes: frag.startMinutes, endMinutes: frag.endMinutes, is24HourClock: is24HourClock)
                                .trim(from: 0, to: animationProgress)
                                .stroke(Color.black.opacity(0.15 * opacity), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                                .offset(x: 0.5, y: 0.5)
                            
                            // Main Task Fill
                            TaskArc(startMinutes: frag.startMinutes, endMinutes: frag.endMinutes, is24HourClock: is24HourClock)
                                .trim(from: 0, to: animationProgress)
                                .stroke(task.color.opacity(opacity), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                            
                            // Highlight
                            TaskArc(startMinutes: frag.startMinutes, endMinutes: frag.endMinutes, is24HourClock: is24HourClock)
                                .trim(from: 0, to: animationProgress)
                                .stroke(
                                    LinearGradient(colors: [.white.opacity(0.2 * opacity), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                                )
                                .blendMode(.overlay)
                        }
                        .frame(width: r * 2, height: r * 2)
                    }
                }

                // Premium Ticks (Baton markers)
                let numTicks = is24HourClock ? 48 : 60
                ForEach(0..<numTicks, id: \.self) { i in
                    let isHour = is24HourClock ? (i % 4 == 0) : (i % 5 == 0)
                    let angleDeg = Double(i) * (360.0 / Double(numTicks)) - 90
                    let angle = Angle.degrees(angleDeg)
                    let tickStart = faceRadius - (isHour ? 12 : 8)
                    let tickEnd = faceRadius - 4
                    
                    Path { path in
                        let startX = center.x + cos(CGFloat(angle.radians)) * tickStart
                        let startY = center.y + sin(CGFloat(angle.radians)) * tickStart
                        let endX = center.x + cos(CGFloat(angle.radians)) * tickEnd
                        let endY = center.y + sin(CGFloat(angle.radians)) * tickEnd
                        path.move(to: CGPoint(x: startX, y: startY))
                        path.addLine(to: CGPoint(x: endX, y: endY))
                    }
                    .stroke(goldColor.opacity(isHour ? 0.6 : 0.2), lineWidth: isHour ? 1.5 : 0.5)
                }

                // Clock Numbers
                if showText {
                    if is24HourClock {
                        ForEach(0..<12, id: \.self) { i in
                            let hour = i * 2
                            let angle = Angle.degrees(Double(hour) * 15 - 90)
                            let dist = faceRadius - (size * 0.10)
                            let x = cos(CGFloat(angle.radians)) * dist
                            let y = sin(CGFloat(angle.radians)) * dist
                            
                            let label: String = {
                                if hour == 0 || hour == 24 { return "12AM" }
                                if hour == 6 { return "6AM" }
                                if hour == 12 { return "12PM" }
                                if hour == 18 { return "6PM" }
                                return "\(hour % 12 == 0 ? 12 : hour % 12)"
                            }()
                            
                            let isMain = hour % 6 == 0
                            
                            Text(label)
                                .font(.system(size: isMain ? size * 0.04 : size * 0.045, weight: isMain ? .bold : .medium, design: .serif))
                                .foregroundStyle(isMain ? goldColor : goldColor.opacity(0.4))
                                .position(x: center.x + x, y: center.y + y)
                        }
                    } else {
                        ForEach([12, 3, 6, 9], id: \.self) { hour in
                            let angle = Angle.degrees(Double(hour) * 30 - 90)
                            let dist = faceRadius - (size * 0.1)
                            let x = cos(CGFloat(angle.radians)) * dist
                            let y = sin(CGFloat(angle.radians)) * dist
                            
                            Text("\(hour)")
                                .font(.system(size: size * 0.05, weight: .medium, design: .serif))
                                .foregroundStyle(goldColor.opacity(0.9))
                                .position(x: center.x + x, y: center.y + y)
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
                        .position(x: center.x, y: center.y + faceRadius - (size * 0.18))
                    } else {
                        Text(formatTime(now).uppercased())
                            .font(.system(size: size * 0.03, weight: .bold, design: .monospaced))
                            .tracking(1)
                            .foregroundStyle(textForeground.opacity(0.4))
                            .position(x: center.x, y: center.y + faceRadius - (size * 0.18))
                    }
                }

                // Hands
                if showHands {
                    let hourHandLength = faceRadius * 0.5
                    let minuteHandLength = faceRadius * 0.8

                    // Hour Hand
                    TaperedHand(now: now, is24HourClock: is24HourClock, length: hourHandLength, width: 6)
                        .fill(goldColor)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)

                    // Minute Hand
                    TaperedHand(now: now, is24HourClock: false, length: minuteHandLength, width: 4, isMinute: true)
                        .fill(goldColor)
                        .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 4)

                    // Center dot
                    Circle()
                        .fill(goldColor)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
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
