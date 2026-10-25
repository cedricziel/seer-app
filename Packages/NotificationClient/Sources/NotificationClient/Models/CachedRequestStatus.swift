import Foundation
import SwiftData

/// Tracks the last known status of a media request for detecting changes
@Model
public final class CachedRequestStatus {
    /// Identifier of the request on its Jellyseerr server. Request IDs are
    /// per-server integers, so uniqueness is on `(serverID, requestID)`, not
    /// on `requestID` alone.
    public var requestID: Int

    /// Request approval status, independent of media availability.
    public var status: Int

    /// Nil until a poll establishes availability for this request's resolution.
    public var mediaStatus: Int?

    /// Title of the media for notification display
    public var mediaTitle: String

    /// Type of media (movie, tv)
    public var mediaType: String

    /// When the status was last checked
    public var lastChecked: Date

    /// Server ID this request belongs to
    public var serverID: String

    public init(
        requestID: Int,
        status: Int,
        mediaTitle: String,
        mediaType: String,
        serverID: String
    ) {
        self.requestID = requestID
        self.status = status
        self.mediaTitle = mediaTitle
        self.mediaType = mediaType
        self.serverID = serverID
        lastChecked = Date()
    }
}

/// Status changes that warrant notifications
public enum RequestStatusChange: Sendable {
    case approved(requestID: Int, title: String)
    case available(requestID: Int, title: String)
    case declined(requestID: Int, title: String)

    /// Human-readable status description for notifications
    public var notificationTitle: String {
        switch self {
        case .approved:
            "Request Approved"
        case .available:
            "Media Available"
        case .declined:
            "Request Declined"
        }
    }

    /// Human-readable body for notifications
    public var notificationBody: String {
        switch self {
        case let .approved(_, title):
            "\"\(title)\" has been approved and will be processed."
        case let .available(_, title):
            "\"\(title)\" is now available to watch."
        case let .declined(_, title):
            "Your request for \"\(title)\" was declined."
        }
    }

    public var requestID: Int {
        switch self {
        case let .approved(id, _),
             let .available(id, _),
             let .declined(id, _):
            id
        }
    }
}
