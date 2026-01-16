import SeerCore
import SwiftData
import SwiftUI

@main
struct SeerApp: App {
    @StateObject private var appState: AppState

    let modelContainer: ModelContainer

    init() {
        // Configure SwiftData with CloudKit
        let schema = Schema([ServerConfiguration.self])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.com.cedricziel.seer")
        )

        do {
            modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }

        // Initialize AppState
        let state = AppState()
        _appState = StateObject(wrappedValue: state)

        // Migrate any existing local keychain items to iCloud-synced items
        KeychainManager.shared.migrateToSyncedKeychain()

        // Migrate from NSUbiquitousKeyValueStore to SwiftData (if needed)
        migrateFromKVS(context: modelContainer.mainContext, appState: state)

        // Set the model context on AppState
        state.setModelContext(modelContainer.mainContext)

        // Migrate legacy single-server credentials to multi-server format
        state.migrateLegacyCredentials()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }

    /// Migrate server configurations from NSUbiquitousKeyValueStore to SwiftData
    private func migrateFromKVS(context: ModelContext, appState _: AppState) {
        let kvs = NSUbiquitousKeyValueStore.default

        // Check if migration is needed
        guard let data = kvs.data(forKey: "server_configurations") else {
            // No KVS data to migrate
            return
        }

        // Decode old format
        let decoder = JSONDecoder()
        guard let oldConfigs = try? decoder.decode([LegacyServerConfiguration].self, from: data) else {
            print("Failed to decode legacy server configurations")
            return
        }

        // Get active server ID from KVS
        let activeServerIDString = kvs.string(forKey: "active_server_id")
        let activeServerID = activeServerIDString.flatMap { UUID(uuidString: $0) }

        // Insert into SwiftData
        for old in oldConfigs {
            let isActive = old.id == activeServerID || (activeServerID == nil && old == oldConfigs.first)

            let newConfig = ServerConfiguration(
                id: old.id,
                name: old.name,
                emoji: old.emoji,
                jellyfinURL: old.jellyfinURL,
                jellyseerrURL: old.jellyseerrURL,
                jellyfinUserID: old.jellyfinUserID,
                lastUsed: old.lastUsed,
                createdAt: old.createdAt,
                isActive: isActive
            )

            context.insert(newConfig)
        }

        // Save the migration
        do {
            try context.save()
            print("Successfully migrated \(oldConfigs.count) server configurations from KVS to SwiftData")

            // Clear KVS after successful migration
            kvs.removeObject(forKey: "server_configurations")
            kvs.removeObject(forKey: "active_server_id")
            kvs.synchronize()
        } catch {
            print("Failed to save migrated server configurations: \(error)")
        }
    }
}

// MARK: - Equatable conformance for migration comparison

extension LegacyServerConfiguration: Equatable {
    public static func == (lhs: LegacyServerConfiguration, rhs: LegacyServerConfiguration) -> Bool {
        lhs.id == rhs.id
    }
}
