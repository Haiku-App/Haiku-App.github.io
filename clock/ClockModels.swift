import SwiftUI
internal import Combine
import CloudKit
import WidgetKit
import Foundation
import AppIntents

enum AppSupportDefaults {
    static let userDefaults = UserDefaults(suiteName: "group.reswink.haiku") ?? UserDefaults.standard
    static let categoriesKey = "userCategories"
    static let categoriesLastModifiedKey = "userCategoriesLastModified"
    static let brainDumpTasksKey = "brainDumpTasks"
    static let brainDumpTasksLastModifiedKey = "brainDumpTasksLastModified"
    static let brainDumpListsKey = "brainDumpLists"
    static let brainDumpListsLastModifiedKey = "brainDumpListsLastModified"
    static let routinesKey = "savedRoutines"
    static let routinesLastModifiedKey = "savedRoutinesLastModified"
    static let activeRoutineSessionsKey = "activeRoutineSessions"
}

enum AppSupportNotifications {
    static let brainDumpTasksDidChange = "group.reswink.haiku.brainDumpTasksDidChange"
    static let brainDumpListsDidChange = "group.reswink.haiku.brainDumpListsDidChange"
    static let activeRoutineSessionsDidChange = "group.reswink.haiku.activeRoutineSessionsDidChange"
}

enum ClockTaskDisplayStyle: String, CaseIterable, Identifiable {
    case rings
    case sections

    static let storageKey = "clockTaskDisplayStyle"
    static let sharedStorageKey = "clockTaskDisplayStyleSetting"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rings: return "Rings"
        case .sections: return "Sections"
        }
    }
}

struct RGB: Codable, Equatable {
    var r: Double
    var g: Double
    var b: Double
    var color: Color { Color(red: r, green: g, blue: b) }
}

