import AppIntents
import Foundation
import SwiftData

/// Entity query for `MediaItemEntity` — reads exclusively from the
/// `OfflineSync` SwiftData cache. Voice queries and Spotlight surfaces
/// MUST feel instant, so this query never touches the network.
public struct MediaItemEntityQuery: EntityStringQuery {
    public init() {}

    /// Resolve specific entities by id (used after Shortcut configuration).
    public func entities(for identifiers: [MediaItemEntity.ID]) async throws -> [MediaItemEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<CachedMediaItem>(
                predicate: #Predicate { identifiers.contains($0.id) }
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return rows.map(Self.entity)
        }
    }

    /// String matching: case-insensitive substring on `name`. Empty
    /// string returns all rows (useful for "show me everything"
    /// surfaces and tests).
    public func entities(matching query: String) async throws -> [MediaItemEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<CachedMediaItem>(
                sortBy: [SortDescriptor(\.name)]
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            guard !query.isEmpty else { return rows.map(Self.entity) }
            let needle = query.lowercased()
            return rows
                .filter { $0.name.lowercased().contains(needle) }
                .map(Self.entity)
        }
    }

    /// Suggested entities: most recently played items first, capped at
    /// 10. Falls back to recently synced items if no playback progress
    /// exists yet.
    public func suggestedEntities() async throws -> [MediaItemEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<CachedMediaItem>(
                sortBy: [
                    SortDescriptor(\.lastPlayedDate, order: .reverse),
                    SortDescriptor(\.lastSyncedAt, order: .reverse)
                ]
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return Array(rows.prefix(10)).map(Self.entity)
        }
    }

    // MARK: - Private

    @MainActor
    private func fetch<T>(_ work: (ModelContext) -> T) async throws -> T {
        guard let context = AppIntentsContext.mainContext else {
            // No container registered yet (e.g., intent fired before
            // app launch finished). Return whatever the closure
            // produces against an empty in-memory context — easier
            // than threading optional through every callsite.
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: CachedMediaItem.self,
                configurations: configuration
            )
            return work(container.mainContext)
        }
        return work(context)
    }

    private static func entity(from cached: CachedMediaItem) -> MediaItemEntity {
        MediaItemEntity(
            id: cached.id,
            title: cached.name,
            year: cached.year,
            mediaType: cached.mediaType
        )
    }
}
