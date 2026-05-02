import AppIntents
import SeerCore

/// Registers Seer's Tier 1 App Shortcuts so the system can surface
/// them in Spotlight, the Action Button, Siri, and the Shortcuts
/// app without requiring the user to configure anything first.
///
/// Tier 2 intents (`MarkAsWatchedIntent`, `DownloadForOfflineIntent`,
/// `CheckRequestStatusIntent`) are intentionally NOT listed here —
/// they are still callable as Shortcut actions, but only after the
/// user explicitly adds them.
struct SeerAppShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: RequestMediaIntent(),
            phrases: [
                "Request \(\.$title) on \(.applicationName)",
                "Request \(\.$title) in \(.applicationName)"
            ],
            shortTitle: "Request Media",
            systemImageName: "plus.app"
        )
        AppShortcut(
            intent: SearchMediaIntent(),
            phrases: [
                "Search \(.applicationName) for \(\.$query)",
                "Search for \(\.$query) in \(.applicationName)"
            ],
            shortTitle: "Search",
            systemImageName: "magnifyingglass"
        )
        AppShortcut(
            intent: ResumeWatchingIntent(),
            phrases: [
                "Resume on \(.applicationName)",
                "Continue watching on \(.applicationName)"
            ],
            shortTitle: "Resume Watching",
            systemImageName: "play.circle"
        )
    }
}
