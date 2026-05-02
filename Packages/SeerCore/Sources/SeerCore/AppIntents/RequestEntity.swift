import AppIntents
import CoreSpotlight
import Foundation

/// AppEntity representing a Jellyseerr media request, sourced from the
/// `CachedRequest` SwiftData store.
public struct RequestEntity: AppEntity, IndexedEntity, Equatable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Media Request"
    )

    public static let defaultQuery = RequestEntityQuery()

    public let id: String
    public let title: String
    public let mediaType: String
    public let statusRawValue: Int
    public let requestedAt: Date

    public init(
        id: String,
        title: String,
        mediaType: String,
        statusRawValue: Int,
        requestedAt: Date
    ) {
        self.id = id
        self.title = title
        self.mediaType = mediaType
        self.statusRawValue = statusRawValue
        self.requestedAt = requestedAt
    }

    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(statusName)"
        )
    }

    public var statusName: String {
        switch statusRawValue {
        case 1: "Pending"
        case 2: "Approved"
        case 3: "Declined"
        case 4: "Available"
        case 5: "Processing"
        default: "Unknown"
        }
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .item)
        set.title = title
        set.contentDescription = statusName
        set.identifier = id
        return set
    }
}
