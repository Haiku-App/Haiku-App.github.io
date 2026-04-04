import SwiftUI
internal import Combine
import CloudKit

enum AppSupportDefaults {
    static let userDefaults = UserDefaults(suiteName: "group.reswink.haiku") ?? UserDefaults.standard
    static let categoriesKey = "userCategories"
    static let categoriesLastModifiedKey = "userCategoriesLastModified"
    static let brainDumpTasksKey = "brainDumpTasks"
    static let brainDumpTasksLastModifiedKey = "brainDumpTasksLastModified"
}

struct RGB: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
}

struct Category: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var icon: String
    var rgb: RGB
    var color: Color { rgb.color }
}

enum AppSupportPersistence {
    static func defaultCategories() -> [Category] {
        [
            Category(name: "Deep Work", icon: "brain.head.profile", rgb: RGB(r: 0.75, g: 0.55, b: 0.45)),
            Category(name: "Meeting", icon: "person.2.fill", rgb: RGB(r: 0.85, g: 0.78, b: 0.58)),
            Category(name: "Break", icon: "cup.and.saucer.fill", rgb: RGB(r: 0.35, g: 0.42, b: 0.35)),
            Category(name: "Study", icon: "book.fill", rgb: RGB(r: 0.45, g: 0.50, b: 0.35)),
            Category(name: "Personal", icon: "figure.walk", rgb: RGB(r: 0.45, g: 0.65, b: 0.85)),
            Category(name: "Routine", icon: "arrow.clockwise", rgb: RGB(r: 0.55, g: 0.72, b: 0.55)),
        ]
    }

    static func loadCategories() -> [Category] {
        guard let data = AppSupportDefaults.userDefaults.data(forKey: AppSupportDefaults.categoriesKey),
              let decoded = try? JSONDecoder().decode([Category].self, from: data) else {
            return defaultCategories()
        }

        return decoded
    }

    static func loadBrainDumpTasks() -> [BrainDumpTask] {
        guard let data = AppSupportDefaults.userDefaults.data(forKey: AppSupportDefaults.brainDumpTasksKey),
              var decoded = try? JSONDecoder().decode([BrainDumpTask].self, from: data) else {
            return []
        }

        var modified = false
        for index in decoded.indices {
            if decoded[index].isCompleted && decoded[index].completedDate == nil {
                decoded[index].completedDate = Date()
                modified = true
            }
        }

        if modified {
            saveBrainDumpTasks(decoded, modifiedAt: loadBrainDumpTasksLastModifiedAt() ?? Date())
        }

        return decoded
    }

    static func saveCategories(_ categories: [Category], modifiedAt: Date = Date()) {
        guard let data = try? JSONEncoder().encode(categories) else { return }
        AppSupportDefaults.userDefaults.set(data, forKey: AppSupportDefaults.categoriesKey)
        AppSupportDefaults.userDefaults.set(modifiedAt, forKey: AppSupportDefaults.categoriesLastModifiedKey)
    }

    static func saveBrainDumpTasks(_ tasks: [BrainDumpTask], modifiedAt: Date = Date()) {
        guard let data = try? JSONEncoder().encode(tasks) else { return }
        AppSupportDefaults.userDefaults.set(data, forKey: AppSupportDefaults.brainDumpTasksKey)
        AppSupportDefaults.userDefaults.set(modifiedAt, forKey: AppSupportDefaults.brainDumpTasksLastModifiedKey)
    }

    static func loadCategoriesLastModifiedAt() -> Date? {
        AppSupportDefaults.userDefaults.object(forKey: AppSupportDefaults.categoriesLastModifiedKey) as? Date
    }

    static func loadBrainDumpTasksLastModifiedAt() -> Date? {
        AppSupportDefaults.userDefaults.object(forKey: AppSupportDefaults.brainDumpTasksLastModifiedKey) as? Date
    }
}

enum AppSupportBootstrap {
    static var hasStartedInitialSync = false
}

struct AppSupportCloudSnapshot {
    let categories: [Category]
    let brainDumpTasks: [BrainDumpTask]
    let modifiedAt: Date
}

