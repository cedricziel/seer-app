import AppIntents
import Foundation
import SwiftData

/// Tier 1 intent: "Search Seer for <title>."
///
/// Returns up to 10 `MediaItemEntity` results. Prefers local
/// `OfflineSync` cache hits; supplements with Jellyseerr discovery
/// search when local hits are sparse and the device has network
/// reachability.
public struct SearchMediaIntent: AppIntent {
    public static let title: LocalizedStringResource = "Search Seer"

    public static let description = IntentDescription(
        "Search your library and discoverable media for a title."
    )

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Query")
    public var query: String

    public init() {}

    public init(query: String) {
        self.query = query
    }

    public typealias DiscoverSupplement = @Sendable (String) async throws -> [MediaItemEntity]

    /// Test seam — supplemental discover hits for queries that fall
    /// below the local-hit threshold. Default returns empty.
    public nonisolated(unsafe) static var discoverSupplement: DiscoverSupplement = { _ in [] }

    /// Number of local hits below which we issue a discover query.
    public static let localHitThreshold = 3

    @MainActor
    public func perform() async throws -> some IntentResult & ReturnsValue<[MediaItemEntity]> {
        let local = await (try? MediaItemEntityQuery().entities(matching: query)) ?? []

        guard local.count < Self.localHitThreshold else {
            return .result(value: Array(local.prefix(10)))
        }

        let supplement = await (try? Self.discoverSupplement(query)) ?? []

        // Dedup: prefer local entries (which carry library state) over
        // discover hits with the same id.
        var byID: [String: MediaItemEntity] = [:]
        for item in local {
            byID[item.id] = item
        }
        for item in supplement where byID[item.id] == nil {
            byID[item.id] = item
        }

        let merged = local + supplement.filter { hit in
            !local.contains(where: { $0.id == hit.id })
        }
        return .result(value: Array(merged.prefix(10)))
    }
}
