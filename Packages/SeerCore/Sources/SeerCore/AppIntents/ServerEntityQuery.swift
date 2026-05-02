import AppIntents
import Foundation
import SwiftData

/// Entity query for `ServerEntity` — reads from `ServerConfiguration`.
/// `defaultResult()` resolves to the active server, matching the
/// hybrid multi-server resolution rule (Decision D3).
public struct ServerEntityQuery: EntityStringQuery {
    public init() {}

    public func entities(for identifiers: [ServerEntity.ID]) async throws -> [ServerEntity] {
        try await fetch { context in
            let descriptor = FetchDescriptor<ServerConfiguration>(
                predicate: #Predicate { identifiers.contains($0.id) }
            )
            let rows = (try? context.fetch(descriptor)) ?? []
            return rows.map(Self.entity)
        }
    }

    public func entities(matching query: String) async throws -> [ServerEntity] {
        try await fetch { context in
            let rows = Self.fetchSorted(in: context)
            guard !query.isEmpty else { return rows.map(Self.entity) }
            let needle = query.lowercased()
            return rows
                .filter { $0.name.lowercased().contains(needle) }
                .map(Self.entity)
        }
    }

    public func suggestedEntities() async throws -> [ServerEntity] {
        try await fetch { context in
            Self.fetchSorted(in: context).map(Self.entity)
        }
    }

    /// Fetch with active-first ordering. Done in-memory because SwiftData's
    /// `SortDescriptor` does not accept `Bool` key-paths (Bool is not
    /// `Comparable` in Swift); sort by `lastUsed`/`name` at the database
    /// level then promote the active row to the front in memory.
    private static func fetchSorted(in context: ModelContext) -> [ServerConfiguration] {
        let descriptor = FetchDescriptor<ServerConfiguration>(
            sortBy: [
                SortDescriptor(\.lastUsed, order: .reverse),
                SortDescriptor(\.name)
            ]
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        return rows.sorted { lhs, rhs in
            if lhs.isActive != rhs.isActive { return lhs.isActive }
            return false
        }
    }

    /// Default result is the active server. Used when an intent has an
    /// optional `ServerEntity` parameter and the user did not supply
    /// one (matches Decision D3 — single-server hybrid resolution).
    public func defaultResult() async -> ServerEntity? {
        await MainActor.run {
            guard let context = AppIntentsContext.mainContext else { return nil }
            var descriptor = FetchDescriptor<ServerConfiguration>(
                predicate: #Predicate { $0.isActive }
            )
            descriptor.fetchLimit = 1
            return (try? context.fetch(descriptor).first).map(Self.entity)
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
                for: ServerConfiguration.self,
                configurations: configuration
            )
            return work(container.mainContext)
        }
        return work(context)
    }

    private static func entity(from server: ServerConfiguration) -> ServerEntity {
        ServerEntity(id: server.id, name: server.name, isActive: server.isActive)
    }
}
