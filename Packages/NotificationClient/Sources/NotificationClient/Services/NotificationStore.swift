import Foundation
import SwiftData

/// Value snapshot of a `CachedRequestStatus` row. The store hands these out
/// instead of `@Model` instances so callers never touch a model whose owning
/// `ModelContext` has gone away.
struct CachedRequestStatusSnapshot: Equatable {
    let requestID: Int
    let status: Int
    let mediaTitle: String
    let mediaType: String
    let serverID: String
    let lastChecked: Date
}

/// Handles persistence for notification preferences and cached request statuses.
///
/// Every operation fetches, mutates and saves on a single `ModelContext`.
/// Mutating a model fetched from one context and saving a different one is
/// a silent no-op in SwiftData, which previously caused status updates to
/// never persist and the same "request approved" notification to fire on
/// every poll.
actor NotificationStore {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Preferences

    /// Fetch the current notification preferences (defaults if none are stored)
    func fetchPreferences() throws -> NotificationPreferenceValues {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<NotificationPreferences>()
        descriptor.fetchLimit = 1
        guard let existing = try context.fetch(descriptor).first else {
            return NotificationPreferenceValues()
        }
        return existing.values
    }

    /// Save notification preferences, updating the stored row in place
    func savePreferences(_ values: NotificationPreferenceValues) throws {
        let context = ModelContext(modelContainer)
        let rows = try context.fetch(FetchDescriptor<NotificationPreferences>())

        if let first = rows.first {
            first.apply(values)
            // Collapse any stray duplicate rows
            for extra in rows.dropFirst() {
                context.delete(extra)
            }
        } else {
            context.insert(NotificationPreferences(values: values))
        }

        try context.save()
    }

    // MARK: - Cached Request Status

    /// Fetch all cached request statuses for a server
    func fetchAllCachedStatuses(forServerID serverID: String) throws -> [CachedRequestStatusSnapshot] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedRequestStatus>(
            predicate: #Predicate { $0.serverID == serverID },
            sortBy: [SortDescriptor(\.lastChecked, order: .reverse)]
        )
        return try context.fetch(descriptor).map(\.snapshot)
    }

    /// Fetch cached status for a specific request on a server
    func fetchCachedStatus(requestID: Int, serverID: String) throws -> CachedRequestStatusSnapshot? {
        let context = ModelContext(modelContainer)
        return try Self.fetchRow(requestID: requestID, serverID: serverID, in: context)?.snapshot
    }

    /// Update or insert a cached request status
    func upsertCachedStatus(
        requestID: Int,
        status: Int,
        mediaTitle: String,
        mediaType: String,
        serverID: String
    ) throws {
        let context = ModelContext(modelContainer)

        if let existing = try Self.fetchRow(requestID: requestID, serverID: serverID, in: context) {
            existing.status = status
            existing.mediaTitle = mediaTitle
            existing.mediaType = mediaType
            existing.lastChecked = Date()
        } else {
            context.insert(
                CachedRequestStatus(
                    requestID: requestID,
                    status: status,
                    mediaTitle: mediaTitle,
                    mediaType: mediaType,
                    serverID: serverID
                )
            )
        }

        try context.save()
    }

    /// Delete cached status for a request on a server
    func deleteCachedStatus(requestID: Int, serverID: String) throws {
        let context = ModelContext(modelContainer)
        guard let existing = try Self.fetchRow(requestID: requestID, serverID: serverID, in: context) else {
            return
        }
        context.delete(existing)
        try context.save()
    }

    /// Delete all cached statuses for a server
    func deleteAllCachedStatuses(forServerID serverID: String) throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedRequestStatus>(
            predicate: #Predicate { $0.serverID == serverID }
        )
        for status in try context.fetch(descriptor) {
            context.delete(status)
        }
        try context.save()
    }

    // MARK: - Private

    private static func fetchRow(
        requestID: Int,
        serverID: String,
        in context: ModelContext
    ) throws -> CachedRequestStatus? {
        var descriptor = FetchDescriptor<CachedRequestStatus>(
            predicate: #Predicate { $0.requestID == requestID && $0.serverID == serverID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }
}

private extension CachedRequestStatus {
    var snapshot: CachedRequestStatusSnapshot {
        CachedRequestStatusSnapshot(
            requestID: requestID,
            status: status,
            mediaTitle: mediaTitle,
            mediaType: mediaType,
            serverID: serverID,
            lastChecked: lastChecked
        )
    }
}
