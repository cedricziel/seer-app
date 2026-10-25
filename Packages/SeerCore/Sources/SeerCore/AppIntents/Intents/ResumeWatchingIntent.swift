import AppIntents
import Foundation
import SwiftData

/// Tier 1 intent: "Resume on Seer."
///
/// No parameters. Resolves the most recently played in-progress item
/// from the cache and opens the app to that item's player. When
/// nothing is in progress, returns a "nothing to resume" snippet
/// and opens the Library tab.
public struct ResumeWatchingIntent: AppIntent {
    public static let title: LocalizedStringResource = "Resume Watching"

    public static let description = IntentDescription(
        "Open Seer at the most recent in-progress movie or show."
    )

    public static let openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & OpensIntent {
        let url = resolveURL()

        // For the empty case, we can return the snippet and library URL
        // without an explicit dialog complaint — this is a "soft empty
        // state", not an error.
        return .result(
            opensIntent: OpenURLIntent(url),
            dialog: dialogFor(url: url)
        )
    }

    @MainActor
    private func resolveURL() -> URL {
        guard let context = AppIntentsContext.mainContext else {
            return Self.libraryURL
        }
        var descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.playbackPositionTicks != nil && $0.playbackPositionTicks ?? 0 > 0 },
            sortBy: [SortDescriptor(\.lastPlayedDate, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let item = try? context.fetch(descriptor).first else {
            return Self.libraryURL
        }
        return Self.mediaURL(for: item.id, serverID: item.serverConfigurationID)
    }

    @MainActor
    private func dialogFor(url: URL) -> IntentDialog {
        if url == Self.libraryURL {
            return IntentDialog("Nothing to resume yet.")
        }
        return IntentDialog("Resuming on Seer.")
    }

    // MARK: - URL helpers

    /// `flowmark://media/<id>` — opens the player or detail view.
    public static func mediaURL(for id: String, serverID: UUID? = nil) -> URL {
        var components = URLComponents()
        components.scheme = FlowmarkURLRouter.scheme
        components.host = "media"
        components.path = "/\(id)"
        if let serverID {
            components.queryItems = [URLQueryItem(name: "server", value: serverID.uuidString)]
        }
        return components.url ?? libraryURL
    }

    /// `flowmark://library` — opens the Library tab.
    public static let libraryURL = URL(string: "flowmark://library")!
}
