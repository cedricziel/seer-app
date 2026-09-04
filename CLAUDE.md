# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Seer is an iOS/tvOS app for Jellyfin (media server) and Jellyseerr (media request management). It allows users to browse their media library, search for content, and manage media requests.

## Build Commands

```bash
make setup          # Install dev dependencies (xcodegen, swiftlint, swiftformat, ruby)
make generate       # Generate Xcode project from project.yml (xcodegen)
make build          # Build for iOS Simulator (default: iPhone 17)
make build SIMULATOR="iPhone 15 Pro"  # Build for specific simulator
make build-release  # Build for release (generic/platform=iOS)
make test           # Run tests on simulator
make lint           # Run SwiftLint --strict
make format         # Format code with SwiftFormat (CI runs `swiftformat --lint .`)
make open           # Open Xcode project
make resolve        # Resolve Swift package dependencies
make clean          # Remove build/, DerivedData/, and *.xcodeproj
```

Run a single test. The SeerApp scheme runs `SeerCoreTests`, `PlaybackClientTests`,
`DownloadClientTests`, `JellyfinClientTests`, `JellyseerrClientTests`,
`OfflineSyncTests`, `NotificationClientTests`, `SeerUITests`, `AuthFeatureTests`
and `LibraryFeatureTests`; `SeerUITestsTV` and `SeerAppUITests` have their own
schemes and are not part of CI:
```bash
xcodebuild test -scheme SeerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PlaybackClientTests/PiPPlaybackManagerTests
```

Always run `make lint` and `make format` before committing — CI gates on both
(`swiftlint --strict` and `swiftformat --lint`). SwiftLint also runs as a
preBuildScript on the SeerApp target.

### Fastlane / release

```bash
make fastlane-install   # bundle install via Homebrew Ruby (system Ruby 2.6 fails)
make fastlane-test      # fastlane test lane
make fastlane-beta      # build + upload to TestFlight
make fastlane-release   # promote TestFlight build to App Store
```

`MARKETING_VERSION` in `project.yml` is managed by release-please (look for the
`# x-release-please-version` markers — do not bump manually). The build number
is `git rev-list --count HEAD` injected at archive time. See `docs/releases.md`.

## Architecture

### Project generation

Uses **XcodeGen** with `project.yml` to generate the Xcode project. Never edit
`.xcodeproj` directly — `make clean` deletes it and `make generate` regenerates
it. Add new sources by placing them in an existing `sources` path (e.g.
`Features/<Module>/` or `Packages/<Name>/Sources/<Name>/`); xcodegen picks them
up on next generate. New top-level packages or new dependencies require editing
`project.yml`.

CI/Release builds expect `Config/Secrets.xcconfig` — locally copy from
`Config/Secrets.xcconfig.template` if it doesn't exist.

### Module layout

**App target (SeerApp)** — `App/SeerApp/`
- `SeerApp.swift`, `SeerAppDelegate.swift`, `ContentView.swift` — entry point and tab nav
- `Onboarding/` — `OnboardingManager` (`@AppStorage`-backed flags)
- `WhatsNew/WhatsNewData.swift` — feature announcement content

**Feature modules** (in `Features/`, all part of the SeerApp target)
- `Auth/` — Jellyfin + Jellyseerr server setup flow
- `Library/` — media browsing (libraries, items, continue watching, latest)
- `Discover/` — discovery feed, genre browse, request options sheet
- `Search/` — content search via Jellyseerr
- `Requests/` — media request management
- `Playback/` — video player with PiP
- `Downloads/` — offline media downloads
- `Servers/` — multi-server management
- `Feedback/` — feedback form, diagnostics consent, privacy settings

**Framework targets** (in `Packages/`)
- `SeerCore` — `AppState`, `KeychainManager`, SwiftData models
  (`ServerConfiguration`, `CachedLibrary`, `CachedMediaItem`, `CachedUserProgress`),
  `TelemetryService` (OpenTelemetry), `CrashReportBridge` (PLCrashReporter),
  `DiagnosticsConsent`, `ServerURLResolver`
- `JellyfinClient` — Jellyfin API service and models (wraps `JellyfinAPI` SDK)
- `JellyseerrAPI` — local SwiftPM package; the generated Jellyseerr OpenAPI
  client (excluded from SwiftLint/SwiftFormat — do not hand-edit
  `Sources/JellyseerrAPI/Generated`)
- `JellyseerrClient` — hand-written wrapper over `JellyseerrAPI`
- `SeerUI` — reusable SwiftUI components (MediaCard, PosterImage, LoadingView, WhatsNew, Onboarding)
- `PlaybackClient` — streaming, PiP, `StreamURLBuilder`, `PiPPlaybackManager`
- `OfflineSync` — SwiftData-backed library/item sync, `NetworkMonitor`
- `DownloadClient` — background URLSession downloads
- `NotificationClient` — UNUserNotificationCenter wrapper, request status polling, download notifications

Dependency direction is one-way: features → clients → SeerCore. Clients never
import each other except where declared in `project.yml` (e.g. `DownloadClient`
depends on `PlaybackClient`; `NotificationClient` depends on `JellyseerrClient`
and `DownloadClient`).

### Key patterns

**MVVM** — Each feature has a View + ViewModel pair. ViewModels are
`@MainActor` classes using `@Published` properties. Services are constructed by
the ViewModel using credentials from `AppState`.

**App state** — `AppState` (in `SeerCore`) is the central state holder,
injected via `@Environment`. Manages auth state, credentials (in Keychain via
`KeychainManager`), and multi-server config (`ServerConfiguration` SwiftData
model). iCloud KVS + CloudKit container `iCloud.com.cedricziel.seer` are
enabled in entitlements.

**Service layer** — `JellyfinService`, `JellyseerrService`, `PlaybackService`.
Created on demand by ViewModels; not singletons.

**Offline support** — `OfflineSync` keeps SwiftData caches in sync with
Jellyfin. `NetworkMonitor` flips views to cached data when offline.

**Onboarding & What's New** — `OnboardingManager` tracks first-launch and
last-seen-version via `@AppStorage`. What's New modal shows after version
bumps; first-time tips render in empty states. Content lives in
`App/SeerApp/WhatsNew/WhatsNewData.swift`. See `docs/onboarding.md`.

**Telemetry & crash reporting** — `TelemetryService` exports via OpenTelemetry
OTLP/HTTP (endpoint + auth header read from `Info.plist` keys `OTLPEndpoint` /
`OTLPAuthHeader`, populated from `Config/Secrets.xcconfig`). `CrashReportBridge`
wraps PLCrashReporter. Both gate on `DiagnosticsConsent` — nothing leaves the
device unless the user opts in via `PrivacySettingsView` /
`DiagnosticsConsentSheet`.

### Lint/format limits worth remembering

`.swiftlint.yml`: line_length warn 120 / err 150, function_body warn 60 / err
80, file_length warn 800, type_body warn 550, nesting type/function level 2.
`Packages/JellyseerrAPI` is excluded from both linters.

### Requirements

- iOS 26.0+ / tvOS 26.0+
- Swift 6.2
- Xcode 26+ (iOS 26 SDK)
