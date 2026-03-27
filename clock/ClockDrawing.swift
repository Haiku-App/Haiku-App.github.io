import SwiftUI

struct ClockView: View {
    var now: Date
    var displayedDate: Date = Date()
    @Binding var tasks: [ClockTask]
    @Binding var isFlowState: Bool
    var is24HourClock: Bool = false
    var theme: AppTheme = .sage
    var onTaskUpdated: ((ClockTask) -> Void)? = nil

    // Themed Palette
    private var clockFaceColor: Color { theme.bg }
    private var shadowLight: Color { theme.shadowLight }
    private var shadowDark: Color { theme.shadowDark }
    private var goldColor: Color { theme.accent }
    private var taskTrackColor: Color { theme.taskTrack }
    private var textForeground: Color { theme.textForeground }

    @State private var activeDrag: DragInfo?
    @State private var interactiveTasks: [ClockTask] = []
    @State private var pulseState: Bool = false
    struct DragInfo {
        var taskId: UUID
        var mode: Mode
        var initialMouseMinute: Double
        var lastMouseMinute: Double
        var accumulatedDelta: Double
        var initialStartMinutes: Int
        var initialEndMinutes: Int
        var isInDeadzone: Bool = false

        enum Mode {
            case move, resizeStart, resizeEnd, create
        }
    }

    // Helper to get current minutes from midnight
    private var currentMinute: Double {
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        return Double((comps.hour ?? 0) * 60 + (comps.minute ?? 0)) + Double(comps.second ?? 0) / 60.0
    }
    
    private var dayStatus: Int { // -1: past, 0: today, 1: future
        let cal = Calendar.current
        if cal.isDateInToday(displayedDate) { return 0 }
        return displayedDate < now ? -1 : 1
    }
    
