import DownloadClient
import Foundation
import JellyfinClient
import JellyseerrClient
import OSLog
import SeerCore

/// Installs production implementations for the App Intent test seams.
/// Called once at app launch from `SeerApp.setupServices()`. Replaces
/// the default closures that throw `serverNotReachable` with real
/// service-backed implementations.
///
/// All closures dispatch off the call site's actor; service
/// construction is cheap and per-call so we don't share mutable
/// service instances across intent invocations.
@MainActor
enum IntentSeams {
    private static let logger = Logger(
        subsystem: "com.cedricziel.seer",
        category: "IntentSeams"
    )

    /// Wire all four seam closures. Safe to call repeatedly; later
    /// calls overwrite previous installations.
    static func install(
        appState: AppState,
        downloadManager: DownloadManager?
    ) {
        installRequestSubmitter()
        installSearchSupplement(appState: appState)
        installMarkAsWatchedUpdater(appState: appState)
        installDownloadEnqueuer(
            appState: appState,
            downloadManager: downloadManager
        )
    }

    // MARK: - RequestMediaIntent.submitter

    private static func installRequestSubmitter() {
        RequestMediaIntent.submitter = { submission in
            let service = JellyseerrService(
                serverURL: submission.jellyseerrURL,
                apiKey: submission.apiKey
            )

            // Resolve the title to a Jellyseerr media id by searching.
            let response = try await service.search(query: submission.title)

            // When the user supplied a media type, prefer matches of
            // that type; only fall back to a non-person match if the
            // typed match is missing. When no type was supplied, take
            // the first non-person match directly.
            let typed: SearchResult.MediaType? = submission.mediaType.map { type in
                type == .show ? .tvShow : .movie
            }
            let typedMatch = typed.flatMap { type in
                response.results.first(where: { $0.mediaType == type })
            }
            let fallbackMatch = response.results.first(where: { $0.mediaType != .person })
            guard let match = typedMatch ?? fallbackMatch else {
                throw IntentError.notFound(submission.title)
            }

            let request = try await service.createRequest(
                mediaType: match.mediaType,
                mediaId: match.id
            )

            // Status 2 = approved (auto-approval enabled or admin),
            // anything else (typically 1 = pending) lands in queue.
            let displayTitle = match.displayTitle ?? submission.title
            return request.status == .approved
                ? .created(title: displayTitle)
                : .pendingApproval(title: displayTitle)
        }
    }

    // MARK: - SearchMediaIntent.discoverSupplement

    private static func installSearchSupplement(appState: AppState) {
        SearchMediaIntent.discoverSupplement = { query in
            await Task { @MainActor in
                guard let url = appState.jellyseerrServerURL,
                      let key = appState.jellyseerrAPIKey
                else {
                    return [MediaItemEntity]()
                }
                let service = JellyseerrService(serverURL: url, apiKey: key)
                do {
                    let response = try await service.search(query: query)
                    var entities: [MediaItemEntity] = []
                    entities.reserveCapacity(20)
                    for result in response.results where result.mediaType != .person {
                        let id = result.mediaInfo?.tmdbId.map { "tmdb:\($0)" }
                            ?? "discover:\(result.id)"
                        let year = SearchResult.parseYear(
                            from: result.releaseDate ?? result.firstAirDate
                        )
                        entities.append(MediaItemEntity(
                            id: id,
                            title: result.displayTitle ?? "Untitled",
                            year: year,
                            mediaType: result.mediaType == .movie ? "Movie" : "Series"
                        ))
                        if entities.count >= 20 { break }
                    }
                    return entities
                } catch {
                    logger.error("Discover supplement failed: \(String(describing: error))")
                    return []
                }
            }.value
        }
    }

    // MARK: - MarkAsWatchedIntent.updater

    private static func installMarkAsWatchedUpdater(appState: AppState) {
        MarkAsWatchedIntent.updater = { submission in
            let creds = await Task { @MainActor in
                appState.jellyfinCredentials
            }.value
            guard let creds else {
                throw IntentError.needsConfiguration
            }
            let service = JellyfinService(
                serverURL: creds.serverURL,
                accessToken: creds.accessToken,
                userID: creds.userId,
                deviceID: creds.deviceId
            )
            if submission.watched {
                try await service.markAsPlayed(itemId: submission.itemID)
            } else {
                try await service.markAsUnplayed(itemId: submission.itemID)
            }
        }
    }

    // MARK: - DownloadForOfflineIntent.enqueuer

    private static func installDownloadEnqueuer(
        appState: AppState,
        downloadManager: DownloadManager?
    ) {
        DownloadForOfflineIntent.enqueuer = { payload in
            let manager = await Task { @MainActor in
                downloadManager
            }.value
            guard let manager else {
                throw IntentError.serverNotReachable
            }
            // Resolve credentials for the payload's server id (NOT the
            // active server). Multi-server scenario: an intent can
            // target a non-active server via its ServerEntity param.
            let creds = await Task { @MainActor in
                appState.jellyfinCredentials(for: payload.serverID)
            }.value
            guard let creds else {
                throw IntentError.needsConfiguration
            }

            // Fetch full MediaItem so DownloadManager can populate
            // metadata fields it requires (mediaType, runtime, etc.).
            let service = JellyfinService(
                serverURL: creds.serverURL,
                accessToken: creds.accessToken,
                userID: creds.userId,
                deviceID: creds.deviceId
            )
            let item = try await service.getItem(id: payload.itemID)
            try await manager.downloadItem(
                item,
                serverID: payload.serverID.uuidString
            )
        }
    }
}

private extension SearchResult {
    /// Pull the four-digit year from a Jellyseerr release date string
    /// (movies) or first-air-date string (TV). Returns nil if absent
    /// or malformed.
    static func parseYear(from string: String?) -> Int? {
        guard let string, string.count >= 4 else { return nil }
        return Int(string.prefix(4))
    }
}
