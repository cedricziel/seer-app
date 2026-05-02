import AppIntents
import Foundation
import SwiftData

/// Entity query for `RequestEntity` — reads from `CachedRequest`.
public struct RequestEntityQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [RequestEntity.ID]) async throws -> [RequestEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<CachedRequest>(
                predicate: #Predicate { identifiers.contains($0.id) }
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return rows.map(Self.entity)
        }
    }

    public func entities(matching query: String) async throws -> [RequestEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<CachedRequest>(
                sortBy: [SortDescriptor(\.requestedAt, order: .reverse)]
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            guard !query.isEmpty else { return rows.map(Self.entity) }
            let needle = query.lowercased()
            return rows
                .filter { $0.title.lowercased().contains(needle) }
                .map(Self.entity)
        }
    }

    public func suggestedEntities() async throws -> [RequestEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<CachedRequest>(
                sortBy: [SortDescriptor(\.requestedAt, order: .reverse)]
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return Array(rows.prefix(10)).map(Self.entity)
        }
    }

    // MARK: - Private

    @MainActor
    private func fetch<T>(_ work: (ModelContext) -> T) async throws -> T {
        guard let context = AppIntentsContext.mainContext else {
            let configuration = ModelConfiguration(
                isStoredInMemoryOnly: true,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(
                for: CachedRequest.self,
                configurations: configuration
            )
            return work(container.mainContext)
        }
        return work(context)
    }

    private static func entity(from cached: CachedRequest) -> RequestEntity {
        RequestEntity(
            id: cached.id,
            title: cached.title,
            mediaType: cached.mediaType,
            statusRawValue: cached.statusRawValue,
            requestedAt: cached.requestedAt
        )
    }
}
