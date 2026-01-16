import SeerCore
import SwiftUI

@main
struct SeerApp: App {
    @StateObject private var appState = AppState()

    init() {
        // Migrate any existing local keychain items to iCloud-synced items
        KeychainManager.shared.migrateToSyncedKeychain()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
        }
    }
}
