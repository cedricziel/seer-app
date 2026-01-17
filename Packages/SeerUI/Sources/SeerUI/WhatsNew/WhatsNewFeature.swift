import SwiftUI

/// A feature to display in the What's New modal
public struct WhatsNewFeature: Identifiable, Sendable {
    public let id: UUID
    public let icon: String
    public let iconColor: Color
    public let title: String
    public let description: String

    public init(
        id: UUID = UUID(),
        icon: String,
        iconColor: Color,
        title: String,
        description: String
    ) {
        self.id = id
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.description = description
    }
}
