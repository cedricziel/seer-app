import Foundation
import SwiftData

/// Cached library for offline browsing
/// Synced via CloudKit with the ServerConfiguration
@Model
public final class CachedLibrary {
    // Note: CloudKit doesn't support unique constraints, using regular attribute
    public var id: String = ""
    public var serverConfigurationID: UUID = UUID()
    public var name: String = ""
    public var collectionType: String?
    public var lastSyncedAt: Date = Date()
    public var imageBlurHashPrimary: String?

    @Relationship(deleteRule: .cascade, inverse: \CachedMediaItem.library)
    public var items: [CachedMediaItem]?

    public init(
        id: String,
        serverConfigurationID: UUID,
        name: String,
        collectionType: String? = nil,
        lastSyncedAt: Date = Date(),
        imageBlurHashPrimary: String? = nil
    ) {
        self.id = id
        self.serverConfigurationID = serverConfigurationID
        self.name = name
        self.collectionType = collectionType
        self.lastSyncedAt = lastSyncedAt
        self.imageBlurHashPrimary = imageBlurHashPrimary
    }
}
