import Foundation
import JellyfinClient
import SeerCore
import SwiftData

/// Handles syncing of media items
@MainActor
public final class MediaItemSyncService {
    private let modelContext: ModelContext
    private let conflictResolver = ConflictResolver()

    /// Maximum items to cache per library
    private let maxItemsPerLibrary = 500

    /// Maximum total cached items
    private let maxTotalItems = 2000

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Library Items Sync

    /// Syncs items for a specific library
    public func syncLibraryItems(
        library: CachedLibrary,
        serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        let response = try await service.getItems(
            parentID: library.id,
            includeItemTypes: nil,
            limit: maxItemsPerLibrary,
            startIndex: 0
        )

        let serverItems = response.items
        try await syncItems(
            serverItems,
            serverConfig: serverConfig,
            library: library
        )
    }

    /// Syncs continue watching items
    public func syncContinueWatching(
        serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        let items = try await service.getContinueWatching(limit: 20)
        try await syncItems(items, serverConfig: serverConfig, library: nil)
    }

    /// Syncs latest items
    public func syncLatestItems(
        serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        let items = try await service.getLatestItems(limit: 30)
        try await syncItems(items, serverConfig: serverConfig, library: nil)
    }

    /// Syncs series details (seasons and episodes)
    public func syncSeriesDetails(
        seriesId: String,
        serverConfig: ServerConfiguration,
        service: JellyfinService
    ) async throws {
        // Fetch seasons
        let seasons = try await service.getSeasons(seriesId: seriesId)
        try await syncItems(seasons, serverConfig: serverConfig, library: nil)

        // Fetch episodes for each season
        for season in seasons {
            let episodes = try await service.getEpisodes(seasonId: season.id)
            try await syncItems(episodes, serverConfig: serverConfig, library: nil)

            // Link episodes to season
            linkEpisodesToSeason(seasonId: season.id, episodes: episodes)
        }

        // Link seasons to series
        linkSeasonsToSeries(seriesId: seriesId, seasons: seasons)
    }

    public func updateCachedItemProgress(
        mediaItemId: String, playbackPositionTicks: Int64, isFavorite: Bool, isPlayed: Bool
    ) {
        let desc = FetchDescriptor<CachedMediaItem>(predicate: #Predicate { $0.id == mediaItemId })
        guard let item = try? modelContext.fetch(desc).first else { return }
        item.playbackPositionTicks = playbackPositionTicks
        item.isFavorite = isFavorite
        item.isPlayed = isPlayed
        item.lastPlayedDate = Date()
        try? modelContext.save()
    }

    public func getCachedItems(for libraryId: String?, serverConfigurationID: UUID) throws -> [CachedMediaItem] {
        let descriptor = if let libraryId {
            FetchDescriptor<CachedMediaItem>(
                predicate: #Predicate {
                    $0.serverConfigurationID == serverConfigurationID && $0.libraryId == libraryId
                },
                sortBy: [SortDescriptor(\.name)]
            )
        } else {
            FetchDescriptor<CachedMediaItem>(
                predicate: #Predicate { $0.serverConfigurationID == serverConfigurationID },
                sortBy: [SortDescriptor(\.name)]
            )
        }
        return try modelContext.fetch(descriptor)
    }

    public func getCachedItem(id: String) throws -> CachedMediaItem? {
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    /// Gets cached continue watching items
    public func getCachedContinueWatching(
        serverConfigurationID: UUID
    ) throws -> [CachedMediaItem] {
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate {
                $0.serverConfigurationID == serverConfigurationID &&
                    $0.playbackPositionTicks != nil &&
                    $0.playbackPositionTicks! > 0 &&
                    $0.isPlayed == false
            },
            sortBy: [SortDescriptor(\.lastPlayedDate, order: .reverse)]
        )
        var fetchDescriptor = descriptor
        fetchDescriptor.fetchLimit = 20
        return try modelContext.fetch(fetchDescriptor)
    }