actor AppSupportCloudSyncManager {
    static let shared = AppSupportCloudSyncManager()

    private let container = CKContainer.default()
    private let recordID = CKRecord.ID(recordName: "app-support-state")
    private let recordType = "AppSupportState"
    private let schemaVersion: Int64 = 1
    private let mergeWindow: TimeInterval = 300

    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    func synchronize(localSnapshot: AppSupportCloudSnapshot?) async -> AppSupportCloudSnapshot? {
        guard await isiCloudAvailable() else { return nil }

        let remoteRecord = await fetchRemoteRecord()

        switch remoteRecord {
        case .success(let record):
            guard let remoteSnapshot = decodeSnapshot(from: record) else { return nil }

            guard let localSnapshot else {
                return remoteSnapshot
            }

            let timeDelta = remoteSnapshot.modifiedAt.timeIntervalSince(localSnapshot.modifiedAt)

            if timeDelta > mergeWindow {
                return remoteSnapshot
            }

            if -timeDelta > mergeWindow {
                await upload(snapshot: localSnapshot, existingRecord: record)
                return nil
            }

            let mergedSnapshot = mergeSnapshots(
                local: localSnapshot,
                remote: remoteSnapshot,
                preferLocal: localSnapshot.modifiedAt >= remoteSnapshot.modifiedAt
            )

            if mergedSnapshot.categories != remoteSnapshot.categories ||
                mergedSnapshot.brainDumpTasks != remoteSnapshot.brainDumpTasks {
                await upload(snapshot: mergedSnapshot, existingRecord: record)
            }

            if mergedSnapshot.categories != localSnapshot.categories ||
                mergedSnapshot.brainDumpTasks != localSnapshot.brainDumpTasks ||
                mergedSnapshot.modifiedAt != localSnapshot.modifiedAt {
                return mergedSnapshot
            }

            return nil

        case .notFound:
            if let localSnapshot {
                await upload(snapshot: localSnapshot, existingRecord: nil)
            }
            return nil

        case .failure:
            return nil
        }
    }

    func uploadLocalSnapshot(snapshot: AppSupportCloudSnapshot) async {
        guard await isiCloudAvailable() else { return }

        let remoteRecord = await fetchRemoteRecord()

        switch remoteRecord {
        case .success(let record):
            if let remoteSnapshot = decodeSnapshot(from: record) {
                let timeDelta = remoteSnapshot.modifiedAt.timeIntervalSince(snapshot.modifiedAt)

                if timeDelta > mergeWindow {
                    return
                }

                let mergedSnapshot = mergeSnapshots(
                    local: snapshot,
                    remote: remoteSnapshot,
                    preferLocal: snapshot.modifiedAt >= remoteSnapshot.modifiedAt
                )
                await upload(snapshot: mergedSnapshot, existingRecord: record)
                return
            }

            await upload(snapshot: snapshot, existingRecord: record)

        case .notFound:
            await upload(snapshot: snapshot, existingRecord: nil)

        case .failure:
            return
        }
    }

    private func isiCloudAvailable() async -> Bool {
        do {
            return try await container.accountStatus() == .available
        } catch {
            print("CloudKit: Failed to read iCloud account status for app support sync: \(error)")
            return false
        }
    }

    private func fetchRemoteRecord() async -> FetchResult {
        do {
            let record = try await privateDatabase.record(for: recordID)
            return .success(record)
        } catch let error as CKError {
            if error.code == .unknownItem {
                return .notFound
            }
            print("CloudKit: Failed to fetch remote app support state: \(error)")
            return .failure
        } catch {
            print("CloudKit: Failed to fetch remote app support state: \(error)")
            return .failure
        }
    }

    private func upload(snapshot: AppSupportCloudSnapshot, existingRecord: CKRecord?) async {
        guard let data = encodeSnapshot(snapshot) else { return }

        let record = existingRecord ?? CKRecord(recordType: recordType, recordID: recordID)
        record["schemaVersion"] = schemaVersion as NSNumber
        record["modifiedAt"] = snapshot.modifiedAt as NSDate
        record["payload"] = data as NSData

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            print("CloudKit: Failed to save remote app support state: \(error)")
        }
    }

    private func encodeSnapshot(_ snapshot: AppSupportCloudSnapshot) -> Data? {
        let payload = Payload(categories: snapshot.categories, brainDumpTasks: snapshot.brainDumpTasks)
        return try? JSONEncoder().encode(payload)
    }

    private func decodeSnapshot(from record: CKRecord) -> AppSupportCloudSnapshot? {
        guard let modifiedAt = record["modifiedAt"] as? Date,
              let payload = record["payload"] as? Data,
              let decoded = try? JSONDecoder().decode(Payload.self, from: payload) else {
            return nil
        }

        return AppSupportCloudSnapshot(
            categories: decoded.categories,
            brainDumpTasks: decoded.brainDumpTasks,
            modifiedAt: modifiedAt
        )
    }

    private func mergeSnapshots(
        local: AppSupportCloudSnapshot,
        remote: AppSupportCloudSnapshot,
        preferLocal: Bool
    ) -> AppSupportCloudSnapshot {
        AppSupportCloudSnapshot(
            categories: mergeCategories(local: local.categories, remote: remote.categories, preferLocal: preferLocal),
            brainDumpTasks: mergeBrainDumpTasks(local: local.brainDumpTasks, remote: remote.brainDumpTasks, preferLocal: preferLocal),
            modifiedAt: max(local.modifiedAt, remote.modifiedAt)
        )
    }

    private func mergeCategories(
        local: [Category],
        remote: [Category],
        preferLocal: Bool
    ) -> [Category] {
        var mergedByID: [UUID: Category] = [:]
        let firstPass = preferLocal ? remote : local
        let secondPass = preferLocal ? local : remote

        for category in firstPass {
            mergedByID[category.id] = category
        }

        for category in secondPass {
            mergedByID[category.id] = category
        }

        return mergedByID.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func mergeBrainDumpTasks(
        local: [BrainDumpTask],
        remote: [BrainDumpTask],
        preferLocal: Bool
    ) -> [BrainDumpTask] {
        var mergedByID: [UUID: BrainDumpTask] = [:]
        let firstPass = preferLocal ? remote : local
        let secondPass = preferLocal ? local : remote

        for task in firstPass {
            mergedByID[task.id] = task
        }

        for task in secondPass {
            mergedByID[task.id] = task
        }

        return sortedBrainDumpTasks(Array(mergedByID.values))
    }

    private enum FetchResult {
        case success(CKRecord)
        case notFound
        case failure
    }

    private struct Payload: Codable {
        let categories: [Category]
        let brainDumpTasks: [BrainDumpTask]
    }
}

