import AppIntents
import Foundation
import SwiftData

/// Tier 2 intent: "Check my requests on Seer."
///
/// Returns up to 10 cached requests, ordered by `requestedAt`
/// descending. Reads from `CachedRequest`; returns a graceful empty
/// snippet when nothing has been cached yet (fresh install before
/// the user has opened the Requests tab).
public struct CheckRequestStatusIntent: AppIntent {
    public static let title: LocalizedStringResource = "Check Request Status"

    public static let description = IntentDescription(
        "List your pending and recently fulfilled Jellyseerr requests."
    )

    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws
        -> some IntentResult & ReturnsValue<[RequestEntity]> & ProvidesDialog {
        guard let appState = AppIntentsContext.appState, appState.isAuthenticated else {
            throw IntentError.needsConfiguration
        }

        let entities = await (try? RequestEntityQuery().suggestedEntities()) ?? []

        if entities.isEmpty {
            return .result(
                value: entities,
                dialog: IntentDialog(
                    "No cached requests yet — open Seer's Requests tab to populate."
                )
            )
        }

        let pending = entities.count(where: { $0.statusRawValue == 1 })
        let dialog = if pending > 0 {
            IntentDialog("You have \(pending) pending request(s).")
        } else {
            IntentDialog("You have \(entities.count) recent request(s).")
        }

        return .result(value: entities, dialog: dialog)
    }
}
