import Combine
import Foundation
import JellyfinClient
import PlaybackClient
import SeerCore
import SwiftData

/// Main orchestrator for download operations
@MainActor
@Observable
public final class DownloadManager {
    // MARK: - Published State

    /// All downloads
    public private(set) var downloads: [Download] = []

    /// Currently active downloads (downloading state)
    public var activeDownloads: [Download] {
        downloads.filter { $0.state == .downloading }
    }

    /// Completed downloads
    public var completedDownloads: [Download] {
        downloads.filter { $0.state == .completed }
    }

    /// Total downloaded size in bytes
    public private(set) var totalDownloadedSize: Int64 = 0

    /// Whether a refresh is in progress
    public private(set) var isRefreshing: Bool = false

    /// Last error message
    public private(set) var lastError: String?

    // MARK: - Internal State (accessible to extensions)

    let store: DownloadStore
    private let storage: DownloadStorage
    let queue: DownloadQueue
    let sessionManager: BackgroundSessionManager
    private let modelContainer: ModelContainer

    // Server credentials (set when authenticated)
    private var serverURL: URL?
    private var accessToken: String?
    private var userID: String?
    private var deviceID: String?

    // WiFi-only downloads setting
    var wifiOnlyEnabled: Bool = true

    // MARK: - Initialization

    public init(modelContainer: ModelContainer) throws {
        self.modelContainer = modelContainer
        store = DownloadStore(modelContainer: modelContainer)
        storage = try DownloadStorage()
        queue = DownloadQueue(maxConcurrent: 2)
        sessionManager = BackgroundSessionManager.shared
        sessionManager.delegate = self

        // Set up queue callback SYNCHRONOUSLY (not in a Task)
        queue.setOnShouldStartDownloadSync { [weak self] downloadID in
            Task { @MainActor [weak self] in
                await self?.startDownloadTask(downloadID: downloadID)
            }
        }

        // Set up network status change callback
        Task { [weak self] in
            await self?.queue.setOnNetworkStatusChanged { [weak self] isConnected, isOnWiFi in
                Task { @MainActor [weak self] in
                    await self?.handleNetworkStatusChanged(isConnected: isConnected, isOnWiFi: isOnWiFi)
                }
            }
        }

        // Load initial state
        Task { [weak self] in
            await self?.refresh()
        }
    }

    // MARK: - Configuration

    /// Configure with server credentials
    public func configure(
        serverURL: URL,
        accessToken: String,
        userID: String,
        deviceID: String
    ) {
        self.serverURL = serverURL
        self.accessToken = accessToken
        self.userID = userID
        self.deviceID = deviceID

        // Process any pending downloads now that we have credentials
        Task { [weak self] in
            await self?.requeuePendingDownloads()
        }
    }

    /// Configure from AppState
    public func configure(from appState: AppState) {
        guard let serverURL = appState.jellyfinServerURL,
              let accessToken = appState.jellyfinAccessToken,
              let userID = appState.jellyfinUserID,
              let deviceID = appState.jellyfinDeviceID
        else { return }
        configure(
            serverURL: serverURL,
            accessToken: accessToken,
            userID: userID,
            deviceID: deviceID
        )
    }

    /// Re-enqueue pending and interrupted downloads to trigger processing
    private func requeuePendingDownloads() async {
        guard let downloads = try? await store.fetchAllDownloads() else { return }

        // Get currently active background tasks to avoid duplicates
        let activeTasks = await sessionManager.activeTaskIdentifiers()

        for download in downloads {
            if download.state == .pending {
                await queue.enqueue(download.id)
            } else if download.state == .downloading {
                // Check if this download's task is still running in the background
                if let taskID = download.taskIdentifier, activeTasks.contains(taskID) {
                    // Task is still running, re-register mapping and mark as active
                    sessionManager.registerTask(taskID, forDownload: download.id)
                    await queue.markActive(download.id)
                } else {
                    // Task not running, reset to pending and re-enqueue
                    try? await store.updateState(downloadID: download.id, state: .pending)
                    await queue.enqueue(download.id)
                }
            }
        }
    }

    // MARK: - Public API

    /// Refresh downloads from store
    public func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            downloads = try await store.fetchAllDownloads()
            totalDownloadedSize = try await store.totalDownloadedSize()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Download a media item
    public func downloadItem(
        _ item: MediaItem,
        serverID: String,
        quality: DownloadQuality = .high
    ) async throws {
        guard serverURL != nil, accessToken != nil else {
            throw DownloadError.notConfigured
        }

        // Check if already downloaded or downloading
        if let existing = try await store.fetchDownload(itemID: item.id, serverID: serverID) {
            if existing.state == .completed {
                throw DownloadError.alreadyDownloaded
            }
            if existing.state == .downloading || existing.state == .pending {
                throw DownloadError.alreadyInQueue
            }
        }

        // Create download record
        let download = Download(
            serverID: serverID,
            itemID: item.id,
            mediaSourceID: item.id, // Will be updated when we get stream info
            name: item.name,
            mediaType: item.type.rawValue,
            quality: quality,
            seriesName: item.seriesName,
            seasonNumber: item.parentIndexNumber,
            episodeNumber: item.indexNumber,
            runTimeTicks: item.runTimeTicks,
            year: item.year
        )

        // Save to store
        try await store.insert(download)

        // Add to queue
        await queue.enqueue(download.id)

        // Refresh state
        await refresh()
    }