private func latestAppSupportModifiedAt(fallback: Date) -> Date {
    max(
        max(
            AppSupportPersistence.loadCategoriesLastModifiedAt() ?? fallback,
            AppSupportPersistence.loadBrainDumpTasksLastModifiedAt() ?? fallback
        ),
        max(
            AppSupportPersistence.loadBrainDumpListsLastModifiedAt() ?? fallback,
            AppSupportPersistence.loadRoutinesLastModifiedAt() ?? fallback
        )
    )
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

    static func loadBrainDumpLists() -> [BrainDumpList] {
        guard let data = AppSupportDefaults.userDefaults.data(forKey: AppSupportDefaults.brainDumpListsKey),
              let decoded = try? JSONDecoder().decode([BrainDumpList].self, from: data) else {
            return []
        }

        return sortedBrainDumpLists(decoded)
    }

    static func loadRoutines() -> [Routine] {
        guard let data = AppSupportDefaults.userDefaults.data(forKey: AppSupportDefaults.routinesKey),
              let decoded = try? JSONDecoder().decode([Routine].self, from: data) else {
            return []
        }

        return decoded
    }

    static func loadActiveRoutineSessions() -> [RoutineSession] {
        guard let data = AppSupportDefaults.userDefaults.data(forKey: AppSupportDefaults.activeRoutineSessionsKey),
              let decoded = try? JSONDecoder().decode([RoutineSession].self, from: data) else {
            return []
        }

        return decoded.sorted { $0.createdAt < $1.createdAt }
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
        WidgetCenter.shared.reloadAllTimelines()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppSupportNotifications.brainDumpTasksDidChange as CFString),
            nil,
            nil,
            true
        )
    }

    static func saveBrainDumpLists(_ lists: [BrainDumpList], modifiedAt: Date = Date()) {
        guard let data = try? JSONEncoder().encode(sortedBrainDumpLists(lists)) else { return }
        AppSupportDefaults.userDefaults.set(data, forKey: AppSupportDefaults.brainDumpListsKey)
        AppSupportDefaults.userDefaults.set(modifiedAt, forKey: AppSupportDefaults.brainDumpListsLastModifiedKey)
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppSupportNotifications.brainDumpListsDidChange as CFString),
            nil,
            nil,
            true
        )
    }

    static func saveRoutines(_ routines: [Routine], modifiedAt: Date = Date()) {
        guard let data = try? JSONEncoder().encode(routines) else { return }
        AppSupportDefaults.userDefaults.set(data, forKey: AppSupportDefaults.routinesKey)
        AppSupportDefaults.userDefaults.set(modifiedAt, forKey: AppSupportDefaults.routinesLastModifiedKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    static func saveActiveRoutineSessions(_ sessions: [RoutineSession]) {
        let sortedSessions = sessions.sorted { $0.createdAt < $1.createdAt }

        if let data = try? JSONEncoder().encode(sortedSessions) {
            AppSupportDefaults.userDefaults.set(data, forKey: AppSupportDefaults.activeRoutineSessionsKey)
        } else {
            AppSupportDefaults.userDefaults.removeObject(forKey: AppSupportDefaults.activeRoutineSessionsKey)
        }

        WidgetCenter.shared.reloadAllTimelines()
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(AppSupportNotifications.activeRoutineSessionsDidChange as CFString),
            nil,
            nil,
            true
        )
    }

    static func loadCategoriesLastModifiedAt() -> Date? {
        AppSupportDefaults.userDefaults.object(forKey: AppSupportDefaults.categoriesLastModifiedKey) as? Date
    }

    static func loadBrainDumpTasksLastModifiedAt() -> Date? {
        AppSupportDefaults.userDefaults.object(forKey: AppSupportDefaults.brainDumpTasksLastModifiedKey) as? Date
    }

    static func loadBrainDumpListsLastModifiedAt() -> Date? {
        AppSupportDefaults.userDefaults.object(forKey: AppSupportDefaults.brainDumpListsLastModifiedKey) as? Date
    }

    static func loadRoutinesLastModifiedAt() -> Date? {
        AppSupportDefaults.userDefaults.object(forKey: AppSupportDefaults.routinesLastModifiedKey) as? Date
    }

    static func toggleBrainDumpTaskCompletion(id: UUID) {
        var tasks = loadBrainDumpTasks()
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }

        tasks[index].isCompleted.toggle()
        tasks[index].completedDate = tasks[index].isCompleted ? Date() : nil

        saveBrainDumpTasks(sortedBrainDumpTasks(tasks))
    }

    static func setBrainDumpTaskCompletion(id: UUID, isCompleted: Bool) {
        var tasks = loadBrainDumpTasks()
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        guard tasks[index].isCompleted != isCompleted else { return }

        tasks[index].isCompleted = isCompleted
        tasks[index].completedDate = isCompleted ? Date() : nil

        saveBrainDumpTasks(sortedBrainDumpTasks(tasks))
    }

    static func toggleRoutineSessionItem(sessionId: UUID, itemId: UUID) {
        var sessions = loadActiveRoutineSessions()
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let itemIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }

        sessions[sessionIndex].items[itemIndex].isCompleted.toggle()

        if !sessions[sessionIndex].items.isEmpty && sessions[sessionIndex].items.allSatisfy(\.isCompleted) {
            sessions.removeAll { $0.id == sessionId }
        }

        saveActiveRoutineSessions(sessions)
    }

    static func setRoutineSessionItemCompletion(sessionId: UUID, itemId: UUID, isCompleted: Bool) {
        var sessions = loadActiveRoutineSessions()
        guard let sessionIndex = sessions.firstIndex(where: { $0.id == sessionId }),
              let itemIndex = sessions[sessionIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }
        guard sessions[sessionIndex].items[itemIndex].isCompleted != isCompleted else { return }

        sessions[sessionIndex].items[itemIndex].isCompleted = isCompleted

        if !sessions[sessionIndex].items.isEmpty && sessions[sessionIndex].items.allSatisfy(\.isCompleted) {
            sessions.removeAll { $0.id == sessionId }
        }

        saveActiveRoutineSessions(sessions)
    }
}

enum AppSupportBootstrap {
    static var hasStartedInitialSync = false
}

