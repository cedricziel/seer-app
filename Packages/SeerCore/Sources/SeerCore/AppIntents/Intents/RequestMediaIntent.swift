import AppIntents
import Foundation
import SwiftData

/// Tier 1 intent: "Request <title> on Seer."
///
/// Submits a Jellyseerr request for a media title given by the user.
/// Before contacting Jellyseerr, checks whether the title is already
/// in the user's library cache (`CachedMediaItem` matched by tmdbId)
/// and short-circuits with a "you already have this" snippet if so.
public struct RequestMediaIntent: AppIntent {
    public static let title: LocalizedStringResource = "Request Media"

    public static let description = IntentDescription(
        "Submit a Jellyseerr request for a movie or show by name."
    )

    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Title")
    public var title: String

    @Parameter(title: "Type")
    public var mediaType: RequestMediaType?

    @Parameter(title: "Server")
    public var server: ServerEntity?

    public init() {}

    public init(title: String, mediaType: RequestMediaType? = nil, server: ServerEntity? = nil) {
        self.title = title
        self.mediaType = mediaType
        self.server = server
    }

    public typealias Submitter = @Sendable (RequestSubmission) async throws -> RequestOutcome
    public typealias CredentialsProvider = @Sendable @MainActor (UUID) -> JellyseerrCredentials?

    /// Test seam: replace to inject a fake submission. Default impl
    /// throws `serverNotReachable` until the host app installs a
    /// real submitter at launch (see `SeerApp.swift`).
    public nonisolated(unsafe) static var submitter: Submitter = { _ in
        throw IntentError.serverNotReachable
    }

    /// Test seam: how the intent looks up Jellyseerr credentials for a
    /// resolved server. Default impl reads from `Keychain` + the
    /// `ServerConfiguration` SwiftData store via `AppState`. Tests
    /// override to avoid requiring keychain entitlements in the test
    /// sandbox.
    public nonisolated(unsafe) static var credentialsProvider: CredentialsProvider = { serverID in
        guard let appState = AppIntentsContext.appState,
              let server = appState.servers.first(where: { $0.id == serverID }),
              let url = server.jellyseerrURL,
              let apiKey = KeychainManager.shared.getCredential(
                  for: serverID,
                  key: .jellyseerrAPIKey
              )
        else { return nil }
        return JellyseerrCredentials(url: url, apiKey: apiKey)
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let appState = AppIntentsContext.appState, appState.isAuthenticated else {
            throw IntentError.needsConfiguration
        }

        // Resolve server (param wins; otherwise active).
        let resolvedServer = try await resolveServer(appState: appState)

        // Library short-circuit: if user already owns it, surface that.
        if let owned = findOwnedItem(
            matching: title,
            serverID: resolvedServer.id
        ) {
            return .result(
                dialog: IntentDialog("You already have \(owned.title) in your library.")
            )
        }

        guard let credentials = Self.credentialsProvider(resolvedServer.id) else {
            throw IntentError.jellyseerrNotConfigured
        }

        let outcome = try await Self.submitter(
            RequestSubmission(
                serverID: resolvedServer.id,
                jellyseerrURL: credentials.url,
                apiKey: credentials.apiKey,
                title: title,
                mediaType: mediaType
            )
        )

        switch outcome {
        case let .created(title):
            return .result(dialog: IntentDialog("Requested \(title)."))
        case let .pendingApproval(title):
            return .result(
                dialog: IntentDialog(
                    "Request for \(title) submitted. Waiting for admin approval."
                )
            )
        }
    }

    // MARK: - Private helpers

    @MainActor
    private func resolveServer(appState: AppState) async throws -> ServerEntity {
        if let server { return server }
        guard let active = appState.activeServer else {
            throw IntentError.needsConfiguration
        }
        return ServerEntity(id: active.id, name: active.name, isActive: active.isActive)
    }

    @MainActor
    private func findOwnedItem(matching title: String, serverID: UUID) -> MediaItemEntity? {
        guard let context = AppIntentsContext.mainContext else { return nil }
        let needle = title.lowercased()
        let descriptor = FetchDescriptor<CachedMediaItem>(
            predicate: #Predicate { $0.serverConfigurationID == serverID }
        )
        let rows = (try? context.fetch(descriptor)) ?? []
        guard let match = rows.first(where: { $0.name.lowercased() == needle }) else {
            return nil
        }
        return MediaItemEntity(
            id: match.id,
            title: match.name,
            year: match.year,
            mediaType: match.mediaType
        )
    }
}

/// Media-type parameter for `RequestMediaIntent`.
public enum RequestMediaType: String, AppEnum {
    case movie
    case show

    public static let typeDisplayRepresentation: TypeDisplayRepresentation = "Media Type"

    public static let caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .movie: "Movie",
        .show: "Show"
    ]
}

/// Payload passed to `RequestMediaIntent.submitter`. Decoupled from
/// `JellyseerrService` so tests don't need to construct a real one.
public struct RequestSubmission: Sendable {
    public let serverID: UUID
    public let jellyseerrURL: URL
    public let apiKey: String
    public let title: String
    /// `nil` when the user did not specify a media type. The submitter
    /// SHOULD treat this as "either type acceptable" rather than
    /// silently defaulting to one direction.
    public let mediaType: RequestMediaType?

    public init(
        serverID: UUID,
        jellyseerrURL: URL,
        apiKey: String,
        title: String,
        mediaType: RequestMediaType?
    ) {
        self.serverID = serverID
        self.jellyseerrURL = jellyseerrURL
        self.apiKey = apiKey
        self.title = title
        self.mediaType = mediaType
    }
}

/// Outcome reported back from the submitter to the intent.
public enum RequestOutcome: Sendable, Equatable {
    case created(title: String)
    case pendingApproval(title: String)
}

/// Credentials lookup result for the credentialsProvider seam.
public struct JellyseerrCredentials: Sendable {
    public let url: URL
    public let apiKey: String

    public init(url: URL, apiKey: String) {
        self.url = url
        self.apiKey = apiKey
    }
}
