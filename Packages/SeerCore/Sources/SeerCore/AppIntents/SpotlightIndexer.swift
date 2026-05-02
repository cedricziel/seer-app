import CoreSpotlight
import Foundation
import OSLog
import SwiftData

/// Maintains a Spotlight `CSSearchableIndex` of `MediaItemEntity`
/// values for the user's library. Gated entirely behind
/// `AppState.appIntentsIndexingEnabled` (per-device, opt-in,
/// defaults off).
///
/// What is indexed: title, year, type, identifier. Nothing else —
/// no posters, no plot summaries, no watched state. Matches the
/// privacy footer exposed in `PrivacySettingsView`.
@MainActor
public final class SpotlightIndexer {
    private static let logger = Logger(subsystem: "com.cedricziel.seer", category: "SpotlightIndexer")

    private let appState: AppState
    private let modelContainer: ModelContainer
    private let searchableIndex: CSSearchableIndex

    /// Stable domain identifier so we can purge ALL Seer-registered
    /// items in a single call when the user opts out.
    public static let domainIdentifier = "com.cedricziel.seer.media"

    public init(
        appState: AppState,
        modelContainer: ModelContainer,
        searchableIndex: CSSearchableIndex = .default()
    ) {
        self.appState = appState
        self.modelContainer = modelContainer
        self.searchableIndex = searchableIndex
    }

    /// Reconcile the index to the current flag state. Call on launch
    /// and again any time `appIntentsIndexingEnabled` changes.
    public func reconcile() {
        if appState.appIntentsIndexingEnabled {
            Task { await rebuildIndex() }
        } else {
            Task { await purgeIndex() }
        }
    }

    /// Re-index everything. Called from `reconcile` and from
    /// OfflineSync refresh notifications.
    public func rebuildIndex() async {
        guard appState.appIntentsIndexingEnabled else {
            await purgeIndex()
            return
        }

        let context = modelContainer.mainContext
        let descriptor = FetchDescriptor<CachedMediaItem>(sortBy: [SortDescriptor(\.name)])
        let rows = (try? context.fetch(descriptor)) ?? []

        let items: [CSSearchableItem] = rows.map { row in
            let attrs = CSSearchableItemAttributeSet(contentType: .item)
            attrs.title = row.name
            if let year = row.year {
                attrs.contentDescription = "\(year)"
            }
            attrs.identifier = row.id
            return CSSearchableItem(
                uniqueIdentifier: row.id,
                domainIdentifier: Self.domainIdentifier,
                attributeSet: attrs
            )
        }

        do {
            try await searchableIndex.deleteSearchableItems(
                withDomainIdentifiers: [Self.domainIdentifier]
            )
            if !items.isEmpty {
                try await searchableIndex.indexSearchableItems(items)
            }
            Self.logger.info("Spotlight index rebuilt with \(items.count) items")
        } catch {
            Self.logger.error("Spotlight rebuild failed: \(String(describing: error))")
        }
    }

    /// Remove every Seer-registered item from the system index.
    public func purgeIndex() async {
        do {
            try await searchableIndex.deleteSearchableItems(
                withDomainIdentifiers: [Self.domainIdentifier]
            )
            Self.logger.info("Spotlight index purged")
        } catch {
            Self.logger.error("Spotlight purge failed: \(String(describing: error))")
        }
    }
}