struct AppSupportCloudSnapshot {
    let categories: [Category]
    let brainDumpTasks: [BrainDumpTask]
    let brainDumpLists: [BrainDumpList]
    let routines: [Routine]
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
                mergedSnapshot.brainDumpTasks != remoteSnapshot.brainDumpTasks ||
                mergedSnapshot.brainDumpLists != remoteSnapshot.brainDumpLists ||
                mergedSnapshot.routines != remoteSnapshot.routines {
                await upload(snapshot: mergedSnapshot, existingRecord: record)
            }

            if mergedSnapshot.categories != localSnapshot.categories ||
                mergedSnapshot.brainDumpTasks != localSnapshot.brainDumpTasks ||
                mergedSnapshot.brainDumpLists != localSnapshot.brainDumpLists ||
                mergedSnapshot.routines != localSnapshot.routines ||
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
        let payload = Payload(
            categories: snapshot.categories,
            brainDumpTasks: snapshot.brainDumpTasks,
            brainDumpLists: snapshot.brainDumpLists,
            routines: snapshot.routines
        )
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
            brainDumpLists: decoded.brainDumpLists ?? [],
            routines: decoded.routines,
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
            brainDumpLists: mergeBrainDumpLists(local: local.brainDumpLists, remote: remote.brainDumpLists, preferLocal: preferLocal),
            routines: mergeRoutines(local: local.routines, remote: remote.routines, preferLocal: preferLocal),
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

        return Array(mergedByID.values).sorted { lhs, rhs in
            let leftDate = lhs.scheduledDate ?? lhs.reminderDueDate
            let rightDate = rhs.scheduledDate ?? rhs.reminderDueDate

            switch (leftDate, rightDate) {
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
    }

    private func mergeBrainDumpLists(
        local: [BrainDumpList],
        remote: [BrainDumpList],
        preferLocal: Bool
    ) -> [BrainDumpList] {
        var mergedByID: [UUID: BrainDumpList] = [:]
        let firstPass = preferLocal ? remote : local
        let secondPass = preferLocal ? local : remote

        for list in firstPass {
            mergedByID[list.id] = list
        }

        for list in secondPass {
            mergedByID[list.id] = list
        }

        return sortedBrainDumpLists(Array(mergedByID.values))
    }

    private func mergeRoutines(
        local: [Routine],
        remote: [Routine],
        preferLocal: Bool
    ) -> [Routine] {
        var mergedByID: [UUID: Routine] = [:]
        let firstPass = preferLocal ? remote : local
        let secondPass = preferLocal ? local : remote

        for routine in firstPass {
            mergedByID[routine.id] = routine
        }

        for routine in secondPass {
            mergedByID[routine.id] = routine
        }

        return Array(mergedByID.values).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private enum FetchResult {
        case success(CKRecord)
        case notFound
        case failure
    }

    private struct Payload: Codable {
        let categories: [Category]
        let brainDumpTasks: [BrainDumpTask]
        let brainDumpLists: [BrainDumpList]?
        let routines: [Routine]
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
                    brainDumpLists: AppSupportPersistence.loadBrainDumpLists(),
                    routines: AppSupportPersistence.loadRoutines(),
                    modifiedAt: latestAppSupportModifiedAt(fallback: modifiedAt)
                )
            )
        }
    }

    private func startInitialSyncIfNeeded() {
        guard !AppSupportBootstrap.hasStartedInitialSync else { return }
        AppSupportBootstrap.hasStartedInitialSync = true

        Task {
            let localModifiedAt = latestAppSupportModifiedAt(fallback: .distantPast)
            let localSnapshot: AppSupportCloudSnapshot? = localModifiedAt == .distantPast
                ? nil
                : AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    brainDumpLists: AppSupportPersistence.loadBrainDumpLists(),
                    routines: AppSupportPersistence.loadRoutines(),
                    modifiedAt: localModifiedAt
                )
            let snapshot = await AppSupportCloudSyncManager.shared.synchronize(
                localSnapshot: localSnapshot
            )

            guard let snapshot else { return }

            await MainActor.run {
                CategoryManager.shared.applyCloudCategories(snapshot.categories, modifiedAt: snapshot.modifiedAt)
                BrainDumpManager.shared.applyCloudBrainDump(tasks: snapshot.brainDumpTasks, lists: snapshot.brainDumpLists, modifiedAt: snapshot.modifiedAt)
                RoutineManager.shared.applyCloudRoutines(snapshot.routines, modifiedAt: snapshot.modifiedAt)
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

enum RoutineWeekday: Int, CaseIterable, Codable, Identifiable, Comparable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortLabel: String {
        let index = max(0, min(rawValue - 1, Calendar.current.shortWeekdaySymbols.count - 1))
        return Calendar.current.shortWeekdaySymbols[index]
    }

    var symbol: String {
        let index = max(0, min(rawValue - 1, Calendar.current.weekdaySymbols.count - 1))
        return Calendar.current.weekdaySymbols[index]
    }

    static func < (lhs: RoutineWeekday, rhs: RoutineWeekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct RoutineStep: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var durationMinutes: Int
    var rgb: RGB
    var categoryId: UUID? = nil
    var categoryName: String? = nil

    var color: Color { rgb.color }
}

struct Routine: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var preferredStartMinutes: Int = 8 * 60
    var autoScheduleDays: [RoutineWeekday] = []
    var steps: [RoutineStep]

    var totalDurationMinutes: Int {
        steps.reduce(0) { $0 + $1.durationMinutes }
    }

    var isAutoScheduleEnabled: Bool {
        !autoScheduleDays.isEmpty
    }
}

struct RoutineSession: Identifiable, Codable, Equatable {
    var id = UUID()
    var routineId: UUID
    var name: String
    var items: [SessionItem]
    var createdAt: Date
    
    var progress: Double {
        guard !items.isEmpty else { return 0 }
        return Double(items.filter(\.isCompleted).count) / Double(items.count)
    }
}

struct SessionItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var sourceStepId: UUID? = nil
    var title: String
    var isCompleted: Bool = false
}

