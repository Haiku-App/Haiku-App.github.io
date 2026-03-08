import SwiftUI

struct ClockView: View {
    var now: Date
    @Binding var tasks: [ClockTask]

    // Palette matching the Haiku image
    private let clockFaceColor = Color(red: 0.18, green: 0.23, blue: 0.18)
    private let shadowLight = Color(red: 0.22, green: 0.28, blue: 0.22)
    private let shadowDark = Color(red: 0.12, green: 0.16, blue: 0.12)
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)
    private let taskTrackColor = Color(red: 0.15, green: 0.20, blue: 0.15)
    
    // For task creation coloring
    private let themeColors: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 0.58),
        Color(red: 0.75, green: 0.55, blue: 0.45),
        Color(red: 0.45, green: 0.50, blue: 0.35),
        Color(red: 0.80, green: 0.72, blue: 0.60),
        Color(red: 0.35, green: 0.42, blue: 0.35)
    ]
    
    @State private var activeDrag: DragInfo?
    @State private var pulseState: Bool = false

    struct DragInfo {
        var taskId: UUID
        var mode: Mode
        var initialMouseMinute: Double
        var initialStartMinutes: Int
        var initialEndMinutes: Int

        enum Mode {
            case move, resizeStart, resizeEnd, create
        }
    }

    // Helper to get current minutes from midnight
    private var currentMinute: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        return Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) + Double(comps.second ?? 0) / 60.0
    }
    
    private var activeTask: ClockTask? {
        // Return first task that is currently happening
        let min = Int(currentMinute)
        return tasks.first { !($0.isCompleted) && min >= $0.startMinutes && min < $0.endMinutes }
    }

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width/2, y: proxy.size.height/2)
            let radius = size / 2

            ZStack {
                // Interactive Background Layer
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if activeDrag == nil {
                                    handleDragStart(location: value.location, size: proxy.size)
                                }
                                handleDragChange(location: value.location, size: proxy.size)
                            }
                            .onEnded { _ in
                                activeDrag = nil
                                tasks.sort { $0.startMinutes < $1.startMinutes }
                            }
                    )
                
                // Task Tracks (Concentric AM/PM Rings)
                let ringWidth: CGFloat = 12
                let pmRingRadius = radius - (ringWidth/2)
                let amRingRadius = pmRingRadius - ringWidth - 4
                
                // Neumorphic Base
                let faceRadius = amRingRadius - (ringWidth/2) - 4
                
                Circle()
                    .fill(clockFaceColor)
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .shadow(color: shadowDark, radius: 10, x: 8, y: 8)
                    .shadow(color: shadowLight, radius: 10, x: -8, y: -8)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .allowsHitTesting(false)
                
                // Empty AM Track (Inner)
                Circle()
                    .stroke(taskTrackColor.opacity(0.7), lineWidth: ringWidth)
                    .frame(width: amRingRadius * 2, height: amRingRadius * 2)
                    .allowsHitTesting(false)
                
                // Empty PM Track (Outer)
                Circle()
                    .stroke(taskTrackColor, lineWidth: ringWidth)
                    .frame(width: pmRingRadius * 2, height: pmRingRadius * 2)
                    .allowsHitTesting(false)

                // Track Indicators
                Text("AM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(goldColor.opacity(0.3))
                    .position(x: center.x, y: center.y - amRingRadius)
                    .allowsHitTesting(false)
                Text("PM")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(goldColor.opacity(0.3))
                    .position(x: center.x, y: center.y - pmRingRadius)
                    .allowsHitTesting(false)
                
                // Scheduled Tasks
                ForEach(tasks) { task in
                    let isDragging = activeDrag?.taskId == task.id
                    let isActive = activeTask?.id == task.id && !isDragging
                    let isPast = task.endMinutes <= Int(currentMinute) && !isDragging
                    
                    let opacity = task.isCompleted ? 0.2 : (isPast ? 0.3 : 1.0)
                    let glowRadius: CGFloat = (isActive && pulseState) ? 8 : (isDragging ? 4 : 0)
                    let glowColor = task.color.opacity((isActive && pulseState) ? 0.6 : (isDragging ? 0.8 : 0))

                    ForEach(Array(getFragments(for: task).enumerated()), id: \.offset) { index, frag in
                        let r = frag.isAM ? amRingRadius : pmRingRadius
                        TaskArc(startMinutes: frag.startMinutes, endMinutes: frag.endMinutes)
                            .stroke(frag.task.color.opacity(opacity), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                            .frame(width: r * 2, height: r * 2)
                            .shadow(color: glowColor, radius: glowRadius)
                            .allowsHitTesting(false)
                            .animation(.none, value: activeDrag?.taskId) // Disable animation on drag state change
                            .animation(isDragging ? .none : .easeInOut(duration: 1.0), value: pulseState)
                    }
                }

                // Clock Dots and Numbers
                ForEach(0..<12, id: \.self) { i in
                    let angle = Angle.degrees(Double(i) * 30 - 90)
                    let dotDistance = faceRadius - 20
                    
                    let x = cos(CGFloat(angle.radians)) * dotDistance
                    let y = sin(CGFloat(angle.radians)) * dotDistance
                    
                    if i % 3 == 0 { // 12, 3, 6, 9
                        let hourNumber = i == 0 ? 12 : i
                        Text("\(hourNumber)")
                            .font(.system(size: 14, weight: .light, design: .serif))
                            .foregroundStyle(goldColor)
                            .position(x: center.x + x, y: center.y + y)
                    } else {
                        Circle()
                            .fill(goldColor.opacity(0.6))
                            .frame(width: 3, height: 3)
                            .position(x: center.x + x, y: center.y + y)
                    }
                }
                .allowsHitTesting(false)

                // Central Status Text
                if let active = activeTask {
                    let minsRemaining = active.endMinutes - Int(currentMinute)
                    Text("\(minsRemaining) min left")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(active.color)
                        .position(x: center.x, y: center.y + faceRadius - 40)
                        .allowsHitTesting(false)
                } else {
                    Text(formatTime(now))
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(.white.opacity(0.5))
                        .position(x: center.x, y: center.y + faceRadius - 40)
                        .allowsHitTesting(false)
                }

                // Hands
                let hourHandLength = faceRadius * 0.45
                let minuteHandLength = faceRadius * 0.75
                let secondHandLength = faceRadius * 0.85

                TimeHand(now: now)
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: hourHandLength * 2, height: hourHandLength * 2)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 2)
                    .allowsHitTesting(false)

                MinuteHand(now: now)
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: minuteHandLength * 2, height: minuteHandLength * 2)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 2)
                    .allowsHitTesting(false)

                SecondHand(now: now)
                    .stroke(Color(red: 0.85, green: 0.35, blue: 0.25), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .frame(width: secondHandLength * 2, height: secondHandLength * 2)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 1, y: 1)
                    .allowsHitTesting(false)

                // Center dot
                Circle()
                    .fill(goldColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
                    .allowsHitTesting(false)
            }
            .position(center)
            .onAppear {
                withAnimation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                    pulseState = true
                }
            }
        }
    }
    
    // MARK: - Drag Logic

    private func handleDragStart(location: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        let radius = size.width / 2
        
        let ringWidth: CGFloat = 12
        let pmRingRadius = radius - (ringWidth/2)
        let amRingRadius = pmRingRadius - ringWidth - 4
        
        let isAMClick = abs(dist - amRingRadius) < abs(dist - pmRingRadius)
        
        // Ensure user is tapping near one of the tracks
        if abs(dist - (isAMClick ? amRingRadius : pmRingRadius)) > 30 { return }
        
        let min12h = minute(from: location, in: size)
        let absoluteMinute = isAMClick ? min12h : min12h + 720
        
        // Find if we touched an existing task
        for task in tasks {
            if absoluteMinute >= Double(task.startMinutes) && absoluteMinute <= Double(task.endMinutes) {
                let distToStart = abs(absoluteMinute - Double(task.startMinutes))
                let distToEnd = abs(absoluteMinute - Double(task.endMinutes))
                
                var mode: DragInfo.Mode = .move
                if distToStart <= 15 { mode = .resizeStart }
                else if distToEnd <= 15 { mode = .resizeEnd }
                
                activeDrag = DragInfo(taskId: task.id, mode: mode, initialMouseMinute: min12h, initialStartMinutes: task.startMinutes, initialEndMinutes: task.endMinutes)
                return
            }
        }
    }

    private func handleDragChange(location: CGPoint, size: CGSize) {
        guard let drag = activeDrag, let index = tasks.firstIndex(where: { $0.id == drag.taskId }) else { return }
        
        let currentMin = minute(from: location, in: size)
        var totalDelta = currentMin - drag.initialMouseMinute
        
        // Handle wrap-around the 12-hour dial
        if totalDelta > 360 { totalDelta -= 720 }
        else if totalDelta < -360 { totalDelta += 720 }
        
        var task = tasks[index]
        let oldStart = task.startMinutes
        let oldEnd = task.endMinutes
        
        // Aim assist: snaps to nearest 30 mins if within 8 minutes
        func snap(_ val: Int) -> Int {
            let remainder = val % 30
            if remainder < 8 { return val - remainder }
            if remainder > 22 { return val + (30 - remainder) }
            return val
        }
        
        switch drag.mode {
        case .move:
            let rawStart = drag.initialStartMinutes + Int(totalDelta)
            let snappedStart = snap(rawStart)
            let duration = drag.initialEndMinutes - drag.initialStartMinutes
            
            task.startMinutes = snappedStart
            task.endMinutes = snappedStart + duration
            
            // Constrain to 24h
            if task.startMinutes < 0 {
                task.startMinutes = 0
                task.endMinutes = duration
            } else if task.endMinutes > 1440 {
                task.endMinutes = 1440
                task.startMinutes = 1440 - duration
            }

        case .resizeStart:
            let rawStart = drag.initialStartMinutes + Int(totalDelta)
            task.startMinutes = snap(rawStart)
            if task.startMinutes < 0 { task.startMinutes = 0 }
            if task.startMinutes > task.endMinutes - 5 { task.startMinutes = task.endMinutes - 5 }
        case .resizeEnd, .create:
            let rawEnd = drag.initialEndMinutes + Int(totalDelta)
            task.endMinutes = snap(rawEnd)
            if task.endMinutes > 1440 { task.endMinutes = 1440 }
            if task.endMinutes < task.startMinutes + 5 { task.endMinutes = task.startMinutes + 5 }
        }
        
        // Haptic feedback when snapping to a new 30 or 60 min boundary
        let startChangedToSnap = task.startMinutes != oldStart && task.startMinutes % 30 == 0
        let endChangedToSnap = task.endMinutes != oldEnd && task.endMinutes % 30 == 0
        
        if startChangedToSnap || endChangedToSnap {
            let isHour = (task.startMinutes % 60 == 0) || (task.endMinutes % 60 == 0)
            UIImpactFeedbackGenerator(style: isHour ? .medium : .soft).impactOccurred()
        }
        
        tasks[index] = task
    }

    private func minute(from location: CGPoint, in size: CGSize) -> Double {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi
        angle += 90 // Shift 0 to 12 o'clock
        if angle < 0 { angle += 360 }
        return (angle / 360) * 720
    }
    
    private func minDiff(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b)
        return min(d, 720 - d)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Shapes

