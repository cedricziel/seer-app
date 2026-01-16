// NotificationClient - Local notifications for Seer
//
// This package provides:
// - Local notification management for downloads and requests
// - Permission handling with contextual requests
// - Background request status polling
// - Configurable notification preferences

@_exported import Foundation
@_exported import UserNotifications

// MARK: - SwiftData Container

import SwiftData

/// Create a model container for notifications (no CloudKit)
public func createNotificationModelContainer() throws -> ModelContainer {
    let schema = Schema([
        NotificationPreferences.self,
        CachedRequestStatus.self
    ])

    let configuration = ModelConfiguration(
        "Notifications",
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .none, // Per-device, no shared container
        cloudKitDatabase: .none // No CloudKit sync
    )

    return try ModelContainer(for: schema, configurations: [configuration])
}