    /// Pause a download
    public func pauseDownload(_ downloadID: UUID) async throws {
        guard let download = try await store.fetchDownload(id: downloadID),
              download.state == .downloading,
              let taskIdentifier = download.taskIdentifier
        else {
            return
        }

        // Cancel with resume data
        let resumeData = await sessionManager.cancelDownload(taskIdentifier: taskIdentifier)

        // Update state
        try await store.updateState(downloadID: downloadID, state: .paused)
        if let resumeData {
            try await store.updateResumeData(downloadID: downloadID, resumeData: resumeData)
        }

        await queue.dequeue(downloadID)
        await refresh()
    }

    /// Resume a paused download
    public func resumeDownload(_ downloadID: UUID) async throws {
        guard let download = try await store.fetchDownload(id: downloadID),
              download.state == .paused
        else {
            return
        }

        // Update state and re-queue
        try await store.updateState(downloadID: downloadID, state: .pending)
        await queue.enqueue(downloadID)
        await refresh()
    }

    /// Cancel and remove a download
    public func cancelDownload(_ downloadID: UUID) async throws {
        guard let download = try await store.fetchDownload(id: downloadID) else { return }

        // Cancel active task if any
        if let taskIdentifier = download.taskIdentifier {
            _ = await sessionManager.cancelDownload(taskIdentifier: taskIdentifier, saveResumeData: false)
        }

        // Remove from queue
        await queue.dequeue(downloadID)

        // Delete file if exists
        if let relativePath = download.relativePath {
            try await storage.deleteFile(relativePath: relativePath)
        }

        // Delete from store
        try await store.delete(downloadID: downloadID)

        await refresh()
    }

    /// Delete a completed download
    public func deleteDownload(_ downloadID: UUID) async throws {
        try await cancelDownload(downloadID)
    }

    /// Get download for an item
    public func download(forItemID itemID: String, serverID: String) async -> Download? {
        try? await store.fetchDownload(itemID: itemID, serverID: serverID)
    }

    /// Check if an item is downloaded
    public func isDownloaded(itemID: String, serverID: String) async -> Bool {
        guard let download = try? await store.fetchDownload(itemID: itemID, serverID: serverID) else {
            return false
        }
        return download.state == .completed
    }

    /// Get local file URL for a downloaded item
    public func localFileURL(forItemID itemID: String, serverID: String) async -> URL? {
        guard let download = try? await store.fetchDownload(itemID: itemID, serverID: serverID),
              download.state == .completed,
              let relativePath = download.relativePath
        else {
            return nil
        }

        return await storage.fullURL(forRelativePath: relativePath)
    }

    // MARK: - Playback Integration

    /// Update playback position for a download
    public func updatePlaybackPosition(
        downloadID: UUID,
        positionTicks: Int64,
        isWatched: Bool
    ) async throws {
        try await store.updatePlaybackPosition(
            downloadID: downloadID,
            positionTicks: positionTicks,
            isWatched: isWatched
        )
        await refresh()
    }

    // MARK: - Queue Control

    /// Pause all downloads
    public func pauseQueue() async {
        await queue.pauseQueue()
    }

    /// Resume queue processing
    public func resumeQueue() async {
        await queue.resumeQueue()
    }

    /// Whether queue is paused
    public var isQueuePaused: Bool {
        get async { await queue.queuePaused }
    }

    // MARK: - Private Download Logic

    private func startDownloadTask(downloadID: UUID) async {
        guard let serverURL, let accessToken, let deviceID else {
            try? await store.updateState(downloadID: downloadID, state: .failed, errorMessage: "Not configured")
            return
        }
        guard let download = try? await store.fetchDownload(id: downloadID) else { return }
        try? await store.updateState(downloadID: downloadID, state: .downloading)
        do {
            let playbackService = PlaybackService(
                serverURL: serverURL, accessToken: accessToken, userID: userID ?? "", deviceID: deviceID
            )
            let streamInfo = try await playbackService.getStreamInfo(itemId: download.itemID)
            let downloadURL = buildDownloadURL(
                itemID: download.itemID, mediaSourceID: streamInfo.mediaSourceId,
                serverURL: serverURL, accessToken: accessToken, quality: download.quality
            )
            let headers = StreamURLBuilder.buildAuthHeaders(accessToken: accessToken, deviceID: deviceID)
            let task = sessionManager.startDownload(url: downloadURL, downloadID: downloadID, headers: headers)
            try await store.updateTaskIdentifier(downloadID: downloadID, taskIdentifier: task.taskIdentifier)
            await refresh()
        } catch {
            let msg = error.localizedDescription
            print("[Download] Failed to start: \(msg)")
            try? await store.updateState(downloadID: downloadID, state: .failed, errorMessage: msg)
            await queue.markCompleted(downloadID)
            await refresh()
        }
    }