struct TimeHand: Shape {
    var now: Date

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let totalMinutes12h = (hour.truncatingRemainder(dividingBy: 12)) * 60 + minute + second/60
        let angleDeg = totalMinutes12h * 0.5 - 90
        let angle = Angle.degrees(angleDeg)

        let end = CGPoint(
            x: center.x + cos(CGFloat(angle.radians)) * radius,
            y: center.y + sin(CGFloat(angle.radians)) * radius
        )
        
        p.move(to: center)
        p.addLine(to: end)
        return p
    }
}

struct MinuteHand: Shape {
    var now: Date

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let totalMinutes = minute + second/60
        let angleDeg = totalMinutes * 6 - 90
        let angle = Angle.degrees(angleDeg)

        let end = CGPoint(
            x: center.x + cos(CGFloat(angle.radians)) * radius,
            y: center.y + sin(CGFloat(angle.radians)) * radius
        )
        
        p.move(to: center)
        p.addLine(to: end)
        return p
    }
}

struct SecondHand: Shape {
    var now: Date

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.second, .nanosecond], from: now)
        let second = Double(comps.second ?? 0)
        let nano = Double(comps.nanosecond ?? 0)

        let totalSeconds = second + nano / 1_000_000_000
        let angleDeg = totalSeconds * 6 - 90
        let angle = Angle.degrees(angleDeg)

        let end = CGPoint(
            x: center.x + cos(CGFloat(angle.radians)) * radius,
            y: center.y + sin(CGFloat(angle.radians)) * radius
        )
        
        p.move(to: center)
        p.addLine(to: end)
        return p
    }
}

