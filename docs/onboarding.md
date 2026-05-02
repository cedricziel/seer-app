# Onboarding System

This document describes the onboarding and What's New feature implementation in Seer.

## Architecture Overview

The onboarding system consists of three main components:

1. **OnboardingManager** - Central state management for onboarding flows
2. **What's New Modal** - Apple-style feature announcement for returning users
3. **First-Time User Tips** - Contextual guidance for new users

## Components

### OnboardingManager

Location: `App/SeerApp/Onboarding/OnboardingManager.swift`

The `OnboardingManager` is an `@MainActor` `ObservableObject` that tracks:

- `hasCompletedOnboarding` - Whether the user has completed initial server setup
- `lastSeenWhatsNewVersion` - The app version when the user last saw What's New
- `isFirstLaunchAfterSetup` - Flag for showing first-time user tips
- `showWhatsNew` - Published property that triggers the What's New modal

```swift
@MainActor
final class OnboardingManager: ObservableObject {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("lastSeenWhatsNewVersion") private var lastSeenWhatsNewVersion = ""
    @AppStorage("isFirstLaunchAfterSetup") private(set) var isFirstLaunchAfterSetup = false

    @Published var showWhatsNew = false

    var currentAppVersion: String { ... }
    var shouldShowWhatsNew: Bool { ... }

    func markOnboardingComplete() { ... }
    func markWhatsNewSeen() { ... }
    func checkAndShowWhatsNew() { ... }
    func clearFirstLaunchFlag() { ... }
}
```

### What's New Components

Location: `Packages/SeerUI/Sources/SeerUI/WhatsNew/`

**WhatsNewFeature.swift** - Data model for feature entries:

```swift
public struct WhatsNewFeature: Identifiable, Sendable {
    public let id: UUID
    public let icon: String           // SF Symbol name
    public let iconColor: Color
    public let title: String
    public let description: String
}
```

**WhatsNewView.swift** - Apple-style modal presentation with:
- App icon header
- "What's New in [App Name]" title
- Scrollable list of feature rows with icons
- Full-width "Continue" button
- Dismiss button in toolbar

### First-Time User Tips

Location: `Packages/SeerUI/Sources/SeerUI/Onboarding/`

**OnboardingTipView.swift** - Inline tip card component:

```swift
public struct OnboardingTipView: View {
    public let title: String
    public let description: String
    public let icon: String           // Default: "lightbulb.fill"
    public let iconColor: Color       // Default: .yellow
}
```

### What's New Content

Location: `App/SeerApp/WhatsNew/WhatsNewData.swift`

Static array of `WhatsNewFeature` items describing current app features:

```swift
enum WhatsNewData {
    static let features: [WhatsNewFeature] = [
        WhatsNewFeature(
            icon: "sparkles",
            iconColor: .purple,
            title: "Discover New Content",
            description: "Browse trending movies and TV shows powered by Jellyseerr."
        ),
        // ... more features
    ]
}
```

## User Flows

### New User Flow

The first-run path. Composed of three SwiftUI views in SeerUI
orchestrated by `OnboardingViewModel` (`Features/Auth/`).

```
App Launch
    ↓
ContentView (not authenticated)
    ↓
OnboardingFlowView
    ↓
WelcomeView (state-aware)
    Suggestions sourced from:
      • iCloud-synced ServerConfigurations  → primary
      • Bonjour-discovered _jellyfin._tcp   → fallback primary
      • Manual entry                        → footer / fresh-install primary
    ↓
ManualServerEntryView   (if user picks manual)
    URL → ServerInfoFetcher.fetch(/System/Info/Public)
    ↓
QuickConnectView        (if server's /QuickConnect/Enabled is true)
    Initiate → poll → exchange secret for AccessToken
    "Use Password Instead" + "Cancel" available throughout
    ↓
Password form           (fallback or user choice)
    JellyfinService.authenticate(username:password:)
    ↓
persistAndComplete
    ServerConfiguration written; LAN URL learned for manual paths
    OnboardingManager.markOnboardingComplete()
    appState.isAuthenticated = true
    TelemetryService.recordOnboardingCompleted()
    ↓
MainTabView
    LibraryView shows first-time tip (isFirstLaunchAfterSetup = true)
    Jellyseerr is NOT requested — the Discover/Search/Requests tabs
    each surface a JellyseerrConnectPrompt on demand.
```

### Telemetry funnel

When `DiagnosticsConsent.performanceMetricsEnabled` is true,
`TelemetryService` records four PII-free events:

| Event | When |
|---|---|
| `onboarding_welcome_shown` | First render of `WelcomeView` |
| `onboarding_path_selected` (`bonjour`/`icloud`/`manual`) | User taps a suggestion or "Add a server manually" |
| `onboarding_auth_method` (`quickconnect`/`password`) | Authentication attempted |
| `onboarding_completed` | `appState.isAuthenticated` flips to true |

Payloads carry only the enum rawValues — no hostnames, URLs, or
usernames.


### Returning User Flow (After Update)

```
App Launch
    ↓
MainTabView (authenticated)
    ↓
checkAndShowWhatsNew()
    ↓
shouldShowWhatsNew = true (version mismatch)
    ↓
What's New modal appears
    ↓
"Continue" button → markWhatsNewSeen()
    ↓
Normal app usage
```

## Adding New Features to What's New

When releasing a new version with features to announce:

1. Edit `App/SeerApp/WhatsNew/WhatsNewData.swift`
2. Add new `WhatsNewFeature` entries to the `features` array
3. Use appropriate SF Symbols and colors that match the feature

```swift
WhatsNewFeature(
    icon: "star.fill",           // SF Symbol
    iconColor: .yellow,          // Icon background color
    title: "New Feature",
    description: "Description of what this feature does."
)
```

## Adding Contextual Tips

To add tips to empty states or other views:

1. Import `SeerUI`
2. Add `OnboardingTipView` where appropriate
3. Consider gating with `onboardingManager.isFirstLaunchAfterSetup`

```swift
if onboardingManager.isFirstLaunchAfterSetup {
    OnboardingTipView(
        title: "Pro Tip",
        description: "Helpful information for new users."
    )
}
```

## State Persistence

All onboarding state is persisted using `@AppStorage`:

| Key | Type | Purpose |
|-----|------|---------|
| `hasCompletedOnboarding` | Bool | Server setup completed |
| `lastSeenWhatsNewVersion` | String | Version string when What's New was last dismissed |
| `isFirstLaunchAfterSetup` | Bool | Show first-time tips |

## Environment Object Injection

The `OnboardingManager` is created in `ContentView` and injected via `.environmentObject()`:

```swift
struct ContentView: View {
    @StateObject private var onboardingManager = OnboardingManager()

    var body: some View {
        Group {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(onboardingManager)
            } else {
                ServerSetupView()
                    .environmentObject(onboardingManager)
            }
        }
        .sheet(isPresented: $onboardingManager.showWhatsNew) {
            WhatsNewView(...)
        }
    }
}
```

Views that need onboarding state should add:

```swift
@EnvironmentObject private var onboardingManager: OnboardingManager
```

## Testing

### Simulate Fresh Install
Delete the app or clear UserDefaults to reset all onboarding state.

### Simulate App Update
In Debug, temporarily set `lastSeenWhatsNewVersion` to an old version:
```swift
UserDefaults.standard.set("0.9.0", forKey: "lastSeenWhatsNewVersion")
```

### Verify First-Time Tips
Set `isFirstLaunchAfterSetup` to true to see tips in LibraryView.