    /// Gets cached seasons for a series
    public func getCachedSeasons(seriesId: String) throws -> [CachedMediaItem] {
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate {
                $0.seriesId == seriesId && $0.mediaType == "Season"
            },
            sortBy: [SortDescriptor(\.indexNumber)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Gets cached episodes for a season
    public func getCachedEpisodes(seasonId: String) throws -> [CachedMediaItem] {
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate {
                $0.parentSeasonStoredId == seasonId && $0.mediaType == "Episode"
            },
            sortBy: [SortDescriptor(\.indexNumber)]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Cleanup

    /// Removes items older than the specified date
    public func removeOldItems(olderThan date: Date) throws {
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.lastSyncedAt < date }
        )
        let oldItems = try modelContext.fetch(descriptor)
        for item in oldItems {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    /// Removes all items for a server
    public func removeItems(for serverConfigurationID: UUID) throws {
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.serverConfigurationID == serverConfigurationID }
        )
        let items = try modelContext.fetch(descriptor)
        for item in items {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    /// Enforces storage limits by removing oldest items
    public func enforceStorageLimits() throws {
        let countDescriptor = FetchDescriptor<CachedMediaItem>()
        let totalCount = try modelContext.fetchCount(countDescriptor)

        guard totalCount > maxTotalItems else { return }

        // Remove oldest items to get under the limit
        let itemsToRemove = totalCount - maxTotalItems
        let descriptor = FetchDescriptor<CachedMediaItem>(
            sortBy: [SortDescriptor(\.lastSyncedAt)]
        )
        var fetchDescriptor = descriptor
        fetchDescriptor.fetchLimit = itemsToRemove

        let oldestItems = try modelContext.fetch(fetchDescriptor)
        for item in oldestItems {
            modelContext.delete(item)
        }
        try modelContext.save()
    }

    // MARK: - Private Methods

    func syncItems(
        _ serverItems: [MediaItem],
        serverConfig: ServerConfiguration,
        library: CachedLibrary?
    ) async throws {
        let serverIds = Set(serverItems.map(\.id))
        let configID = serverConfig.id

        // Look up existing rows by (server, item id) regardless of which
        // library they were first cached under. Latest / continue-watching
        // syncs cache items with `libraryId == nil`; a later library sync must
        // update those rows rather than insert a second row with the same id.
        let ids = Array(serverIds)
        let byIdDescriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.serverConfigurationID == configID && ids.contains($0.id) }
        )
        let matchingItems = try modelContext.fetch(byIdDescriptor)

        // The CloudKit-backed store cannot enforce uniqueness, so duplicates
        // can still arrive from other devices. Keep the first row per id and
        // drop the rest instead of trapping in `Dictionary(uniqueKeysWithValues:)`.
        var existingById: [String: CachedMediaItem] = [:]
        for item in matchingItems {
            if existingById[item.id] == nil {
                existingById[item.id] = item
            } else {
                modelContext.delete(item)
            }
        }

        // Update or create items
        for serverItem in serverItems {
            if let existing = existingById[serverItem.id] {
                updateCachedItem(existing, from: serverItem, library: library)
            } else {
                let cached = createCachedItem(from: serverItem, serverConfig: serverConfig, library: library)
                modelContext.insert(cached)
            }
        }

        // Remove items from this library that no longer exist on server
        if let library {
            let libId = library.id
            let libraryDescriptor = FetchDescriptor<CachedMediaItem>(
                predicate: #Predicate { $0.libraryId == libId }
            )
            let libraryItems = try modelContext.fetch(libraryDescriptor)
            for existing in libraryItems where !serverIds.contains(existing.id) {
                modelContext.delete(existing)
            }
        }

        try modelContext.save()
        try enforceStorageLimits()
    }

    private func createCachedItem(
        from serverItem: MediaItem,
        serverConfig: ServerConfiguration,
        library: CachedLibrary?
    ) -> CachedMediaItem {
        CachedMediaItem(
            id: serverItem.id,
            serverConfigurationID: serverConfig.id,
            name: serverItem.name,
            overview: serverItem.overview,
            year: serverItem.year,
            communityRating: serverItem.communityRating,
            officialRating: serverItem.officialRating,
            runTimeTicks: serverItem.runTimeTicks,
            mediaType: serverItem.type.rawValue,
            seriesId: serverItem.seriesId,
            seriesName: serverItem.seriesName,
            seasonName: serverItem.seasonName,
            indexNumber: serverItem.indexNumber,
            parentIndexNumber: serverItem.parentIndexNumber,
            playbackPositionTicks: serverItem.userData?.playbackPositionTicks,
            playCount: serverItem.userData?.playCount,
            isFavorite: serverItem.userData?.isFavorite ?? false,
            isPlayed: serverItem.userData?.played ?? false,
            lastPlayedDate: serverItem.userData?.lastPlayedDate,
            imageBlurHashPrimary: serverItem.imageBlurHashes?.primary?.values.first,
            imageBlurHashBackdrop: serverItem.imageBlurHashes?.backdrop?.values.first,
            lastSyncedAt: Date(),
            premiereDate: serverItem.premiereDate,
            container: serverItem.container,
            videoCodec: serverItem.videoCodec,
            audioCodec: serverItem.audioCodec,
            videoResolution: serverItem.videoResolution,
            audioChannels: serverItem.audioChannels,
            libraryId: library?.id,
            library: library
        )
    }

    private func updateCachedItem(
        _ cached: CachedMediaItem,
        from serverItem: MediaItem,
        library: CachedLibrary?
    ) {
        // Server wins for metadata
        cached.name = serverItem.name
        cached.overview = serverItem.overview
        cached.year = serverItem.year
        cached.communityRating = serverItem.communityRating
        cached.officialRating = serverItem.officialRating
        cached.runTimeTicks = serverItem.runTimeTicks
        cached.seriesId = serverItem.seriesId
        cached.seriesName = serverItem.seriesName
        cached.seasonName = serverItem.seasonName
        cached.indexNumber = serverItem.indexNumber
        cached.parentIndexNumber = serverItem.parentIndexNumber
        cached.imageBlurHashPrimary = serverItem.imageBlurHashes?.primary?.values.first
        cached.imageBlurHashBackdrop = serverItem.imageBlurHashes?.backdrop?.values.first
        cached.premiereDate = serverItem.premiereDate
        cached.lastSyncedAt = Date()

        // Update format information
        cached.container = serverItem.container
        cached.videoCodec = serverItem.videoCodec
        cached.audioCodec = serverItem.audioCodec
        cached.videoResolution = serverItem.videoResolution
        cached.audioChannels = serverItem.audioChannels

        if let library {
            cached.library = library
            cached.libraryId = library.id
        }

        // Merge progress (take higher value for position)
        if let serverPosition = serverItem.userData?.playbackPositionTicks {
            if let localPosition = cached.playbackPositionTicks {
                cached.playbackPositionTicks = max(localPosition, serverPosition)
            } else {
                cached.playbackPositionTicks = serverPosition
            }
        }

        // Use server values for favorite/played if no pending local change
        cached.playCount = serverItem.userData?.playCount
        cached.isFavorite = serverItem.userData?.isFavorite ?? false
        cached.isPlayed = serverItem.userData?.played ?? false
        cached.lastPlayedDate = serverItem.userData?.lastPlayedDate
    }

    private func linkEpisodesToSeason(seasonId: String, episodes: [MediaItem]) {
        let seasonDescriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.id == seasonId }
        )
        guard let season = try? modelContext.fetch(seasonDescriptor).first else { return }

        let episodeIds = episodes.map(\.id)
        let episodeDescriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { episodeIds.contains($0.id) }
        )
        guard let cachedEpisodes = try? modelContext.fetch(episodeDescriptor) else { return }

        for episode in cachedEpisodes {
            episode.parentSeason = season
            episode.parentSeasonStoredId = seasonId
        }
        season.episodes = cachedEpisodes
    }

    private func linkSeasonsToSeries(seriesId: String, seasons: [MediaItem]) {
        let seriesDescriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.id == seriesId }
        )
        guard let series = try? modelContext.fetch(seriesDescriptor).first else { return }

        let seasonIds = seasons.map(\.id)
        let seasonDescriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { seasonIds.contains($0.id) }
        )
        guard let cachedSeasons = try? modelContext.fetch(seasonDescriptor) else { return }

        for season in cachedSeasons {
            season.parentSeries = series
            season.parentSeriesStoredId = seriesId
        }
        series.seasons = cachedSeasons
    }
}