    private var activeTask: ClockTask? {
        // Return first task that is currently happening
        let min = Int(currentMinute)
        return interactiveTasks.first { min >= $0.startMinutes && min < $0.normalizedEndMinutes }
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
                        DragGesture(minimumDistance: 5)
                            .onChanged { value in
                                if activeDrag == nil {
                                    handleDragStart(location: value.location, size: proxy.size)
                                }
                                handleDragChange(location: value.location, size: proxy.size)
                            }
                            .onEnded { _ in
                                interactiveTasks.sort { $0.startMinutes < $1.startMinutes }
                                tasks = interactiveTasks

                                if let drag = activeDrag, let task = interactiveTasks.first(where: { $0.id == drag.taskId }) {
                                    onTaskUpdated?(task)
                                    logAnalytics("task_modified_via_drag", properties: ["mode": "\(drag.mode)"])
                                }
                                activeDrag = nil
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                    )
                
                // Task Tracks (Concentric AM/PM Rings)
                let ringWidth: CGFloat = is24HourClock ? 24 : 18
                let pmRingRadius = radius - (ringWidth/2)
                let amRingRadius = pmRingRadius - ringWidth - 4
                
                // Neumorphic Base
                let faceRadius = is24HourClock ? (pmRingRadius - (ringWidth/2) - 4) : (amRingRadius - (ringWidth/2) - 4)
                
                // Outer Bezel / Depth Ring
                Circle()
                    .stroke(textForeground.opacity(0.1), lineWidth: 1)
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .allowsHitTesting(false)

                Circle()
                    .fill(
                        RadialGradient(colors: [clockFaceColor.opacity(0.9), clockFaceColor], center: .center, startRadius: 0, endRadius: faceRadius)
                    )
                    .frame(width: faceRadius * 2, height: faceRadius * 2)
                    .shadow(color: shadowDark.opacity(0.4), radius: 15, x: 8, y: 8) // Softer, deeper shadow
                    .shadow(color: shadowLight.opacity(0.3), radius: 15, x: -8, y: -8)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(colors: [textForeground.opacity(0.15), .clear, textForeground.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                                lineWidth: 1
                            )
                    )
                    .overlay(
                        // Frosted / Ceramic Texture
                        Circle()
                            .fill(.white.opacity(0.02))
                            .blur(radius: 1)
                    )
                    .allowsHitTesting(false)
                
                if is24HourClock {
                    // Empty 24H Track (Outer) - Clean Engraved Look
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
                        .allowsHitTesting(false)

                    // Sun/Moon indicators (Positioned near labels like the reference image)
                    Group {
                        Image(systemName: "moon.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(goldColor.opacity(0.8))
                            .position(x: center.x, y: center.y - faceRadius + 58)
                        
                        Image(systemName: "sun.max.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.yellow.opacity(0.8))
                            .position(x: center.x, y: center.y + faceRadius - 58)
                    }
                    .allowsHitTesting(false)

                } else {
                    // Empty AM/PM Tracks (Clean Engraved Look with Dynamic Focus)
                    let isAM = currentMinute < 720
                    let amOpacity: Double = isAM ? 1.0 : 0.25
                    let pmOpacity: Double = isAM ? 0.25 : 1.0
                    
                    Group {
                        // AM Track
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [shadowDark.opacity(0.7 * amOpacity), shadowLight.opacity(0.3 * amOpacity)],
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
                                    colors: [shadowDark.opacity(0.7 * pmOpacity), shadowLight.opacity(0.3 * pmOpacity)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: ringWidth
                            )
                            .frame(width: pmRingRadius * 2, height: pmRingRadius * 2)
                    }
                    .allowsHitTesting(false)
                    
                    // AM/PM Labels & Anchors
                    Group {
                        // AM Section
                        VStack(spacing: 2) {
                            Image(systemName: "sun.max.fill")
                                .font(.system(size: 8))
                            Text("AM")
                                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(goldColor.opacity(isAM ? 0.8 : 0.2))
                        .position(x: center.x, y: center.y - amRingRadius)
                        
                        // PM Section
                        VStack(spacing: 2) {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 8))
                            Text("PM")
                                .font(.system(size: 7, weight: .heavy, design: .monospaced))
                        }
                        .foregroundStyle(goldColor.opacity(!isAM ? 0.8 : 0.2))
                        .position(x: center.x, y: center.y - pmRingRadius)
                    }
                    .allowsHitTesting(false)
                }
                
                // Scheduled Tasks
                ForEach(interactiveTasks) { task in
                    let taskForClock = task.normalizedForClock
                    let isDragging = activeDrag?.taskId == task.id
                    let isActive = activeTask?.id == task.id && !isDragging
                    
                    let glowRadius: CGFloat = (isActive && (pulseState || isFlowState)) ? (isFlowState ? 16 : 8) : (isDragging ? 4 : 0)
                    let glowColor = task.color.opacity((isActive && (pulseState || isFlowState)) ? (isFlowState ? 0.6 : 0.4) : (isDragging ? 0.6 : 0))

                    let frags = is24HourClock ? [TaskFragment(isAM: false, startMinutes: Double(taskForClock.startMinutes), endMinutes: Double(taskForClock.endMinutes), task: taskForClock)] : getFragments(for: taskForClock)
                    ForEach(frags) { frag in
                        let r = is24HourClock ? pmRingRadius : (frag.isAM ? amRingRadius : pmRingRadius)
                        
                        Group {
                            if isDragging || dayStatus > 0 {
                                // Full color for dragging or future days
                                TaskSegmentView(start: frag.startMinutes, end: frag.endMinutes, color: task.color, opacity: 1.0, isFuture: true, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock)
                            } else if dayStatus < 0 {
                                // Greyed out for past days
                                TaskSegmentView(start: frag.startMinutes, end: frag.endMinutes, color: task.color, opacity: 0.3, isFuture: false, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock)
                            } else {
                                // Today logic: split if needed
                                let fragStart = frag.startMinutes
                                let fragEnd = frag.endMinutes
                                let absStart = is24HourClock ? fragStart : (frag.isAM ? fragStart : fragStart + 720)
                                let absEnd = is24HourClock ? fragEnd : (frag.isAM ? fragEnd : fragEnd + 720)
                                
                                if currentMinute >= absEnd {
                                    // Fragment entirely in the past
                                    TaskSegmentView(start: fragStart, end: fragEnd, color: task.color, opacity: 0.3, isFuture: false, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock)
                                } else if currentMinute <= absStart {
                                    // Fragment entirely in the future
                                    TaskSegmentView(start: fragStart, end: fragEnd, color: task.color, opacity: 1.0, isFuture: true, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock)
                                } else {
                                    // Fragment spans current time: SPLIT
                                    let splitPoint = is24HourClock ? currentMinute : (frag.isAM ? currentMinute : currentMinute - 720)
                                    
                                    ZStack {
                                        TaskSegmentView(start: fragStart, end: splitPoint, color: task.color, opacity: 0.3, isFuture: false, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock)
                                        TaskSegmentView(start: splitPoint, end: fragEnd, color: task.color, opacity: 1.0, isFuture: true, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock)
                                    }
                                }
                            }
                        }
                        .frame(width: r * 2, height: r * 2)
                        .allowsHitTesting(false)
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
                .allowsHitTesting(false)

                // Hour Numbers (Minimalist)
                if is24HourClock {
                    ForEach(0..<12, id: \.self) { i in
                        let hour = i * 2
                        // For 24h clock, each hour is 15 degrees. 24 (0) is at top, 6 at right, 12 at bottom, 18 at left.
                        let angle = Angle.degrees(Double(hour) * 15 - 90)
                        let dist = faceRadius - 32
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
                            .font(.system(size: isMain ? 14 : 15, weight: isMain ? .bold : .medium, design: .serif))
                            .foregroundStyle(isMain ? goldColor : goldColor.opacity(0.4))
                            .position(x: center.x + x, y: center.y + y)
                    }
                } else {
                    ForEach([12, 3, 6, 9], id: \.self) { hour in
                        let angle = Angle.degrees(Double(hour) * 30 - 90)
                        let dist = faceRadius - 28
                        let x = cos(CGFloat(angle.radians)) * dist
                        let y = sin(CGFloat(angle.radians)) * dist
                        
                        Text("\(hour)")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(goldColor.opacity(0.9))
                            .position(x: center.x + x, y: center.y + y)
                    }
                }

                // Central Status Text & Flow State Toggle
                if let active = activeTask {
                    let minsRemaining = active.endMinutes - Int(currentMinute)
                    let h = minsRemaining / 60
                    let m = minsRemaining % 60
                    let timeLabel: String = {
                        if h > 0 {
                            return "\(h) hour\(h > 1 ? "s" : "")\(m > 0 ? " \(m) mins" : "") left"
                        } else {
                            return "\(m) mins left"
                        }
                    }()
                    
                    Button(action: {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                            isFlowState.toggle()
                            logAnalytics("flow_state_toggled", properties: ["is_active": isFlowState])
                        }
                    }) {
                        VStack(spacing: 4) {
                            Text(timeLabel)
                                .font(.system(size: isFlowState ? 16 : 12, weight: .bold, design: .rounded))
                                .foregroundStyle(active.color)
                            
                            if isFlowState {
                                Text(active.title.uppercased())
                                    .font(.system(size: 11, weight: .black, design: .rounded))
                                    .tracking(2)
                                    .foregroundStyle(active.color.opacity(0.8))
                                    .transition(.asymmetric(insertion: .opacity.combined(with: .scale), removal: .opacity))
                            }
                        }
                        .padding(24)
                        .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .position(x: center.x, y: center.y + faceRadius - (isFlowState ? 50 : 45))
                    
                } else {
                    Text(formatTime(now).uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(textForeground.opacity(0.4))
                        .position(x: center.x, y: center.y + faceRadius - 45)
                        .allowsHitTesting(false)
                }

                // Hands
                let hourHandLength = faceRadius * 0.5
                let minuteHandLength = faceRadius * 0.8
                let secondHandLength = faceRadius * 0.85

                // Hour Hand
                TaperedHand(now: now, is24HourClock: is24HourClock, length: hourHandLength, width: 6)
                    .fill(goldColor)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)
                    .allowsHitTesting(false)

                // Minute Hand
                TaperedHand(now: now, is24HourClock: false, length: minuteHandLength, width: 4, isMinute: true)
                    .fill(goldColor)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 4)
                    .allowsHitTesting(false)

                // Second Hand (Elegant Sweep Style)
                ElegantSecondHand(now: now, length: secondHandLength)
                    .stroke(Color(red: 0.9, green: 0.3, blue: 0.2), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 2)
                    .allowsHitTesting(false)

                // Center Cap
                Circle()
                    .fill(goldColor)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().stroke(Color.black.opacity(0.1), lineWidth: 1))
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    .allowsHitTesting(false)
            }
            .position(center)
            .onAppear {
                interactiveTasks = tasks
                
                withAnimation(Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseState = true
                }
            }
            .onChange(of: tasks) { _, newTasks in
                guard activeDrag == nil else { return }
                interactiveTasks = newTasks
            }
        }
    }
    
    // Lightweight analytics shim to avoid hard dependency on an AnalyticsManager implementation
    private func logAnalytics(_ event: String, properties: [String: Any] = [:]) {
        // Intentionally left as a no-op. Hook up your analytics SDK here if desired.
        // print("Analytics: \(event) -> \(properties)")
    }
    
    // MARK: - Drag Logic

    private func handleDragStart(location: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        let radius = size.width / 2
        
        let ringWidth: CGFloat = is24HourClock ? 24 : 18
        let pmRingRadius = radius - (ringWidth/2)
        let amRingRadius = pmRingRadius - ringWidth - 4
        
        let isAMClick = is24HourClock ? false : abs(dist - amRingRadius) < abs(dist - pmRingRadius)
        
        let targetRadius = is24HourClock ? pmRingRadius : (isAMClick ? amRingRadius : pmRingRadius)
        if abs(dist - targetRadius) > 30 { return }
        
        let min12h = minute(from: location, in: size)
        let absoluteMinute = is24HourClock ? (min12h * 2) : (isAMClick ? min12h : min12h + 720)
        
        for task in interactiveTasks {
            if task.isCompleted { continue }
            
            let touchBuffer: Double = 10.0
            let absMinWrap = absoluteMinute + 1440
            
            // Check if touch is within task bounds (handling midnight wrap)
            let taskForClock = task.normalizedForClock
            let duration = Double(taskForClock.endMinutes - taskForClock.startMinutes)
            let inNormal = absoluteMinute >= (Double(taskForClock.startMinutes) - touchBuffer) && absoluteMinute <= (Double(taskForClock.endMinutes) + touchBuffer)
            let inWrap = absMinWrap >= (Double(taskForClock.startMinutes) - touchBuffer) && absMinWrap <= (Double(taskForClock.endMinutes) + touchBuffer)
            
            if inNormal || inWrap {
                let effAbsolute = inWrap && !inNormal ? absMinWrap : absoluteMinute
                let distToStart = abs(effAbsolute - Double(taskForClock.startMinutes))
                let distToEnd = abs(effAbsolute - Double(taskForClock.endMinutes))
                
                var mode: DragInfo.Mode = .move
                if duration <= 15 {
                    if distToStart <= 5 && distToStart < distToEnd { mode = .resizeStart }
                    else if distToEnd <= 5 { mode = .resizeEnd }
                } else {
                    if distToStart <= 15 { mode = .resizeStart }
                    else if distToEnd <= 15 { mode = .resizeEnd }
                }
                
                activeDrag = DragInfo(taskId: task.id, mode: mode, initialMouseMinute: min12h, lastMouseMinute: min12h, accumulatedDelta: 0, initialStartMinutes: taskForClock.startMinutes, initialEndMinutes: taskForClock.endMinutes)
                return
            }
        }
    }

    private func handleDragChange(location: CGPoint, size: CGSize) {
        guard var drag = activeDrag, let index = interactiveTasks.firstIndex(where: { $0.id == drag.taskId }) else { return }
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        let deadzoneRadius = min(size.width, size.height) * 0.18
        let deadzoneExitRadius = deadzoneRadius + 14
        
        // Calculate the raw minute based solely on angle (0...720)
        let min12h = minute(from: location, in: size)

        // Freeze the drag while the finger is near the center. Angle gets unstable there,
        // so we suspend tracking until the touch is clearly back outside the deadzone.
        if drag.isInDeadzone {
            if dist < deadzoneExitRadius {
                activeDrag = drag
                return
            }

            drag.lastMouseMinute = min12h
            drag.isInDeadzone = false
            activeDrag = drag
            return
        }

        if dist < deadzoneRadius {
            drag.isInDeadzone = true
            activeDrag = drag
            return
        }
        
        // Calculate angular delta
        var delta = min12h - drag.lastMouseMinute
        
        // Handle angular wrap-around (crossing 12 o'clock)
        if delta > 360 { delta -= 720 }
        else if delta < -360 { delta += 720 }
        
        drag.accumulatedDelta += delta
        drag.lastMouseMinute = min12h
        activeDrag = drag // Update state
        
        var totalDelta = drag.accumulatedDelta
        if is24HourClock {
            totalDelta *= 2 // 360 degrees = 1440 minutes for 24h clock
        }
        
        var task = interactiveTasks[index].normalizedForClock
        let oldStart = task.startMinutes
        let oldEnd = task.endMinutes
        
        // Smoother Aim Assist: snap to nearest 15 mins if within 4 minutes
        func snap(_ val: Int) -> Int {
            let remainder = val % 15
            if remainder < 4 { return val - remainder }
            if remainder > 11 { return val + (15 - remainder) }
            return val
        }
        
        var proposedStart = task.startMinutes
        var proposedEnd = task.endMinutes
        
        switch drag.mode {
        case .move:
            let rawStart = drag.initialStartMinutes + Int(totalDelta)
            let snappedStart = snap(rawStart)
            let duration = drag.initialEndMinutes - drag.initialStartMinutes
            
            proposedStart = snappedStart
            proposedEnd = snappedStart + duration
            
            // Wrap around 24h allowing tasks to span midnight smoothly
            if proposedStart < 0 {
                proposedStart += 1440
                proposedEnd += 1440
            } else if proposedStart >= 1440 {
                proposedStart -= 1440
                proposedEnd -= 1440
            }

        case .resizeStart:
            let rawStart = drag.initialStartMinutes + Int(totalDelta)
            proposedStart = snap(rawStart)
            
            if proposedStart < 0 { proposedStart += 1440 }
            if proposedStart >= 1440 { proposedStart -= 1440 }
            
            // Prevent inverted resize (start going past end)
            var dist = proposedEnd - proposedStart
            if dist < 0 { dist += 1440 }
            if dist < 5 { proposedStart = proposedEnd - 5 }
            
        case .resizeEnd, .create:
            let rawEnd = drag.initialEndMinutes + Int(totalDelta)
            proposedEnd = snap(rawEnd)
            
            if proposedEnd < 0 { proposedEnd += 1440 }
            if proposedEnd >= 2880 { proposedEnd -= 1440 } // Keep it within 2 days span for safety
            
            var dist = proposedEnd - proposedStart
            if dist < 0 { dist += 1440 }
            if dist < 5 { proposedEnd = proposedStart + 5 }
        }
        
        // Haptic feedback when snapping to a new boundary
        let startChangedToSnap = proposedStart != oldStart && proposedStart % 15 == 0
        let endChangedToSnap = proposedEnd != oldEnd && proposedEnd % 15 == 0
        
        if startChangedToSnap || endChangedToSnap {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        task.startMinutes = proposedStart
        task.endMinutes = proposedEnd
        interactiveTasks[index] = task
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

struct TaperedHand: Shape {
    var now: Date
    var is24HourClock: Bool = false
    var length: CGFloat
    var width: CGFloat
    var isMinute: Bool = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        
        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let angleDeg: Double
        if isMinute {
            let totalMinutes = minute + second/60
            angleDeg = totalMinutes * 6 - 90
        } else {
            if is24HourClock {
                let totalMinutes24h = hour * 60 + minute + second/60
                angleDeg = totalMinutes24h * 0.25 - 90
            } else {
                let totalMinutes12h = (hour.truncatingRemainder(dividingBy: 12)) * 60 + minute + second/60
                angleDeg = totalMinutes12h * 0.5 - 90
            }
        }
        
        let angle = Angle.degrees(angleDeg).radians
        let rotation = CGAffineTransform(rotationAngle: CGFloat(angle))
        
        // Create a tapered diamond/sword shape
        let handPath = Path { path in
            path.move(to: CGPoint(x: -2, y: 0)) // Counterweight start
            path.addLine(to: CGPoint(x: -width/2, y: -width/2))
            path.addLine(to: CGPoint(x: length * 0.9, y: -width/4))
            path.addLine(to: CGPoint(x: length, y: 0)) // Tip
            path.addLine(to: CGPoint(x: length * 0.9, y: width/4))
            path.addLine(to: CGPoint(x: -width/2, y: width/2))
            path.closeSubpath()
        }
        
        p.addPath(handPath.applying(rotation).applying(CGAffineTransform(translationX: center.x, y: center.y)))
        return p
    }
}

struct ElegantSecondHand: Shape {
    var now: Date
    var length: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        let comps = Calendar.current.dateComponents([.second, .nanosecond], from: now)
        let second = Double(comps.second ?? 0)
        let nano = Double(comps.nanosecond ?? 0)

        let totalSeconds = second + nano / 1_000_000_000
        let angleDeg = totalSeconds * 6 - 90
        let angle = Angle.degrees(angleDeg).radians
        
        let cosA = cos(CGFloat(angle))
        let sinA = sin(CGFloat(angle))
        
        // Main line
        p.move(to: CGPoint(x: center.x - cosA * 15, y: center.y - sinA * 15)) // Counterweight end
        p.addLine(to: CGPoint(x: center.x + cosA * length, y: center.y + sinA * length))
        
        // Small circle at the end for "Premium" look
        let circleRadius: CGFloat = 3
        let circleCenter = CGPoint(x: center.x + cosA * (length - 15), y: center.y + sinA * (length - 15))
        p.addEllipse(in: CGRect(x: circleCenter.x - circleRadius, y: circleCenter.y - circleRadius, width: circleRadius*2, height: circleRadius*2))
        
        return p
    }
}

