import Foundation
import JellyfinClient
import Observation
import OfflineSync
import SeerCore
import SwiftData

/// ViewModel for managing TV series detail view state including seasons and episodes with offline support
@MainActor
@Observable
final class SeriesDetailViewModel {
    // MARK: - Observable Properties

    var seasons: [MediaItem] = []
    var episodesBySeason: [String: [MediaItem]] = [:]
    var expandedSeasons: Set<String> = []
    var isLoadingSeasons: Bool = false
    var isLoadingEpisodes: [String: Bool] = [:]
    var errorMessage: String?

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

    /// Loads all seasons for the series
    func loadSeasons() async {
        isLoadingSeasons = true
        defer { isLoadingSeasons = false }

        // Load cached seasons first
        await loadCachedSeasons()

        guard let service = jellyfinService else {
            if seasons.isEmpty {
                errorMessage = "Not connected to Jellyfin"
            }
            return
        }

        // Check if we're offline
        guard networkMonitor?.isConnected ?? true else {
            isShowingCachedData = !seasons.isEmpty
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
            print("Failed to load cached seasons: \(error)")
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
            print("Failed to load episodes for season \(season.name): \(error)")
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
            print("Failed to load cached episodes: \(error)")
        }
    }

    /// Toggles the expanded state of a season and loads episodes if needed
    func toggleSeason(_ seasonId: String) async {
        if expandedSeasons.contains(seasonId) {
            expandedSeasons.remove(seasonId)
        } else {
            expandedSeasons.insert(seasonId)
            await loadEpisodesIfNeeded(for: seasonId)
        }
    }

    private func loadEpisodesIfNeeded(for seasonId: String) async {
        guard episodesBySeason[seasonId] == nil else { return }
        guard let season = seasons.first(where: { $0.id == seasonId }) else { return }
        await loadEpisodes(for: season)
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
