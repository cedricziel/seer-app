import AppIntents
import CoreSpotlight
import Foundation

/// AppEntity representing a media item (movie, episode, series) that the
/// user has cached locally via `OfflineSync`. Surfaced to Siri,
/// Shortcuts, and Spotlight semantic indexing.
///
/// The identifier shape matches `CachedMediaItem.id` — Jellyfin's
/// server-side identifier, which is stable across re-syncs.
///
/// Conforms to `IndexedEntity` so the system can include this entity in
/// the on-device semantic index when the user opts in via the
/// `appIntentsIndexingEnabled` privacy flag.
public struct MediaItemEntity: AppEntity, IndexedEntity, Equatable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Media Item"
    )

    public static let defaultQuery = MediaItemEntityQuery()

    public let id: String
    public let title: String
    public let year: Int?
    public let mediaType: String

    public init(id: String, title: String, year: Int? = nil, mediaType: String = "") {
        self.id = id
        self.title = title
        self.year = year
        self.mediaType = mediaType
    }

    public var displayRepresentation: DisplayRepresentation {
        if let year {
            return DisplayRepresentation(
                title: "\(title)",
                subtitle: "\(year)"
            )
        }
        return DisplayRepresentation(title: "\(title)")
    }

    /// Spotlight attributes — kept intentionally minimal: title, year,
    /// type, identifier. No posters, no plot summaries, no watched
    /// state. Matches the `app-intents-foundation` spec's "what is
    /// indexed" footer text.
    public var attributeSet: CSSearchableItemAttributeSet {
        let set = CSSearchableItemAttributeSet(contentType: .item)
        set.title = title
        if let year {
            set.contentDescription = "\(year)"
        }
        set.identifier = id
        return set
    }
}
