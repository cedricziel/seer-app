import Foundation
import JellyfinClient
import Observation
import OfflineSync
import os
import SeerCore
import SwiftData

/// ViewModel for managing TV series detail view state including seasons and episodes with offline support
@MainActor
@Observable
final class SeriesDetailViewModel {
    private static let logger = Logger(subsystem: "com.seer.app", category: "SeriesDetailViewModel")

    // MARK: - Observable Properties

    var seasons: [MediaItem] = []
    var episodesBySeason: [String: [MediaItem]] = [:]
    var isLoadingSeasons: Bool = false
    var isLoadingEpisodes: [String: Bool] = [:]
    var errorMessage: String?

    /// The season currently shown in the season chip row / episode list.
    /// Defaults to the first season with an unplayed episode (fallback:
    /// the first season) once `loadSeasons()` completes. Changes every time
    /// the user taps a chip.
    var selectedSeasonID: String?

    /// Indicates if the view is showing cached data
    var isShowingCachedData: Bool = false

    // MARK: - Private Properties

    let series: MediaItem
    private let jellyfinService: JellyfinService?
    private var serverURL: URL?
    private let appState: AppState

    // Offline sync components
    private var modelContext: ModelContext?
    private var mediaItemSyncService: MediaItemSyncService?
    private var serverConfigurationID: UUID?
    private weak var networkMonitor: NetworkMonitor?

    // MARK: - Initialization

    init(series: MediaItem, appState: AppState) {
        self.series = series
        self.appState = appState

        guard let serverURL = appState.jellyfinServerURL,
              let accessToken = appState.jellyfinAccessToken,
              let userID = appState.jellyfinUserID
        else {
            jellyfinService = nil
            return
        }

        self.serverURL = serverURL
        jellyfinService = JellyfinService(
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            deviceID: appState.jellyfinDeviceID
        )
    }

    /// Sets up offline sync with model context and network monitor
    func setupOfflineSync(
        modelContext: ModelContext,
        networkMonitor: NetworkMonitor
    ) {
        self.modelContext = modelContext
        self.networkMonitor = networkMonitor
        mediaItemSyncService = MediaItemSyncService(modelContext: modelContext)

        if let activeServer = appState.activeServer {
            serverConfigurationID = activeServer.id
        }
    }

    // MARK: - Public Methods

    /// Loads all seasons for the series. `isLoadingSeasons` is cleared as
    /// soon as the season list itself is known, so the chip row can render
    /// immediately; the initial-season scan that follows only occupies the
    /// per-season `isLoadingEpisodes` flags, not the whole section.
    func loadSeasons() async {
        isLoadingSeasons = true

        // Load cached seasons first
        await loadCachedSeasons()

        guard let service = jellyfinService else {
            if seasons.isEmpty {
                errorMessage = "Not connected to Jellyfin"
            }
            isLoadingSeasons = false
            await selectInitialSeasonIfNeeded()
            return
        }

        // Check if we're offline
        guard networkMonitor?.isConnected ?? true else {
            isShowingCachedData = !seasons.isEmpty
            isLoadingSeasons = false
            await selectInitialSeasonIfNeeded()
            return
        }

        errorMessage = nil

        do {
            seasons = try await service.getSeasons(seriesId: series.id)
            isShowingCachedData = false

            // Sync to cache
            if let serverConfig = appState.activeServer {
                try? await mediaItemSyncService?.syncSeriesDetails(
                    seriesId: series.id,
                    serverConfig: serverConfig,
                    service: service
                )
            }
        } catch {
            if seasons.isEmpty {
                errorMessage = error.localizedDescription
            }
        }

        isLoadingSeasons = false
        await selectInitialSeasonIfNeeded()
    }

    /// Loads cached seasons from SwiftData
    private func loadCachedSeasons() async {
        guard let mediaItemSyncService else { return }

        do {
            let cachedSeasons = try mediaItemSyncService.getCachedSeasons(seriesId: series.id)
            if !cachedSeasons.isEmpty {
                seasons = cachedSeasons.map { convertCachedToMediaItem($0) }
                isShowingCachedData = true
            }
        } catch {
            Self.logger.debug("Failed to load cached seasons: \(error.localizedDescription)")
        }
    }