@MainActor
class CategoryManager: ObservableObject {
    static let shared = CategoryManager()

    @Published var categories: [Category] = [] {
        didSet {
            guard !isApplyingRemoteSnapshot else { return }
            persistAndSync()
        }
    }

    private var isApplyingRemoteSnapshot = false

    init() {
        var loaded = AppSupportPersistence.loadCategories()
        // Silently add any default categories that are missing (e.g. after an app update)
        let existingNames = Set(loaded.map { $0.name.lowercased() })
        let missing = AppSupportPersistence.defaultCategories().filter { !existingNames.contains($0.name.lowercased()) }
        if !missing.isEmpty {
            loaded.append(contentsOf: missing)
            AppSupportPersistence.saveCategories(loaded)
        }
        self.categories = loaded
        startInitialSyncIfNeeded()
    }

    func applyCloudCategories(_ categories: [Category], modifiedAt: Date) {
        isApplyingRemoteSnapshot = true
        self.categories = categories
        AppSupportPersistence.saveCategories(categories, modifiedAt: modifiedAt)
        isApplyingRemoteSnapshot = false
    }

    private func persistAndSync() {
        let modifiedAt = Date()
        AppSupportPersistence.saveCategories(categories, modifiedAt: modifiedAt)

        Task {
            await AppSupportCloudSyncManager.shared.uploadLocalSnapshot(
                snapshot: AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    modifiedAt: max(
                        AppSupportPersistence.loadCategoriesLastModifiedAt() ?? modifiedAt,
                        AppSupportPersistence.loadBrainDumpTasksLastModifiedAt() ?? modifiedAt
                    )
                )
            )
        }
    }

    private func startInitialSyncIfNeeded() {
        guard !AppSupportBootstrap.hasStartedInitialSync else { return }
        AppSupportBootstrap.hasStartedInitialSync = true

        Task {
            let localModifiedAt = max(
                AppSupportPersistence.loadCategoriesLastModifiedAt() ?? .distantPast,
                AppSupportPersistence.loadBrainDumpTasksLastModifiedAt() ?? .distantPast
            )
            let localSnapshot: AppSupportCloudSnapshot? = localModifiedAt == .distantPast
                ? nil
                : AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    modifiedAt: localModifiedAt
                )
            let snapshot = await AppSupportCloudSyncManager.shared.synchronize(
                localSnapshot: localSnapshot
            )

            guard let snapshot else { return }

            await MainActor.run {
                CategoryManager.shared.applyCloudCategories(snapshot.categories, modifiedAt: snapshot.modifiedAt)
                BrainDumpManager.shared.applyCloudTasks(snapshot.brainDumpTasks, modifiedAt: snapshot.modifiedAt)
            }
        }
    }
}