private func sortedRoutines(_ routines: [Routine]) -> [Routine] {
    routines.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}

struct BrainDumpList: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var createdAt: Date = Date()
}

private func sortedBrainDumpLists(_ lists: [BrainDumpList]) -> [BrainDumpList] {
    lists.sorted {
        if $0.createdAt != $1.createdAt {
            return $0.createdAt < $1.createdAt
        }
        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
}

struct BrainDumpTask: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isCompleted: Bool = false
    var scheduledDate: Date? = nil
    var completedDate: Date? = nil
    var reminderDueDate: Date? = nil
    var externalReminderId: String? = nil
    var repeatFrequency: RepeatFrequency = .never
    var listId: UUID? = nil
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

func brainDumpInboxTasks(from tasks: [BrainDumpTask], now: Date = Date()) -> [BrainDumpTask] {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: now)

    return tasks.filter { task in
        if task.isCompleted {
            guard let completedDate = task.completedDate else { return false }
            return calendar.isDateInToday(completedDate)
        }

        if let date = task.scheduledDate ?? task.reminderDueDate {
            return calendar.startOfDay(for: date) <= today
        }

        return true
    }
}

func brainDumpCompletedArchiveTasks(from tasks: [BrainDumpTask], now: Date = Date()) -> [BrainDumpTask] {
    let calendar = Calendar.current

    return tasks.filter { task in
        guard task.isCompleted, let completedDate = task.completedDate else { return false }
        return !calendar.isDateInToday(completedDate)
    }
}

struct ToggleBrainDumpTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle To-Do Item"

    @Parameter(title: "Task ID")
    var taskID: String

    init() {}

    init(taskID: String) {
        self.taskID = taskID
    }

    func perform() async throws -> some IntentResult {
        guard let uuid = UUID(uuidString: taskID) else {
            return .result()
        }

        await MainActor.run {
            AppSupportPersistence.toggleBrainDumpTaskCompletion(id: uuid)
        }
        return .result()
    }
}

struct ToggleRoutineSessionItemIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Routine Item"

    @Parameter(title: "Session ID")
    var sessionID: String

    @Parameter(title: "Item ID")
    var itemID: String

    init() {}

    init(sessionID: String, itemID: String) {
        self.sessionID = sessionID
        self.itemID = itemID
    }

    func perform() async throws -> some IntentResult {
        guard let sessionUUID = UUID(uuidString: sessionID),
              let itemUUID = UUID(uuidString: itemID) else {
            return .result()
        }

        await MainActor.run {
            AppSupportPersistence.toggleRoutineSessionItem(sessionId: sessionUUID, itemId: itemUUID)
        }
        return .result()
    }
}

@MainActor
class BrainDumpManager: ObservableObject {
    static let shared = BrainDumpManager()

    @Published var tasks: [BrainDumpTask] = [] {
        didSet {
            guard !isApplyingRemoteSnapshot, !isSynchronizingSharedState else { return }
            persistTasksAndSync()
        }
    }

    @Published var lists: [BrainDumpList] = [] {
        didSet {
            guard !isApplyingRemoteSnapshot, !isSynchronizingSharedState else { return }
            persistListsAndSync()
        }
    }

    @Published var activeRoutineSessions: [RoutineSession] = [] {
        didSet {
            guard !isSynchronizingSharedState else { return }
            persistActiveRoutineSessions()
        }
    }

    private var isApplyingRemoteSnapshot = false
    private var isSynchronizingSharedState = false

    init() {
        self.tasks = AppSupportPersistence.loadBrainDumpTasks()
        self.lists = AppSupportPersistence.loadBrainDumpLists()
        loadActiveRoutineSessions()
        sortTasks()
        startObservingSharedStore()
        startInitialSyncIfNeeded()
    }

    deinit {
        CFNotificationCenterRemoveEveryObserver(
            CFNotificationCenterGetDarwinNotifyCenter(),
            Unmanaged.passUnretained(self).toOpaque()
        )
    }

    var hasActiveRoutineSessions: Bool {
        !activeRoutineSessions.isEmpty
    }

    func startRoutine(_ routine: Routine) {
        let session = RoutineSession(
            routineId: routine.id,
            name: routine.name,
            items: routine.steps.map { SessionItem(sourceStepId: $0.id, title: $0.title) },
            createdAt: Date()
        )
        activeRoutineSessions.removeAll { $0.routineId == routine.id }
        activeRoutineSessions.append(session)
        activeRoutineSessions.sort { $0.createdAt < $1.createdAt }
    }

    func toggleRoutineItem(_ itemId: UUID, in sessionId: UUID) {
        guard let sessionIndex = activeRoutineSessions.firstIndex(where: { $0.id == sessionId }),
              let itemIndex = activeRoutineSessions[sessionIndex].items.firstIndex(where: { $0.id == itemId }) else {
            return
        }

        activeRoutineSessions[sessionIndex].items[itemIndex].isCompleted.toggle()
    }

    func clearRoutineSession(_ sessionId: UUID) {
        activeRoutineSessions.removeAll { $0.id == sessionId }
    }

    func clearAllRoutineSessions() {
        activeRoutineSessions = []
    }

    func removeActiveRoutineSessions(for routineId: UUID) {
        activeRoutineSessions.removeAll { $0.routineId == routineId }
    }

    func removeOrphanedRoutineSessions(validRoutineIDs: Set<UUID>) {
        activeRoutineSessions.removeAll { !validRoutineIDs.contains($0.routineId) }
    }

    func session(for sessionId: UUID) -> RoutineSession? {
        activeRoutineSessions.first(where: { $0.id == sessionId })
    }

    func refreshActiveRoutineSessions(for routine: Routine) {
        var didChange = false
        for index in activeRoutineSessions.indices {
            guard activeRoutineSessions[index].routineId == routine.id else { continue }
            activeRoutineSessions[index].name = routine.name
            activeRoutineSessions[index].items = routine.steps.map { step in
                let existingCompletion = activeRoutineSessions[index].items
                    .first(where: { $0.sourceStepId == step.id })?
                    .isCompleted ?? false
                return SessionItem(sourceStepId: step.id, title: step.title, isCompleted: existingCompletion)
            }
            didChange = true
        }

        if didChange {
            activeRoutineSessions.sort { $0.createdAt < $1.createdAt }
        }
    }

