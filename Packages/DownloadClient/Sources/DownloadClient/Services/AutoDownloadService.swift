import BackgroundTasks
import Foundation
import JellyfinClient
import SeerCore
import SwiftData

/// Service for processing auto-download rules
public actor AutoDownloadService {
    /// Background task identifier
    public static let taskIdentifier = "com.cedricziel.seer.autodownload"

    /// Processing interval in seconds (1 hour)
    private static let processingInterval: TimeInterval = 60 * 60

    private let store: DownloadStore
    private weak var downloadManager: DownloadManager?

    // Server credentials
    private var serverURL: URL?
    private var accessToken: String?
    private var userID: String?
    private var deviceID: String?

    public init(store: DownloadStore) {
        self.store = store
    }

    // MARK: - Configuration

    /// Configure with download manager and credentials
    public func configure(
        downloadManager: DownloadManager,
        serverURL: URL,
        accessToken: String,
        userID: String,
        deviceID: String
    ) {
        self.downloadManager = downloadManager
        self.serverURL = serverURL
        self.accessToken = accessToken
        self.userID = userID
        self.deviceID = deviceID
    }

    // MARK: - Background Task Registration

    /// Register background task with the system
    @MainActor
    public static func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { task in
            guard let task = task as? BGProcessingTask else { return }
            Task {
                // This would be called by the app delegate with proper service instance
                task.setTaskCompleted(success: true)
            }
        }
    }

    /// Schedule background task
    @MainActor
    public static func scheduleBackgroundTask() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false
        request.earliestBeginDate = Date(timeIntervalSinceNow: processingInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule auto-download task: \(error)")
        }
    }

    // MARK: - Rule Processing

    /// Process all enabled rules
    public func processAllRules(serverID: String) async {
        guard serverURL != nil, accessToken != nil, let userID else { return }

        do {
            let rules = try await store.fetchEnabledRules(forServer: serverID)

            for rule in rules {
                await processRule(rule, userID: userID)
                try? await store.updateRuleLastProcessed(ruleID: rule.id)
            }

            // Cleanup watched content
            await cleanupWatchedContent(serverID: serverID)

        } catch {
            print("Failed to process auto-download rules: \(error)")
        }
    }

    /// Process a single rule
    private func processRule(_ rule: AutoDownloadRule, userID: String) async {
        guard let serverURL, let accessToken, let deviceID, let downloadManager else { return }

        // Check WiFi requirement
        if rule.wifiOnly {
            let isOnWiFi = await checkWiFiStatus()
            guard isOnWiFi else { return }
        }

        do {
            // Get unwatched episodes for the series
            let service = JellyfinService(
                serverURL: serverURL,
                accessToken: accessToken,
                userID: userID,
                deviceID: deviceID
            )

            let episodes: [MediaItem]
            if let seriesID = rule.seriesID {
                // Specific series
                episodes = try await fetchUnwatchedEpisodes(
                    seriesID: seriesID,
                    service: service,
                    limit: rule.episodesToKeep
                )
            } else {
                // All series - get next up
                episodes = try await fetchNextUpEpisodes(
                    service: service,
                    limit: rule.episodesToKeep
                )
            }

            // Download episodes that aren't already downloaded
            for episode in episodes {
                let isDownloaded = await downloadManager.isDownloaded(
                    itemID: episode.id,
                    serverID: rule.serverID
                )

                if !isDownloaded {
                    // Check storage limit
                    if rule.maxStorageBytes > 0 {
                        let currentSize = try await store.totalDownloadedSize()
                        if currentSize >= rule.maxStorageBytes {
                            break
                        }
                    }

                    try? await downloadManager.downloadItem(
                        episode,
                        serverID: rule.serverID,
                        quality: rule.quality
                    )
                }
            }

        } catch {
            print("Failed to process rule \(rule.id): \(error)")
        }
    }

    /// Fetch unwatched episodes for a series
    private func fetchUnwatchedEpisodes(
        seriesID: String,
        service: JellyfinService,
        limit: Int
    ) async throws -> [MediaItem] {
        // Get seasons
        let seasons = try await service.getSeasons(seriesId: seriesID)

        var episodes: [MediaItem] = []

        for season in seasons {
            let seasonEpisodes = try await service.getEpisodes(seasonId: season.id)

            // Filter unwatched
            let unwatched = seasonEpisodes.filter { $0.userData?.played != true }
            episodes.append(contentsOf: unwatched)

            if episodes.count >= limit {
                break
            }
        }

        return Array(episodes.prefix(limit))
    }

    /// Fetch next up episodes across all series
    private func fetchNextUpEpisodes(
        service: JellyfinService,
        limit: Int
    ) async throws -> [MediaItem] {
        // Use continue watching which includes next up
        let items = try await service.getContinueWatching()
        return Array(items.filter { $0.type == .episode }.prefix(limit))
    }

    // MARK: - Cleanup

    /// Clean up watched content based on rules
    private func cleanupWatchedContent(serverID: String) async {
        do {
            let rules = try await store.fetchEnabledRules(forServer: serverID)
            let downloads = try await store.fetchDownloads(forServer: serverID)

            for download in downloads where download.isWatched {
                // Find applicable rule
                let rule = rules.first { rule in
                    rule.deleteWhenWatched && (rule.seriesID == nil || rule.seriesID == download.seriesName)
                }

                guard let rule else { continue }

                // Check if should delete based on age
                if let lastPlayed = download.lastPlayedDate {
                    let daysOld = Calendar.current.dateComponents(
                        [.day],
                        from: lastPlayed,
                        to: Date()
                    ).day ?? 0

                    if daysOld >= rule.daysToKeepWatched {
                        try? await downloadManager?.deleteDownload(download.id)
                    }
                }
            }
        } catch {
            print("Failed to cleanup watched content: \(error)")
        }
    }

    // MARK: - Helpers

    private func checkWiFiStatus() async -> Bool {
        // Would check actual WiFi status via NWPathMonitor
        // For now, return true
        true
    }
}
