import SeerCore
import SwiftUI

@main
struct SeerApp: App {
    @StateObject private var appState: AppState

    init() {
        // Migrate any existing local keychain items to iCloud-synced items
        KeychainManager.shared.migrateToSyncedKeychain()

        // Initialize AppState (this will set up the server config store)
        let state = AppState()

        // Migrate legacy single-server credentials to multi-server format
        state.migrateLegacyCredentials()

        _appState = StateObject(wrappedValue: state)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
