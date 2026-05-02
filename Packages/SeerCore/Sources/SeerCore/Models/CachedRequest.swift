import Foundation
import SwiftData

/// Cached Jellyseerr request, used by `CheckRequestStatusIntent` and the
/// `RequestEntity` AppEntity query. Mirrors a subset of
/// `JellyseerrClient.MediaRequest` — only the fields needed to render a
/// system-rendered intent snippet (title, type, status, requestedAt).
///
/// This cache is populated opportunistically by `RequestsViewModel`
/// whenever the user opens the Requests tab; it is not a complete mirror
/// of the server. Intents that read from this cache return whatever
/// happens to be present and gracefully return empty when nothing has
/// been cached yet.
@Model
public final class CachedRequest {
    /// Stable identifier composed from `serverConfigurationID:requestId`
    /// so two servers with the same numeric request id remain distinct.
    public var id: String = ""

    /// Server this request belongs to.
    public var serverConfigurationID: UUID = UUID()

    /// Numeric request id from Jellyseerr.
    public var requestID: Int = 0

    /// Display title at request time. Falls back to `originalTitle` then
    /// `name` if the title is missing.
    public var title: String = ""

    /// "movie" or "tv".
    public var mediaType: String = ""

    /// Raw `MediaRequest.RequestStatus` rawValue. Stored as Int so the
    /// model survives schema renames in the upstream API.
    public var statusRawValue: Int = 0

    /// When the user submitted the request.
    public var requestedAt: Date = Date()

    /// TMDB id of the requested media, used to dedupe against the
    /// `CachedMediaItem` library cache.
    public var mediaTmdbId: Int?

    /// Jellyseerr media availability raw value (so a request marked
    /// "available" can be distinguished from one still processing).
    public var availabilityRawValue: Int?

    /// Last refresh time — used to avoid stale entries on display.
    public var lastSyncedAt: Date = Date()

    public init(
        serverConfigurationID: UUID,
        requestID: Int,
        title: String,
        mediaType: String,
        statusRawValue: Int,
        requestedAt: Date,
        mediaTmdbId: Int? = nil,
        availabilityRawValue: Int? = nil,
        lastSyncedAt: Date = Date()
    ) {
        id = "\(serverConfigurationID.uuidString):\(requestID)"
        self.serverConfigurationID = serverConfigurationID
        self.requestID = requestID
        self.title = title
        self.mediaType = mediaType
        self.statusRawValue = statusRawValue
        self.requestedAt = requestedAt
        self.mediaTmdbId = mediaTmdbId
        self.availabilityRawValue = availabilityRawValue
        self.lastSyncedAt = lastSyncedAt
    }
}
