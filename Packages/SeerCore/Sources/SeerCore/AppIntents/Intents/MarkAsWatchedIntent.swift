import AppIntents
import Foundation

/// Tier 2 intent: "Mark <item> as watched."
///
/// Toggles Jellyfin play state for a `MediaItemEntity`. Used as a
/// Shortcut building block — not auto-surfaced in Spotlight via
/// `AppShortcutsProvider`.
public struct MarkAsWatchedIntent: AppIntent {
    public static let title: LocalizedStringResource = "Mark as Watched"

    public static let description = IntentDescription(
        "Toggle the Jellyfin played-state for an item."
    )

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Item")
    public var item: MediaItemEntity

    @Parameter(title: "Watched", default: true)
    public var watched: Bool

    public init() {}

    public init(item: MediaItemEntity, watched: Bool = true) {
        self.item = item
        self.watched = watched
    }

    public typealias PlayedStateUpdater = @Sendable (MarkAsWatchedSubmission) async throws -> Void

    /// Test seam: how the intent applies the played-state change.
    /// Default impl throws `serverNotReachable` until the host app
    /// installs a real updater at launch.
    public nonisolated(unsafe) static var updater: PlayedStateUpdater = { _ in
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

        try await Self.updater(
            MarkAsWatchedSubmission(
                serverID: serverID,
                itemID: item.id,
                watched: watched
            )
        )

        let dialog = watched
            ? IntentDialog("Marked \(item.title) as watched.")
            : IntentDialog("Marked \(item.title) as unwatched.")
        return .result(dialog: dialog)
    }
}

public struct MarkAsWatchedSubmission: Sendable {
    public let serverID: UUID
    public let itemID: String
    public let watched: Bool

    public init(serverID: UUID, itemID: String, watched: Bool) {
        self.serverID = serverID
        self.itemID = itemID
        self.watched = watched
    }
}
