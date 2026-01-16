import Foundation
import SwiftData

/// Actor for managing SwiftData operations for downloads
public actor DownloadStore {
    private let modelContainer: ModelContainer

    public init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Download Operations

    /// Fetch all downloads
    public func fetchAllDownloads() throws -> [Download] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<Download>(
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch downloads for a specific server
    public func fetchDownloads(forServer serverID: String) throws -> [Download] {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.serverID == serverID }
        let descriptor = FetchDescriptor<Download>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.addedDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch a download by item ID
    public func fetchDownload(itemID: String, serverID: String) throws -> Download? {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.itemID == itemID && $0.serverID == serverID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    /// Fetch a download by ID
    public func fetchDownload(id: UUID) throws -> Download? {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == id }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)
        return try context.fetch(descriptor).first
    }

    /// Fetch downloads with a specific state
    public func fetchDownloads(withState state: DownloadState) throws -> [Download] {
        let stateRaw = state.rawValue
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.stateRawValue == stateRaw }
        let descriptor = FetchDescriptor<Download>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.addedDate)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch pending downloads (for queue processing)
    public func fetchPendingDownloads() throws -> [Download] {
        try fetchDownloads(withState: .pending)
    }

    /// Fetch downloading downloads (active)
    public func fetchActiveDownloads() throws -> [Download] {
        try fetchDownloads(withState: .downloading)
    }

    /// Fetch completed downloads
    public func fetchCompletedDownloads() throws -> [Download] {
        try fetchDownloads(withState: .completed)
    }

    /// Insert a new download
    public func insert(_ download: Download) throws {
        let context = ModelContext(modelContainer)
        context.insert(download)
        try context.save()
    }

    /// Update download progress
    public func updateProgress(downloadID: UUID, progress: Double, bytesDownloaded: Int64, totalBytes: Int64) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        download.progress = progress
        download.bytesDownloaded = bytesDownloaded
        download.totalBytes = totalBytes

        try context.save()
    }

    /// Update download state
    public func updateState(downloadID: UUID, state: DownloadState, errorMessage: String? = nil) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        download.state = state
        download.errorMessage = errorMessage

        if state == .completed {
            download.completedDate = Date()
            download.progress = 1.0
        }

        try context.save()
    }

    /// Update download file path
    public func updateFilePath(downloadID: UUID, relativePath: String) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        download.relativePath = relativePath
        try context.save()
    }

    /// Update resume data for paused download
    public func updateResumeData(downloadID: UUID, resumeData: Data?) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        download.resumeData = resumeData
        try context.save()
    }

    /// Update task identifier
    public func updateTaskIdentifier(downloadID: UUID, taskIdentifier: Int?) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        download.taskIdentifier = taskIdentifier
        try context.save()
    }

    /// Update playback position
    public func updatePlaybackPosition(downloadID: UUID, positionTicks: Int64, isWatched: Bool) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        download.playbackPositionTicks = positionTicks
        download.isWatched = isWatched
        download.lastPlayedDate = Date()

        try context.save()
    }

    /// Delete a download
    public func delete(downloadID: UUID) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<Download> { $0.id == downloadID }
        let descriptor = FetchDescriptor<Download>(predicate: predicate)

        guard let download = try context.fetch(descriptor).first else { return }

        context.delete(download)
        try context.save()
    }

    /// Calculate total downloaded size
    public func totalDownloadedSize() throws -> Int64 {
        let downloads = try fetchCompletedDownloads()
        return downloads.reduce(0) { $0 + $1.totalBytes }
    }

    // MARK: - Auto-Download Rule Operations

    /// Fetch all auto-download rules
    public func fetchAllRules() throws -> [AutoDownloadRule] {
        let context = ModelContext(modelContainer)
        let descriptor = FetchDescriptor<AutoDownloadRule>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    /// Fetch enabled rules for a server
    public func fetchEnabledRules(forServer serverID: String) throws -> [AutoDownloadRule] {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<AutoDownloadRule> {
            $0.serverID == serverID && $0.isEnabled == true
        }
        let descriptor = FetchDescriptor<AutoDownloadRule>(predicate: predicate)
        return try context.fetch(descriptor)
    }

    /// Insert a new rule
    public func insert(_ rule: AutoDownloadRule) throws {
        let context = ModelContext(modelContainer)
        context.insert(rule)
        try context.save()
    }

    /// Update rule's last processed date
    public func updateRuleLastProcessed(ruleID: UUID) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<AutoDownloadRule> { $0.id == ruleID }
        let descriptor = FetchDescriptor<AutoDownloadRule>(predicate: predicate)

        guard let rule = try context.fetch(descriptor).first else { return }

        rule.lastProcessedDate = Date()
        try context.save()
    }

    /// Delete a rule
    public func deleteRule(ruleID: UUID) throws {
        let context = ModelContext(modelContainer)
        let predicate = #Predicate<AutoDownloadRule> { $0.id == ruleID }
        let descriptor = FetchDescriptor<AutoDownloadRule>(predicate: predicate)

        guard let rule = try context.fetch(descriptor).first else { return }

        context.delete(rule)
        try context.save()
    }
}
