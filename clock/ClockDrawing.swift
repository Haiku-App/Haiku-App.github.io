import SwiftUI

struct ClockView: View {
    var now: Date
    var tasks: [ClockTask]

    // Palette matching the Haiku image
    private let clockFaceColor = Color(red: 0.18, green: 0.23, blue: 0.18) // matches background but with neumorphic effect
    private let shadowLight = Color(red: 0.22, green: 0.28, blue: 0.22) // lighter green for top-left shadow
    private let shadowDark = Color(red: 0.12, green: 0.16, blue: 0.12)  // darker green for bottom-right shadow
    private let goldColor = Color(red: 0.85, green: 0.78, blue: 0.58)
    private let taskTrackColor = Color(red: 0.15, green: 0.20, blue: 0.15) // subtle track
    
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width/2, y: proxy.size.height/2)
            let radius = size / 2

            ZStack {
                // Task Track (outermost rim)
                let ringWidth: CGFloat = 8
                let ringRadius = radius - (ringWidth/2)
                
                // Neumorphic Base (slightly indented from the task ring)
                let faceRadius = radius - ringWidth - 4
                
                Circle()
                    .fill(clockFaceColor)
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .shadow(color: shadowDark, radius: 10, x: 8, y: 8)
                    .shadow(color: shadowLight, radius: 10, x: -8, y: -8)
                    // subtle inner stroke to enhance the pop
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
                
                // Empty Task Track
                Circle()
                    .stroke(taskTrackColor, lineWidth: ringWidth)
                    .frame(width: ringRadius * 2, height: ringRadius * 2)
                
                // Scheduled Tasks
                ForEach(tasks) { task in
                    TaskArc(startMinutes: task.start12h, endMinutes: task.end12h)
                        .stroke(task.color, style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                        .frame(width: ringRadius * 2, height: ringRadius * 2)
                }

                // Clock Dots
                ForEach(0..<12) { i in
                    let angle = Angle.degrees(Double(i) * 30 - 90)
                    let dotRadius: CGFloat = (i % 3 == 0) ? 2.5 : 1.5 // slightly larger at 12, 3, 6, 9
                    let dotDistance = faceRadius - 20
                    
                    let x = cos(CGFloat(angle.radians)) * dotDistance
                    let y = sin(CGFloat(angle.radians)) * dotDistance
                    
                    Circle()
                        .fill(goldColor)
                        .frame(width: dotRadius * 2, height: dotRadius * 2)
                        .position(x: center.x + x, y: center.y + y)
                }

                // Digital Time
                Text(formatTime(now))
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(.white.opacity(0.5))
                    .position(x: center.x, y: center.y + faceRadius - 40)

                // Hands
                let hourHandLength = faceRadius * 0.45
                let minuteHandLength = faceRadius * 0.75

                TimeHand(now: now)
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: hourHandLength * 2, height: hourHandLength * 2)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 2)

                MinuteHand(now: now)
                    .stroke(goldColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: minuteHandLength * 2, height: minuteHandLength * 2)
                    .shadow(color: .black.opacity(0.4), radius: 3, x: 1, y: 2)

                // Center dot
                Circle()
                    .fill(goldColor)
                    .frame(width: 6, height: 6)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)
            }
            .position(center)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// Current time hand on a 12-hour dial
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

        // Hour hand with minute/second contribution for smoothness
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

// Minute hand on a 12-hour dial
struct MinuteHand: Shape {
    var now: Date

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        // Minute hand with second contribution for smooth sweep
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

// Arc representing a task on a 12-hour dial. Start/end in minutes [0, 720).
struct TaskArc: Shape {
    var startMinutes: Double
    var endMinutes: Double

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        // Convert minutes to angles (0 at top, clockwise positive)
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
