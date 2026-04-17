import SwiftUI

struct TodoView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage(ReminderManager.syncEnabledKey) private var isAppleRemindersSyncEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var brainDumpManager = BrainDumpManager.shared
    @ObservedObject private var reminderManager = ReminderManager.shared
    @State private var newTaskTitle: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingBulkImport = false
    
    enum Filter: String, CaseIterable {
        case active = "Inbox"
        case completed = "Done"
    }
    @State private var selectedFilter: Filter = .active

    @State private var showingClearAlert = false
    
    // Selection for scheduling
    @State private var isSelectionMode = false
    @State private var selectedTaskIds = Set<UUID>()
    
    var onSchedule: (String, UUID) -> Void
    
    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }
    private var isAppleReminderSyncActive: Bool {
        storeManager.isPro && isAppleRemindersSyncEnabled && ReminderManager.hasReminderAccess()
    }

    var filteredTasks: [BrainDumpTask] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        switch selectedFilter {
        case .active:
            return brainDumpManager.tasks.filter { task in
                if task.isCompleted {
                    guard let completedDate = task.completedDate else { return false }
                    return cal.isDateInToday(completedDate)
                } else {
                    // Hide tasks scheduled for the future
                    if let date = task.scheduledDate ?? task.reminderDueDate {
                        return cal.startOfDay(for: date) <= today
                    }
                    return true
                }
            }
        case .completed:
            return brainDumpManager.tasks.filter { task in
                guard task.isCompleted, let completedDate = task.completedDate else { return false }
                return !cal.isDateInToday(completedDate)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("BRAIN DUMP")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                // Main Filter Picker (Inbox / Done)
                HStack(spacing: 0) {
                    ForEach(Filter.allCases, id: \.self) { filter in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(filter.rawValue.uppercased())
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundStyle(selectedFilter == filter ? goldColor : (currentTheme.textForeground.opacity(0.4) as Color))
                                    .tracking(1)
                                
                                Rectangle()
                                    .fill(selectedFilter == filter ? goldColor : (SwiftUI.Color.clear.opacity(0.001) as Color))
                                    .frame(height: 2)
                                    .frame(width: 40)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 12)

                if selectedFilter == .completed {
                    HStack {
                        Text("Completed before today")
                            .font(.system(size: 10, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.45))
                            .tracking(1)

                        Spacer()

                        if !filteredTasks.isEmpty {
                            Button(action: { showingClearAlert = true }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10))
                                    Text("CLEAR")
                                        .font(.system(size: 10, weight: .bold, design: .serif))
                                }
                                .foregroundStyle(Color.red.opacity(0.7))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if !isSelectionMode && selectedFilter == .active {
                    // Quick Add Input
                    HStack(spacing: 12) {
                        TextField("Quick task...", text: $newTaskTitle)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(currentTheme.textForeground)
                            .tint(goldColor)
                            .focused($isFocused)
                            .submitLabel(.done)
                            .onSubmit {
                                addTask()
                            }
                        
                        Button(action: { showingBulkImport = true }) {
                            Image(systemName: "text.badge.plus")
                                .font(.system(size: 22))
                                .foregroundStyle(goldColor)
                        }

                        Button(action: addTask) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(newTaskTitle.isEmpty ? (currentTheme.textForeground.opacity(0.3) as Color) : goldColor)
                        }
                        .disabled(newTaskTitle.isEmpty)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentTheme.fieldBg)
                    )
                    .padding(.horizontal, 40)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: selectedFilter == .active ? "brain.head.profile" : "checkmark.seal")
                            .font(.system(size: 32))
                            .foregroundStyle(goldColor.opacity(0.5) as Color)
                        Text(selectedFilter == .active ? "Clear your mind" : "No completed tasks yet")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.5) as Color)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredTasks) { task in
                            BrainDumpRow(
                                title: task.title,
                                isCompleted: task.isCompleted,
                                scheduledDate: task.scheduledDate,
                                completedDate: task.completedDate,
                                reminderDueDate: task.reminderDueDate,
                                isSelected: selectedTaskIds.contains(task.id),
                                isSelectionMode: isSelectionMode,
                                repeatFrequency: task.repeatFrequency,
                                onToggle: {
                                    if isSelectionMode {
                                        if selectedTaskIds.contains(task.id) {
                                            selectedTaskIds.remove(task.id)
                                        } else {
                                            selectedTaskIds.insert(task.id)
                                        }
                                    } else {
                                        if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                            let wasCompleted = brainDumpManager.tasks[index].isCompleted
                                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                                brainDumpManager.tasks[index].isCompleted.toggle()
                                                if brainDumpManager.tasks[index].isCompleted {
                                                    brainDumpManager.tasks[index].completedDate = Date()
                                                    
                                                    // Handle repetition
                                                    let originalTask = brainDumpManager.tasks[index]
                                                    let freq = originalTask.repeatFrequency
                                                    if freq != .never {
                                                        let cal = Calendar.current
                                                        let component: Calendar.Component = {
                                                            switch freq {
                                                            case .daily: return .day
                                                            case .weekly: return .weekOfYear
                                                            case .monthly: return .month
                                                            case .never: return .day
                                                            }
                                                        }()
                                                        
                                                        // Always base the NEXT task on TODAY to ensure it stays hidden until the future
                                                        let today = cal.startOfDay(for: Date())
                                                        if let nextDate = cal.date(byAdding: component, value: 1, to: today) {
                                                            var newTask = BrainDumpTask(title: originalTask.title)
                                                            newTask.repeatFrequency = freq
                                                            
                                                            // Always schedule repeating tasks so they can be filtered out until they are due
                                                            newTask.scheduledDate = nextDate
                                                            
                                                            // Avoid duplicates for the same day
                                                            let exists = brainDumpManager.tasks.contains { t in
                                                                !t.isCompleted && 
                                                                t.title == newTask.title && 
                                                                t.scheduledDate == newTask.scheduledDate &&
                                                                t.repeatFrequency == newTask.repeatFrequency
                                                            }
                                                            
                                                            if !exists {
                                                                brainDumpManager.tasks.append(newTask)
                                                                brainDumpManager.sortTasks()
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    brainDumpManager.tasks[index].completedDate = nil
                                                }
                                            }
                                            
                                            let nowCompleted = brainDumpManager.tasks[index].isCompleted
                                            
                                            if !wasCompleted && nowCompleted {
                                                AnalyticsManager.shared.capture("brain_dump_task_completed")
                                                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                                                SoundManager.shared.playBing()
                                            } else if wasCompleted && !nowCompleted {
                                                AnalyticsManager.shared.capture("brain_dump_task_reactivated")
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }

                                            syncTaskToAppleRemindersIfNeeded(brainDumpManager.tasks[index])
                                        }
                                    }
                                },
                                onSetRepeat: { freq in
                                    if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                        brainDumpManager.tasks[index].repeatFrequency = freq
                                        AnalyticsManager.shared.capture("brain_dump_task_repeat_set", properties: ["frequency": freq.rawValue])
                                    }
                                }
                            )
                            .listRowBackground(SwiftUI.Color.clear.opacity(0.001) as Color)
                            .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                        let externalReminderId = brainDumpManager.tasks[index].externalReminderId
                                        AnalyticsManager.shared.capture("brain_dump_task_deleted")
                                        withAnimation(.easeInOut) {
                                            _ = brainDumpManager.tasks.remove(at: index)
                                        }
                                        if isAppleReminderSyncActive, let externalReminderId {
                                            reminderManager.deleteTask(externalId: externalReminderId)
                                        }
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                        .onMove(perform: moveTask)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }

            // Bottom Action Bar
            ZStack(alignment: .bottomTrailing) {
                if isSelectionMode && !selectedTaskIds.isEmpty {
                    Button(action: {
                        if let firstId = selectedTaskIds.first,
                           let task = brainDumpManager.tasks.first(where: { $0.id == firstId }) {
                            AnalyticsManager.shared.capture("brain_dump_task_scheduled")
                            onSchedule(task.title, task.id)
                            withAnimation {
                                isSelectionMode = false
                                selectedTaskIds.removeAll()
                            }
                        }
                    }) {
                        Text("Schedule Selected")
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.bg)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 35)
                                    .fill(goldColor)
                                    .shadow(color: Color.black.opacity(0.3) as Color, radius: 10, x: 0, y: 5)
                            )
                    }
                    .padding(.trailing, 86) // Avoid overlapping the FAB
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                // Floating Action Button (Toggle)
                Button(action: { 
                    if !isSelectionMode && brainDumpManager.tasks.isEmpty { return }
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                        isSelectionMode.toggle()
                        if !isSelectionMode {
                            selectedTaskIds.removeAll()
                        }
                    }
                    AnalyticsManager.shared.capture("brain_dump_selection_mode_toggled", properties: ["is_active": isSelectionMode])
                }) {
                    ZStack {
                        Circle()
                            .fill(goldColor)
                            .frame(width: 70, height: 70)
                            .shadow(color: Color.black.opacity(0.3) as Color, radius: 10, x: 0, y: 5)
                        
                        Image(systemName: isSelectionMode ? "xmark" : "calendar.badge.plus")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(currentTheme.bg)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!isSelectionMode && brainDumpManager.tasks.isEmpty)
                .opacity((!isSelectionMode && brainDumpManager.tasks.isEmpty) ? (0.4 as Double) : (1.0 as Double))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(isPresented: $showingBulkImport, manager: brainDumpManager)
        }
        .alert("Clear Done Tasks?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                AnalyticsManager.shared.capture("brain_dump_list_cleared", properties: ["filter": "Done"])
                clearCurrentFilter()
            }
        } message: {
            Text("Are you sure you want to clear your done list? This action cannot be undone.")
        }
        .onAppear {
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: reminderManager.eventsDidChange) { _, _ in
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: isAppleRemindersSyncEnabled) { _, newValue in
            guard newValue else { return }
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: storeManager.isPro) { _, newValue in
            guard newValue else { return }
            syncAppleRemindersIfNeeded()
        }
    }
    
    private func addTask() {
        guard !newTaskTitle.isEmpty else { return }
        let newTask = BrainDumpTask(title: newTaskTitle)
        withAnimation {
            brainDumpManager.tasks.insert(newTask, at: 0)
        }
        AnalyticsManager.shared.capture("brain_dump_task_added")
        syncTaskToAppleRemindersIfNeeded(newTask)
        newTaskTitle = ""
        isFocused = true
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        brainDumpManager.tasks.move(fromOffsets: source, toOffset: destination)
    }

    private func clearCurrentFilter() {
        let reminderIDsToDelete = filteredTasks.compactMap(\.externalReminderId)
        let idsToRemove = Set(filteredTasks.map { $0.id })
        withAnimation {
            brainDumpManager.tasks.removeAll { idsToRemove.contains($0.id) }
        }
        if isAppleReminderSyncActive {
            for reminderID in reminderIDsToDelete {
                reminderManager.deleteTask(externalId: reminderID)
            }
        }
    }

    private func syncAppleRemindersIfNeeded() {
        guard isAppleReminderSyncActive else { return }

        reminderManager.fetchTasks { reminderTasks in
            guard isAppleReminderSyncActive else { return }
            brainDumpManager.applySyncedReminderTasks(reminderTasks)
            
            // After applying remote changes, upload any local tasks that don't have a remote counterpart
            for task in brainDumpManager.tasks {
                if task.externalReminderId == nil {
                    syncTaskToAppleRemindersIfNeeded(task)
                }
            }
        }
    }

    private func syncTaskToAppleRemindersIfNeeded(_ task: BrainDumpTask) {
        guard isAppleReminderSyncActive else { return }

        if task.externalReminderId != nil {
            reminderManager.updateTask(task)
            return
        }

        reminderManager.saveTask(task) { externalReminderId, dueDate in
            guard let externalReminderId else { return }
            brainDumpManager.attachReminder(externalReminderId, dueDate: dueDate, to: task.id)
        }
    }
}

