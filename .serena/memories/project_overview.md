# Seer App Project Overview

## Purpose
iOS app for Jellyfin (media server) and Jellyseerr (media request management). Allows users to browse media library, search content, and manage media requests.

## Tech Stack
- Swift 6.0, iOS 26.0+, Xcode 16.0+
- XcodeGen for project generation (project.yml)
- SwiftUI with MVVM architecture
- Dependencies: JellyfinAPI (jellyfin-sdk-swift), Kingfisher

## Module Structure
- **SeerApp**: Main app target with ContentView and tab navigation
- **SeerCore**: Shared utilities (AppState, KeychainManager, extensions)
- **JellyfinClient**: Jellyfin API service and models
- **JellyseerrClient**: Jellyseerr API service and models
- **SeerUI**: Reusable UI components

## Feature Modules
- **Auth**: Server setup flow (Jellyfin + Jellyseerr authentication)
- **Library**: Media browsing (libraries, items, continue watching, latest)
- **Search**: Content search via Jellyseerr
- **Requests**: Media request management

## Key Patterns
- MVVM with @Observable ViewModels
- AppState as central state holder injected via @Environment
- Credentials stored in Keychain via KeychainManager
- Services created by ViewModels using credentials from AppState