    private func persistActiveRoutineSessions() {
        AppSupportPersistence.saveActiveRoutineSessions(activeRoutineSessions)
    }

    private func loadActiveRoutineSessions() {
        let savedSessions = AppSupportPersistence.loadActiveRoutineSessions()
        if !savedSessions.isEmpty {
            activeRoutineSessions = savedSessions
            return
        }

        // Migrate from the original single-active-routine storage if present.
        let legacyName = AppSupportDefaults.userDefaults.string(forKey: "activeRoutineName")
        if let data = AppSupportDefaults.userDefaults.data(forKey: "activeRoutineTasks"),
           let legacyItems = try? JSONDecoder().decode([SessionItem].self, from: data),
           let legacyName,
           !legacyItems.isEmpty {
            let matchedRoutineId = AppSupportPersistence.loadRoutines()
                .first(where: { $0.name.localizedCaseInsensitiveCompare(legacyName) == .orderedSame })?
                .id ?? UUID()
            activeRoutineSessions = [
                RoutineSession(
                    routineId: matchedRoutineId,
                    name: legacyName,
                    items: legacyItems,
                    createdAt: Date()
                )
            ]
        } else {
            activeRoutineSessions = []
        }

        AppSupportDefaults.userDefaults.removeObject(forKey: "activeRoutineName")
        AppSupportDefaults.userDefaults.removeObject(forKey: "activeRoutineTasks")
    }

    func reloadFromSharedStoreIfNeeded() {
        let sharedTasks = AppSupportPersistence.loadBrainDumpTasks()
        let sharedLists = AppSupportPersistence.loadBrainDumpLists()
        let sharedSessions = AppSupportPersistence.loadActiveRoutineSessions()

        guard sharedTasks != tasks || sharedLists != lists || sharedSessions != activeRoutineSessions else { return }

        isSynchronizingSharedState = true
        if sharedTasks != tasks {
            tasks = sharedTasks
        }
        if sharedLists != lists {
            lists = sharedLists
        }
        if sharedSessions != activeRoutineSessions {
            activeRoutineSessions = sharedSessions
        }
        isSynchronizingSharedState = false
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

    func applyCloudBrainDump(tasks: [BrainDumpTask], lists: [BrainDumpList], modifiedAt: Date) {
        isApplyingRemoteSnapshot = true
        self.lists = sortedBrainDumpLists(lists)
        self.tasks = sortedBrainDumpTasks(tasks)
        AppSupportPersistence.saveBrainDumpLists(self.lists, modifiedAt: modifiedAt)
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

    private func persistTasksAndSync() {
        let modifiedAt = Date()
        AppSupportPersistence.saveBrainDumpTasks(tasks, modifiedAt: modifiedAt)
        uploadSupportSnapshot(modifiedAt: modifiedAt)
    }

    private func persistListsAndSync() {
        let modifiedAt = Date()
        AppSupportPersistence.saveBrainDumpLists(lists, modifiedAt: modifiedAt)
        uploadSupportSnapshot(modifiedAt: modifiedAt)
    }

    private func uploadSupportSnapshot(modifiedAt: Date) {
        Task {
            await AppSupportCloudSyncManager.shared.uploadLocalSnapshot(
                snapshot: AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    brainDumpLists: AppSupportPersistence.loadBrainDumpLists(),
                    routines: AppSupportPersistence.loadRoutines(),
                    modifiedAt: latestAppSupportModifiedAt(fallback: modifiedAt)
                )
            )
        }
    }

    private func startInitialSyncIfNeeded() {
        guard !AppSupportBootstrap.hasStartedInitialSync else { return }
        AppSupportBootstrap.hasStartedInitialSync = true

        Task {
            let localModifiedAt = latestAppSupportModifiedAt(fallback: .distantPast)
            let localSnapshot: AppSupportCloudSnapshot? = localModifiedAt == .distantPast
                ? nil
                : AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    brainDumpLists: AppSupportPersistence.loadBrainDumpLists(),
                    routines: AppSupportPersistence.loadRoutines(),
                    modifiedAt: localModifiedAt
                )
            let snapshot = await AppSupportCloudSyncManager.shared.synchronize(
                localSnapshot: localSnapshot
            )

            guard let snapshot else { return }

            await MainActor.run {
                CategoryManager.shared.applyCloudCategories(snapshot.categories, modifiedAt: snapshot.modifiedAt)
                BrainDumpManager.shared.applyCloudBrainDump(tasks: snapshot.brainDumpTasks, lists: snapshot.brainDumpLists, modifiedAt: snapshot.modifiedAt)
                RoutineManager.shared.applyCloudRoutines(snapshot.routines, modifiedAt: snapshot.modifiedAt)
            }
        }
    }

