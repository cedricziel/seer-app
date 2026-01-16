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

    // MARK: - Permission Helpers

    /// User permissions as an OptionSet for easier handling
    public var userPermissions: UserPermissions {
        UserPermissions(rawValue: permissions)
    }

    /// Whether the user can manage requests (approve/decline)
    public var canManageRequests: Bool {
        userPermissions.canManageRequests
    }

    /// Whether the user can request 4K content
    public var canRequest4K: Bool {
        userPermissions.canRequest4K
    }

    /// Whether the user can request 4K movies
    public var canRequest4KMovie: Bool {
        userPermissions.canRequest4KMovie
    }

    /// Whether the user can request 4K TV shows
    public var canRequest4KTV: Bool {
        userPermissions.canRequest4KTV
    }

    /// Whether the user has admin privileges
    public var isAdmin: Bool {
        userPermissions.contains(.admin)
    }

    /// Whether the user can use advanced request options
    public var canUseAdvancedRequest: Bool {
        userPermissions.contains(.admin) || userPermissions.contains(.requestAdvanced)
    }
}

// MARK: - User Permissions

/// Jellyseerr permission flags represented as an OptionSet
public struct UserPermissions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // Basic permissions
    public static let admin = UserPermissions(rawValue: 2)
    public static let manageSettings = UserPermissions(rawValue: 4)
    public static let manageUsers = UserPermissions(rawValue: 8)
    public static let manageRequests = UserPermissions(rawValue: 16)
    public static let request = UserPermissions(rawValue: 32)
    public static let vote = UserPermissions(rawValue: 64)
    public static let autoApprove = UserPermissions(rawValue: 128)
    public static let autoApproveMovie = UserPermissions(rawValue: 256)
    public static let autoApproveTV = UserPermissions(rawValue: 512)

    // 4K permissions
    public static let request4K = UserPermissions(rawValue: 1024)
    public static let request4KMovie = UserPermissions(rawValue: 2048)
    public static let request4KTV = UserPermissions(rawValue: 4096)

    // Advanced permissions
    public static let requestAdvanced = UserPermissions(rawValue: 8192)
    public static let autoApprove4K = UserPermissions(rawValue: 16384)
    public static let autoApprove4KMovie = UserPermissions(rawValue: 32768)
    public static let autoApprove4KTV = UserPermissions(rawValue: 65536)

    // Additional permissions
    public static let manageIssues = UserPermissions(rawValue: 131_072)
    public static let viewIssues = UserPermissions(rawValue: 262_144)
    public static let createIssues = UserPermissions(rawValue: 524_288)
    public static let autoRequestMovie = UserPermissions(rawValue: 1_048_576)
    public static let autoRequestTV = UserPermissions(rawValue: 2_097_152)
    public static let recentlyViewed = UserPermissions(rawValue: 4_194_304)
    public static let watchlistSync = UserPermissions(rawValue: 8_388_608)

    // MARK: - Convenience Properties

    /// Whether the user can manage requests (approve/decline)
    public var canManageRequests: Bool {
        contains(.admin) || contains(.manageRequests)
    }

    /// Whether the user can request 4K content (any type)
    public var canRequest4K: Bool {
        contains(.admin) || contains(.request4K) ||
            contains(.request4KMovie) || contains(.request4KTV)
    }

    /// Whether the user can request 4K movies specifically
    public var canRequest4KMovie: Bool {
        contains(.admin) || contains(.request4K) || contains(.request4KMovie)
    }

    /// Whether the user can request 4K TV shows specifically
    public var canRequest4KTV: Bool {
        contains(.admin) || contains(.request4K) || contains(.request4KTV)
    }
}
