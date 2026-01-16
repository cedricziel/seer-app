import Foundation

/// Jellyseerr permission flags represented as an OptionSet
///
/// This is a lightweight representation used in SeerCore.
/// JellyseerrClient has a more complete UserPermissions type.
public struct JellyseerrPermissions: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    // Basic permissions
    public static let admin = JellyseerrPermissions(rawValue: 2)
    public static let manageSettings = JellyseerrPermissions(rawValue: 4)
    public static let manageUsers = JellyseerrPermissions(rawValue: 8)
    public static let manageRequests = JellyseerrPermissions(rawValue: 16)
    public static let request = JellyseerrPermissions(rawValue: 32)
    public static let vote = JellyseerrPermissions(rawValue: 64)
    public static let autoApprove = JellyseerrPermissions(rawValue: 128)
    public static let autoApproveMovie = JellyseerrPermissions(rawValue: 256)
    public static let autoApproveTV = JellyseerrPermissions(rawValue: 512)

    // 4K permissions
    public static let request4K = JellyseerrPermissions(rawValue: 1024)
    public static let request4KMovie = JellyseerrPermissions(rawValue: 2048)
    public static let request4KTV = JellyseerrPermissions(rawValue: 4096)

    // Advanced permissions
    public static let requestAdvanced = JellyseerrPermissions(rawValue: 8192)

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
