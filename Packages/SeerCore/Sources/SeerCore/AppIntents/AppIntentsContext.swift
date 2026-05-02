import Foundation
import SwiftData

/// Shared accessor for the SwiftData container that AppEntity queries
/// read from. The app sets this at launch (in `SeerApp.init`); tests
/// inject an in-memory container before each test.
///
/// AppIntents `EntityQuery` types are constructed by the framework via
/// parameterless `init()`, so they cannot accept dependencies through
/// their initializers. A shared accessor is the conventional pattern.
public enum AppIntentsContext {
    /// The model container queries read from. May be nil before app
    /// launch completes; queries treat nil as "no data yet" and return
    /// empty results rather than throwing.
    @MainActor public static var modelContainer: ModelContainer?

    /// Convenience accessor for the main context. Returns nil when no
    /// container has been registered yet.
    @MainActor public static var mainContext: ModelContext? {
        modelContainer?.mainContext
    }
}
