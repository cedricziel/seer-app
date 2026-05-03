import Foundation

/// Detailed information about a person (actor, director, etc.) returned by
/// `/Users/{userID}/Items/{personID}` when the item is a Person.
public struct PersonDetail: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let name: String
    public let overview: String?
    public let premiereDate: Date?
    public let endDate: Date?
    public let productionLocations: [String]?
    public let imageTag: String?

    public init(
        id: String,
        name: String,
        overview: String? = nil,
        premiereDate: Date? = nil,
        endDate: Date? = nil,
        productionLocations: [String]? = nil,
        imageTag: String? = nil
    ) {
        self.id = id
        self.name = name
        self.overview = overview
        self.premiereDate = premiereDate
        self.endDate = endDate
        self.productionLocations = productionLocations
        self.imageTag = imageTag
    }

    enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case overview = "Overview"
        case premiereDate = "PremiereDate"
        case endDate = "EndDate"
        case productionLocations = "ProductionLocations"
        case imageTags = "ImageTags"
    }

    private enum ImageTagKeys: String, CodingKey {
        case primary = "Primary"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        overview = try container.decodeIfPresent(String.self, forKey: .overview)
        premiereDate = try container.decodeIfPresent(Date.self, forKey: .premiereDate)
        endDate = try container.decodeIfPresent(Date.self, forKey: .endDate)
        productionLocations = try container.decodeIfPresent([String].self, forKey: .productionLocations)

        if let tagContainer = try? container.nestedContainer(keyedBy: ImageTagKeys.self, forKey: .imageTags) {
            imageTag = try tagContainer.decodeIfPresent(String.self, forKey: .primary)
        } else {
            imageTag = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(overview, forKey: .overview)
        try container.encodeIfPresent(premiereDate, forKey: .premiereDate)
        try container.encodeIfPresent(endDate, forKey: .endDate)
        try container.encodeIfPresent(productionLocations, forKey: .productionLocations)
        if let imageTag {
            var tagContainer = container.nestedContainer(keyedBy: ImageTagKeys.self, forKey: .imageTags)
            try tagContainer.encode(imageTag, forKey: .primary)
        }
    }
}
