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

    // Palette (matching the image)
    private let emptyTaskRingColor: Color = Color(red: 0.12, green: 0.16, blue: 0.24)
    private let middleRingColor: Color = Color(red: 0.18, green: 0.25, blue: 0.38)
    private let innerFaceColor: Color = Color(red: 0.08, green: 0.11, blue: 0.16)
    private let tickColorMinute: Color = Color(red: 0.45, green: 0.55, blue: 0.7).opacity(0.6)
    private let tickColorHour: Color = Color(red: 0.6, green: 0.7, blue: 0.85)
    private let numeralColor: Color = Color.white.opacity(0.9)
    private let handColor: Color = Color(red: 0.45, green: 0.68, blue: 0.93)
    
    // Geometry helpers
    private let taskRingWidth: CGFloat = 24
    private let middleRingWidth: CGFloat = 52

    var body: some View {
        GeometryReader { proxy in
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width/2, y: proxy.size.height/2)
            let radius = size / 2
            
            let middleRingOuterRadius = radius - taskRingWidth
            let innerCircleRadius = middleRingOuterRadius - middleRingWidth

            ZStack {
                // Middle ring (base for numbers and ticks)
                Circle()
                    .fill(middleRingColor)
                    .frame(width: middleRingOuterRadius * 2, height: middleRingOuterRadius * 2)

                // Inner circle (dark center)
                Circle()
                    .fill(innerFaceColor)
                    .frame(width: innerCircleRadius * 2, height: innerCircleRadius * 2)

                // Task arcs (3rd outer circle)
                let taskRingCenterRadius = radius - taskRingWidth / 2
                
                // Empty background track for tasks
                Circle()
                    .stroke(emptyTaskRingColor, lineWidth: taskRingWidth)
                    .frame(width: taskRingCenterRadius * 2, height: taskRingCenterRadius * 2)

                ForEach(tasks) { task in
                    TaskArc(startMinutes: task.start12h, endMinutes: task.end12h)
                        .stroke(task.color, style: StrokeStyle(lineWidth: taskRingWidth, lineCap: .butt))
                        .frame(width: taskRingCenterRadius * 2, height: taskRingCenterRadius * 2)
                }

                // Minute and hour tick marks around the outer edge of the middle ring
                GeometryReader { tickProxy in
                    let tickCenter = CGPoint(x: tickProxy.size.width/2, y: tickProxy.size.height/2)

                    ZStack {
                        ForEach(0..<60, id: \.self) { i in
                            let isHour = i % 5 == 0
                            let length: CGFloat = isHour ? 8 : 4
                            let lineWidth: CGFloat = isHour ? 2 : 1
                            let angle = Angle.degrees(Double(i) * 6 - 90)

                            let outerR = middleRingOuterRadius
                            let innerR = outerR - length

                            let startX = cos(CGFloat(angle.radians)) * outerR
                            let startY = sin(CGFloat(angle.radians)) * outerR
                            let endX = cos(CGFloat(angle.radians)) * innerR
                            let endY = sin(CGFloat(angle.radians)) * innerR

                            Path { p in
                                p.move(to: CGPoint(x: tickCenter.x + startX, y: tickCenter.y + startY))
                                p.addLine(to: CGPoint(x: tickCenter.x + endX, y: tickCenter.y + endY))
                            }
                            .stroke(isHour ? tickColorHour : tickColorMinute, lineWidth: lineWidth)
                        }
                    }
                }

                // Hour number labels (1–12) positioned in the middle of the middle ring
                let labelRadius = innerCircleRadius + (middleRingWidth / 2)
                ClockLabels(labelRadius: labelRadius)
                    .foregroundStyle(numeralColor)

                // Clock hands: hour and minute
                let hourHandLength = innerCircleRadius - 6
                let minuteHandLength = innerCircleRadius + (middleRingWidth * 0.6)

                TimeHand(now: now)
                    .stroke(handColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: hourHandLength * 2, height: hourHandLength * 2)

                MinuteHand(now: now)
                    .stroke(handColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .frame(width: minuteHandLength * 2, height: minuteHandLength * 2)

                // Center dot
                Circle()
                    .fill(handColor)
                    .frame(width: 8, height: 8)
            }
            .position(center)
        }
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Shapes

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

struct ClockLabels: View {
    var labelRadius: CGFloat
    
    var body: some View {
        GeometryReader { proxy in
            let center = CGPoint(x: proxy.size.width/2, y: proxy.size.height/2)

            ZStack {
                ForEach(1...12, id: \.self) { hour in
                    let angle = Angle.degrees(Double(hour) * 30 - 90)
                    let x = cos(CGFloat(angle.radians)) * labelRadius
                    let y = sin(CGFloat(angle.radians)) * labelRadius

                    Text("\(hour)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .position(x: center.x + x, y: center.y + y)
                        .accessibilityLabel("\(hour)")
                }
            }
        }
    }
}
