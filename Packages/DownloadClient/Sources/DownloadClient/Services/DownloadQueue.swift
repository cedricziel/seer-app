import Foundation
import Network

/// Actor for managing download queue with concurrency control
public actor DownloadQueue {
    /// Maximum concurrent downloads
    private let maxConcurrent: Int

    /// Currently downloading item IDs
    private var activeDownloads: Set<UUID> = []

    /// Queue of pending downloads (FIFO)
    private var pendingQueue: [UUID] = []

    /// Network path monitor
    private let pathMonitor = NWPathMonitor()

    /// Current network status
    private var isConnected: Bool = true
    private var isOnWiFi: Bool = false

    /// Whether queue processing is paused
    private var isPaused: Bool = false

    /// Callback when a download should start
    public var onShouldStartDownload: (@Sendable (UUID) async -> Void)?

    /// Set the callback for when a download should start
    public func setOnShouldStartDownload(_ callback: @escaping @Sendable (UUID) async -> Void) {
        onShouldStartDownload = callback
    }

    /// Set callback synchronously (for use in init before actor isolation)
    public nonisolated func setOnShouldStartDownloadSync(_ callback: @escaping @Sendable (UUID) async -> Void) {
        Task { await self.setOnShouldStartDownload(callback) }
    }

    public init(maxConcurrent: Int = 2) {
        self.maxConcurrent = maxConcurrent
        Task { [weak self] in
            await self?.setupNetworkMonitoring()
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                await self?.updateNetworkStatus(
                    connected: path.status == .satisfied,
                    wifi: path.usesInterfaceType(.wifi)
                )
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func updateNetworkStatus(connected: Bool, wifi: Bool) {
        isConnected = connected
        isOnWiFi = wifi

        // Process queue if network became available
        if connected, !isPaused {
            Task { await processQueue() }
        }
    }

    // MARK: - Public Properties

    /// Number of active downloads
    public var activeCount: Int {
        activeDownloads.count
    }

    /// Number of pending downloads
    public var pendingCount: Int {
        pendingQueue.count
    }

    /// Whether we have network connectivity
    public var hasNetworkConnection: Bool {
        isConnected
    }

    /// Whether we're on WiFi
    public var isWiFiConnected: Bool {
        isOnWiFi
    }

    /// Whether queue is paused
    public var queuePaused: Bool {
        isPaused
    }

    // MARK: - Queue Management

    /// Add a download to the queue
    public func enqueue(_ downloadID: UUID) {
        guard !activeDownloads.contains(downloadID), !pendingQueue.contains(downloadID) else {
            return
        }

        pendingQueue.append(downloadID)
        Task { await processQueue() }
    }

    /// Add a download with high priority (front of queue)
    public func enqueuePriority(_ downloadID: UUID) {
        guard !activeDownloads.contains(downloadID) else { return }

        // Remove from existing position if present
        pendingQueue.removeAll { $0 == downloadID }

        // Add to front
        pendingQueue.insert(downloadID, at: 0)
        Task { await processQueue() }
    }

    /// Remove a download from the queue
    public func dequeue(_ downloadID: UUID) {
        pendingQueue.removeAll { $0 == downloadID }
        activeDownloads.remove(downloadID)
        Task { await processQueue() }
    }

    /// Mark a download as completed (removes from active)
    public func markCompleted(_ downloadID: UUID) {
        activeDownloads.remove(downloadID)
        Task { await processQueue() }
    }

    /// Pause all queue processing
    public func pauseQueue() {
        isPaused = true
    }

    /// Resume queue processing
    public func resumeQueue() {
        isPaused = false
        Task { await processQueue() }
    }

    /// Check if a download is active
    public func isActive(_ downloadID: UUID) -> Bool {
        activeDownloads.contains(downloadID)
    }

    /// Check if a download is in queue (pending or active)
    public func isInQueue(_ downloadID: UUID) -> Bool {
        activeDownloads.contains(downloadID) || pendingQueue.contains(downloadID)
    }

    /// Mark a download as active without starting it (for recovering background tasks)
    public func markActive(_ downloadID: UUID) {
        guard !activeDownloads.contains(downloadID) else { return }
        pendingQueue.removeAll { $0 == downloadID }
        activeDownloads.insert(downloadID)
    }

    // MARK: - Queue Processing

    private func processQueue() async {
        guard !isPaused, isConnected else { return }

        while activeDownloads.count < maxConcurrent, !pendingQueue.isEmpty {
            let downloadID = pendingQueue.removeFirst()
            activeDownloads.insert(downloadID)
            await onShouldStartDownload?(downloadID)
        }
    }

    /// Force process queue (for recovery scenarios)
    public func forceProcessQueue() async {
        await processQueue()
    }

    // MARK: - WiFi-Only Downloads

    /// Check if a WiFi-only download should proceed
    public func shouldProceedWiFiOnly() -> Bool {
        isOnWiFi
    }

    /// Get all queued download IDs (pending + active)
    public func allQueuedIDs() -> [UUID] {
        Array(activeDownloads) + pendingQueue
    }

    /// Get active download IDs
    public func activeDownloadIDs() -> [UUID] {
        Array(activeDownloads)
    }

    /// Get pending download IDs
    public func pendingDownloadIDs() -> [UUID] {
        pendingQueue
    }

    // MARK: - Cleanup

    deinit {
        pathMonitor.cancel()
    }
}
