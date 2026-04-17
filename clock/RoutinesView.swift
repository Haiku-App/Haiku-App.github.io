import SwiftUI

struct RoutinesView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @ObservedObject private var routineManager = RoutineManager.shared
    @Binding var selectedDate: Date

    var onStartNow: (Routine) -> Void
    var onApplyPreferredTime: (Routine) -> Void

    @State private var showingEditor = false
    @State private var routineToEdit: Routine?

    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROUTINES")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(goldColor)
                            .tracking(2)
                            .padding(.top, 40)

                        Text("Build reusable bundles, then start them now or drop them onto \(selectedDateLabel).")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.65))
                    }
                    .padding(.horizontal, 28)

                    if routineManager.routines.isEmpty {
                        emptyStateCard
                            .padding(.horizontal, 28)
                    } else {
                        VStack(spacing: 16) {
                            ForEach(routineManager.routines) { routine in
                                RoutineCard(
                                    routine: routine,
                                    selectedDateLabel: selectedDateLabel,
                                    theme: currentTheme,
                                    onStartNow: { 
                                        BrainDumpManager.shared.startRoutine(routine)
                                        onStartNow(routine) 
                                    },
                                    onApplyPreferredTime: { onApplyPreferredTime(routine) },
                                    onEdit: {
                                        routineToEdit = routine
                                        showingEditor = true
                                    },
                                    onDelete: {
                                        withAnimation(.easeInOut) {
                                            routineManager.deleteRoutine(routine)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 28)
                        .padding(.bottom, 110)
                    }
                }
                .padding(.bottom, 28)
            }

            Button(action: {
                routineToEdit = nil
                showingEditor = true
            }) {
                ZStack {
                    Circle()
                        .fill(goldColor)
                        .frame(width: 70, height: 70)
                        .shadow(color: Color.black.opacity(0.25), radius: 10, x: 0, y: 5)

                    Image(systemName: "plus")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(currentTheme == .sakura ? currentTheme.textForeground : bgColor)
                }
            }
            .buttonStyle(.plain)
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $showingEditor) {
            RoutineEditorView(routine: routineToEdit) { savedRoutine in
                routineManager.saveRoutine(savedRoutine)
            }
        }
    }

    private var emptyStateCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "rectangle.stack.badge.plus")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(goldColor.opacity(0.8))

            Text("Save a routine once and reuse it whenever your day starts.")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(currentTheme.textForeground.opacity(0.85))
                .multilineTextAlignment(.center)

            Text("Morning reset, gym warm-up, night wind-down, whatever you repeat.")
                .font(.system(size: 13, weight: .light))
                .foregroundStyle(currentTheme.textForeground.opacity(0.55))
                .multilineTextAlignment(.center)

            Button(action: {
                routineToEdit = nil
                showingEditor = true
            }) {
                Text("Create Routine")
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundStyle(currentTheme == .sakura ? currentTheme.textForeground : bgColor)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(goldColor)
                    )
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
        .padding(.vertical, 28)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(fieldBgColor)
                .shadow(color: shadowDark, radius: 10, x: 6, y: 6)
                .shadow(color: shadowLight, radius: 10, x: -6, y: -6)
        )
    }

    private var selectedDateLabel: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: selectedDate)
    }
}

private struct RoutineCard: View {
    let routine: Routine
    let selectedDateLabel: String
    let theme: AppTheme
    let onStartNow: () -> Void
    let onApplyPreferredTime: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var fieldBgColor: Color { theme.fieldBg }
    private var goldColor: Color { theme.accent }
    private var shadowLight: Color { theme.shadowLight }
    private var shadowDark: Color { theme.shadowDark }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(routine.name)
                            .font(.system(size: 19, weight: .medium, design: .serif))
                            .foregroundStyle(theme.textForeground)

