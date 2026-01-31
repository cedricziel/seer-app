import Foundation
import JellyseerrClient
import SwiftData

/// Actor that polls for request status changes and triggers notifications
public actor RequestStatusPoller {
    private let store: NotificationStore
    private let notificationService: RequestNotificationService
    private let serverID: String

    private var jellyseerrService: JellyseerrService?
    private var pollingTask: Task<Void, Never>?

    /// Polling configuration
    private let pollingInterval: TimeInterval = 15 * 60 // 15 minutes

    public init(
        modelContainer: ModelContainer,
        notificationService: RequestNotificationService,
        serverID: String
    ) {
        store = NotificationStore(modelContainer: modelContainer)
        self.notificationService = notificationService
        self.serverID = serverID
    }

    // MARK: - Configuration

    /// Configure with Jellyseerr credentials
    public func configure(serverURL: URL, apiKey: String) {
        jellyseerrService = JellyseerrService(serverURL: serverURL, apiKey: apiKey)
    }

    // MARK: - Polling

    /// Start background polling
    public func startPolling() {
        guard pollingTask == nil else { return }

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(self?.pollingInterval ?? 900))
            }
        }
    }

    /// Stop background polling
    public func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Perform a single poll (can be called from background task)
    public func poll() async {
        guard let service = jellyseerrService else {
            print("[RequestStatusPoller] Not configured")
            return
        }

        do {
            // Fetch current requests from Jellyseerr
            let response = try await service.getRequests(take: 50, skip: 0, filter: .all, sort: .modified)
            let currentRequests = response.results

            // Get cached statuses
            let cachedStatuses = try await store.fetchAllCachedStatuses()
            let cachedByID = Dictionary(uniqueKeysWithValues: cachedStatuses.map { ($0.requestID, $0) })

            // Detect changes
            var changes: [RequestStatusChange] = []

            for request in currentRequests {
                let currentStatus = request.status.rawValue
                let title = request.media.displayTitle ?? "Unknown"

                if let cached = cachedByID[request.id] {
                    // Check for meaningful status changes
                    if cached.status != currentStatus {
                        if let change = detectChange(
                            oldStatus: cached.status,
                            newStatus: currentStatus,
                            requestID: request.id,
                            title: title
                        ) {
                            changes.append(change)
                        }
                    }

                    // Update cached status
                    try await store.upsertCachedStatus(
                        requestID: request.id,
                        status: currentStatus,
                        mediaTitle: title,
                        mediaType: request.type.rawValue,
                        serverID: serverID
                    )
                } else {
                    // New request - cache it but don't notify (user already knows they made it)
                    try await store.upsertCachedStatus(
                        requestID: request.id,
                        status: currentStatus,
                        mediaTitle: title,
                        mediaType: request.type.rawValue,
                        serverID: serverID
                    )
                }
            }

            // Send notifications for changes
            if !changes.isEmpty {
                await notificationService.notifyRequestStatusChanges(changes, serverID: serverID)
            }
        } catch {
            print("[RequestStatusPoller] Poll failed: \(error)")
        }
    }

    // MARK: - Change Detection

    /// Detect meaningful status changes
    private func detectChange(
        oldStatus: Int,
        newStatus: Int,
        requestID: Int,
        title: String
    ) -> RequestStatusChange? {
        // Status values:
        // 1 = pending, 2 = approved, 3 = declined, 4 = available, 5 = processing

        // Pending -> Approved
        if oldStatus == 1, newStatus == 2 {
            return .approved(requestID: requestID, title: title)
        }

        // Pending -> Declined
        if oldStatus == 1, newStatus == 3 {
            return .declined(requestID: requestID, title: title)
        }

        // Approved/Processing -> Available
        if oldStatus == 2 || oldStatus == 5, newStatus == 4 {
            return .available(requestID: requestID, title: title)
        }

        // Processing -> Available (content finished downloading)
        if oldStatus == 5, newStatus == 4 {
            return .available(requestID: requestID, title: title)
        }

        return nil
    }

    // MARK: - Cleanup

    /// Clear all cached statuses for this server
    public func clearCache() async {
        try? await store.deleteAllCachedStatuses(forServerID: serverID)
    }
}
