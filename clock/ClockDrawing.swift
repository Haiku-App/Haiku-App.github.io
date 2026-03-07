import SwiftUI

struct ClockView: View {
    var now: Date
    @Binding var tasks: [ClockTask]

    // Palette matching the Haiku image
    private let clockFaceColor = Color(red: 0.18, green: 0.23, blue: 0.18) // matches background but with neumorphic effect
    private let shadowLight = Color(red: 0.22, green: 0.28, blue: 0.22) // lighter green for top-left shadow
    private let shadowDark = Color(red: 0.12, green: 0.16, blue: 0.12)  // darker green for bottom-right shadow
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)
    private let taskTrackColor = Color(red: 0.15, green: 0.20, blue: 0.15) // subtle track
    
    // For task creation coloring
    private let themeColors: [Color] = [
        Color(red: 0.85, green: 0.78, blue: 0.58),
        Color(red: 0.75, green: 0.55, blue: 0.45),
        Color(red: 0.45, green: 0.50, blue: 0.35),
        Color(red: 0.80, green: 0.72, blue: 0.60),
        Color(red: 0.35, green: 0.42, blue: 0.35)
    ]
    
    @State private var activeDrag: DragInfo?

    struct DragInfo {
        var taskId: UUID
        var mode: Mode
        var lastMouseMinute: Double

        enum Mode {
            case move, resizeStart, resizeEnd, create
        }
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
                
                // Task Track (outermost rim)
                let ringWidth: CGFloat = 16 // Slightly thicker for easier tapping
                let ringRadius = radius - (ringWidth/2)
                
                // Neumorphic Base (slightly indented from the task ring)
                let faceRadius = radius - ringWidth - 4
                
                // The clock base doesn't block touches because it is behind Color.clear
                Circle()
                    .fill(clockFaceColor)
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .shadow(color: shadowDark, radius: 10, x: 8, y: 8)
                    .shadow(color: shadowLight, radius: 10, x: -8, y: -8)
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                    .allowsHitTesting(false)
                
                // Empty Task Track
                Circle()
                    .stroke(taskTrackColor, lineWidth: ringWidth)
                    .frame(width: ringRadius * 2, height: ringRadius * 2)
                    .allowsHitTesting(false)
                
                // Scheduled Tasks
                ForEach(tasks) { task in
                    TaskArc(startMinutes: task.start12h, endMinutes: task.end12h)
                        .stroke(task.color.opacity(task.isCompleted ? 0.3 : 1.0), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .frame(width: ringRadius * 2, height: ringRadius * 2)
                        // Add glow if currently being dragged
                        .shadow(color: activeDrag?.taskId == task.id ? task.color.opacity(0.8) : .clear, radius: 4)
                        .allowsHitTesting(false)
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

                // Digital Time
                Text(formatTime(now))
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: center.x, y: center.y + faceRadius - 40)
                    .allowsHitTesting(false)

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
        }
    }
    
    // MARK: - Drag Logic

    private func handleDragStart(location: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        let radius = size.width / 2
        
        let ringWidth: CGFloat = 16
        let ringRadius = radius - (ringWidth/2)
        
        // Ensure user is tapping somewhere near the outer track
        if abs(dist - ringRadius) > 30 { return }
        
        let min = minute(from: location, in: size)
        
        // Find if we touched an existing task
        for task in tasks {
            let s = task.start12h
            let e = task.end12h
            
            let isInside: Bool
            if e > s {
                isInside = min >= s && min <= e
            } else {
                isInside = min >= s || min <= e // Handles 12 o'clock wraparound
            }
            
            if isInside {
                let distToStart = minDiff(min, s)
                let distToEnd = minDiff(min, e)
                
                var mode: DragInfo.Mode = .move
                if distToStart <= 15 {
                    mode = .resizeStart
                } else if distToEnd <= 15 {
                    mode = .resizeEnd
                }
                
                activeDrag = DragInfo(taskId: task.id, mode: mode, lastMouseMinute: min)
                return
            }
        }
        
        // Tapped empty space -> Do nothing, preventing new task creation via radial
    }

    private func handleDragChange(location: CGPoint, size: CGSize) {
        guard var drag = activeDrag, let index = tasks.firstIndex(where: { $0.id == drag.taskId }) else { return }
        
        let currentMin = minute(from: location, in: size)
        var delta = currentMin - drag.lastMouseMinute
        
        // Handle wrap-around the 12-hour dial
        if delta > 360 { delta -= 720 }
        else if delta < -360 { delta += 720 }
        
        if abs(delta) < 1 { return } // Prevent tiny jitters
        
        var task = tasks[index]
        
        switch drag.mode {
        case .move:
            task.startMinutes += Int(delta)
            task.endMinutes += Int(delta)
        case .resizeStart:
            task.startMinutes += Int(delta)
            // Prevent dragging start past end
            if task.startMinutes > task.endMinutes - 5 {
                task.startMinutes = task.endMinutes - 5
            }
        case .resizeEnd, .create:
            task.endMinutes += Int(delta)
            // Prevent dragging end before start
            if task.endMinutes < task.startMinutes + 5 {
                task.endMinutes = task.startMinutes + 5
            }
        }
        
        tasks[index] = task
        drag.lastMouseMinute = currentMin
        activeDrag = drag
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
