import Foundation
import JellyseerrClient
import SwiftData

/// Actor that polls for request status changes and triggers notifications
public actor RequestStatusPoller {
    private let store: NotificationStore
    private let notify: @Sendable ([RequestStatusChange], String) async -> Void
    private let fetchRequests: (@Sendable () async throws -> RequestsResponse)?
    /// Configuration ID of the server this poller watches. `nonisolated` so
    /// the app can compare it synchronously when deciding whether to
    /// recreate the poller after a server switch.
    public nonisolated let serverID: String

    private var jellyseerrService: JellyseerrService?
    private var pollingTask: Task<Void, Never>?

    /// Set by `stopPolling()`. Checked after awaited work so a poll that was
    /// already in flight (including one started by a background task) does
    /// not write to the cache or notify after the poller was retired.
    private var isStopped = false

    /// Polling configuration
    private let pollingInterval: TimeInterval = 15 * 60 // 15 minutes

    public init(
        modelContainer: ModelContainer,
        notificationService: RequestNotificationService,
        serverID: String
    ) {
        store = NotificationStore(modelContainer: modelContainer)
        notify = { changes, serverID in
            await notificationService.notifyRequestStatusChanges(changes, serverID: serverID)
        }
        fetchRequests = nil
        self.serverID = serverID
    }

    init(
        modelContainer: ModelContainer,
        serverID: String,
        fetchRequests: @escaping @Sendable () async throws -> RequestsResponse,
        notify: @escaping @Sendable ([RequestStatusChange], String) async -> Void
    ) {
        store = NotificationStore(modelContainer: modelContainer)
        self.serverID = serverID
        self.fetchRequests = fetchRequests
        self.notify = notify
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
        isStopped = false

        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(self?.pollingInterval ?? 900))
            }
        }
    }

    /// Stop background polling
    public func stopPolling() {
        isStopped = true
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Perform a single poll (can be called from background task)
    public func poll() async {
        do {
            let response: RequestsResponse
            if let fetchRequests {
                response = try await fetchRequests()
            } else if let service = jellyseerrService {
                response = try await service.getRequests(take: 50, skip: 0, filter: .all, sort: .modified)
            } else {
                return
            }
            guard !isStopped else { return }
            let currentRequests = response.results

            // Get cached statuses for this server only; request IDs collide across servers
            let cachedStatuses = try await store.fetchAllCachedStatuses(forServerID: serverID)
            guard !isStopped else { return }
            let cachedByID = Dictionary(cachedStatuses.map { ($0.requestID, $0) }) { first, _ in first }

            // Detect changes
            var changes: [RequestStatusChange] = []

            for request in currentRequests {
                // Each upsert suspends; a stop in the meantime must end the poll
                guard !isStopped else { return }
                let currentStatus = request.status.rawValue
                let title = request.media.displayTitle ?? "Unknown"

                let mediaStatus = request.is4k ? request.media.status4k : request.media.status

                if let cached = cachedByID[request.id] {
                    changes += Self.detectChanges(cached: cached, request: request)
                }

                try await store.upsertCachedStatus(
                    requestID: request.id,
                    status: currentStatus,
                    mediaTitle: title,
                    mediaType: request.type.rawValue,
                    serverID: serverID,
                    mediaStatus: mediaStatus
                )
            }

            // Send notifications for changes (unless retired mid-poll)
            if !changes.isEmpty, !isStopped {
                await notify(changes, serverID)
            }
        } catch {
            print("[RequestStatusPoller] Poll failed: \(error)")
        }
    }

    // MARK: - Change Detection

    private static func detectChanges(
        cached: CachedRequestStatusSnapshot,
        request: MediaRequest
    ) -> [RequestStatusChange] {
        let title = request.media.displayTitle ?? "Unknown"
        var changes: [RequestStatusChange] = []
        if cached.status == MediaRequest.RequestStatus.pending.rawValue {
            if request.status == .approved {
                changes.append(.approved(requestID: request.id, title: title))
            } else if request.status == .declined {
                changes.append(.declined(requestID: request.id, title: title))
            }
        }

        let mediaStatus = request.is4k ? request.media.status4k : request.media.status
        if request.status != .pending,
           request.status != .declined,
           let previous = cached.mediaStatus,
           previous != MediaRequest.MediaAvailabilityStatus.available.rawValue,
           mediaStatus == MediaRequest.MediaAvailabilityStatus.available.rawValue {
            changes.append(.available(requestID: request.id, title: title))
        }
        return changes
    }

    // MARK: - Cleanup

    /// Clear all cached statuses for this server
    public func clearCache() async {
        try? await store.deleteAllCachedStatuses(forServerID: serverID)
    }
}
