// DownloadClient - Offline media storage for Seer
//
// This package provides:
// - Background download management with URLSession
// - Per-device SwiftData storage (no CloudKit sync)
// - Download queue with concurrency control
// - Auto-download rules for TV series
// - iOS storage management integration (visible in Settings)

@_exported import Foundation

// MARK: - Models

@_exported import struct Foundation.Data
@_exported import struct Foundation.Date
@_exported import struct Foundation.URL
@_exported import struct Foundation.UUID

/// Re-export public types
public typealias DownloadID = UUID

// MARK: - SwiftData Container

import SwiftData

/// Create a model container for downloads (no CloudKit)
public func createDownloadModelContainer() throws -> ModelContainer {
    let schema = Schema([
        Download.self,
        AutoDownloadRule.self
    ])

    let configuration = ModelConfiguration(
        "Downloads",
        schema: schema,
        isStoredInMemoryOnly: false,
        allowsSave: true,
        groupContainer: .none, // Per-device, no shared container
        cloudKitDatabase: .none // No CloudKit sync
    )

    return try ModelContainer(for: schema, configurations: [configuration])
}