struct BrainDumpRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var isCompleted: Bool
    var scheduledDate: Date? = nil
    var completedDate: Date? = nil
    var reminderDueDate: Date? = nil
    var isSelected: Bool = false
    var isSelectionMode: Bool = false
    var repeatFrequency: RepeatFrequency = .never
    var onToggle: () -> Void
    var onSetRepeat: (RepeatFrequency) -> Void = { _ in }
    
    @State private var confettiCounter = 0

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    var body: some View {
        Button(action: {
            if !isCompleted && !isSelectionMode {
                confettiCounter += 1
            }
            onToggle()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    if isSelectionMode {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(isSelected ? currentTheme.accent : (currentTheme.textForeground.opacity(0.3) as Color))
                    } else {
                        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 22, weight: .light))
                            .foregroundStyle(isCompleted ? (currentTheme.textForeground.opacity(0.3) as Color) : currentTheme.accent)
                        
                        ConfettiView(counter: confettiCounter)
                            .allowsHitTesting(false)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .regular))
                            .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.4 : 0.9) as Color)
                            .strikethrough(isCompleted && !isSelectionMode, color: (currentTheme.textForeground.opacity(0.4) as Color))
                        
                        if repeatFrequency != .never {
                            Image(systemName: "repeat")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(currentTheme.accent.opacity(0.8))
                        }
                    }
                    
                    if isCompleted, let completedDate = completedDate {
                        Text("Completed on \(formatDate(completedDate))")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.4) as Color)
                    } else if let scheduledDate = scheduledDate {
                        Text("Scheduled on \(formatDate(scheduledDate))")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.4) as Color)
                    } else if let reminderDueDate = reminderDueDate {
                        Text("Due on \(formatDate(reminderDueDate))")
                            .font(.system(size: 11, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.4) as Color)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .contextMenu {
            if !isSelectionMode {
                Menu("Repeat") {
                    ForEach(RepeatFrequency.allCases) { freq in
                        Button(action: { onSetRepeat(freq) }) {
                            HStack {
                                Text(freq.rawValue)
                                if repeatFrequency == freq {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct ConfettiView: View {
    let counter: Int
    @State private var pieces: [ConfettiPieceModel] = []
    
    var body: some View {
        ZStack {
            ForEach(pieces) { piece in
                ConfettiPiece(model: piece)
            }
        }
        .onChange(of: counter) { _, _ in
            spawnConfetti()
        }
    }
    
    private func spawnConfetti() {
        let newPieces = (0..<16).map { _ in ConfettiPieceModel() }
        pieces.append(contentsOf: newPieces)
        
        // Clean up old pieces after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if pieces.count >= 16 {
                pieces.removeFirst(16)
            }
        }
    }
}

struct ConfettiPieceModel: Identifiable {
    let id = UUID()
    let color: Color = [.red, .blue, .green, .yellow, .pink, .purple, .orange, .cyan].randomElement()!
    let size = CGFloat.random(in: 4...9)
    let angle = Double.random(in: 0...360)
    let distance = Double.random(in: 35...80)
    let rotation = Double.random(in: 0...360)
}

struct ConfettiPiece: View {
    let model: ConfettiPieceModel
    @State private var offset = CGSize.zero
    @State private var opacity = 1.0
    @State private var scale = 1.0
    @State private var rotation = 0.0
    
    var body: some View {
        Rectangle()
            .fill(model.color)
            .frame(width: model.size, height: model.size)
            .rotationEffect(.degrees(model.rotation + rotation))
            .offset(offset)
            .opacity(opacity)
            .scaleEffect(scale)
            .onAppear {
                let radians = model.angle * .pi / 180
                withAnimation(.easeOut(duration: 0.7)) {
                    offset = CGSize(
                        width: cos(radians) * model.distance,
                        height: sin(radians) * model.distance
                    )
                    opacity = 0
                    scale = 0.4
                    rotation = Double.random(in: 90...360)
                }
            }
    }
}
