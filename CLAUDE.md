# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Seer is an iOS app for Jellyfin (media server) and Jellyseerr (media request management). It allows users to browse their media library, search for content, and manage media requests.

## Build Commands

```bash
make setup          # Install dev dependencies (xcodegen, swiftlint, swiftformat)
make generate       # Generate Xcode project from project.yml
make build          # Build for iOS Simulator (default: iPhone 16)
make build SIMULATOR="iPhone 15 Pro"  # Build for specific simulator
make build-release  # Build for release
make test           # Run tests on simulator
make lint           # Run SwiftLint (--strict mode)
make format         # Format code with SwiftFormat
make open           # Open Xcode project
make resolve        # Resolve Swift package dependencies
make clean          # Clean build artifacts and derived data
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

**Framework Targets (in `Packages/`)**
- `SeerCore` - Shared utilities (AppState, KeychainManager, extensions)
- `JellyfinClient` - Jellyfin API service and models
- `JellyseerrClient` - Jellyseerr API service and models
- `SeerUI` - Reusable UI components (MediaCard, PosterImage, LoadingView, etc.)

### Key Patterns

**MVVM Architecture**
- Each feature has a View + ViewModel pair
- ViewModels are `@Observable` classes with `@Published` properties
- Views observe state changes and call ViewModel methods

**App State Management**
- `AppState` (in SeerCore) is the central state holder, injected via `@Environment`
- Manages authentication state, credentials, and error handling
- Credentials stored in Keychain via `KeychainManager`

**Service Layer**
- `JellyfinService` - Handles Jellyfin API (auth, libraries, items, images, search)
- `JellyseerrService` - Handles Jellyseerr API (auth, search, requests, media details)
- Services are created by ViewModels using credentials from AppState

### Dependencies
- `JellyfinAPI` (jellyfin-sdk-swift) - Official Jellyfin SDK
- `Kingfisher` - Image loading and caching

### Requirements
- iOS 26.0+
- Swift 6.0
- Xcode 16.0+