                        if routine.isAutoScheduleEnabled {
                            Text("AUTO")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(theme == .sakura ? theme.textForeground : theme.bg)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(goldColor)
                                )
                        }
                    }

                    Text("\(routine.steps.count) steps • \(routine.totalDurationMinutes) min")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.textForeground.opacity(0.5))

                    Text(scheduleSummary)
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(theme.textForeground.opacity(0.65))
                }

                Spacer()

                Menu {
                    Button("Edit", action: onEdit)
                    Button("Delete", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(goldColor.opacity(0.8))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(routine.steps.prefix(3).enumerated()), id: \.element.id) { index, step in
                    HStack(spacing: 10) {
                        Circle()
                            .fill(step.color)
                            .frame(width: 10, height: 10)

                        Text(step.title)
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(theme.textForeground.opacity(0.85))
                            .lineLimit(1)

                        Spacer()

                        Text("\(step.durationMinutes)m")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(theme.textForeground.opacity(0.45))
                    }

                    if index < min(routine.steps.count, 3) - 1 {
                        Rectangle()
                            .fill(theme.textForeground.opacity(0.08))
                            .frame(height: 1)
                    }
                }

                if routine.steps.count > 3 {
                    Text("+\(routine.steps.count - 3) more")
                        .font(.system(size: 12, weight: .medium, design: .serif))
                        .foregroundStyle(goldColor.opacity(0.8))
                        .padding(.leading, 20)
                }
            }

            HStack(spacing: 12) {
                Button(action: onStartNow) {
                    Text("Start Now")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundStyle(theme == .sakura ? theme.textForeground : theme.bg)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(goldColor)
                        )
                }
                .buttonStyle(.plain)

                Button(action: onApplyPreferredTime) {
                    Text("Add to \(selectedDateLabel)")
                        .font(.system(size: 14, weight: .medium, design: .serif))
                        .foregroundStyle(theme.textForeground.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(theme.textForeground.opacity(0.12), lineWidth: 1)
                                .background(
                                    RoundedRectangle(cornerRadius: 16)
                                        .fill(theme.bg.opacity(0.15))
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 28)
                .fill(fieldBgColor)
                .shadow(color: shadowDark, radius: 10, x: 6, y: 6)
                .shadow(color: shadowLight, radius: 10, x: -6, y: -6)
        )
    }

    private var scheduleSummary: String {
        if routine.isAutoScheduleEnabled {
            return "Auto-schedules \(weekdaySummary) at \(formattedTime(minutes: routine.preferredStartMinutes))."
        }
        return "Preferred start time: \(formattedTime(minutes: routine.preferredStartMinutes))."
    }

    private var weekdaySummary: String {
        let sortedDays = routine.autoScheduleDays.sorted()
        if sortedDays == [.monday, .tuesday, .wednesday, .thursday, .friday] {
            return "weekdays"
        }
        return sortedDays.map(\.shortLabel).joined(separator: ", ")
    }

    private func formattedTime(minutes: Int) -> String {
        var comps = DateComponents()
        comps.hour = (minutes % 1440) / 60
        comps.minute = minutes % 60
        let date = Calendar.current.date(from: comps) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

private struct RoutineEditorView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var categoryManager = CategoryManager.shared

    let routine: Routine?
    let onSave: (Routine) -> Void

    @State private var name: String
    @State private var preferredStartTime: Date
    @State private var autoScheduleDays: Set<RoutineWeekday>
    @State private var steps: [RoutineStep]

    init(routine: Routine?, onSave: @escaping (Routine) -> Void) {
        self.routine = routine
        self.onSave = onSave

        let startMinutes = routine?.preferredStartMinutes ?? 8 * 60
        let dayStart = Calendar.current.startOfDay(for: Date())
        let time = Calendar.current.date(byAdding: .minute, value: startMinutes, to: dayStart) ?? Date()

        self._name = State(initialValue: routine?.name ?? "")
        self._preferredStartTime = State(initialValue: time)
        self._autoScheduleDays = State(initialValue: Set(routine?.autoScheduleDays ?? []))
        self._steps = State(initialValue: routine?.steps.isEmpty == false ? routine?.steps ?? [] : [RoutineEditorView.defaultStep()])
    }

    private var bgColor: Color { currentTheme.bg }
    private var fieldBgColor: Color { currentTheme.fieldBg }
    private var goldColor: Color { currentTheme.accent }
    private var shadowLight: Color { currentTheme.shadowLight }
    private var shadowDark: Color { currentTheme.shadowDark }

    private var sanitizedSteps: [RoutineStep] {
        steps.compactMap { step in
            let trimmedTitle = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return nil }

            var copy = step
            copy.title = trimmedTitle
            copy.durationMinutes = min(max(copy.durationMinutes, 5), 240)
            return copy
        }
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !sanitizedSteps.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 28) {
                        section(title: "ROUTINE NAME") {
                            TextField("Morning Routine", text: $name)
                                .font(.system(size: 16, weight: .regular))
                                .foregroundStyle(currentTheme.textForeground)
                                .padding()
                                .background(cardBackground)
                        }

                        section(title: "DEFAULT START") {
                            DatePicker("Start Time", selection: $preferredStartTime, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .colorMultiply(currentTheme == .sakura ? currentTheme.textForeground : .white)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(cardBackground)
                        }

                        section(title: "AUTO-SCHEDULE DAYS") {
                            HStack(spacing: 10) {
                                ForEach(RoutineWeekday.allCases) { day in
                                    Button(action: { toggleDay(day) }) {
                                        Text(day.shortLabel)
                                            .font(.system(size: 12, weight: .bold, design: .rounded))
                                            .foregroundStyle(autoScheduleDays.contains(day) ? (currentTheme == .sakura ? currentTheme.textForeground : bgColor) : currentTheme.textForeground.opacity(0.75))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                Capsule()
                                                    .fill(autoScheduleDays.contains(day) ? goldColor : fieldBgColor)
                                                    .overlay(
                                                        Capsule()
                                                            .stroke(currentTheme.textForeground.opacity(autoScheduleDays.contains(day) ? 0 : 0.1), lineWidth: 1)
                                                    )
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("STEPS")
                                    .font(.system(size: 12, weight: .regular, design: .serif))
                                    .foregroundStyle(goldColor)
                                    .tracking(1)

                                Spacer()

                                Button(action: addStep) {
                                    Label("Add Step", systemImage: "plus")
                                        .font(.system(size: 13, weight: .bold, design: .serif))
                                        .foregroundStyle(goldColor)
                                }
                                .buttonStyle(.plain)
                            }

                            VStack(spacing: 16) {
                                ForEach(Array(steps.indices), id: \.self) { index in
                                    stepEditor(index: index)
                                }
                            }
                        }
                    }
                    .padding(24)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle(routine == nil ? "New Routine" : "Edit Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarColorScheme(currentTheme == .sakura ? .light : .dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 16, design: .serif))
                        .foregroundStyle(goldColor)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveRoutine)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundStyle(canSave ? goldColor : goldColor.opacity(0.35))
                        .disabled(!canSave)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .regular, design: .serif))
                .foregroundStyle(goldColor)
                .tracking(1)

            content()
        }
    }

    private func stepEditor(index: Int) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("STEP \(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(goldColor.opacity(0.85))
                    .tracking(1)

                Spacer()

                HStack(spacing: 12) {
                    Button(action: { moveStep(from: index, offset: -1) }) {
                        Image(systemName: "arrow.up")
                            .foregroundStyle(index == 0 ? currentTheme.textForeground.opacity(0.2) : goldColor.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .disabled(index == 0)

                    Button(action: { moveStep(from: index, offset: 1) }) {
                        Image(systemName: "arrow.down")
                            .foregroundStyle(index == steps.count - 1 ? currentTheme.textForeground.opacity(0.2) : goldColor.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .disabled(index == steps.count - 1)

                    Button(role: .destructive, action: { deleteStep(at: index) }) {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.red.opacity(0.75))
                    }
                    .buttonStyle(.plain)
                    .disabled(steps.count == 1)
                }
            }

            TextField("Brush teeth", text: Binding(
                get: { steps[index].title },
                set: { steps[index].title = $0 }
            ))
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(currentTheme.textForeground)

            HStack(spacing: 16) {
                Stepper(
                    "\(steps[index].durationMinutes) min",
                    value: Binding(
                        get: { steps[index].durationMinutes },
                        set: { steps[index].durationMinutes = min(max($0, 5), 240) }
                    ),
                    in: 5...240,
                    step: 5
                )
                .foregroundStyle(currentTheme.textForeground.opacity(0.85))

                Spacer()

                Menu {
                    Button("Keep Custom Color") {
                        steps[index].categoryId = nil
                        steps[index].categoryName = nil
                    }

                    ForEach(categoryManager.categories) { category in
                        Button(category.name) {
                            steps[index].categoryId = category.id
                            steps[index].categoryName = category.name
                            steps[index].rgb = category.rgb
                        }
                    }
                } label: {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(steps[index].color)
                            .frame(width: 12, height: 12)

                        Text(steps[index].categoryName ?? "Custom Color")
                            .font(.system(size: 13, weight: .medium, design: .serif))
                            .foregroundStyle(currentTheme.textForeground.opacity(0.8))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .stroke(currentTheme.textForeground.opacity(0.12), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(cardBackground)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(fieldBgColor)
            .shadow(color: shadowDark, radius: 6, x: 4, y: 4)
            .shadow(color: shadowLight, radius: 6, x: -4, y: -4)
    }

    private func toggleDay(_ day: RoutineWeekday) {
        if autoScheduleDays.contains(day) {
            autoScheduleDays.remove(day)
        } else {
            autoScheduleDays.insert(day)
        }
    }

    private func addStep() {
        steps.append(Self.defaultStep())
    }

    private func deleteStep(at index: Int) {
        guard steps.count > 1 else { return }
        steps.remove(at: index)
    }

    private func moveStep(from index: Int, offset: Int) {
        let destination = index + offset
        guard steps.indices.contains(index), steps.indices.contains(destination) else { return }
        let step = steps.remove(at: index)
        steps.insert(step, at: destination)
    }

    private func saveRoutine() {
        guard canSave else { return }

        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: preferredStartTime)
        let minutes = (timeComponents.hour ?? 0) * 60 + (timeComponents.minute ?? 0)

        let savedRoutine = Routine(
            id: routine?.id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            preferredStartMinutes: minutes,
            autoScheduleDays: Array(autoScheduleDays).sorted(),
            steps: sanitizedSteps
        )

        onSave(savedRoutine)
        dismiss()
    }

    private static func defaultStep() -> RoutineStep {
        RoutineStep(
            title: "",
            durationMinutes: 10,
            rgb: aestheticColors.first ?? RGB(r: 0.85, g: 0.78, b: 0.58)
        )
    }
}
