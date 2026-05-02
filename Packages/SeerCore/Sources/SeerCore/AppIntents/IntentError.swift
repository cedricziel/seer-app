import AppIntents
import Foundation

/// Errors thrown by Seer's App Intents. Conforms to
/// `LocalizedError` so the system can surface a useful message to
/// the user, and to `CustomLocalizedStringResourceConvertible` so the
/// system can render localized snippets in Siri/Shortcuts surfaces.
public enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    /// User has not finished onboarding / is not signed in. Surfaces
    /// to the system as "Set up Seer to use this shortcut."
    case needsConfiguration

    /// Resolved server is not reachable (network error / wrong URL).
    case serverNotReachable

    /// Item or request not found in cache or on the server.
    case notFound(String)

    /// Required Jellyseerr server is not configured for the resolved
    /// server (some users only configure Jellyfin).
    case jellyseerrNotConfigured

    public var localizedStringResource: LocalizedStringResource {
        switch self {
        case .needsConfiguration:
            "Set up Seer to use this shortcut."
        case .serverNotReachable:
            "Couldn't reach your Seer server. Try again when you're back online."
        case let .notFound(name):
            "Couldn't find \(name) on your server."
        case .jellyseerrNotConfigured:
            "Jellyseerr isn't set up yet. Open Seer and configure it from the Discover tab."
        }
    }
}
