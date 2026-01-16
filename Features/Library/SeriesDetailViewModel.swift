import Foundation
import JellyfinClient
import Observation
import SeerCore

/// ViewModel for managing TV series detail view state including seasons and episodes
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

    // MARK: - Private Properties

    let series: MediaItem
    private let jellyfinService: JellyfinService?
    private var serverURL: URL?

    // MARK: - Initialization

    init(series: MediaItem, appState: AppState) {
        self.series = series

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

    // MARK: - Public Methods

    /// Loads all seasons for the series
    func loadSeasons() async {
        isLoadingSeasons = true
        defer { isLoadingSeasons = false }

        guard let service = jellyfinService else {
            errorMessage = "Not connected to Jellyfin"
            return
        }

        errorMessage = nil

        do {
            seasons = try await service.getSeasons(seriesId: series.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Loads episodes for a specific season
    func loadEpisodes(for season: MediaItem) async {
        isLoadingEpisodes[season.id] = true
        defer { isLoadingEpisodes[season.id] = false }

        guard let service = jellyfinService else { return }

        do {
            let episodes = try await service.getEpisodes(seasonId: season.id)
            episodesBySeason[season.id] = episodes
        } catch {
            print("Failed to load episodes for season \(season.name): \(error)")
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
}
