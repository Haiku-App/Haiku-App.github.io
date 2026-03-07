//
//  ClockDrawing.swift
//  clock
//
//  Shapes and views for rendering the clock face and overlays.
//

import SwiftUI

// MARK: - Clock View

struct ClockView: View {
    var tasks: [ClockTask]
    var now: Date

    // Geometry helpers
    private let ringInset: CGFloat = 16
    private let arcThickness: CGFloat = 10 // thin border ring for tasks

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width/2, y: proxy.size.height/2)
            let outerRadius = size/2 - 8 // slight padding from edges

            ZStack {
                // Background clock face
                Circle()
                    .fill(.ultraThinMaterial)
                Circle()
                    .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)

                // Hour ticks
                ForEach(0..<12) { hour in
                    TickMark()
                        .stroke(Color.secondary, lineWidth: hour % 3 == 0 ? 3 : 1)
                        .frame(width: outerRadius*2 - ringInset*2, height: outerRadius*2 - ringInset*2)
                        .rotationEffect(.degrees(Double(hour) * 30))
                        .opacity(0.7)
                }

                // Task arcs as thin border ring at the outer edge
                ForEach(tasks) { task in
                    TaskArc(startMinutes: task.start12h, endMinutes: task.end12h)
                        .stroke(task.color.opacity(0.95), style: StrokeStyle(lineWidth: arcThickness, lineCap: .round))
                        .frame(width: outerRadius*2, height: outerRadius*2)
                        .shadow(color: task.color.opacity(0.25), radius: 2, x: 0, y: 1)
                        .accessibilityLabel(task.title)
                }

                // Clock hands: hour and minute
                let minuteHandDiameter = outerRadius*2 - arcThickness*2 - ringInset - 10

                TimeHand(now: now)
                    .stroke(Color.primary, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: minuteHandDiameter * 0.5, height: minuteHandDiameter * 0.5)
                    .shadow(radius: 1)

                MinuteHand(now: now)
                    .stroke(Color.primary.opacity(0.9), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .frame(width: minuteHandDiameter, height: minuteHandDiameter)
                    .shadow(radius: 1)

                SecondHand(now: now)
                    .stroke(Color.red.opacity(0.9), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    .frame(width: minuteHandDiameter, height: minuteHandDiameter)
                    .shadow(radius: 0.5)

                // Center dot
                Circle()
                    .fill(Color.primary)
                    .frame(width: 6, height: 6)

                // Hour number labels (1–12)
                ClockLabels()
                    .foregroundStyle(.secondary)
            }
            .position(center)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Shapes

// Short radial tick from outer ring inward
struct TickMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let inset: CGFloat = 10
        let start = CGPoint(x: rect.midX, y: rect.minY)
        let end = CGPoint(x: rect.midX, y: rect.minY + inset)
        p.move(to: start)
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
            // 720 minutes in 360 degrees => 0.5 deg per minute
            let deg = minutes * 0.5 - 90 // -90 to put 0 at top
            return .degrees(deg)
        }

        let start = angle(for: startMinutes)
        let end = angle(for: endMinutes)

        // Handle wrap-around if end < start (e.g., 11:30 to 12:15 on 12h dial)
        if endMinutes == startMinutes {
            // Render a tiny arc for zero-length tasks
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: start + .degrees(2), clockwise: false)
        } else if endMinutes > startMinutes {
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        } else {
            // Split into two arcs: start->360 and 0->end
            p.addArc(center: center, radius: radius, startAngle: start, endAngle: .degrees(270), clockwise: false)
            p.addArc(center: center, radius: radius, startAngle: .degrees(-90), endAngle: end, clockwise: false)
        }

        return p
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
        let angleDeg = totalMinutes12h * 0.5 - 90 // 0.5 deg per minute, -90 to top
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
        let angleDeg = totalMinutes * 6 - 90 // 6 deg per minute, -90 to top
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

// Second hand on a 12-hour dial
struct SecondHand: Shape {
    var now: Date

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.second, .nanosecond], from: now)
        let second = Double(comps.second ?? 0)
        let nano = Double(comps.nanosecond ?? 0)

        // Smooth sweep with sub-second contribution
        let totalSeconds = second + nano / 1_000_000_000
        let angleDeg = totalSeconds * 6 - 90 // 6 deg per second, -90 to top
        let angle = Angle.degrees(angleDeg)

        // Start at exact center so the hand originates from the center dot
        let tip = CGPoint(
            x: center.x + cos(CGFloat(angle.radians)) * radius,
            y: center.y + sin(CGFloat(angle.radians)) * radius
        )

        p.move(to: center)
        p.addLine(to: tip)
        return p
    }
}

struct ClockLabels: View {
    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let radius = size / 2
            // Place labels slightly inside the tick marks
            let labelRadius = radius - 28

            ZStack {
                ForEach(1...12, id: \.self) { hour in
                    let angle = Angle.degrees(Double(hour) * 30 - 90)
                    let x = cos(CGFloat(angle.radians)) * labelRadius
                    let y = sin(CGFloat(angle.radians)) * labelRadius

                    Text("\(hour)")
                        .font(.caption)
                        .position(x: radius + x, y: radius + y)
                        .accessibilityLabel("\(hour)")
                }
            }
        }
    }
}