struct TimeHand: Shape {
    var now: Date
    var is24HourClock: Bool = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let angleDeg: Double
        if is24HourClock {
            let totalMinutes24h = hour * 60 + minute + second/60
            angleDeg = totalMinutes24h * 0.25 - 90
        } else {
            let totalMinutes12h = (hour.truncatingRemainder(dividingBy: 12)) * 60 + minute + second/60
            angleDeg = totalMinutes12h * 0.5 - 90
        }
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
    var is24HourClock: Bool = false

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        func angle(for minutes: Double) -> Angle {
            let deg = is24HourClock ? (minutes * 0.25 - 90) : (minutes * 0.5 - 90)
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
            let eInPM = min(e, 1440)
            frags.append(TaskFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(eInPM) - 720.0, task: task))
            if e > 1440 {
                let wrappedE = min(e - 1440, 720)
                frags.append(TaskFragment(isAM: true, startMinutes: 0.0, endMinutes: Double(wrappedE), task: task))
                if e > 2160 {
                    frags.append(TaskFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(e - 2160), task: task))
                }
            }
        }
    } else {
        let sInPM = max(s, 720)
        let eInPM = min(e, 1440)
        frags.append(TaskFragment(isAM: false, startMinutes: Double(sInPM) - 720.0, endMinutes: Double(eInPM) - 720.0, task: task))
        if e > 1440 {
            let wrappedE = min(e - 1440, 720)
            frags.append(TaskFragment(isAM: true, startMinutes: 0.0, endMinutes: Double(wrappedE), task: task))
            if e > 2160 {
                frags.append(TaskFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(e - 2160), task: task))
            }
        }
    }
    return frags
}

struct TaskSegmentView: View {
    let start: Double
    let end: Double
    let color: Color
    let opacity: Double
    let isFuture: Bool
    let glowColor: Color
    let glowRadius: CGFloat
    let ringWidth: CGFloat
    let is24HourClock: Bool

    var body: some View {
        ZStack {
            // Subtle Bottom Shadow
            TaskArc(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock)
                .stroke(Color.black.opacity(0.15 * opacity), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                .offset(x: 0.5, y: 0.5)
            
            // Main Task Fill
            TaskArc(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock)
                .stroke(
                    color.opacity(opacity),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
            
            // Very subtle Top Highlight
            TaskArc(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock)
                .stroke(
                    LinearGradient(colors: [.white.opacity(0.2 * opacity), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                )
                .blendMode(.overlay)
        }
        .shadow(color: isFuture ? glowColor : .clear, radius: glowRadius)
    }
}
