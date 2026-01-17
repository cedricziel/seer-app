import SeerUI
import SwiftUI

/// Version and feature content for What's New modal
enum WhatsNewData {
    /// Current features to display in What's New modal
    static let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "sparkles",
            iconColor: .purple,
            title: "Discover New Content",
            description: "Browse trending movies and TV shows powered by Jellyseerr."
        ),
        WhatsNewFeature(
            icon: "pip.fill",
            iconColor: .blue,
            title: "Picture-in-Picture",
            description: "Keep watching while you browse with PiP support."
        ),
        WhatsNewFeature(
            icon: "arrow.down.circle.fill",
            iconColor: .green,
            title: "Download for Offline",
            description: "Save content to watch later without an internet connection."
        ),
        WhatsNewFeature(
            icon: "server.rack",
            iconColor: .orange,
            title: "Multi-Server Support",
            description: "Connect to multiple Jellyfin servers and switch between them easily."
        ),
        WhatsNewFeature(
            icon: "icloud.fill",
            iconColor: .cyan,
            title: "iCloud Sync",
            description: "Your servers sync across devices with iCloud."
        )
    ]
}
