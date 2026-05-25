import SwiftUI

struct ClockView: View {
    var now: Date
    var displayedDate: Date = Date()
    @Binding var tasks: [ClockTask]
    var is24HourClock: Bool = false
    var taskDisplayStyle: ClockTaskDisplayStyle = .rings
    var zoomedHour: Int? = nil
    var theme: AppTheme = .sage
    var displayTasks: [ClockTask]? = nil
    var onTaskUpdated: ((ClockTask) -> Void)? = nil
    var onTasksPreviewUpdated: (([ClockTask]?) -> Void)? = nil

    // Themed Palette
    private var clockFaceColor: Color { theme.bg }
    private var shadowLight: Color { theme.shadowLight }
    private var shadowDark: Color { theme.shadowDark }
    private var goldColor: Color { theme.accent }
    private var taskTrackColor: Color { theme.taskTrack }
    private var textForeground: Color { theme.textForeground }
    private var usesTaskSections: Bool {
        is24HourClock && taskDisplayStyle == .sections && zoomedHour == nil
    }
    private var dragMinutePeriod: Double {
        if zoomedHour != nil { return 60 }
        return is24HourClock ? 1440 : 720
    }

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
        return tasksForDisplay.first { min >= $0.startMinutes && min < $0.normalizedEndMinutes }
    }

    private var tasksForDisplay: [ClockTask] {
        displayTasks ?? interactiveTasks
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
                                onTasksPreviewUpdated?(nil)

                                if let drag = activeDrag, let task = interactiveTasks.first(where: { $0.id == drag.taskId }) {
                                    onTaskUpdated?(task)
                                    logAnalytics("task_modified_via_drag", properties: ["mode": "\(drag.mode)"])
                                }
                                activeDrag = nil
                                UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                            }
                    )
                
                // Task Tracks (Concentric AM/PM Rings)
                let ringWidth: CGFloat = zoomedHour != nil ? 40 : (usesTaskSections ? 8 : (is24HourClock ? 24 : 18))
                let pmRingRadius = radius - (ringWidth/2)
                let amRingRadius = pmRingRadius - ringWidth - 4
                
                // Neumorphic Base
                let faceRadius = usesTaskSections ? (radius - 4) : (zoomedHour != nil ? (pmRingRadius - (ringWidth/2) - 4) : (is24HourClock ? (pmRingRadius - (ringWidth/2) - 4) : (amRingRadius - (ringWidth/2) - 4)))
                
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
                
                if zoomedHour != nil {
                    // Larger track for 1H mode
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
                } else if usesTaskSections {
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [shadowDark.opacity(0.45), shadowLight.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.5
                        )
                        .frame(width: faceRadius * 2, height: faceRadius * 2)
                        .allowsHitTesting(false)
                } else if is24HourClock {
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
                scheduledTasksView(ringWidth: ringWidth, amRingRadius: amRingRadius, pmRingRadius: pmRingRadius, faceRadius: faceRadius)

                // Premium Ticks (Baton markers)
                let numTicks = zoomedHour != nil ? 60 : (is24HourClock ? 48 : 60)
                ForEach(0..<numTicks, id: \.self) { i in
                    let isHour = zoomedHour != nil ? (i % 5 == 0) : (is24HourClock ? (i % 4 == 0) : (i % 5 == 0))
                    
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
                    if let zh = zoomedHour {
                        ForEach([0, 15, 30, 45], id: \.self) { minute in
                            let angle = Angle.degrees(Double(minute) * 6 - 90)
                            let dist = faceRadius - 28
                            let x = cos(CGFloat(angle.radians)) * dist
                            let y = sin(CGFloat(angle.radians)) * dist
                            
                            let label: String = {
                                if minute == 0 {
                                    let h = zh % 12
                                    let displayH = h == 0 ? 12 : h
                                    let ampm = (zh % 24) < 12 ? "AM" : "PM"
                                    return "\(displayH)\(ampm)"
                                } else {
                                    return "\(minute)"
                                }
                            }()
                            
                            Text(label)
                                .font(.system(size: minute == 0 ? 18 : 16, weight: minute == 0 ? .bold : .medium, design: .serif))
                                .foregroundStyle(goldColor.opacity(minute == 0 ? 1.0 : 0.9))
                                .position(x: center.x + x, y: center.y + y)
                        }
                    } else if is24HourClock {
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
                            let h = hour % 12
                            return "\(h == 0 ? 12 : h)"
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

                // Central Status Text
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
                    
                    Text(timeLabel)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(active.color.opacity(0.65))
                        .position(x: center.x, y: center.y + faceRadius - 45)
                        .allowsHitTesting(false)
                    
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
                TaperedHand(now: now, is24HourClock: is24HourClock, zoomedHour: zoomedHour, length: hourHandLength, width: 6)
                    .fill(goldColor)
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 3)
                    .allowsHitTesting(false)
                    .opacity(zoomedHour != nil ? 0 : 1)

                // Minute Hand
                TaperedHand(now: now, is24HourClock: false, zoomedHour: zoomedHour, length: minuteHandLength, width: 4, isMinute: true)
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
            .onDisappear {
                onTasksPreviewUpdated?(nil)
            }
            .onChange(of: tasks) { _, newTasks in
                guard activeDrag == nil else { return }
                interactiveTasks = newTasks
                onTasksPreviewUpdated?(nil)
            }
        }
    }
    
    // Lightweight analytics shim to avoid hard dependency on an AnalyticsManager implementation
    private func logAnalytics(_ event: String, properties: [String: Any] = [:]) {
        // Intentionally left as a no-op. Hook up your analytics SDK here if desired.
        // print("Analytics: \(event) -> \(properties)")
    }

    @ViewBuilder
    private func scheduledTasksView(ringWidth: CGFloat, amRingRadius: CGFloat, pmRingRadius: CGFloat, faceRadius: CGFloat) -> some View {
        ForEach(tasksForDisplay) { task in
            scheduledFragmentsView(for: task, ringWidth: ringWidth, amRingRadius: amRingRadius, pmRingRadius: pmRingRadius, faceRadius: faceRadius)
        }
    }

    @ViewBuilder
    private func scheduledFragmentsView(for task: ClockTask, ringWidth: CGFloat, amRingRadius: CGFloat, pmRingRadius: CGFloat, faceRadius: CGFloat) -> some View {
        let taskForClock = task.normalizedForClock
        let isDragging = activeDrag?.taskId == task.id
        let isActive = activeTask?.id == task.id && !isDragging
        let glowRadius: CGFloat = (isActive && pulseState) ? 8 : (isDragging ? 4 : 0)
        let glowColor = task.color.opacity((isActive && pulseState) ? 0.4 : (isDragging ? 0.6 : 0))
        
        let fragments: [TaskFragment] = {
            if let zh = zoomedHour {
                // Filter tasks that intersect with the zoomed hour
                let hourStart = zh * 60
                let hourEnd = hourStart + 60
                
                if task.startMinutes < hourEnd && task.normalizedEndMinutes > hourStart {
                    // Adjust fragment for zoomed view
                    let visibleStart = max(Double(task.startMinutes), Double(hourStart))
                    let visibleEnd = min(Double(task.normalizedEndMinutes), Double(hourEnd))
                    
                    return [TaskFragment(id: "\(task.id.uuidString)-zoom", isAM: false, startMinutes: visibleStart - Double(hourStart), endMinutes: visibleEnd - Double(hourStart), task: task)]
                } else {
                    return []
                }
            } else {
                return is24HourClock ? [TaskFragment(id: "\(task.id.uuidString)-0", isAM: false, startMinutes: Double(taskForClock.startMinutes), endMinutes: Double(taskForClock.endMinutes), task: taskForClock)] : getFragments(for: taskForClock)
            }
        }()

        ForEach(fragments) { fragment in
            scheduledFragmentView(
                fragment: fragment,
                task: task,
                isDragging: isDragging,
                glowColor: glowColor,
                glowRadius: glowRadius,
                ringWidth: ringWidth,
                amRingRadius: amRingRadius,
                pmRingRadius: pmRingRadius,
                faceRadius: faceRadius
            )
        }
    }

    @ViewBuilder
    private func scheduledFragmentView(fragment: TaskFragment, task: ClockTask, isDragging: Bool, glowColor: Color, glowRadius: CGFloat, ringWidth: CGFloat, amRingRadius: CGFloat, pmRingRadius: CGFloat, faceRadius: CGFloat) -> some View {
        let radius = usesTaskSections ? faceRadius : (zoomedHour != nil ? pmRingRadius : (is24HourClock ? pmRingRadius : (fragment.isAM ? amRingRadius : pmRingRadius)))

        Group {
            if isDragging || dayStatus > 0 {
                TaskSegmentView(start: fragment.startMinutes, end: fragment.endMinutes, color: task.color, opacity: 1.0, isFuture: true, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock, isTaskSection: usesTaskSections, zoomedHour: zoomedHour)
            } else if dayStatus < 0 {
                TaskSegmentView(start: fragment.startMinutes, end: fragment.endMinutes, color: task.color, opacity: 0.3, isFuture: false, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock, isTaskSection: usesTaskSections, zoomedHour: zoomedHour)
            } else {
                todayFragmentView(fragment: fragment, task: task, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth)
            }
        }
        .frame(width: radius * 2, height: radius * 2)
        .allowsHitTesting(false)
        .transaction { transaction in
            if activeDrag != nil {
                transaction.animation = nil
            }
        }
    }

    @ViewBuilder
    private func todayFragmentView(fragment: TaskFragment, task: ClockTask, glowColor: Color, glowRadius: CGFloat, ringWidth: CGFloat) -> some View {
        let fragmentStart = fragment.startMinutes
        let fragmentEnd = fragment.endMinutes
        
        let (absoluteStart, absoluteEnd, current): (Double, Double, Double) = {
            if let zh = zoomedHour {
                return (fragmentStart, fragmentEnd, currentMinute - Double(zh * 60))
            } else {
                let start = is24HourClock ? fragmentStart : (fragment.isAM ? fragmentStart : fragmentStart + 720)
                let end = is24HourClock ? fragmentEnd : (fragment.isAM ? fragmentEnd : fragmentEnd + 720)
                return (start, end, currentMinute)
            }
        }()

        if current >= absoluteEnd {
            TaskSegmentView(start: fragmentStart, end: fragmentEnd, color: task.color, opacity: 0.3, isFuture: false, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock, isTaskSection: usesTaskSections, zoomedHour: zoomedHour)
        } else if current <= absoluteStart {
            TaskSegmentView(start: fragmentStart, end: fragmentEnd, color: task.color, opacity: 1.0, isFuture: true, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock, isTaskSection: usesTaskSections, zoomedHour: zoomedHour)
        } else {
            let splitPoint: Double = {
                if zoomedHour != nil {
                    return current
                } else {
                    return is24HourClock ? currentMinute : (fragment.isAM ? currentMinute : currentMinute - 720)
                }
            }()

            ZStack {
                TaskSegmentView(start: fragmentStart, end: splitPoint, color: task.color, opacity: 0.3, isFuture: false, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock, isTaskSection: usesTaskSections, zoomedHour: zoomedHour)
                TaskSegmentView(start: splitPoint, end: fragmentEnd, color: task.color, opacity: 1.0, isFuture: true, glowColor: glowColor, glowRadius: glowRadius, ringWidth: ringWidth, is24HourClock: is24HourClock, isTaskSection: usesTaskSections, zoomedHour: zoomedHour)
            }
        }
    }
    
    // MARK: - Drag Logic

    private func handleDragStart(location: CGPoint, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        let radius = min(size.width, size.height) / 2
        
        let ringWidth: CGFloat = zoomedHour != nil ? 40 : (usesTaskSections ? 8 : (is24HourClock ? 24 : 18))
        let pmRingRadius = radius - (ringWidth/2)
        let amRingRadius = pmRingRadius - ringWidth - 4
        let faceRadius = usesTaskSections ? (radius - 4) : pmRingRadius
        
        let mouseMinute = minute(from: location, in: size)

        // Find which task/ring we are hitting
        // Priority: PM ring (outer) first, then AM ring (inner)
        if usesTaskSections {
            if dist <= faceRadius {
                if let taskIndex = interactiveTasks.firstIndex(where: { taskContains($0, minute: mouseMinute) }) {
                    startDragging(taskIndex: taskIndex, mouseMinute: mouseMinute, location: location, size: size)
                    return
                }

                return
            }
        } else if zoomedHour != nil {
             if abs(dist - pmRingRadius) < ringWidth {
                 if let taskIndex = interactiveTasks.firstIndex(where: {
                     let hourStart = Double(zoomedHour! * 60)
                     let hourEnd = hourStart + 60
                     return Double($0.startMinutes) < hourEnd && Double($0.normalizedEndMinutes) > hourStart &&
                            mouseMinute >= max(Double($0.startMinutes), hourStart) && mouseMinute <= min(Double($0.normalizedEndMinutes), hourEnd)
                 }) {
                     startDragging(taskIndex: taskIndex, mouseMinute: mouseMinute, location: location, size: size)
                     return
                 }
             }
        } else if is24HourClock {
            if abs(dist - pmRingRadius) < ringWidth {
                if let taskIndex = interactiveTasks.firstIndex(where: { mouseMinute >= Double($0.startMinutes) && mouseMinute <= Double($0.normalizedEndMinutes) }) {
                    startDragging(taskIndex: taskIndex, mouseMinute: mouseMinute, location: location, size: size)
                    return
                }
            }
        } else {
            if abs(dist - pmRingRadius) < ringWidth {
                if let taskIndex = interactiveTasks.firstIndex(where: { Double($0.startMinutes) >= 720 && mouseMinute >= Double($0.startMinutes) - 720 && mouseMinute <= Double($0.normalizedEndMinutes) - 720 }) {
                    startDragging(taskIndex: taskIndex, mouseMinute: mouseMinute, location: location, size: size)
                    return
                }
            } else if abs(dist - amRingRadius) < ringWidth {
                if let taskIndex = interactiveTasks.firstIndex(where: { Double($0.startMinutes) < 720 && mouseMinute >= Double($0.startMinutes) && mouseMinute <= Double($0.normalizedEndMinutes) }) {
                    startDragging(taskIndex: taskIndex, mouseMinute: mouseMinute, location: location, size: size)
                    return
                }
            }
        }

        // If no task hit, create new
        if zoomedHour == nil && !usesTaskSections {
            createNewTask(at: mouseMinute, dist: dist, amRingRadius: amRingRadius, pmRingRadius: pmRingRadius, ringWidth: ringWidth)
        }
    }

    private func startDragging(taskIndex: Int, mouseMinute: Double, location: CGPoint, size: CGSize) {
        let task = interactiveTasks[taskIndex]
        let mode: DragInfo.Mode
        
        let startMin = zoomedHour != nil ? Double(task.startMinutes) : (is24HourClock ? Double(task.startMinutes) : (Double(task.startMinutes) >= 720 ? Double(task.startMinutes) - 720 : Double(task.startMinutes)))
        let endMin = zoomedHour != nil ? Double(task.normalizedEndMinutes) : (is24HourClock ? Double(task.normalizedEndMinutes) : (Double(task.normalizedEndMinutes) >= 720 ? Double(task.normalizedEndMinutes) - 720 : Double(task.normalizedEndMinutes)))
        let startDistance = minuteDistance(mouseMinute, startMin, period: dragMinutePeriod)
        let endDistance = minuteDistance(mouseMinute, endMin, period: dragMinutePeriod)

        if startDistance < 15 {
            mode = .resizeStart
        } else if endDistance < 15 {
            mode = .resizeEnd
        } else {
            mode = .move
        }

        activeDrag = DragInfo(
            taskId: task.id,
            mode: mode,
            initialMouseMinute: mouseMinute,
            lastMouseMinute: mouseMinute,
            accumulatedDelta: 0,
            initialStartMinutes: task.startMinutes,
            initialEndMinutes: task.endMinutes
        )
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func createNewTask(at mouseMinute: Double, dist: CGFloat, amRingRadius: CGFloat, pmRingRadius: CGFloat, ringWidth: CGFloat) {
        let isPM = usesTaskSections ? dist <= pmRingRadius + ringWidth : abs(dist - pmRingRadius) < ringWidth
        let isAM = abs(dist - amRingRadius) < ringWidth
        
        guard isPM || isAM else { return }
        
        let startMin = Int(mouseMinute)
        let absoluteStart = isPM ? (is24HourClock ? startMin : startMin + 720) : startMin
        
        let newTask = ClockTask(
            title: "New Task",
            startMinutes: absoluteStart,
            endMinutes: absoluteStart + 30,
            color: goldColor
        )
        
        interactiveTasks.append(newTask)
        activeDrag = DragInfo(
            taskId: newTask.id,
            mode: .create,
            initialMouseMinute: mouseMinute,
            lastMouseMinute: mouseMinute,
            accumulatedDelta: 0,
            initialStartMinutes: absoluteStart,
            initialEndMinutes: absoluteStart
        )
        
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func handleDragChange(location: CGPoint, size: CGSize) {
        guard var drag = activeDrag, let index = interactiveTasks.firstIndex(where: { $0.id == drag.taskId }) else { return }
        let minimumTaskDuration = 5
        let maximumTaskDuration = 1435
        
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let dist = sqrt(dx*dx + dy*dy)
        let deadzoneRadius = min(size.width, size.height) * (usesTaskSections ? 0.06 : 0.18)
        let deadzoneExitRadius = deadzoneRadius + (usesTaskSections ? 8 : 14)
        
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
        let limit = dragMinutePeriod
        if delta > limit / 2 { delta -= limit }
        else if delta < -limit / 2 { delta += limit }
        
        drag.accumulatedDelta += delta
        drag.lastMouseMinute = min12h
        activeDrag = drag // Update state
        
        let totalDelta = drag.accumulatedDelta
        // totalDelta is already in minutes for the active clock mode.
        
        var task = interactiveTasks[index].normalizedForClock
        let oldStart = task.startMinutes
        let oldEnd = task.endMinutes
        
        // Smoother Aim Assist: snap to nearest 15 mins if within 4 minutes
        func snap(_ val: Int) -> Int {
            if zoomedHour != nil {
                let remainder = ((val % 5) + 5) % 5
                if remainder < 2 { return val - remainder }
                if remainder > 3 { return val + (5 - remainder) }
                return val
            }
            let remainder = ((val % 15) + 15) % 15
            if remainder < 4 { return val - remainder }
            if remainder > 11 { return val + (15 - remainder) }
            return val
        }
        
        func clamp(_ value: Int, min lower: Int, max upper: Int) -> Int {
            min(max(value, lower), upper)
        }
        
        func normalizeDraggedRange(start rawStart: Int, end rawEnd: Int) -> (start: Int, end: Int) {
            var start = rawStart
            var end = max(rawEnd, rawStart + minimumTaskDuration)
            
            let limit = zoomedHour != nil ? 144000 : 1440 // Avoid wrapping too much in zoom mode for now
            
            if zoomedHour == nil {
                while start < 0 {
                    start += limit
                    end += limit
                }
                
                while start >= limit {
                    start -= limit
                    end -= limit
                }
            }
            
            let maxDuration = zoomedHour != nil ? 60 : maximumTaskDuration
            if end - start > maxDuration {
                end = start + maxDuration
            }
            
            return (start, end)
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

        case .resizeStart:
            let rawStart = drag.initialStartMinutes + Int(totalDelta)
            let snappedStart = snap(rawStart)
            let minStart = drag.initialEndMinutes - maximumTaskDuration
            let maxStart = drag.initialEndMinutes - minimumTaskDuration
            proposedStart = clamp(snappedStart, min: minStart, max: maxStart)
            
        case .resizeEnd, .create:
            let rawEnd = drag.initialEndMinutes + Int(totalDelta)
            let snappedEnd = snap(rawEnd)
            let minEnd = drag.initialStartMinutes + minimumTaskDuration
            let maxEnd = drag.initialStartMinutes + maximumTaskDuration
            proposedEnd = clamp(snappedEnd, min: minEnd, max: maxEnd)
        }
        
        let normalizedRange = normalizeDraggedRange(start: proposedStart, end: proposedEnd)
        proposedStart = normalizedRange.start
        proposedEnd = normalizedRange.end
        
        // Haptic feedback when snapping to a new boundary
        let startChangedToSnap = proposedStart != oldStart && proposedStart % 15 == 0
        let endChangedToSnap = proposedEnd != oldEnd && proposedEnd % 15 == 0
        
        if startChangedToSnap || endChangedToSnap {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
        
        task.startMinutes = proposedStart
        task.endMinutes = proposedEnd
        interactiveTasks[index] = task
        onTasksPreviewUpdated?(interactiveTasks.sorted { $0.startMinutes < $1.startMinutes })
    }

    private func minute(from location: CGPoint, in size: CGSize) -> Double {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let dx = location.x - center.x
        let dy = location.y - center.y
        var angle = atan2(dy, dx) * 180 / .pi
        angle += 90 // Shift 0 to 12 o'clock
        if angle < 0 { angle += 360 }
        
        if let zh = zoomedHour {
            return Double(zh * 60) + (angle / 360.0) * 60.0
        }
        return is24HourClock ? (angle / 360) * 1440 : (angle / 360) * 720
    }

    private func minuteDistance(_ lhs: Double, _ rhs: Double, period: Double) -> Double {
        let normalizedLHS = lhs.truncatingRemainder(dividingBy: period)
        let normalizedRHS = rhs.truncatingRemainder(dividingBy: period)
        let diff = abs(normalizedLHS - normalizedRHS)
        return min(diff, period - diff)
    }

    private func taskContains(_ task: ClockTask, minute: Double) -> Bool {
        let normalized = task.normalizedForClock
        let period = dragMinutePeriod
        let start = Double(normalized.startMinutes).truncatingRemainder(dividingBy: period)
        let end = Double(normalized.normalizedEndMinutes).truncatingRemainder(dividingBy: period)

        if normalized.normalizedEndMinutes - normalized.startMinutes >= Int(period) {
            return true
        }

        if Double(normalized.normalizedEndMinutes) <= period {
            return minute >= start && minute <= Double(normalized.normalizedEndMinutes)
        }

        return minute >= start || minute <= end
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
    var zoomedHour: Int? = nil
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
        if zoomedHour != nil {
            if isMinute {
                angleDeg = minute * 6 + second * 0.1 - 90
            } else {
                angleDeg = 0 - 90 // Hide hour hand or keep it static
            }
        } else if isMinute {
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
    var zoomedHour: Int? = nil

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        let comps = Calendar.current.dateComponents([.hour, .minute, .second], from: now)
        let hour = Double(comps.hour ?? 0)
        let minute = Double(comps.minute ?? 0)
        let second = Double(comps.second ?? 0)

        let angleDeg: Double
        if let zh = zoomedHour {
            let totalMinutes = hour * 60 + minute + second/60
            let mins = totalMinutes - Double(zh * 60)
            angleDeg = mins * 6.0 - 90
        } else if is24HourClock {
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

struct TaskSector: Shape {
    var startMinutes: Double
    var endMinutes: Double
    var is24HourClock: Bool = true
    var zoomedHour: Int? = nil
    var insetMinutes: Double = 0

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let safeInset = max(0, min(insetMinutes, max(0, endMinutes - startMinutes - 1) / 2))
        let adjustedStart = startMinutes + safeInset
        let adjustedEnd = max(adjustedStart + 1, endMinutes - safeInset)

        func angle(for minutes: Double) -> Angle {
            let deg: Double
            if zoomedHour != nil {
                deg = minutes * 6.0 - 90
            } else {
                deg = is24HourClock ? (minutes * 0.25 - 90) : (minutes * 0.5 - 90)
            }
            return .degrees(deg)
        }

        let start = angle(for: adjustedStart)
        let end = angle(for: adjustedEnd)

        p.move(to: center)
        p.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
        p.closeSubpath()
        return p
    }
}

struct TaskArc: Shape {
    var startMinutes: Double
    var endMinutes: Double
    var is24HourClock: Bool = false
    var zoomedHour: Int? = nil

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height)/2

        func angle(for minutes: Double) -> Angle {
            let deg: Double
            if zoomedHour != nil {
                deg = minutes * 6.0 - 90
            } else {
                deg = is24HourClock ? (minutes * 0.25 - 90) : (minutes * 0.5 - 90)
            }
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
    let id: String
    let isAM: Bool
    let startMinutes: Double
    let endMinutes: Double
    let task: ClockTask
}

func getFragments(for task: ClockTask) -> [TaskFragment] {
    var frags = [TaskFragment]()
    let s = task.startMinutes
    let e = task.endMinutes
    
    func appendFragment(isAM: Bool, startMinutes: Double, endMinutes: Double) {
        let fragmentID = "\(task.id.uuidString)-\(frags.count)"
        frags.append(
            TaskFragment(
                id: fragmentID,
                isAM: isAM,
                startMinutes: startMinutes,
                endMinutes: endMinutes,
                task: task
            )
        )
    }
    
    if s < 720 {
        if e <= 720 {
            appendFragment(isAM: true, startMinutes: Double(s), endMinutes: Double(e))
        } else {
            appendFragment(isAM: true, startMinutes: Double(s), endMinutes: 720.0)
            let eInPM = min(e, 1440)
            appendFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(eInPM) - 720.0)
            if e > 1440 {
                let wrappedE = min(e - 1440, 720)
                appendFragment(isAM: true, startMinutes: 0.0, endMinutes: Double(wrappedE))
                if e > 2160 {
                    appendFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(e - 2160))
                }
            }
        }
    } else {
        let sInPM = max(s, 720)
        let eInPM = min(e, 1440)
        appendFragment(isAM: false, startMinutes: Double(sInPM) - 720.0, endMinutes: Double(eInPM) - 720.0)
        if e > 1440 {
            let wrappedE = min(e - 1440, 720)
            appendFragment(isAM: true, startMinutes: 0.0, endMinutes: Double(wrappedE))
            if e > 2160 {
                appendFragment(isAM: false, startMinutes: 0.0, endMinutes: Double(e - 2160))
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
    var isTaskSection: Bool = false
    var zoomedHour: Int? = nil

    var body: some View {
        ZStack {
            if isTaskSection {
                TaskSector(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock, zoomedHour: zoomedHour, insetMinutes: 1.25)
                    .fill(color.opacity(0.56 * opacity))

                TaskSector(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock, zoomedHour: zoomedHour, insetMinutes: 1.25)
                    .stroke(Color.black.opacity(0.18 * opacity), lineWidth: 1)
            } else {
                // Subtle Bottom Shadow
                TaskArc(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock, zoomedHour: zoomedHour)
                    .stroke(Color.black.opacity(0.15 * opacity), style: StrokeStyle(lineWidth: ringWidth, lineCap: .round))
                    .offset(x: 0.5, y: 0.5)

                // Main Task Fill
                TaskArc(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock, zoomedHour: zoomedHour)
                    .stroke(
                        color.opacity(opacity),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )

                // Very subtle Top Highlight
                TaskArc(startMinutes: start, endMinutes: end, is24HourClock: is24HourClock, zoomedHour: zoomedHour)
                    .stroke(
                        LinearGradient(colors: [.white.opacity(0.2 * opacity), .clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: ringWidth, lineCap: .round)
                    )
                    .blendMode(.overlay)
            }
        }
        .compositingGroup()
        .shadow(color: isFuture ? glowColor : .clear, radius: glowRadius)
    }
}
