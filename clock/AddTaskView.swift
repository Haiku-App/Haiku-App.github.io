import SwiftUI
import UniformTypeIdentifiers

struct AddTaskView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage(CalendarSyncProvider.storageKey) private var activeCalendarSyncProvider: CalendarSyncProvider = .none
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @Binding var tasksByDate: [Date: [ClockTask]]
    @Binding var selectedDate: Date
    
    var prefilledTitle: String?
    var brainDumpTaskId: UUID?
    var taskToEdit: ClockTask?
    
    @State private var taskDate: Date
    @State private var title = ""
    @State private var startTime = Date()
    @State private var endTime = Date().addingTimeInterval(3600)
    
    @StateObject private var categoryManager = CategoryManager.shared
    @ObservedObject private var brainDumpManager = BrainDumpManager.shared
    @StateObject private var calendarManager = CalendarManager()
    @ObservedObject private var googleCalendarManager = GoogleCalendarManager.shared
    @State private var selectedCategoryId: UUID? = nil
    
    @State private var showingNewCategory = false
    @State private var newCategoryName = ""
    @State private var draggedCategory: Category?
    @State private var repeatFrequency: RepeatFrequency = .never
    @State private var showingOptions: Bool
    
    @State private var selectedColorIndex: Int

    private static let lastTaskCategoryIdKey = "lastTaskCategoryId"
    private static let lastTaskColorIndexKey = "lastTaskColorIndex"
    
    init(tasksByDate: Binding<[Date: [ClockTask]]>, selectedDate: Binding<Date>, prefilledTitle: String? = nil, brainDumpTaskId: UUID? = nil, taskToEdit: ClockTask? = nil) {
        self._tasksByDate = tasksByDate
        self._selectedDate = selectedDate
        self.prefilledTitle = prefilledTitle
        self.brainDumpTaskId = brainDumpTaskId
        self.taskToEdit = taskToEdit
        
        let initialDate = selectedDate.wrappedValue
        self._taskDate = State(initialValue: initialDate)
        
        if let toEdit = taskToEdit {
            self._title = State(initialValue: toEdit.title)
            self._selectedCategoryId = State(initialValue: toEdit.categoryId)
            self._repeatFrequency = State(initialValue: toEdit.repeatFrequency)
            
            let cal = Calendar.current
            let dayStart = cal.startOfDay(for: initialDate)
            self._startTime = State(initialValue: cal.date(byAdding: .minute, value: toEdit.startMinutes, to: dayStart) ?? Date())
            self._endTime = State(initialValue: cal.date(byAdding: .minute, value: toEdit.normalizedEndMinutes, to: dayStart) ?? Date())
            self._selectedColorIndex = State(initialValue: aestheticColors.firstIndex(where: { $0.color == toEdit.color }) ?? 0)
            self._showingOptions = State(initialValue: true)
        } else {
            let defaultStart = Self.defaultStartTime(for: initialDate)
            let defaultEnd = Calendar.current.date(byAdding: .hour, value: 1, to: defaultStart) ?? defaultStart
            let initialCategoryId = Self.initialCategoryId()

            self._title = State(initialValue: prefilledTitle ?? "")
            self._selectedCategoryId = State(initialValue: initialCategoryId)
            self._startTime = State(initialValue: defaultStart)
            self._endTime = State(initialValue: defaultEnd)
            self._selectedColorIndex = State(initialValue: Self.initialColorIndex(for: initialCategoryId))
            self._showingOptions = State(initialValue: false)
        }
    }
    
    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }
    private var selectedCategory: Category? {
        categoryManager.categories.first { $0.id == selectedCategoryId }
    }

    private var optionsSummary: String {
        let repeatText = repeatFrequency == .never ? nil : repeatFrequency.rawValue
        let categoryText = selectedCategory?.name ?? "No category"
        return [repeatText, categoryText].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()
                
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 32) {
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
                                .colorMultiply(currentTheme == .sakura ? currentTheme.textForeground : .white)
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
                                    .colorMultiply(currentTheme == .sakura ? currentTheme.textForeground : .white)
                                    .padding()
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.9))
                                
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal)
                                
                                DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                                    .colorMultiply(currentTheme == .sakura ? currentTheme.textForeground : .white)
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

                        optionalDetailsSection

                    }
                    .padding(32)
                }

                // Fixed Bottom Action Bar
                VStack(spacing: 0) {
                    Divider()
                        .background(goldColor.opacity(0.2))
                    
                    VStack(spacing: 8) {
                        Button(action: saveTask) {
                            Text(taskToEdit == nil ? "Schedule Task" : "Update Task")
                                .font(.system(size: 16, weight: .bold, design: .serif))
                                .foregroundStyle(currentTheme == .sakura ? currentTheme.textForeground : bgColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(goldColor)
                                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                                )
                        }
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
            .toolbarColorScheme(currentTheme == .sakura ? .light : .dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(goldColor)
                }
            }
            .onChange(of: selectedCategoryId) { _, newCategoryId in
                guard let newCategoryId,
                      let category = categoryManager.categories.first(where: { $0.id == newCategoryId }) else { return }
                selectedColorIndex = Self.closestColorIndex(to: category.rgb)
            }
            .sheet(isPresented: $showingNewCategory) {
                NewCategoryView(categoryManager: categoryManager, selectedCategoryId: $selectedCategoryId, theme: currentTheme)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var optionalDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    showingOptions.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("OPTIONS")
                            .font(.system(size: 12, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(1)

                        Text(optionsSummary)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.65))
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(goldColor)
                        .rotationEffect(.degrees(showingOptions ? 180 : 0))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(fieldBgColor)
                        .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                        .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
                )
            }
            .buttonStyle(.plain)

            if showingOptions {
                VStack(spacing: 28) {
                    repeatSection
                    categorySection
                    colorSection
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var repeatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REPEAT")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(1)

            RepeatFrequencyPicker(
                selection: $repeatFrequency,
                theme: currentTheme
            )
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(fieldBgColor)
                    .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
                    .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
            )
        }
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CATEGORY")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(1)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                ScrollViewReader { proxy in
                    HStack(spacing: 16) {
                        Button(action: {
                            selectedCategoryId = nil
                        }) {
                            VStack(spacing: 12) {
                                Image(systemName: "circle.slash")
                                    .font(.system(size: 24))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.55))
                                Text("None")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                            }
                            .frame(width: 100, height: 100)
                            .background(categoryTileBackground(isSelected: selectedCategoryId == nil, strokeColor: goldColor))
                        }
                        .buttonStyle(.plain)

                        ForEach(categoryManager.categories) { cat in
                            Button(action: {
                                selectedCategoryId = cat.id
                                selectedColorIndex = Self.closestColorIndex(to: cat.rgb)
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
                                .background(categoryTileBackground(isSelected: selectedCategoryId == cat.id, strokeColor: cat.color))
                            }
                            .id(cat.id)
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    if let index = categoryManager.categories.firstIndex(where: { $0.id == cat.id }) {
                                        AnalyticsManager.shared.capture("category_deleted", properties: ["name": cat.name])
                                        categoryManager.categories.remove(at: index)
                                        if selectedCategoryId == cat.id {
                                            selectedCategoryId = nil
                                        }
                                    }
                                }) {
                                    Label("Delete Category", systemImage: "trash")
                                }
                            }
                            .onDrag {
                                self.draggedCategory = cat
                                return NSItemProvider(object: cat.id.uuidString as NSString)
                            }
                            .onDrop(of: [.text], delegate: CategoryDropDelegate(item: cat, items: $categoryManager.categories, draggedItem: $draggedCategory, proxy: proxy))
                        }

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
        }
    }

    private var colorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COLOR")
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(1)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0..<aestheticColors.count, id: \.self) { index in
                        Button(action: {
                            selectedColorIndex = index
                            AnalyticsManager.shared.capture("manual_color_selected", properties: ["color_index": index])
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
    }

    private func categoryTileBackground(isSelected: Bool, strokeColor: Color) -> some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(fieldBgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? strokeColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: shadowDark, radius: 5, x: 4, y: 4)
            .shadow(color: shadowLight, radius: 5, x: -4, y: -4)
    }

    private static func defaultStartTime(for selectedDate: Date) -> Date {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        let nowComponents = calendar.dateComponents([.hour, .minute], from: Date())
        let currentMinutes = (nowComponents.hour ?? 0) * 60 + (nowComponents.minute ?? 0)
        let roundedMinutes = min(((currentMinutes + 14) / 15) * 15, (24 * 60) - 15)
        return calendar.date(byAdding: .minute, value: roundedMinutes, to: dayStart) ?? selectedDate
    }

    private static func initialCategoryId() -> UUID? {
        let categories = AppSupportPersistence.loadCategories()
        let defaults = UserDefaults.standard

        if let storedValue = defaults.string(forKey: lastTaskCategoryIdKey) {
            guard !storedValue.isEmpty else { return nil }
            if let savedId = UUID(uuidString: storedValue),
               categories.contains(where: { $0.id == savedId }) {
                return savedId
            }
        }

        return categories.first {
            $0.name.caseInsensitiveCompare("Personal") == .orderedSame
        }?.id
    }

    private static func initialColorIndex(for categoryId: UUID?) -> Int {
        let categories = AppSupportPersistence.loadCategories()

        if let categoryId,
           let category = categories.first(where: { $0.id == categoryId }) {
            return closestColorIndex(to: category.rgb)
        }

        let savedIndex = UserDefaults.standard.integer(forKey: lastTaskColorIndexKey)
        if aestheticColors.indices.contains(savedIndex) {
            return savedIndex
        }

        return Int.random(in: 0..<aestheticColors.count)
    }

    private static func closestColorIndex(to rgb: RGB) -> Int {
        aestheticColors.indices.min { lhs, rhs in
            colorDistance(aestheticColors[lhs], rgb) < colorDistance(aestheticColors[rhs], rgb)
        } ?? 0
    }

    private static func colorDistance(_ lhs: RGB, _ rhs: RGB) -> Double {
        pow(lhs.r - rhs.r, 2) + pow(lhs.g - rhs.g, 2) + pow(lhs.b - rhs.b, 2)
    }

    private func persistTaskDefaults(categoryId: UUID?, colorIndex: Int) {
        let defaults = UserDefaults.standard
        defaults.set(categoryId?.uuidString ?? "", forKey: Self.lastTaskCategoryIdKey)
        defaults.set(colorIndex, forKey: Self.lastTaskColorIndexKey)
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
        let normalizedEndMinutes: Int = {
            if eMin < sMin { return eMin + 1440 }
            if eMin == sMin { return sMin + 60 }
            return eMin
        }()
        
        let colorToUse = aestheticColors[selectedColorIndex].color
        let cat = categoryManager.categories.first(where: { $0.id == selectedCategoryId })
        let categoryId = cat?.id
        let categoryName = cat?.name
        persistTaskDefaults(categoryId: categoryId, colorIndex: selectedColorIndex)
        
        let day = cal.startOfDay(for: taskDate)
        
        let isPro = storeManager.isPro
        
        if let toEdit = taskToEdit {
            // Update single task or all future? Let's just update this one for now to keep it simple,
            // but update the repeat frequency for future reference.
            
            // Remove old version if date changed
            if cal.startOfDay(for: selectedDate) != day {
                tasksByDate[selectedDate]?.removeAll { $0.id == toEdit.id }
            }
            
            var updatedTask = toEdit
            updatedTask.title = title.isEmpty ? "Updated Task" : title
            updatedTask.startMinutes = sMin
            updatedTask.endMinutes = normalizedEndMinutes
            updatedTask.color = colorToUse
            updatedTask.categoryId = categoryId
            updatedTask.categoryName = categoryName
            updatedTask.repeatFrequency = repeatFrequency
            
            // Sync update to Apple Calendar or Google Calendar if Pro
            if isPro {
                switch updatedTask.calendarSyncProvider {
                case .google:
                    GoogleCalendarManager.shared.updateTask(updatedTask, date: day)
                case .apple:
                    calendarManager.updateTask(updatedTask, date: day)
                case .none:
                    if let extId = connectTaskToActiveCalendar(updatedTask, on: day) {
                        updatedTask.externalEventId = extId
                    }
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
                "duration_minutes": updatedTask.normalizedEndMinutes - updatedTask.startMinutes,
                "category": categoryName ?? "None",
                "repeat": repeatFrequency.rawValue
            ])

        } else {
            // Create the first instance
            let firstTask = ClockTask(
                title: title.isEmpty ? "New Task" : title,
                startMinutes: sMin,
                endMinutes: normalizedEndMinutes,
                color: colorToUse,
                categoryId: categoryId,
                categoryName: categoryName,
                repeatFrequency: repeatFrequency
            )
            
            saveTaskInstance(firstTask, on: day)
            
            // Handle repetition
            if repeatFrequency != .never {
                let limit: Int
                let component: Calendar.Component
                
                switch repeatFrequency {
                case .daily:
                    limit = 30
                    component = .day
                case .weekly:
                    limit = 12
                    component = .weekOfYear
                case .monthly:
                    limit = 6
                    component = .month
                case .never:
                    limit = 0
                    component = .day
                }
                
                for i in 1...limit {
                    if let futureDate = cal.date(byAdding: component, value: i, to: day) {
                        let taskInstance = ClockTask(
                            id: UUID(), // Each instance gets a new ID to be safe in the local store
                            title: firstTask.title,
                            startMinutes: firstTask.startMinutes,
                            endMinutes: firstTask.endMinutes,
                            color: firstTask.color,
                            categoryId: firstTask.categoryId,
                            categoryName: firstTask.categoryName,
                            repeatFrequency: firstTask.repeatFrequency
                        )
                        saveTaskInstance(taskInstance, on: futureDate)
                    }
                }
            }

            // PostHog: Track task creation
            AnalyticsManager.shared.capture("task_created", properties: [
                "duration_minutes": firstTask.normalizedEndMinutes - firstTask.startMinutes,
                "from_brain_dump": brainDumpTaskId != nil,
                "repeat": repeatFrequency.rawValue
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

    private func saveTaskInstance(_ task: ClockTask, on day: Date) {
        var mutableTask = task
        let isPro = storeManager.isPro
        
        // Push to external calendars if Pro
        if isPro {
            switch activeCalendarSyncProvider {
            case .google:
                googleCalendarManager.saveTask(mutableTask, date: day) { extId in
                    if let extId = extId {
                        DispatchQueue.main.async {
                            if let idx = tasksByDate[day]?.firstIndex(where: { $0.id == mutableTask.id }) {
                                tasksByDate[day]?[idx].externalEventId = extId
                            }
                        }
                    }
                }
            case .apple:
                if let extId = calendarManager.saveTask(mutableTask, date: day) {
                    mutableTask.externalEventId = extId
                }
            case .none:
                break
            }
        }
        
        var dayTasks = tasksByDate[day, default: []]
        dayTasks.append(mutableTask)
        dayTasks.sort { $0.startMinutes < $1.startMinutes }
        tasksByDate[day] = dayTasks
    }

    private func connectTaskToActiveCalendar(_ task: ClockTask, on day: Date) -> String? {
        switch activeCalendarSyncProvider {
        case .none:
            return nil
        case .apple:
            return calendarManager.saveTask(task, date: day)
        case .google:
            googleCalendarManager.saveTask(task, date: day) { extId in
                guard let extId else { return }

                DispatchQueue.main.async {
                    if let idx = tasksByDate[day]?.firstIndex(where: { $0.id == task.id }) {
                        tasksByDate[day]?[idx].externalEventId = extId
                    }
                }
            }
            return nil
        }
    }
}

private struct RepeatFrequencyPicker: View {
    @Binding var selection: RepeatFrequency
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(RepeatFrequency.allCases) { frequency in
                Button(action: { selection = frequency }) {
                    Text(frequency.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(selection == frequency ? theme.bg : theme.textForeground.opacity(0.72))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            Capsule()
                                .fill(selection == frequency ? theme.accent : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            Capsule()
                .fill(theme.textForeground.opacity(0.08))
        )
    }
}

struct TaskRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var time: String
    var title: String
    var color: Color
    var icon: String = "leaf.fill"
    var isRepeating: Bool = false
    
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
            
            // Icon
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                
                if isRepeating {
                    Image(systemName: "repeat")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(color.opacity(0.8))
                }
            }
            .foregroundStyle(color)
            
            Text(title)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(currentTheme.textForeground.opacity(0.9))
            
            Spacer()
        }
    }
}

struct CategoryDropDelegate: DropDelegate {
    let item: Category
    var items: Binding<[Category]>
    @Binding var draggedItem: Category?
    let proxy: ScrollViewProxy
    
    func performDrop(info: DropInfo) -> Bool {
        self.draggedItem = nil
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = self.draggedItem,
              let from = items.wrappedValue.firstIndex(where: { $0.id == draggedItem.id }),
              let to = items.wrappedValue.firstIndex(where: { $0.id == item.id }),
              from != to else { return }
        
        withAnimation {
            items.wrappedValue.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
        }
        
        // Auto-scroll to the new position
        withAnimation {
            proxy.scrollTo(item.id, anchor: .center)
        }
    }
}
