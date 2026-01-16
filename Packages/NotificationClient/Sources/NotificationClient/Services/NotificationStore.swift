import Foundation
import SwiftData

/// Handles persistence for notification preferences and cached request statuses
actor NotificationStore {
    private let modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Preferences

    /// Fetch the current notification preferences (creates default if none exist)
    func fetchPreferences() async throws -> NotificationPreferences {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<NotificationPreferences>()
        let results = try context.fetch(descriptor)

        if let existing = results.first {
            return existing
        }

        // Create default preferences
        let defaults = NotificationPreferences()
        context.insert(defaults)
        try context.save()
        return defaults
    }

    /// Save notification preferences
    func savePreferences(_ preferences: NotificationPreferences) async throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<NotificationPreferences>()
        let results = try context.fetch(descriptor)

        // Delete existing preferences
        for existing in results {
            context.delete(existing)
        }

        // Insert new preferences
        context.insert(preferences)
        try context.save()
    }

    // MARK: - Cached Request Status

    /// Fetch all cached request statuses
    func fetchAllCachedStatuses() async throws -> [CachedRequestStatus] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedRequestStatus>(
            sortBy: [SortDescriptor(\.lastChecked, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch cached status for a specific request
    func fetchCachedStatus(requestID: Int) async throws -> CachedRequestStatus? {
        let context = ModelContext(modelContainer)
        var descriptor = FetchDescriptor<CachedRequestStatus>(
            predicate: #Predicate { $0.requestID == requestID }
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Update or insert a cached request status
    func upsertCachedStatus(
        requestID: Int,
        status: Int,
        mediaTitle: String,
        mediaType: String,
        serverID: String
    ) async throws {
        let context = ModelContext(modelContainer)

        if let existing = try await fetchCachedStatus(requestID: requestID) {
            // Update existing
            existing.status = status
            existing.mediaTitle = mediaTitle
            existing.mediaType = mediaType
            existing.lastChecked = Date()
        } else {
            // Insert new
            let cached = CachedRequestStatus(
                requestID: requestID,
                status: status,
                mediaTitle: mediaTitle,
                mediaType: mediaType,
                serverID: serverID
            )
            context.insert(cached)
        }

        try context.save()
    }

    /// Delete cached status for a request
    func deleteCachedStatus(requestID: Int) async throws {
        let context = ModelContext(modelContainer)
        if let existing = try await fetchCachedStatus(requestID: requestID) {
            context.delete(existing)
            try context.save()
        }
    }

    /// Delete all cached statuses for a server
    func deleteAllCachedStatuses(forServerID serverID: String) async throws {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<CachedRequestStatus>(
            predicate: #Predicate { $0.serverID == serverID }
        )
        let results = try context.fetch(descriptor)
        for status in results {
            context.delete(status)
        }
        try context.save()
    }
}
