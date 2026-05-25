import SwiftUI
import StoreKit

struct TodoView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage(DemoScreenshotData.storageKey) private var isDemoScreenshotDataEnabled = false
    @AppStorage(ReminderManager.syncEnabledKey) private var isAppleRemindersSyncEnabled = false
    @AppStorage("todoCompletedTaskCountForReview") private var completedTaskCountForReview = 0
    @AppStorage("hasRequestedTodoReview") private var hasRequestedTodoReview = false
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject var storeManager: StoreManager
    @StateObject private var brainDumpManager = BrainDumpManager.shared
    @ObservedObject private var reminderManager = ReminderManager.shared
    @State private var newTaskTitle: String = ""
    @FocusState private var isFocused: Bool
    @State private var showingBulkImport = false
    @State private var selectedListId: UUID? = nil
    @State private var showingNewListAlert = false
    @State private var newListName = ""
    
    enum Filter: String, CaseIterable {
        case active = "Inbox"
        case completed = "Done"
        case routine = "Routine"
    }
    @State private var selectedFilter: Filter = .active

    @State private var showingClearAlert = false
    @State private var routineSessionPendingEnd: RoutineSession?
    
    init(onSchedule: @escaping (String, UUID) -> Void) {
        self.onSchedule = onSchedule
        // Automatically switch to routine tab if one is active
        if BrainDumpManager.shared.hasActiveRoutineSessions {
            _selectedFilter = State(initialValue: .routine)
        }
    }
    
    // Selection for scheduling
    @State private var isSelectionMode = false
    @State private var selectedTaskIds = Set<UUID>()
    
    var onSchedule: (String, UUID) -> Void
    
    private var bgColor: Color { currentTheme.bg }
    private var goldColor: Color { currentTheme.accent }
    private var isAppleReminderSyncActive: Bool {
        storeManager.isPro && isAppleRemindersSyncEnabled && ReminderManager.hasReminderAccess()
    }
    private var usesDemoScreenshotData: Bool {
        AppConfiguration.isTestingMode && isDemoScreenshotDataEnabled
    }
    private var visibleBrainDumpTasks: [BrainDumpTask] {
        usesDemoScreenshotData ? DemoScreenshotData.brainDumpTasks(relativeTo: Date()) : brainDumpManager.tasks
    }
    private var visibleBrainDumpLists: [BrainDumpList] {
        usesDemoScreenshotData ? DemoScreenshotData.brainDumpLists() : brainDumpManager.lists
    }
    private var visibleRoutineSessions: [RoutineSession] {
        usesDemoScreenshotData ? DemoScreenshotData.routineSessions(relativeTo: Date()) : brainDumpManager.activeRoutineSessions
    }
    private var hasVisibleRoutineSessions: Bool {
        !visibleRoutineSessions.isEmpty
    }
    private var hasAutoScheduledRoutineToday: Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return RoutineManager.shared.routines.contains { routine in
            routine.autoScheduleDays.contains(where: { $0.rawValue == Calendar.current.component(.weekday, from: today) })
        }
    }
    private var selectedListName: String {
        guard let selectedListId,
              let list = visibleBrainDumpLists.first(where: { $0.id == selectedListId }) else {
            return "Inbox"
        }
        return list.name
    }

    var filteredTasks: [BrainDumpTask] {
        switch selectedFilter {
        case .active:
            return brainDumpInboxTasks(from: visibleBrainDumpTasks).filter { $0.listId == selectedListId }
        case .completed:
            return brainDumpCompletedArchiveTasks(from: visibleBrainDumpTasks)
        case .routine:
            return []
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text("TO-DO")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                    .padding(.top, 40)
                    .padding(.bottom, 24)

                // Main Filter Picker (Inbox / Done / Routine)
                HStack(spacing: 0) {
                    ForEach(Filter.allCases, id: \.self) { filter in
                        let label: String = {
                            if filter == .routine {
                                return "ROUTINES"
                            }
                            return filter.rawValue.uppercased()
                        }()
                        
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFilter = filter
                            }
                        }) {
                            VStack(spacing: 8) {
                                Text(label)
                                    .font(.system(size: 12, weight: .medium, design: .serif))
                                    .foregroundStyle(selectedFilter == filter ? goldColor : (currentTheme.textForeground.opacity(0.4) as Color))
                                    .tracking(1)
                                    .lineLimit(1)
                                
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

                if selectedFilter == .active {
                    todoListSelector
                        .padding(.bottom, 14)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

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
                        
                        Button(action: {
                            guard !usesDemoScreenshotData else { return }
                            showingBulkImport = true
                        }) {
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
                if selectedFilter == .routine {
                    if hasVisibleRoutineSessions {
                        routineTasksListView
                    } else {
                        noActiveRoutineView
                    }
                } else if filteredTasks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: selectedFilter == .active ? "brain.head.profile" : "checkmark.seal")
                            .font(.system(size: 32))
                            .foregroundStyle(goldColor.opacity(0.5) as Color)
                        Text(selectedFilter == .active ? (selectedListId == nil ? "Clear your mind" : "No tasks in \(selectedListName)") : "No completed tasks yet")
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
                                lists: visibleBrainDumpLists,
                                listId: task.listId,
                                onToggle: {
                                    if isSelectionMode {
                                        if selectedTaskIds.contains(task.id) {
                                            selectedTaskIds.remove(task.id)
                                        } else {
                                            selectedTaskIds.insert(task.id)
                                        }
                                    } else {
                                        guard !usesDemoScreenshotData else { return }

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
                                                handleTodoCompletionForReviewPrompt()
                                            } else if wasCompleted && !nowCompleted {
                                                AnalyticsManager.shared.capture("brain_dump_task_reactivated")
                                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                            }

                                            syncTaskToAppleRemindersIfNeeded(brainDumpManager.tasks[index])
                                        }
                                    }
                                },
                                onSetRepeat: { freq in
                                    guard !usesDemoScreenshotData else { return }

                                    if let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) {
                                        brainDumpManager.tasks[index].repeatFrequency = freq
                                        AnalyticsManager.shared.capture("brain_dump_task_repeat_set", properties: ["frequency": freq.rawValue])
                                    }
                                },
                                onMoveToList: { listId in
                                    guard !usesDemoScreenshotData else { return }
                                    moveTask(task, to: listId)
                                }
                            )
                            .listRowBackground(SwiftUI.Color.clear.opacity(0.001) as Color)
                            .listRowInsets(EdgeInsets(top: 14, leading: 40, bottom: 14, trailing: 40))
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    guard !usesDemoScreenshotData else { return }

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
                        if usesDemoScreenshotData {
                            withAnimation {
                                isSelectionMode = false
                                selectedTaskIds.removeAll()
                            }
                            return
                        }

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
                    if !isSelectionMode && visibleBrainDumpTasks.isEmpty { return }
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
                .disabled(!isSelectionMode && visibleBrainDumpTasks.isEmpty)
                .opacity((!isSelectionMode && visibleBrainDumpTasks.isEmpty) ? (0.4 as Double) : (1.0 as Double))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingBulkImport) {
            BulkImportView(isPresented: $showingBulkImport, manager: brainDumpManager, listId: selectedListId)
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
        .alert("New List", isPresented: $showingNewListAlert) {
            TextField("List name", text: $newListName)
            Button("Cancel", role: .cancel) { }
            Button("Create") {
                createList()
            }
            .disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: {
            Text("Create a list for related to-dos.")
        }
        .onAppear {
            if !usesDemoScreenshotData {
                brainDumpManager.reloadFromSharedStoreIfNeeded()
                syncAppleRemindersIfNeeded()
            }
        }
        .onChange(of: reminderManager.eventsDidChange) { _, _ in
            guard !usesDemoScreenshotData else { return }
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            guard !usesDemoScreenshotData else { return }
            brainDumpManager.reloadFromSharedStoreIfNeeded()
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: isAppleRemindersSyncEnabled) { _, newValue in
            guard newValue else { return }
            guard !usesDemoScreenshotData else { return }
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: storeManager.isPro) { _, newValue in
            guard newValue else { return }
            guard !usesDemoScreenshotData else { return }
            syncAppleRemindersIfNeeded()
        }
        .onChange(of: isDemoScreenshotDataEnabled) { _, _ in
            withAnimation {
                isSelectionMode = false
                selectedTaskIds.removeAll()
                if let selectedListId, !visibleBrainDumpLists.contains(where: { $0.id == selectedListId }) {
                    self.selectedListId = nil
                }
            }
        }
        .onChange(of: brainDumpManager.activeRoutineSessions) { _, newValue in
            guard !usesDemoScreenshotData else { return }
            if newValue.isEmpty, selectedFilter == .routine {
                selectedFilter = .active
            }
        }
        .onChange(of: brainDumpManager.lists) { _, _ in
            if let selectedListId, !visibleBrainDumpLists.contains(where: { $0.id == selectedListId }) {
                self.selectedListId = nil
            }
        }
    }
    
    private func addTask() {
        guard !usesDemoScreenshotData else { return }
        guard !newTaskTitle.isEmpty else { return }
        var newTask = BrainDumpTask(title: newTaskTitle)
        newTask.listId = selectedListId
        withAnimation {
            brainDumpManager.tasks.insert(newTask, at: 0)
        }
        AnalyticsManager.shared.capture("brain_dump_task_added")
        syncTaskToAppleRemindersIfNeeded(newTask)
        newTaskTitle = ""
        isFocused = true
    }

    private func handleTodoCompletionForReviewPrompt() {
        guard !hasRequestedTodoReview else { return }

        completedTaskCountForReview += 1
        guard (15...20).contains(completedTaskCountForReview) else { return }

        hasRequestedTodoReview = true
        AnalyticsManager.shared.capture("todo_review_prompt_requested", properties: [
            "completed_task_count": completedTaskCountForReview
        ])

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            requestReview()
        }
    }

    private func createList() {
        guard !usesDemoScreenshotData else { return }
        let trimmedName = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let newList = BrainDumpList(name: trimmedName)
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            brainDumpManager.lists.append(newList)
            selectedListId = newList.id
        }
        AnalyticsManager.shared.capture("brain_dump_list_created")
        newListName = ""
    }

    private func deleteList(_ list: BrainDumpList) {
        guard !usesDemoScreenshotData else { return }

        withAnimation(.easeInOut) {
            for index in brainDumpManager.tasks.indices where brainDumpManager.tasks[index].listId == list.id {
                brainDumpManager.tasks[index].listId = nil
            }
            brainDumpManager.lists.removeAll { $0.id == list.id }
            if selectedListId == list.id {
                selectedListId = nil
            }
        }
        AnalyticsManager.shared.capture("brain_dump_list_deleted")
    }

    private func moveTask(_ task: BrainDumpTask, to listId: UUID?) {
        guard !usesDemoScreenshotData else { return }
        guard let index = brainDumpManager.tasks.firstIndex(where: { $0.id == task.id }) else { return }
        withAnimation(.easeInOut) {
            brainDumpManager.tasks[index].listId = listId
        }
        AnalyticsManager.shared.capture("brain_dump_task_moved_to_list")
    }
    
    private func moveTask(from source: IndexSet, to destination: Int) {
        guard !usesDemoScreenshotData else { return }

        let visibleTasks = filteredTasks
        let movingTasks = source.compactMap { index in
            visibleTasks.indices.contains(index) ? visibleTasks[index] : nil
        }
        let movingIDs = Set(movingTasks.map(\.id))

        brainDumpManager.tasks.removeAll { movingIDs.contains($0.id) }

        let remainingVisibleTasks = filteredTasks
        let insertionIndex: Int
        if destination < remainingVisibleTasks.count,
           let destinationIndex = brainDumpManager.tasks.firstIndex(where: { $0.id == remainingVisibleTasks[destination].id }) {
            insertionIndex = destinationIndex
        } else {
            insertionIndex = brainDumpManager.tasks.count
        }

        brainDumpManager.tasks.insert(contentsOf: movingTasks, at: insertionIndex)
    }

    private func clearCurrentFilter() {
        guard !usesDemoScreenshotData else { return }

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
        guard !usesDemoScreenshotData else { return }
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
        guard !usesDemoScreenshotData else { return }
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
    var lists: [BrainDumpList] = []
    var listId: UUID? = nil
    var onToggle: () -> Void
    var onSetRepeat: (RepeatFrequency) -> Void = { _ in }
    var onMoveToList: (UUID?) -> Void = { _ in }
    
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

                Menu("Move to List") {
                    Button(action: { onMoveToList(nil) }) {
                        HStack {
                            Text("Inbox")
                            if listId == nil {
                                Image(systemName: "checkmark")
                            }
                        }
                    }

                    ForEach(lists) { list in
                        Button(action: { onMoveToList(list.id) }) {
                            HStack {
                                Text(list.name)
                                if listId == list.id {
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

struct TodoListChip: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .serif))
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .foregroundStyle(isSelected ? theme.bg : theme.textForeground.opacity(0.72))
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(
                Capsule()
                    .fill(isSelected ? theme.accent : theme.fieldBg)
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.2) : theme.textForeground.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

struct RoutineSessionRow: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    var title: String
    var isCompleted: Bool
    var onToggle: () -> Void

    @State private var confettiCounter = 0

    var body: some View {
        Button(action: {
            if !isCompleted {
                confettiCounter += 1
            }
            onToggle()
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(isCompleted ? (currentTheme.textForeground.opacity(0.3) as Color) : currentTheme.accent)

                    ConfettiView(counter: confettiCounter)
                        .allowsHitTesting(false)
                }

                Text(title)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(currentTheme.textForeground.opacity(isCompleted ? 0.4 : 0.9) as Color)
                    .strikethrough(isCompleted, color: (currentTheme.textForeground.opacity(0.4) as Color))

                Spacer()
            }
        }
        .buttonStyle(.plain)
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

extension TodoView {
    private var todoListSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                TodoListChip(
                    title: "Inbox",
                    systemImage: "tray.fill",
                    isSelected: selectedListId == nil,
                    theme: currentTheme,
                    action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            selectedListId = nil
                        }
                    }
                )

                ForEach(visibleBrainDumpLists) { list in
                    TodoListChip(
                        title: list.name,
                        systemImage: "list.bullet",
                        isSelected: selectedListId == list.id,
                        theme: currentTheme,
                        action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedListId = list.id
                            }
                        }
                    )
                    .contextMenu {
                        if !usesDemoScreenshotData {
                            Button(role: .destructive) {
                                deleteList(list)
                            } label: {
                                Label("Delete List", systemImage: "trash")
                            }
                        }
                    }
                }

                Button(action: {
                    guard !usesDemoScreenshotData else { return }
                    newListName = ""
                    showingNewListAlert = true
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(goldColor)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(currentTheme.fieldBg))
                        .overlay(Circle().stroke(goldColor.opacity(0.28), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
        }
    }

    private var routineTasksListView: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Active routine checklists")
                        .font(.system(size: 12, weight: .bold, design: .serif))
                        .foregroundStyle(goldColor)
                        .tracking(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 4)

                ForEach(visibleRoutineSessions) { session in
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(session.name.uppercased())
                                    .font(.system(size: 12, weight: .bold, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .tracking(1)

                                Text("\(session.items.filter(\.isCompleted).count) of \(session.items.count) done")
                                    .font(.system(size: 12, weight: .light))
                                    .foregroundStyle(currentTheme.textForeground.opacity(0.55))

                                ProgressView(value: session.progress)
                                    .tint(goldColor)
                                    .scaleEffect(x: 1, y: 1.35, anchor: .center)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            Spacer(minLength: 20)

                            Button(action: {
                                guard !usesDemoScreenshotData else { return }
                                routineSessionPendingEnd = session
                            }) {
                                Text("END")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(currentTheme.bg)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.red.opacity(0.8))
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 20)
                        .padding(.bottom, 18)

                        ForEach(session.items) { item in
                            RoutineSessionRow(
                                title: item.title,
                                isCompleted: item.isCompleted,
                                onToggle: {
                                    handleRoutineItemToggle(item, in: session)
                                }
                            )
                            .padding(.horizontal, 22)
                            .padding(.vertical, 14)

                            if item.id != session.items.last?.id {
                                Rectangle()
                                    .fill(currentTheme.textForeground.opacity(0.08))
                                    .frame(height: 1)
                                    .padding(.horizontal, 22)
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 24)
                            .fill(currentTheme.fieldBg)
                    )
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .alert("End Routine?", isPresented: Binding(
            get: { routineSessionPendingEnd != nil },
            set: { isPresented in
                if !isPresented {
                    routineSessionPendingEnd = nil
                }
            }
        )) {
            Button("Keep Active", role: .cancel) { }
            Button("End Routine", role: .destructive) {
                if let session = routineSessionPendingEnd {
                    withAnimation {
                        brainDumpManager.clearRoutineSession(session.id)
                    }
                }
                routineSessionPendingEnd = nil
            }
        } message: {
            Text("This will remove this checklist from your To-Do routines tab.")
        }
    }
    
    private var noActiveRoutineView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "play.circle")
                .font(.system(size: 32))
                .foregroundStyle(goldColor.opacity(0.5) as Color)
            Text("No active routine")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(currentTheme.textForeground.opacity(0.5) as Color)
            Spacer()
        }
    }

    private func handleRoutineItemToggle(_ item: SessionItem, in session: RoutineSession) {
        guard !usesDemoScreenshotData else { return }

        let wasCompleted = item.isCompleted
        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
            brainDumpManager.toggleRoutineItem(item.id, in: session.id)
        }

        if !wasCompleted {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            SoundManager.shared.playBing()
        } else {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
            guard let refreshedSession = brainDumpManager.session(for: session.id) else { return }
            guard !refreshedSession.items.isEmpty else { return }
            guard refreshedSession.items.allSatisfy(\.isCompleted) else { return }

            withAnimation(.easeInOut(duration: 0.25)) {
                brainDumpManager.clearRoutineSession(refreshedSession.id)
            }
        }
    }
}
