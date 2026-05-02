import AppIntents
import Foundation

/// AppEntity representing a configured Jellyfin/Jellyseerr server.
/// Used as an optional parameter on intents that need multi-server
/// disambiguation (Decision D3 in design.md).
public struct ServerEntity: AppEntity, Equatable {
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: "Server"
    )

    public static let defaultQuery = ServerEntityQuery()

    public let id: UUID
    public let name: String
    public let isActive: Bool

    public init(id: UUID, name: String, isActive: Bool = false) {
        self.id = id
        self.name = name
        self.isActive = isActive
    }

    public var displayRepresentation: DisplayRepresentation {
        if isActive {
            return DisplayRepresentation(
                title: "\(name)",
                subtitle: "Active"
            )
        }
        return DisplayRepresentation(title: "\(name)")
    }
}