    private func buildDownloadURL(
        itemID: String,
        mediaSourceID: String,
        serverURL: URL,
        accessToken: String,
        quality: DownloadQuality
    ) -> URL {
        var components = URLComponents(
            url: serverURL.appendingPathComponent("Items/\(itemID)/Download"),
            resolvingAgainstBaseURL: false
        )!

        var queryItems = [
            URLQueryItem(name: "api_key", value: accessToken),
            URLQueryItem(name: "mediaSourceId", value: mediaSourceID)
        ]

        // Add quality restrictions if not original
        if quality != .original, let maxWidth = quality.maxWidth {
            queryItems.append(URLQueryItem(name: "MaxWidth", value: String(maxWidth)))
            queryItems.append(URLQueryItem(name: "VideoBitRate", value: String(quality.maxBitrate)))
        }

        components.queryItems = queryItems
        return components.url!
    }

    // MARK: - Error Types

    public enum DownloadError: LocalizedError, Sendable {
        case notConfigured
        case alreadyDownloaded
        case alreadyInQueue
        case downloadFailed(String)
        case insufficientStorage

        public var errorDescription: String? {
            switch self {
            case .notConfigured:
                "Download manager not configured with server credentials"
            case .alreadyDownloaded:
                "This item is already downloaded"
            case .alreadyInQueue:
                "This item is already in the download queue"
            case let .downloadFailed(message):
                "Download failed: \(message)"
            case .insufficientStorage:
                "Insufficient storage space"
            }
        }
    }
}

// MARK: - BackgroundSessionDelegate

extension DownloadManager: BackgroundSessionDelegate {
    public nonisolated func downloadDidProgress(
        taskIdentifier: Int,
        progress: Double,
        bytesWritten: Int64,
        totalBytes: Int64
    ) {
        guard let downloadID = sessionManager.downloadID(forTask: taskIdentifier) else { return }

        Task { @MainActor [weak self] in
            try? await self?.store.updateProgress(
                downloadID: downloadID,
                progress: progress,
                bytesDownloaded: bytesWritten,
                totalBytes: totalBytes
            )
            await self?.refresh()
        }
    }

    public nonisolated func downloadDidComplete(taskIdentifier: Int, tempFileURL: URL) {
        guard let downloadID = sessionManager.downloadID(forTask: taskIdentifier) else { return }

        Task { @MainActor [weak self] in
            guard let self,
                  let download = try? await self.store.fetchDownload(id: downloadID)
            else { return }

            do {
                // Move file to permanent location
                let relativePath = try await self.storage.moveDownloadedFile(
                    from: tempFileURL,
                    serverID: download.serverID,
                    mediaType: download.mediaType,
                    itemID: download.itemID,
                    fileName: "\(download.itemID).mp4"
                )

                // Update download record
                try await self.store.updateFilePath(downloadID: downloadID, relativePath: relativePath)
                try await self.store.updateState(downloadID: downloadID, state: .completed)

                await self.queue.markCompleted(downloadID)
                await self.refresh()
            } catch {
                try? await self.store.updateState(
                    downloadID: downloadID,
                    state: .failed,
                    errorMessage: error.localizedDescription
                )
                await self.queue.markCompleted(downloadID)
                await self.refresh()
            }
        }
    }

    public nonisolated func downloadDidFail(taskIdentifier: Int, error: Error, resumeData: Data?) {
        guard let downloadID = sessionManager.downloadID(forTask: taskIdentifier) else { return }

        Task { @MainActor [weak self] in
            // Save resume data if available
            if let resumeData {
                try? await self?.store.updateResumeData(downloadID: downloadID, resumeData: resumeData)
                try? await self?.store.updateState(downloadID: downloadID, state: .paused)
            } else {
                try? await self?.store.updateState(
                    downloadID: downloadID,
                    state: .failed,
                    errorMessage: error.localizedDescription
                )
            }

            await self?.queue.markCompleted(downloadID)
            await self?.refresh()
        }
    }

    public nonisolated func allTasksCompleted() {
        Task { @MainActor [weak self] in
            await self?.refresh()
        }
    }
}