    /// Loads episodes for a specific season
    func loadEpisodes(for season: MediaItem) async {
        isLoadingEpisodes[season.id] = true
        defer { isLoadingEpisodes[season.id] = false }

        // Load cached episodes first
        await loadCachedEpisodes(for: season)

        guard let service = jellyfinService,
              networkMonitor?.isConnected ?? true
        else {
            return
        }

        do {
            let episodes = try await service.getEpisodes(seasonId: season.id)
            episodesBySeason[season.id] = episodes
        } catch {
            Self.logger.debug("Failed to load episodes for season \(season.name): \(error.localizedDescription)")
        }
    }

    /// Loads cached episodes from SwiftData
    private func loadCachedEpisodes(for season: MediaItem) async {
        guard let mediaItemSyncService else { return }

        do {
            let cachedEpisodes = try mediaItemSyncService.getCachedEpisodes(seasonId: season.id)
            if !cachedEpisodes.isEmpty {
                episodesBySeason[season.id] = cachedEpisodes.map { convertCachedToMediaItem($0) }
            }
        } catch {
            Self.logger.debug("Failed to load cached episodes: \(error.localizedDescription)")
        }
    }

    private func loadEpisodesIfNeeded(for seasonId: String) async {
        guard episodesBySeason[seasonId] == nil else { return }
        guard let season = seasons.first(where: { $0.id == seasonId }) else { return }
        await loadEpisodes(for: season)
    }

    /// Selects a season for the season chip row / episode list, loading its
    /// episodes first if they haven't been fetched yet.
    func selectSeason(_ seasonId: String) async {
        selectedSeasonID = seasonId
        await loadEpisodesIfNeeded(for: seasonId)
    }

    /// Picks the first season with an unplayed episode as the initial
    /// selection, falling back to the first season. Seasons are scanned one
    /// at a time, in order, stopping at the first hit, so a fully watched
    /// series costs at most one request per season and a typical one costs
    /// a single round trip; unscanned seasons load lazily when their chip is
    /// tapped.
    private func selectInitialSeasonIfNeeded() async {
        guard selectedSeasonID == nil, !seasons.isEmpty else { return }

        for season in seasons {
            await loadEpisodesIfNeeded(for: season.id)
            // A chip tap (selectSeason) can run while we await the network;
            // a selection made in that window wins over the automatic one.
            guard selectedSeasonID == nil else { return }
            if let episodes = episodesBySeason[season.id],
               episodes.contains(where: { $0.userData?.played != true }) {
                selectedSeasonID = season.id
                return
            }
        }

        guard selectedSeasonID == nil else { return }
        selectedSeasonID = seasons.first?.id
    }

    /// The first unplayed/in-progress episode of the given season, used to
    /// drive the series' "Resume S# · E#" primary action. Recomputed on each
    /// call rather than cached, so it tracks `selectedSeasonID` as the user
    /// browses season chips and hides itself when the selected season has no
    /// unplayed episodes.
    func nextUpEpisode(for seasonId: String) -> MediaItem? {
        episodesBySeason[seasonId]?.first(where: { $0.userData?.played != true })
    }

    // MARK: - Image URLs

    enum ImageType: String {
        case primary = "Primary"
        case backdrop = "Backdrop"
        case thumb = "Thumb"
    }

    func imageURL(for item: MediaItem, type: ImageType = .primary) -> URL? {
        guard let serverURL else { return nil }
        return serverURL.appendingPathComponent("Items/\(item.id)/Images/\(type.rawValue)")
    }

    // MARK: - Private Helpers

    private let dataConverter = CachedDataConverter()

    /// Converts a CachedMediaItem to MediaItem for display
    private func convertCachedToMediaItem(_ cached: CachedMediaItem) -> MediaItem {
        dataConverter.convertToMediaItem(cached)
    }
}
