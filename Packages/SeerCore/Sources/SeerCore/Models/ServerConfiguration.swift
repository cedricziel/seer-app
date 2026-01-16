import Foundation

/// Stored in iCloud (NSUbiquitousKeyValueStore)
/// Non-sensitive metadata synced across devices
public struct ServerConfiguration: Identifiable, Codable, Sendable, Hashable {
    public let id: UUID
    public var name: String
    public var emoji: String
    public var jellyfinURL: URL
    public var jellyseerrURL: URL?
    public var jellyfinUserID: String?
    public var lastUsed: Date?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        emoji: String = "🖥️",
        jellyfinURL: URL,
        jellyseerrURL: URL? = nil,
        jellyfinUserID: String? = nil,
        lastUsed: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.jellyfinURL = jellyfinURL
        self.jellyseerrURL = jellyseerrURL
        self.jellyfinUserID = jellyfinUserID
        self.lastUsed = lastUsed
        self.createdAt = createdAt
    }

    /// Whether this server has Jellyseerr configured
    public var hasJellyseerr: Bool {
        jellyseerrURL != nil
    }

    /// Human-readable display of the Jellyfin host
    public var jellyfinHost: String {
        jellyfinURL.host ?? jellyfinURL.absoluteString
    }

    /// Human-readable display of the Jellyseerr host (if configured)
    public var jellyseerrHost: String? {
        jellyseerrURL?.host
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