struct TaskArc: Shape {
    var startMinutes: Double
    var endMinutes: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        func angle(for minutes: Double) -> Angle {
            let deg = minutes * 0.5 - 90
            return .degrees(deg)
        }

        let start = angle(for: startMinutes)
        let end = angle(for: endMinutes)

        if endMinutes == startMinutes {
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .degrees(2), clockwise: false)
        } else if endMinutes > startMinutes {
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        } else {
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: .degrees(270), clockwise: false)
            p.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: end, clockwise: false)
        }

        return p
    }
}

struct TaskFragment: Identifiable {
    let id = UUID()
    let isAM: Bool
    let startMinutes: Double
    let endMinutes: Double
    let task: ClockTask
}

func getFragments(for task: ClockTask) -> [TaskFragment] {
    var frags = [TaskFragment]()
    let s = task.startMinutes
    let e = task.endMinutes
    
    if s < 720 {
        if e <= 720 {
            frags.append(TaskFragment(isAM: true, startMinutes: Double(s), endMinutes: Double(e), task: task))
        } else {
            frags.append(TaskFragment(isAM: true, startMinutes: Double(s), endMinutes: 720.0, task: task))
            frags.append(TaskFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(min(e, 1440)) - 720.0, task: task))
        }
    } else {
        frags.append(TaskFragment(isAM: false, startMinutes: Double(max(s, 720)) - 720.0, endMinutes: Double(min(e, 1440)) - 720.0, task: task))
    }
    return frags
}
