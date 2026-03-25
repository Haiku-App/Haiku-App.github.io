import SwiftUI

struct AddTaskView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @Environment(\.dismiss) var dismiss
    @Binding var tasksByDate: [Date: [ClockTask]]
    @Binding var selectedDate: Date
    
    var prefilledTitle: String?
    var brainDumpTaskId: UUID?
    var taskToEdit: ClockTask?
    
    @State private var taskDate: Date
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    @StateObject private var categoryManager = CategoryManager()
    @ObservedObject private var brainDumpManager = BrainDumpManager()
    @StateObject private var calendarManager = CalendarManager()
    @ObservedObject private var googleCalendarManager = GoogleCalendarManager.shared
    @State private var selectedCategoryId: UUID? = nil
    
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""
    
    @State private var selectedColorIndex: Int = Int.random(in: 0..<aestheticColors.count)
    
    init(tasksByDate: Binding<[Date: [ClockTask]]>, selectedDate: Binding<Date>, prefilledTitle: String? = nil, brainDumpTaskId: UUID? = nil, taskToEdit: ClockTask? = nil) {
        self._tasksByDate = tasksByDate
        self._selectedDate = selectedDate
        self.prefilledTitle = prefilledTitle
        self.brainDumpTaskId = brainDumpTaskId
        self.taskToEdit = taskToEdit
        
        let initialDate = taskToEdit != nil ? selectedDate.wrappedValue : selectedDate.wrappedValue
        self._taskDate = State(initialValue: initialDate)
        
        if let toEdit = taskToEdit {
            self._title = State(initialValue: toEdit.title)
            
            let cal = Calendar.current
            var sComps = cal.dateComponents([.year, .month, .day], from: initialDate)
            sComps.hour = toEdit.startMinutes / 60
            sComps.minute = toEdit.startMinutes % 60
            self._startTime = State(initialValue: cal.date(from: sComps) ?? Date())
            
            var eComps = cal.dateComponents([.year, .month, .day], from: initialDate)
            eComps.hour = toEdit.endMinutes / 60
            eComps.minute = toEdit.endMinutes % 60
            self._endTime = State(initialValue: cal.date(from: eComps) ?? Date())
        } else {
            self._title = State(initialValue: prefilledTitle ?? "")
        }
    }
    
    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
                        // Categories
                        VStack(alignment: .leading, spacing: 12) {
                            Text("CATEGORIES")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(categoryManager.categories) { cat in
                                        Button(action: {
                                            selectedCategoryId = cat.id
                                        }) {
                                            VStack(spacing: 12) {
                                                Image(systemName: cat.icon)
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(cat.color)
                                                Text(cat.name)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                                            }
                                            .frame(width: 100, height: 100)
                                            .background(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .fill(fieldBgColor)
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 16)
                                                            .stroke(selectedCategoryId == cat.id ? cat.color : Color.clear, lineWidth: 2)
                                                    )
                                                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive, action: {
                                                if let index = categoryManager.categories.firstIndex(where: { $0.id == cat.id }) {
                                                    categoryManager.categories.remove(at: index)
                                                    if selectedCategoryId == cat.id {
                                                        selectedCategoryId = nil
                                                    }
                                                }
                                            }) {
                                                Label("Delete Category", systemImage: "trash")
                                            }
                                        }
                                    }
                                    
                                    // Add new category button
                                    Button(action: {
                                        showingNewCategory = true
                                    }) {
                                        VStack(spacing: 12) {
                                            Image(systemName: "plus")
                                                .font(.system(size: 24))
                                                .foregroundStyle(goldColor)
                                            Text("New")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                                        }
                                        .frame(width: 100, height: 100)
                                        .background(
                                            RoundedRectangle(cornerRadius: 16)
                                                .fill(fieldBgColor)
                                                .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                                .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }
                        
                        // Color Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("TASK COLOR")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                                .padding(.horizontal, 4)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    ForEach(0..<aestheticColors.count, id: \.self) { index in
                                        Button(action: {
                                            selectedColorIndex = index
                                        }) {
                                            Circle()
                                                .fill(aestheticColors[index].color)
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Circle()
                                                        .stroke(selectedColorIndex == index ? currentTheme.textForeground : Color.clear, lineWidth: 3)
                                                )
                                                .shadow(color: shadowDark, radius: 3, x: 2, y: 2)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                            }
                        }

                        // Title Input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TASK NAME")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            TextField("Enter title...", text: $title)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(currentTheme.textForeground)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(fieldBgColor)
                                        .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }
                        
                        // Date Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("DATE")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            DatePicker("Date", selection: $taskDate, displayedComponents: .date)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(fieldBgColor)
                                        .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                        .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                                )
                        }

                        // Time Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SCHEDULE")
                                .font(.system(size: 12, weight: .regular, design: .serif))
                                .foregroundStyle(goldColor)
                                .tracking(1)
                            
                            VStack(spacing: 0) {
                                DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                
                                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .padding()
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(fieldBgColor)
                                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                            )
                        }
                    }
                    .padding(32)
                }

                // Fixed Bottom Action Bar
                VStack(spacing: 0) {
                    Divider()
                        .background(goldColor.opacity(0.2))
                    
                    VStack(spacing: 8) {
                        if selectedCategoryId == nil {
                            Text("Please select a category")
                                .font(.system(size: 12, weight: .medium, design: .serif))
                                .foregroundStyle(goldColor.opacity(0.8))
                                .transition(.opacity)
                        }
                        
                        Button(action: saveTask) {
                            Text(taskToEdit == nil ? "Schedule Task" : "Update Task")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(selectedCategoryId == nil ? goldColor.opacity(0.3) : bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(selectedCategoryId == nil ? goldColor.opacity(0.1) : goldColor)
                                        .shadow(color: .black.opacity(selectedCategoryId == nil ? 0 : 0.2), radius: 10, x: 0, y: 5)
                                )
                        }
                        .disabled(selectedCategoryId == nil)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(
                        bgColor.opacity(0.9)
                            .background(.ultraThinMaterial)
                    )
                }
            }
            }
            .navigationTitle(taskToEdit == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(goldColor)
                }
            }
            .onAppear {
                if taskToEdit == nil {
                    pickDistinctColor()
                }
            }
            .sheet(isPresented: $showingNewCategory) {
                NewCategoryView(categoryManager: categoryManager, selectedCategoryId: $selectedCategoryId, theme: currentTheme)
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func pickDistinctColor() {
        // Get all currently used colors in the day
        let day = Calendar.current.startOfDay(for: taskDate)
        let dayTasks = tasksByDate[day, default: []]
        let usedColors = Set(dayTasks.map { $0.color })
        
        // Find indices of colors not yet used
        let availableIndices = aestheticColors.indices.filter { idx in
            !usedColors.contains(aestheticColors[idx].color)
        }
        
        if !availableIndices.isEmpty {
            selectedColorIndex = availableIndices.randomElement() ?? 0
        } else {
            selectedColorIndex = Int.random(in: 0..<aestheticColors.count)
        }
    }
    
    private func saveTask() {
        let cal = Calendar.current
        let sComps = cal.dateComponents([.hour, .minute], from: startTime)
        let eComps = cal.dateComponents([.hour, .minute], from: endTime)
        let sMin = (sComps.hour ?? 0) * 60 + (sComps.minute ?? 0)
        let eMin = (eComps.hour ?? 0) * 60 + (eComps.minute ?? 0)
        
        let colorToUse = aestheticColors[selectedColorIndex].color
        let cat = categoryManager.categories.first(where: { $0.id == selectedCategoryId })
        let categoryId = cat?.id
        let categoryName = cat?.name
        
        let day = cal.startOfDay(for: taskDate)
        
        let isPro = true // Hardcoded for testing
        
        if let toEdit = taskToEdit {
            // Remove old version if date changed
            if cal.startOfDay(for: selectedDate) != day {
                tasksByDate[selectedDate]?.removeAll { $0.id == toEdit.id }
            }
            
            var updatedTask = toEdit
            updatedTask.title = title.isEmpty ? "Updated Task" : title
            updatedTask.startMinutes = sMin
            updatedTask.endMinutes = eMin
            updatedTask.color = colorToUse
            updatedTask.categoryId = categoryId
            updatedTask.categoryName = categoryName
            
            // Sync update to Apple Calendar or Google Calendar if Pro
            if isPro {
                if let extId = updatedTask.externalEventId {
                    if extId.hasPrefix("google_") {
                        GoogleCalendarManager.shared.updateTask(updatedTask, date: day)
                    } else {
                        calendarManager.updateTask(updatedTask, date: day)
                    }
                } else if let extId = calendarManager.saveTask(updatedTask, date: day) {
                    updatedTask.externalEventId = extId
                }
            }
            
            var dayTasks = tasksByDate[day, default: []]
            if let idx = dayTasks.firstIndex(where: { $0.id == toEdit.id }) {
                dayTasks[idx] = updatedTask
            } else {
                dayTasks.append(updatedTask)
            }
            dayTasks.sort { $0.startMinutes < $1.startMinutes }
            tasksByDate[day] = dayTasks

            // PostHog: Track task update
            AnalyticsManager.shared.capture("task_updated", properties: [
                "duration_minutes": updatedTask.endMinutes - updatedTask.startMinutes,
                "category": categoryName ?? "None"
            ])

        } else {
            var newTask = ClockTask(
                title: title.isEmpty ? "New Task" : title,
                startMinutes: sMin,
                endMinutes: eMin,
                color: colorToUse,
                categoryId: categoryId,
                categoryName: categoryName
            )
            
            // Push to external calendars if Pro
            if isPro {
                if googleCalendarManager.isSignedIn {
                    googleCalendarManager.saveTask(newTask, date: day) { extId in
                        if let extId = extId {
                            DispatchQueue.main.async {
                                if let idx = tasksByDate[day]?.firstIndex(where: { $0.id == newTask.id }) {
                                    tasksByDate[day]?[idx].externalEventId = extId
                                }
                            }
                        }
                    }
                } else {
                    if let extId = calendarManager.saveTask(newTask, date: day) {
                        newTask.externalEventId = extId
                    }
                }
            }
            
            var dayTasks = tasksByDate[day, default: []]
            dayTasks.append(newTask)
            dayTasks.sort { $0.startMinutes < $1.startMinutes }
            tasksByDate[day] = dayTasks

            // PostHog: Track task creation
            AnalyticsManager.shared.capture("task_created", properties: [
                "duration_minutes": newTask.endMinutes - newTask.startMinutes,
                "from_brain_dump": brainDumpTaskId != nil,
            ])

            // Update BrainDumpTask if needed
            if let bdtid = brainDumpTaskId {
                if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == bdtid }) {
                    brainDumpManager.tasks[index].scheduledDate = day
                    brainDumpManager.sortTasks()
                }
            }
        }
        
        // Update selected date so user sees the new task
        withAnimation {
            selectedDate = day
        }
        
        dismiss()
    }
}

struct TaskRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var time: String
    var title: String
    var color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                let parts = time.components(separatedBy: " - ")
                if parts.count == 2 {
                    Text(parts[0])
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                    Text(parts[1])
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.5))
                } else {
                    Text(time)
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                }
            }
            .frame(width: 70, alignment: .leading)
            
            // Vertical separator
            Rectangle()
                .fill(currentTheme.textForeground.opacity(0.3))
                .frame(width: 1)
                .frame(minHeight: 30)
            
            // Colored Leaf icon
            Image(systemName: "leaf.fill")
                .font(.system(size: 14))
                .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(currentTheme.textForeground.opacity(0.9))
            
            Spacer()
        }
    }
}

