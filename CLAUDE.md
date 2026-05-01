# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Seer is an iOS app for Jellyfin (media server) and Jellyseerr (media request management). It allows users to browse their media library, search for content, and manage media requests.

## Build Commands

```bash
make setup          # Install dev dependencies (xcodegen, swiftlint, swiftformat)
make generate       # Generate Xcode project from project.yml
make build          # Build for iOS Simulator (default: iPhone 17)
make build SIMULATOR="iPhone 15 Pro"  # Build for specific simulator
make build-release  # Build for release
make test           # Run tests on simulator
make lint           # Run SwiftLint (--strict mode)
make format         # Format code with SwiftFormat
make open           # Open Xcode project
make resolve        # Resolve Swift package dependencies
make clean          # Clean build artifacts and derived data
```

Run a single test file:
```bash
xcodebuild test -scheme SeerApp \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:PlaybackClientTests/PiPPlaybackManagerTests
```

Always run `make lint` and `make format` before committing.

## Architecture

### Project Generation
Uses XcodeGen with `project.yml` to generate the Xcode project. Never edit `.xcodeproj` directly.

### Module Structure

**App Target (SeerApp)**
- `App/SeerApp/` - Main app entry point and ContentView with tab navigation

**Feature Modules (in `Features/`)**
- `Auth/` - Server setup flow (Jellyfin + Jellyseerr authentication)
- `Library/` - Media browsing (libraries, items, continue watching, latest)
- `Search/` - Content search via Jellyseerr
- `Requests/` - Media request management
- `Playback/` - Video player with PiP support
- `Downloads/` - Offline media downloads
- `Servers/` - Multi-server management

**Framework Targets (in `Packages/`)**
- `SeerCore` - Shared utilities (AppState, KeychainManager, SwiftData models)
- `JellyfinClient` - Jellyfin API service and models
- `JellyseerrClient` - Jellyseerr API service and models
- `SeerUI` - Reusable UI components (MediaCard, PosterImage, LoadingView, etc.)
- `PlaybackClient` - Video playback, streaming, and PiP management
- `OfflineSync` - Offline library caching with SwiftData
- `DownloadClient` - Background media downloads

### Key Patterns

**MVVM Architecture**
- Each feature has a View + ViewModel pair
- ViewModels are `@MainActor` classes using `@Published` properties
- Views observe state changes and call ViewModel methods

**App State Management**
- `AppState` (in SeerCore) is the central state holder, injected via `@Environment`
- Manages authentication state, credentials, and multi-server configuration
- Credentials stored in Keychain via `KeychainManager`
- Server configurations persisted with SwiftData (`ServerConfiguration` model)

**Service Layer**
- `JellyfinService` - Handles Jellyfin API (auth, libraries, items, images, search)
- `JellyseerrService` - Handles Jellyseerr API (auth, search, requests, media details)
- `PlaybackService` - Streaming URL building and playback session management
- Services are created by ViewModels using credentials from AppState

**Offline Support**
- SwiftData models in `SeerCore`: `CachedLibrary`, `CachedMediaItem`, `CachedUserProgress`
- Sync services in `OfflineSync`: `LibrarySyncService`, `MediaItemSyncService`
- `NetworkMonitor` detects connectivity; views show cached data when offline

**Onboarding & What's New**
- `OnboardingManager` tracks first-launch and version states via `@AppStorage`
- What's New modal shown to returning users after app updates
- First-time tips displayed in empty states for new users
- Feature content defined in `App/SeerApp/WhatsNew/WhatsNewData.swift`
- UI components in `Packages/SeerUI/Sources/SeerUI/WhatsNew/` and `.../Onboarding/`
- See `docs/onboarding.md` for detailed documentation

### Dependencies
- `JellyfinAPI` (jellyfin-sdk-swift) - Official Jellyfin SDK
- `Kingfisher` - Image loading and caching

### Requirements
- iOS 26.0+
- Swift 6.2
- Xcode 16.0+
