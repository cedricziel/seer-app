## Why

Offline downloads can consume cellular data despite WiFi-only settings, accept HTTP error bodies as media, and lose viewing progress. Completed downloads also lack a playback action in Downloads.

## What Changes

- Enforce cellular restrictions in fresh and resumed background transfers on iOS and tvOS.
- Reject unsuccessful HTTP responses before saving media or sending completion notifications.
- Play completed movies and episodes directly from Downloads using stored metadata and server identity.
- Persist downloaded-media progress locally and retry server synchronization after reconnecting.
- Add regression tests for these behaviors.
- Repair tvOS compilation by isolating unsupported system integrations and using native player and control alternatives.

## Capabilities

### New Capabilities

- `offline-downloads`: Transfer policy, response validation, playback access, local resume, and progress synchronization.
- `tvos-app-compatibility`: Supported system integrations and native playback and controls on Apple TV.

### Modified Capabilities

None.

## Impact

Both iOS and tvOS. DownloadClient owns background URLSession transfers and per-device SwiftData records, including a new pending-progress table that survives media deletion. PlaybackClient and JellyfinClient wrap playback and server progress reporting. Feature views use those clients; they do not call HTTP APIs directly. No external service configuration changes are required.