    private func startObservingSharedStore() {
        let observer = Unmanaged.passUnretained(self).toOpaque()
        let center = CFNotificationCenterGetDarwinNotifyCenter()
        let callback: CFNotificationCallback = { _, observer, _, _, _ in
            guard let observer else { return }
            let manager = Unmanaged<BrainDumpManager>.fromOpaque(observer).takeUnretainedValue()
            Task { @MainActor in
                manager.reloadFromSharedStoreIfNeeded()
            }
        }

        CFNotificationCenterAddObserver(
            center,
            observer,
            callback,
            AppSupportNotifications.brainDumpTasksDidChange as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            observer,
            callback,
            AppSupportNotifications.brainDumpListsDidChange as CFString,
            nil,
            .deliverImmediately
        )
        CFNotificationCenterAddObserver(
            center,
            observer,
            callback,
            AppSupportNotifications.activeRoutineSessionsDidChange as CFString,
            nil,
            .deliverImmediately
        )
    }
}

@MainActor
class RoutineManager: ObservableObject {
    static let shared = RoutineManager()

    @Published var routines: [Routine] = [] {
        didSet {
            guard !isApplyingRemoteSnapshot else { return }
            persistAndSync()
        }
    }

    private var isApplyingRemoteSnapshot = false

    init() {
        self.routines = sortedRoutines(AppSupportPersistence.loadRoutines())
        startInitialSyncIfNeeded()
    }

    func saveRoutine(_ routine: Routine) {
        let normalized = normalize(routine)
        if let index = routines.firstIndex(where: { $0.id == normalized.id }) {
            routines[index] = normalized
        } else {
            routines.append(normalized)
        }
        routines = sortedRoutines(routines)
        BrainDumpManager.shared.refreshActiveRoutineSessions(for: normalized)
    }

    func deleteRoutine(_ routine: Routine) {
        BrainDumpManager.shared.removeActiveRoutineSessions(for: routine.id)
        routines.removeAll { $0.id == routine.id }
    }

    func applyCloudRoutines(_ routines: [Routine], modifiedAt: Date) {
        isApplyingRemoteSnapshot = true
        self.routines = sortedRoutines(routines.map(normalize))
        AppSupportPersistence.saveRoutines(self.routines, modifiedAt: modifiedAt)
        isApplyingRemoteSnapshot = false
        BrainDumpManager.shared.removeOrphanedRoutineSessions(validRoutineIDs: Set(self.routines.map(\.id)))
    }

    private func normalize(_ routine: Routine) -> Routine {
        var copy = routine
        copy.name = routine.name.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.preferredStartMinutes = min(max(copy.preferredStartMinutes, 0), 1435)
        copy.autoScheduleDays = Array(Set(copy.autoScheduleDays)).sorted()
        copy.steps = copy.steps.compactMap { step in
            let trimmedTitle = step.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedTitle.isEmpty else { return nil }

            var normalizedStep = step
            normalizedStep.title = trimmedTitle
            normalizedStep.durationMinutes = min(max(step.durationMinutes, 5), 240)
            return normalizedStep
        }
        return copy
    }

