import AppIntents
import Foundation
import OSLog

/// Focus Filter that pins Seer's active server for the duration of
/// a Focus mode. When the user activates a Focus configured with
/// this filter (e.g., "Family Movie Night"), the active server
/// flips to the chosen one; when the Focus deactivates, the
/// previously active server is restored.
///
/// Lives in `SeerCore` (rather than the App target) because
/// `SetFocusFilterIntent` types are App Intents — they can run in
/// background contexts and benefit from being in the shared module.
public struct SeerFocusFilter: SetFocusFilterIntent {
    public static let title: LocalizedStringResource = "Pin Server"

    public static let description = IntentDescription(
        "Pin Seer's active server while this Focus is on, restore the previous one when it ends."
    )

    @Parameter(title: "Server")
    public var server: ServerEntity?

    public init() {}

    public init(server: ServerEntity?) {
        self.server = server
    }

    public var displayRepresentation: DisplayRepresentation {
        if let server {
            return DisplayRepresentation(
                title: "Pin to \(server.name)",
                subtitle: "Active server while this Focus is on"
            )
        }
        return DisplayRepresentation(title: "Pin Server")
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        let logger = Logger(subsystem: "com.cedricziel.seer", category: "SeerFocusFilter")
        guard let appState = AppIntentsContext.appState else {
            logger.info("Focus filter triggered before app state was registered")
            return .result()
        }
        guard let server else {
            logger.info("Focus filter triggered without a configured server")
            return .result()
        }

        // If the chosen server is no longer configured (deleted between
        // Focus configuration and activation), no-op gracefully.
        guard appState.servers.contains(where: { $0.id == server.id }) else {
            logger.info("Focus filter server \(server.id, privacy: .public) no longer configured")
            return .result()
        }

        // Push the previous active server onto the stack and switch.
        FocusServerStack.shared.push(appState.activeServerID)
        appState.switchServer(to: server.id)
        return .result()
    }
}

/// Stack of previously-active server ids. When a Focus mode using
/// `SeerFocusFilter` deactivates, the system removes the filter
/// configuration; we restore by popping the stack.
///
/// Lives outside the filter struct because filter types are
/// constructed fresh per perform() — they can't carry state.
@MainActor
public final class FocusServerStack {
    public static let shared = FocusServerStack()

    private var stack: [UUID?] = []

    private init() {}

    public func push(_ serverID: UUID?) {
        stack.append(serverID)
    }

    public func pop() -> UUID? {
        guard !stack.isEmpty else { return nil }
        return stack.removeLast() ?? nil
    }

    public var depth: Int {
        stack.count
    }

    public func reset() {
        stack.removeAll()
    }
}
