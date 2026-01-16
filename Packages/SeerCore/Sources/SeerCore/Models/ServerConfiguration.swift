import Foundation
import SwiftData

/// Stored in SwiftData with CloudKit sync
/// Non-sensitive metadata synced across devices
@Model
public final class ServerConfiguration {
    public var id: UUID = UUID()
    public var name: String = ""
    public var emoji: String = "🖥️"
    public var jellyfinURL: URL = URL(string: "https://localhost")!
    public var jellyseerrURL: URL?
    public var jellyfinUserID: String?
    public var lastUsed: Date?
    public var createdAt: Date = Date()
    public var isActive: Bool = false

    /// Internal URL for local network access (optional)
    public var internalJellyfinURL: URL?
    /// WiFi network SSIDs that trigger internal URL usage
    public var internalNetworkSSIDs: [String] = []

    public init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🖥️",
        jellyfinURL: URL,
        jellyseerrURL: URL? = nil,
        jellyfinUserID: String? = nil,
        lastUsed: Date? = nil,
        createdAt: Date = Date(),
        isActive: Bool = false,
        internalJellyfinURL: URL? = nil,
        internalNetworkSSIDs: [String] = []
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.jellyfinURL = jellyfinURL
        self.jellyseerrURL = jellyseerrURL
        self.jellyfinUserID = jellyfinUserID
        self.lastUsed = lastUsed
        self.createdAt = createdAt
        self.isActive = isActive
        self.internalJellyfinURL = internalJellyfinURL
        self.internalNetworkSSIDs = internalNetworkSSIDs
    }

    /// Whether this server has Jellyseerr configured
    public var hasJellyseerr: Bool {
        jellyseerrURL != nil
    }

    /// Whether this server has an internal URL configured
    public var hasInternalURL: Bool {
        internalJellyfinURL != nil && !internalNetworkSSIDs.isEmpty
    }

    /// Human-readable display of the Jellyfin host
    public var jellyfinHost: String {
        jellyfinURL.host ?? jellyfinURL.absoluteString
    }

    /// Human-readable display of the Jellyseerr host (if configured)
    public var jellyseerrHost: String? {
        jellyseerrURL?.host
    }

    /// Human-readable display of the internal Jellyfin host (if configured)
    public var internalJellyfinHost: String? {
        internalJellyfinURL?.host
    }
}

/// Stored in Keychain (keyed by server config ID)
/// Sensitive credentials synced via iCloud Keychain
public struct ServerCredentials: Sendable {
    public var jellyfinAccessToken: String?
    public var jellyfinDeviceID: String?
    public var jellyseerrAPIKey: String?

    public init(
        jellyfinAccessToken: String? = nil,
        jellyfinDeviceID: String? = nil,
        jellyseerrAPIKey: String? = nil
    ) {
        self.jellyfinAccessToken = jellyfinAccessToken
        self.jellyfinDeviceID = jellyfinDeviceID
        self.jellyseerrAPIKey = jellyseerrAPIKey
    }

    /// Whether the server has valid Jellyfin credentials
    public var hasJellyfinCredentials: Bool {
        jellyfinAccessToken != nil && jellyfinDeviceID != nil
    }
}
