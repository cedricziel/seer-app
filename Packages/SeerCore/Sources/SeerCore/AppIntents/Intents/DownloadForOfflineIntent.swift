import AppIntents
import Foundation

/// Tier 2 intent: "Download <item> for offline."
///
/// Enqueues an offline download via DownloadClient. Useful for
/// pre-flight automations: "before flight, download all Continue
/// Watching items."
public struct DownloadForOfflineIntent: AppIntent {
    public static let title: LocalizedStringResource = "Download for Offline"

    public static let description = IntentDescription(
        "Queue a media item for offline download."
    )

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Item")
    public var item: MediaItemEntity

    public init() {}

    public init(item: MediaItemEntity) {
        self.item = item
    }

    public typealias DownloadEnqueuer = @Sendable (DownloadEnqueuePayload) async throws -> Void

    /// Test seam: how the intent enqueues the download. Default impl
    /// throws `serverNotReachable` until the host app installs a real
    /// enqueuer at launch.
    public nonisolated(unsafe) static var enqueuer: DownloadEnqueuer = { _ in
        throw IntentError.serverNotReachable
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let appState = AppIntentsContext.appState, appState.isAuthenticated else {
            throw IntentError.needsConfiguration
        }
        guard let serverID = appState.activeServerID else {
            throw IntentError.needsConfiguration
        }

        try await Self.enqueuer(
            DownloadEnqueuePayload(
                serverID: serverID,
                itemID: item.id,
                title: item.title
            )
        )

        return .result(
            dialog: IntentDialog("Started downloading \(item.title).")
        )
    }
}

public struct DownloadEnqueuePayload: Sendable {
    public let serverID: UUID
    public let itemID: String
    public let title: String

    public init(serverID: UUID, itemID: String, title: String) {
        self.serverID = serverID
        self.itemID = itemID
        self.title = title
    }
}
