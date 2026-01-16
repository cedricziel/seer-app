import Foundation

/// Represents a Jellyfin library (collection)
public struct Library: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let collectionType: CollectionType?
    public let imageBlurHashes: MediaItem.ImageBlurHashes?

    public enum CollectionType: String, Codable, Sendable {
        case movies
        case tvshows
        case music
        case books
        case homevideos
        case boxsets
        case playlists
        case unknown

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let rawValue = try container.decode(String.self)
            self = CollectionType(rawValue: rawValue) ?? .unknown
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case collectionType = "CollectionType"
        case imageBlurHashes = "ImageBlurHashes"
    }
}

/// Response wrapper for libraries endpoint
public struct LibrariesResponse: Codable, Sendable {
    public let items: [Library]

    enum CodingKeys: String, CodingKey {
        case items = "Items"
    }
}
