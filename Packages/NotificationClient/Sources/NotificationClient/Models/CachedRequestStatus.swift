import Foundation
import SwiftData

/// Tracks the last known status of a media request for detecting changes
@Model
public final class CachedRequestStatus {
    /// Unique identifier for the request
    @Attribute(.unique)
    public var requestID: Int

    /// Current status value (maps to RequestStatus from JellyseerrClient)
    /// 1 = pending, 2 = approved, 3 = declined, 4 = available, 5 = processing
    public var status: Int

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

/// SwiftData @Model classes need explicit Sendable conformance for cross-actor use
extension CachedRequestStatus: @unchecked Sendable {}

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
