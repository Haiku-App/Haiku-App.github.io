import CloudKit
import Foundation

struct TaskCloudSnapshot {
    let tasksByDate: [Date: [ClockTask]]
    let modifiedAt: Date
}

actor TaskCloudSyncManager {
    static let shared = TaskCloudSyncManager()

    private let container = CKContainer.default()
    private let recordID = CKRecord.ID(recordName: "task-state")
    private let recordType = "TaskState"
    private let schemaVersion: Int64 = 1
    private let mergeWindow: TimeInterval = 300

    private var privateDatabase: CKDatabase {
        container.privateCloudDatabase
    }

    func synchronize(localTasksByDate: [Date: [ClockTask]], localModifiedAt: Date?) async -> TaskCloudSnapshot? {
        guard await isiCloudAvailable() else { return nil }

        let remoteRecord = await fetchRemoteRecord()

        switch remoteRecord {
        case .success(let record):
            guard let remoteSnapshot = decodeSnapshot(from: record) else { return nil }

            guard let localModifiedAt else {
                return remoteSnapshot
            }

            let timeDelta = remoteSnapshot.modifiedAt.timeIntervalSince(localModifiedAt)

            if timeDelta > mergeWindow {
                return remoteSnapshot
            }

            if -timeDelta > mergeWindow {
                await upload(tasksByDate: localTasksByDate, modifiedAt: localModifiedAt, existingRecord: record)
                return nil
            }

            let preferLocal = localModifiedAt >= remoteSnapshot.modifiedAt
            let mergedTasks = mergeSnapshots(
                local: localTasksByDate,
                remote: remoteSnapshot.tasksByDate,
                preferLocal: preferLocal
            )
            let mergedModifiedAt = max(localModifiedAt, remoteSnapshot.modifiedAt)

            if mergedTasks != remoteSnapshot.tasksByDate {
                await upload(tasksByDate: mergedTasks, modifiedAt: mergedModifiedAt, existingRecord: record)
            }

            if mergedTasks != localTasksByDate || mergedModifiedAt != localModifiedAt {
                return TaskCloudSnapshot(tasksByDate: mergedTasks, modifiedAt: mergedModifiedAt)
            }

            return nil

        case .notFound:
            if let localModifiedAt {
                await upload(tasksByDate: localTasksByDate, modifiedAt: localModifiedAt, existingRecord: nil)
            }
            return nil

        case .failure:
            return nil
        }
    }

    func uploadLocalSnapshot(tasksByDate: [Date: [ClockTask]], modifiedAt: Date) async {
        guard await isiCloudAvailable() else { return }

        let remoteRecord = await fetchRemoteRecord()

        switch remoteRecord {
        case .success(let record):
            if let remoteSnapshot = decodeSnapshot(from: record) {
                let timeDelta = remoteSnapshot.modifiedAt.timeIntervalSince(modifiedAt)

                if timeDelta > mergeWindow {
                    return
                }

                let mergedTasks = mergeSnapshots(
                    local: tasksByDate,
                    remote: remoteSnapshot.tasksByDate,
                    preferLocal: modifiedAt >= remoteSnapshot.modifiedAt
                )
                let mergedModifiedAt = max(modifiedAt, remoteSnapshot.modifiedAt)

                await upload(tasksByDate: mergedTasks, modifiedAt: mergedModifiedAt, existingRecord: record)
                return
            }

            await upload(tasksByDate: tasksByDate, modifiedAt: modifiedAt, existingRecord: record)

        case .notFound:
            await upload(tasksByDate: tasksByDate, modifiedAt: modifiedAt, existingRecord: nil)

        case .failure:
            return
        }
    }

    private func isiCloudAvailable() async -> Bool {
        do {
            return try await container.accountStatus() == .available
        } catch {
            print("CloudKit: Failed to read iCloud account status: \(error)")
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
            print("CloudKit: Failed to fetch remote task state: \(error)")
            return .failure
        } catch {
            print("CloudKit: Failed to fetch remote task state: \(error)")
            return .failure
        }
    }

    private func upload(tasksByDate: [Date: [ClockTask]], modifiedAt: Date, existingRecord: CKRecord?) async {
        guard let data = SharedTaskManager.encodeTaskGroups(tasksByDate: tasksByDate) else { return }

        let record = existingRecord ?? CKRecord(recordType: recordType, recordID: recordID)
        record["schemaVersion"] = schemaVersion as NSNumber
        record["modifiedAt"] = modifiedAt as NSDate
        record["payload"] = data as NSData

        do {
            _ = try await privateDatabase.save(record)
        } catch {
            print("CloudKit: Failed to save remote task state: \(error)")
        }
    }

    private func decodeSnapshot(from record: CKRecord) -> TaskCloudSnapshot? {
        guard let modifiedAt = record["modifiedAt"] as? Date,
              let payload = record["payload"] as? Data,
              let tasksByDate = SharedTaskManager.decodeTaskGroups(from: payload) else {
            return nil
        }

        return TaskCloudSnapshot(tasksByDate: tasksByDate, modifiedAt: modifiedAt)
    }

    private func mergeSnapshots(
        local: [Date: [ClockTask]],
        remote: [Date: [ClockTask]],
        preferLocal: Bool
    ) -> [Date: [ClockTask]] {
        let allDates = Set(local.keys).union(remote.keys)
        var merged: [Date: [ClockTask]] = [:]

        for date in allDates {
            let mergedTasks = mergeTasks(
                local: local[date, default: []],
                remote: remote[date, default: []],
                preferLocal: preferLocal
            )

            if !mergedTasks.isEmpty {
                merged[date] = mergedTasks
            }
        }

        return merged
    }

    private func mergeTasks(
        local: [ClockTask],
        remote: [ClockTask],
        preferLocal: Bool
    ) -> [ClockTask] {
        var mergedByID: [UUID: ClockTask] = [:]
        let firstPass = preferLocal ? remote : local
        let secondPass = preferLocal ? local : remote

        for task in firstPass {
            mergedByID[task.id] = task
        }

        for task in secondPass {
            mergedByID[task.id] = task
        }

        return mergedByID.values.sorted { lhs, rhs in
            if lhs.startMinutes != rhs.startMinutes {
                return lhs.startMinutes < rhs.startMinutes
            }

            if lhs.endMinutes != rhs.endMinutes {
                return lhs.endMinutes < rhs.endMinutes
            }

            if lhs.title != rhs.title {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }

            return lhs.id.uuidString < rhs.id.uuidString
        }
    }

    private enum FetchResult {
        case success(CKRecord)
        case notFound
        case failure
    }
}
