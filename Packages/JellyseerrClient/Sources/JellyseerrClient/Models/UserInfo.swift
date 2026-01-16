import Foundation

/// Represents the authenticated user info from Jellyseerr
public struct UserInfo: Codable, Sendable {
    public let id: Int
    public let email: String?
    public let plexUsername: String?
    public let jellyfinUsername: String?
    public let username: String?
    public let recoveryLinkExpirationDate: String?
    public let userType: Int
    public let permissions: Int
    public let avatar: String?
    public let movieQuotaLimit: Int?
    public let movieQuotaDays: Int?
    public let tvQuotaLimit: Int?
    public let tvQuotaDays: Int?
    public let createdAt: String
    public let updatedAt: String
    public let requestCount: Int

    /// Display name for the user
    public var displayName: String {
        jellyfinUsername ?? plexUsername ?? username ?? email ?? "User"
    }

    /// User type description
    public var userTypeDescription: String {
        switch userType {
        case 1: "Plex User"
        case 2: "Local User"
        case 3: "Jellyfin User"
        default: "Unknown"
        }
    }
}