enum AppTheme: String, CaseIterable, Identifiable {
    case sage, navy, rose, charcoal, sakura
    var id: String { self.rawValue }
    var name: String { self == .sakura ? "Sakura" : self.rawValue.capitalized }
    
    var bg: Color {
        switch self {
        case .sage: return Color(red: 0.20, green: 0.28, blue: 0.22)
        case .navy: return Color(red: 0.12, green: 0.18, blue: 0.28)
        case .rose: return Color(red: 0.24, green: 0.15, blue: 0.18)
        case .charcoal: return Color(red: 0.12, green: 0.12, blue: 0.12)
        case .sakura: return Color(red: 0.96, green: 0.90, blue: 0.92)
        }
    }
    var fieldBg: Color {
        switch self {
        case .sage: return Color(red: 0.16, green: 0.24, blue: 0.18)
        case .navy: return Color(red: 0.10, green: 0.15, blue: 0.24)
        case .rose: return Color(red: 0.20, green: 0.12, blue: 0.15)
        case .charcoal: return Color(red: 0.09, green: 0.09, blue: 0.09)
        case .sakura: return Color(red: 1.0, green: 0.95, blue: 0.96)
        }
    }
    var accent: Color {
        switch self {
        case .sage: return Color(red: 0.85, green: 0.78, blue: 0.58)
        case .navy: return Color(red: 0.75, green: 0.88, blue: 1.0)
        case .rose: return Color(red: 0.88, green: 0.68, blue: 0.72)
        case .charcoal: return Color(red: 0.80, green: 0.80, blue: 0.80)
        case .sakura: return Color(red: 0.85, green: 0.45, blue: 0.55)
        }
    }
    var shadowLight: Color {
        switch self {
        case .sage: return Color(red: 0.26, green: 0.34, blue: 0.28)
        case .navy: return Color(red: 0.18, green: 0.25, blue: 0.35)
        case .rose: return Color(red: 0.28, green: 0.18, blue: 0.22)
        case .charcoal: return Color(red: 0.16, green: 0.16, blue: 0.16)
        case .sakura: return Color(red: 1.0, green: 1.0, blue: 1.0)
        }
    }
    var shadowDark: Color {
        switch self {
        case .sage: return Color(red: 0.14, green: 0.20, blue: 0.16)
        case .navy: return Color(red: 0.08, green: 0.12, blue: 0.20)
        case .rose: return Color(red: 0.18, green: 0.10, blue: 0.13)
        case .charcoal: return Color(red: 0.08, green: 0.08, blue: 0.08)
        case .sakura: return Color(red: 0.85, green: 0.80, blue: 0.82)
        }
    }
    var taskTrack: Color {
        switch self {
        case .sage: return Color(red: 0.35, green: 0.48, blue: 0.38)
        case .navy: return Color(red: 0.18, green: 0.28, blue: 0.42)
        case .rose: return Color(red: 0.32, green: 0.20, blue: 0.25)
        case .charcoal: return Color(red: 0.20, green: 0.20, blue: 0.20)
        case .sakura: return Color(red: 0.92, green: 0.82, blue: 0.85)
        }
    }
    var textForeground: Color {
        switch self {
        case .sakura: return Color(red: 0.5, green: 0.1, blue: 0.25) // Plum red
        default: return .white
        }
    }
}

