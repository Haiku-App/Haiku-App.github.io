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

            if remoteSnapshot.modifiedAt.timeIntervalSince(localModifiedAt) > 1 {
                return remoteSnapshot
            }

            if localModifiedAt.timeIntervalSince(remoteSnapshot.modifiedAt) > 1 {
                await upload(tasksByDate: localTasksByDate, modifiedAt: localModifiedAt, existingRecord: record)
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
            if let remoteSnapshot = decodeSnapshot(from: record),
               remoteSnapshot.modifiedAt.timeIntervalSince(modifiedAt) > 1 {
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

    private enum FetchResult {
        case success(CKRecord)
        case notFound
        case failure
    }
}
