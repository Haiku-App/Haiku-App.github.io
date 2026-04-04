import SwiftUI

struct BulkImportView: View {
    @AppStorage("appTheme") private var currentTheme: AppTheme = .sage
    @AppStorage(ReminderManager.syncEnabledKey) private var isAppleRemindersSyncEnabled = false
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool
    @ObservedObject var manager: BrainDumpManager
    @ObservedObject private var reminderManager = ReminderManager.shared
    @State private var text: String = ""
    
    private var goldColor: Color { currentTheme.accent }
    private var isAppleReminderSyncActive: Bool {
        storeManager.isPro && isAppleRemindersSyncEnabled && ReminderManager.hasReminderAccess()
    }

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundStyle(goldColor)
                
                Spacer()
                
                Text("BULK IMPORT")
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .foregroundStyle(goldColor)
                    .tracking(2)
                
                Spacer()
                
                Button("Done") {
                    importTasks()
                }
                .foregroundStyle(goldColor)
                .fontWeight(.bold)
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Text("Paste your list below (one task per line)")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(currentTheme.textForeground.opacity(0.7))
                .padding(.horizontal, 24)
            
            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(currentTheme.textForeground)
                    .scrollContentBackground(.hidden)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(currentTheme.fieldBg)
                    )
                
                if text.isEmpty {
                    Text("Paste your list here...")
                        .font(.system(size: 16))
                        .foregroundStyle(currentTheme.textForeground.opacity(0.3))
                        .padding(.horizontal, 22)
                        .padding(.vertical, 24)
                        .allowsHitTesting(false)
                }
            }
            .padding(.horizontal, 24)
            
            Button(action: importTasks) {
                Text("IMPORT TASKS")
                    .font(.system(size: 14, weight: .semibold, design: .serif))
                    .foregroundStyle(currentTheme.bg)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 40)
                    .background(
                        Capsule()
                            .fill(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? goldColor.opacity(0.3) : goldColor)
                    )
            }
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .padding(.bottom, 40)
        }
        .background(currentTheme.bg.ignoresSafeArea())
    }
    
    private func importTasks() {
        let lines = text.components(separatedBy: .newlines)
        var importedCount = 0
        var importedTaskIDs: [UUID] = []
        withAnimation {
            for line in lines.reversed() {
                var title = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Remove common prefixes
                // 1. Check for - [ ] or * [ ] or [ ] or - [x] etc.
                if let bracketRange = title.range(of: #"^(\s*[-*+]\s*\[[ xX]\]\s*|\s*[-*+]\s*|\s*\[[ xX]\]\s*)"#, options: .regularExpression) {
                    title.removeSubrange(bracketRange)
                }
                
                title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !title.isEmpty {
                    let task = BrainDumpTask(title: title)
                    manager.tasks.insert(task, at: 0)
                    importedTaskIDs.append(task.id)
                    importedCount += 1
                }
            }
        }

        if isAppleReminderSyncActive {
            for taskID in importedTaskIDs {
                syncTaskToAppleReminders(taskID)
            }
        }
        
        if importedCount > 0 {
            AnalyticsManager.shared.capture("bulk_import_completed", properties: ["task_count": importedCount])
        }
        
        isPresented = false
    }

    private func syncTaskToAppleReminders(_ taskID: UUID) {
        guard let task = manager.tasks.first(where: { $0.id == taskID }) else { return }

        reminderManager.saveTask(task) { externalReminderId, dueDate in
            guard let externalReminderId else { return }
            manager.attachReminder(externalReminderId, dueDate: dueDate, to: taskID)
        }
    }
}

struct BulkImportView_Previews: PreviewProvider {
    static var previews: some View {
        BulkImportView(isPresented: .constant(true), manager: BrainDumpManager())
            .environmentObject(StoreManager())
    }
}
