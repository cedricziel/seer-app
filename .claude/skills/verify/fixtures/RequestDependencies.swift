import Foundation
import SwiftData

@MainActor
public final class AppState {
    public var activeServerID: UUID?
    public var jellyseerrServerURL: URL?
    public var jellyseerrAPIKey: String?
    public var sharedModelContext: ModelContext?
    public var canManageRequests = false
    public init() {}
}
