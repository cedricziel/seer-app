import Foundation
import JellyfinClient
import SeerCore
import SwiftData

/// Handles syncing of library metadata
@MainActor
public final class LibrarySyncService {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Syncs all libraries from the server
    public func syncLibraries(
        serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        let serverLibraries = try await service.getLibraries()

        // Fetch existing cached libraries for this server
        let configID = serverConfig.id
        let descriptor = FetchDescriptor<CachedLibrary>(
            predicate: #Predicate { $0.serverConfigurationID == configID }
        )
        let existingLibraries = try modelContext.fetch(descriptor)
        let existingIds = Set(existingLibraries.map(\.id))
        let serverIds = Set(serverLibraries.map(\.id))

        // Remove libraries that no longer exist on server
        for library in existingLibraries where !serverIds.contains(library.id) {
            modelContext.delete(library)
        }

        // Update or create libraries
        for serverLibrary in serverLibraries {
            if let existing = existingLibraries.first(where: { $0.id == serverLibrary.id }) {
                // Update existing
                existing.name = serverLibrary.name
                existing.collectionType = serverLibrary.collectionType?.rawValue
                existing.imageBlurHashPrimary = serverLibrary.imageBlurHashes?.primary?.values.first
                existing.lastSyncedAt = Date()
            } else {
                // Create new
                let cached = CachedLibrary(
                    id: serverLibrary.id,
                    serverConfigurationID: serverConfig.id,
                    name: serverLibrary.name,
                    collectionType: serverLibrary.collectionType?.rawValue,
                    lastSyncedAt: Date(),
                    imageBlurHashPrimary: serverLibrary.imageBlurHashes?.primary?.values.first
                )
                modelContext.insert(cached)
            }
        }

        try modelContext.save()
    }

    /// Gets all cached libraries for a server
    public func getCachedLibraries(for serverConfigurationID: UUID) throws -> [CachedLibrary] {
        let descriptor = FetchDescriptor<CachedLibrary>(
            predicate: #Predicate { $0.serverConfigurationID == serverConfigurationID },
            sortBy: [SortDescriptor(\.name)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Removes all cached libraries for a server
    public func removeLibraries(for serverConfigurationID: UUID) throws {
        let descriptor = FetchDescriptor<CachedLibrary>(
            predicate: #Predicate { $0.serverConfigurationID == serverConfigurationID }
        )
        let libraries = try modelContext.fetch(descriptor)
        for library in libraries {
            modelContext.delete(library)
        }
        try modelContext.save()
    }
}