let aestheticColors: [RGB] = [
    // Nature & Earth
    RGB(r: 0.85, g: 0.78, b: 0.58), // Gold
    RGB(r: 0.75, g: 0.55, b: 0.45), // Muted Terracotta
    RGB(r: 0.45, g: 0.50, b: 0.35), // Olive
    RGB(r: 0.48, g: 0.62, b: 0.52), // Sage Green
    
    // Blues & Steels
    RGB(r: 0.40, g: 0.60, b: 0.70), // Slate Blue
    RGB(r: 0.65, g: 0.82, b: 0.95), // Soft Navy
    RGB(r: 0.30, g: 0.50, b: 0.70), // Deep Steel

    // Pinks & Purples
    RGB(r: 0.70, g: 0.40, b: 0.45), // Dusty Rose
    RGB(r: 0.88, g: 0.68, b: 0.72), // Blush
    RGB(r: 0.55, g: 0.50, b: 0.65), // Muted Purple
    RGB(r: 0.75, g: 0.65, b: 0.85), // Soft Lavender

    // Neutrals
    RGB(r: 0.60, g: 0.60, b: 0.60), // Mid Grey
    RGB(r: 0.45, g: 0.45, b: 0.45)  // Dark Grey
]

struct BrainDumpTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var scheduledDate: Date? = nil
    var completedDate: Date? = nil
    var reminderDueDate: Date? = nil
    var externalReminderId: String? = nil
}

private func brainDumpSortDate(for task: BrainDumpTask) -> Date? {
    task.scheduledDate ?? task.reminderDueDate
}

private func brainDumpTaskComesBefore(_ lhs: BrainDumpTask, _ rhs: BrainDumpTask) -> Bool {
    switch (brainDumpSortDate(for: lhs), brainDumpSortDate(for: rhs)) {
    case let (left?, right?):
        if left != right {
            return left < right
        }
    case (.some, nil):
        return true
    case (nil, .some):
        return false
    case (nil, nil):
        break
    }

    if lhs.isCompleted != rhs.isCompleted {
        return !lhs.isCompleted && rhs.isCompleted
    }

    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
}

private func sortedBrainDumpTasks(_ tasks: [BrainDumpTask]) -> [BrainDumpTask] {
    tasks.sorted(by: brainDumpTaskComesBefore)
}

@MainActor
class BrainDumpManager: ObservableObject {
    static let shared = BrainDumpManager()

    @Published var tasks: [BrainDumpTask] = [] {
        didSet {
            guard !isApplyingRemoteSnapshot else { return }
            persistAndSync()
        }
    }

    private var isApplyingRemoteSnapshot = false

    init() {
        self.tasks = AppSupportPersistence.loadBrainDumpTasks()
        sortTasks()
        startInitialSyncIfNeeded()
    }

    func sortTasks() {
        tasks = sortedBrainDumpTasks(tasks)
    }

    func save() {
        tasks = sortedBrainDumpTasks(tasks)
    }

    func applyCloudTasks(_ tasks: [BrainDumpTask], modifiedAt: Date) {
        isApplyingRemoteSnapshot = true
        self.tasks = sortedBrainDumpTasks(tasks)
        AppSupportPersistence.saveBrainDumpTasks(self.tasks, modifiedAt: modifiedAt)
        isApplyingRemoteSnapshot = false
    }

