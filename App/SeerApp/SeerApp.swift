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

        // Set the model context on AppState
        state.setModelContext(modelContainer.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .modelContainer(modelContainer)
        }
    }
}