    private func persistAndSync() {
        let modifiedAt = Date()
        AppSupportPersistence.saveRoutines(routines, modifiedAt: modifiedAt)

        Task {
            await AppSupportCloudSyncManager.shared.uploadLocalSnapshot(
                snapshot: AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    brainDumpLists: AppSupportPersistence.loadBrainDumpLists(),
                    routines: AppSupportPersistence.loadRoutines(),
                    modifiedAt: latestAppSupportModifiedAt(fallback: modifiedAt)
                )
            )
        }
    }

    private func startInitialSyncIfNeeded() {
        guard !AppSupportBootstrap.hasStartedInitialSync else { return }
        AppSupportBootstrap.hasStartedInitialSync = true

        Task {
            let localModifiedAt = latestAppSupportModifiedAt(fallback: .distantPast)
            let localSnapshot: AppSupportCloudSnapshot? = localModifiedAt == .distantPast
                ? nil
                : AppSupportCloudSnapshot(
                    categories: AppSupportPersistence.loadCategories(),
                    brainDumpTasks: AppSupportPersistence.loadBrainDumpTasks(),
                    brainDumpLists: AppSupportPersistence.loadBrainDumpLists(),
                    routines: AppSupportPersistence.loadRoutines(),
                    modifiedAt: localModifiedAt
                )
            let snapshot = await AppSupportCloudSyncManager.shared.synchronize(
                localSnapshot: localSnapshot
            )

            guard let snapshot else { return }

            await MainActor.run {
                CategoryManager.shared.applyCloudCategories(snapshot.categories, modifiedAt: snapshot.modifiedAt)
                BrainDumpManager.shared.applyCloudBrainDump(tasks: snapshot.brainDumpTasks, lists: snapshot.brainDumpLists, modifiedAt: snapshot.modifiedAt)
                RoutineManager.shared.applyCloudRoutines(snapshot.routines, modifiedAt: snapshot.modifiedAt)
            }
        }
    }
}
import SwiftUI

enum AppTab: String, Codable, CaseIterable, Identifiable {
    case clock, weekly, todo, routines, analytics, profile
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .clock: return "clock"
        case .weekly: return "calendar"
        case .todo: return "list.bullet"
        case .routines: return "rectangle.stack.badge.plus"
        case .analytics: return "chart.pie"
        case .profile: return "person"
        }
    }
    
    var text: String {
        switch self {
        case .clock: return "Clock"
        case .weekly: return "Weekly"
        case .todo: return "To-Do"
        case .routines: return "Routines"
        case .analytics: return "Analytics"
        case .profile: return "Profile"
        }
    }
}

class TabManager: ObservableObject {
    static let shared = TabManager()
    
    @AppStorage("tabOrder") private var tabOrderString: String = "clock,weekly,todo,routines,analytics,profile"
    @AppStorage("hiddenTabs") private var hiddenTabsString: String = ""
    
    @Published var tabs: [AppTab] = []
    @Published var hiddenTabs: Set<AppTab> = []
    
    init() {
        load()
    }
    
    private func load() {
        let order = tabOrderString.split(separator: ",").compactMap { AppTab(rawValue: String($0)) }
        let missing = AppTab.allCases.filter { !order.contains($0) }
        tabs = order + missing
        
        let hidden = hiddenTabsString.split(separator: ",").compactMap { AppTab(rawValue: String($0)) }
        hiddenTabs = Set(hidden)
    }
    
    func save() {
        tabOrderString = tabs.map { $0.rawValue }.joined(separator: ",")
        hiddenTabsString = hiddenTabs.map { $0.rawValue }.joined(separator: ",")
    }
    
    var visibleTabs: [AppTab] {
        tabs.filter { !hiddenTabs.contains($0) || $0 == .profile }
    }
    
    func isHidden(_ tab: AppTab) -> Bool {
        tab != .profile && hiddenTabs.contains(tab)
    }
    
    func toggleHidden(_ tab: AppTab) {
        if tab == .profile { return }
        if hiddenTabs.contains(tab) {
            hiddenTabs.remove(tab)
        } else {
            hiddenTabs.insert(tab)
        }
        save()
    }
    
    func moveTab(from source: IndexSet, to destination: Int) {
        tabs.move(fromOffsets: source, toOffset: destination)
        save()
    }
}