    func applySyncedReminderTasks(_ reminderTasks: [BrainDumpTask]) {
        let remoteReminderIDs = Set(reminderTasks.compactMap(\.externalReminderId))
        var mergedTasks = tasks

        for reminderTask in reminderTasks {
            if let index = mergedTasks.firstIndex(where: { $0.externalReminderId == reminderTask.externalReminderId }) {
                var updatedTask = mergedTasks[index]
                updatedTask.title = reminderTask.title
                updatedTask.isCompleted = reminderTask.isCompleted
                updatedTask.completedDate = reminderTask.completedDate
                updatedTask.reminderDueDate = reminderTask.reminderDueDate
                updatedTask.externalReminderId = reminderTask.externalReminderId
                mergedTasks[index] = updatedTask
                continue
            }

            if let index = preferredReminderMatchIndex(for: reminderTask, in: mergedTasks) {
                var matchedTask = mergedTasks[index]
                matchedTask.title = reminderTask.title
                matchedTask.isCompleted = reminderTask.isCompleted
                matchedTask.completedDate = reminderTask.completedDate
                matchedTask.reminderDueDate = reminderTask.reminderDueDate
                matchedTask.externalReminderId = reminderTask.externalReminderId
                mergedTasks[index] = matchedTask
                continue
            }

            mergedTasks.append(reminderTask)
        }

        mergedTasks.removeAll { task in
            guard let externalReminderId = task.externalReminderId else { return false }
            return !remoteReminderIDs.contains(externalReminderId)
        }

        mergedTasks = deduplicatedReminderTasks(mergedTasks)
        let sortedTasks = sortedBrainDumpTasks(mergedTasks)

        guard sortedTasks != tasks else { return }
        tasks = sortedTasks
    }

    func attachReminder(_ externalReminderId: String, dueDate: Date?, to taskID: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].externalReminderId = externalReminderId
        tasks[index].reminderDueDate = dueDate
        tasks = sortedBrainDumpTasks(tasks)
    }

    private func preferredReminderMatchIndex(
        for reminderTask: BrainDumpTask,
        in tasks: [BrainDumpTask]
    ) -> Int? {
        let candidates = tasks.indices.filter { index in
            let task = tasks[index]
            guard task.externalReminderId == nil else { return false }
            guard task.title.trimmingCharacters(in: .whitespacesAndNewlines)
                .localizedCaseInsensitiveCompare(
                    reminderTask.title.trimmingCharacters(in: .whitespacesAndNewlines)
                ) == .orderedSame else {
                return false
            }
            return task.isCompleted == reminderTask.isCompleted
        }

        return candidates.count == 1 ? candidates.first : nil
    }

    private func deduplicatedReminderTasks(_ tasks: [BrainDumpTask]) -> [BrainDumpTask] {
        var seenReminderIDs = Set<String>()
        var result: [BrainDumpTask] = []

        for task in tasks {
            guard let externalReminderId = task.externalReminderId else {
                result.append(task)
                continue
            }

            guard seenReminderIDs.insert(externalReminderId).inserted else { continue }
            result.append(task)
        }

        return result
    }

    private func persistAndSync() {
        let modifiedAt = Date()
        AppSupportPersistence.saveBrainDumpTasks(tasks, modifiedAt: modifiedAt)

        Task {
            await AppSupportCloudSyncManager.shared.uploadLocalSnapshot(
                snapshot: AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    modifiedAt: max(
                        AppSupportPersistence.loadCategoriesLastModifiedAt() ?? modifiedAt,
                        AppSupportPersistence.loadBrainDumpTasksLastModifiedAt() ?? modifiedAt
                    )
                )
            )
        }
    }

    private func startInitialSyncIfNeeded() {
        guard !AppSupportBootstrap.hasStartedInitialSync else { return }
        AppSupportBootstrap.hasStartedInitialSync = true

        Task {
            let localModifiedAt = max(
                AppSupportPersistence.loadCategoriesLastModifiedAt() ?? .distantPast,
                AppSupportPersistence.loadBrainDumpTasksLastModifiedAt() ?? .distantPast
            )
            let localSnapshot: AppSupportCloudSnapshot? = localModifiedAt == .distantPast
                ? nil
                : AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    modifiedAt: localModifiedAt
                )
            let snapshot = await AppSupportCloudSyncManager.shared.synchronize(
                localSnapshot: localSnapshot
            )

            guard let snapshot else { return }

            await MainActor.run {
                CategoryManager.shared.applyCloudCategories(snapshot.categories, modifiedAt: snapshot.modifiedAt)
                BrainDumpManager.shared.applyCloudTasks(snapshot.brainDumpTasks, modifiedAt: snapshot.modifiedAt)
            }
        }
    }
}
