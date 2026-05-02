## Why

Seer plays media via `AVPlayer` / `AVPlayerViewController` but never explicitly enables external playback, and the custom controls overlay does not surface a route picker. AirPlay is effectively hidden — users can only reach it through the system three-dot menu, and even then external playback may be disabled depending on player defaults. We want a first-class "send to TV / speaker" experience that matches what users expect from a Jellyfin client.

## What Changes

- Explicitly enable AirPlay/external playback on the iOS playback path by setting `allowsExternalPlayback = true` and `usesExternalPlaybackWhileExternalScreenIsActive = true` on the `AVPlayer` driving `AVPlayerViewController`.
- Add a SwiftUI wrapper around `AVRoutePickerView` (`AirPlayRouteButton`) and surface it in `PlayerControlsOverlay` next to the existing audio/subtitle controls. iOS-only — `#if os(iOS)`.
- Publish Now-Playing metadata (title, artwork, duration, current time, rate) to `MPNowPlayingInfoCenter` while playback is active and clear it on dismiss, so AirPlay receivers (Apple TV, HomePod, CarPlay) and the iOS lock screen show real metadata instead of generic placeholders.
- No change to the tvOS playback path — tvOS uses the system player which already handles route selection via Siri Remote / Control Center. tvOS *receiving* AirPlay is explicitly out of scope.
- No Chromecast / DLNA support in this change. Adding the Google Cast SDK has independent cost (binary size, privacy disclosures, receiver app registration) and belongs in a separate proposal.

## Capabilities

### New Capabilities
- `airplay-playback`: Enables routing video and audio playback to external AirPlay receivers (Apple TV, AirPlay-compatible speakers/displays) from the in-app video player on iOS, with visible route-picker UI and Now-Playing metadata propagation.

### Modified Capabilities
<!-- None — there is no existing playback spec to amend; AirPlay is additive on top of the current player. -->

## Impact

- **Affected code (iOS only)**:
  - `Features/Playback/VideoPlayerView.swift` — set external-playback flags on the `AVPlayer` (after the player is attached to `AVPlayerViewController`).
  - `Features/Playback/VideoPlayerViewModel.swift` — own the `MPNowPlayingInfoCenter` lifecycle (populate on play, update on rate/time changes, clear on teardown).
  - `Features/Playback/PlayerControlsOverlay.swift` — render the new `AirPlayRouteButton` alongside existing controls.
  - `SeerUI` (or a new file under `Features/Playback/`) — host the `AVRoutePickerView` SwiftUI wrapper. Choice of location depends on whether we want the button reusable; default to `Features/Playback/` to keep `SeerUI` framework-clean.
- **Not affected**: `PlaybackClient` package (no API changes), `StreamURLBuilder` (HLS/MP4 already AirPlay-compatible), `JellyfinClient`, audio session setup (already `.playback / .moviePlayback`), `UIBackgroundModes` (already includes `audio`).
- **Frameworks**: existing — `AVKit`, `AVFoundation`, `MediaPlayer`. No new SwiftPM dependencies.
- **Entitlements / Info.plist**: no changes. AirPlay does not require a capability or permission string.
- **Networking**: none — AirPlay uses the existing stream URLs the player already consumes; the receiver pulls directly from the Jellyfin server's HLS/MP4 endpoint via the same authenticated URL the iOS device hands off.
- **Telemetry**: optional, gated on `DiagnosticsConsent`. If added, log "airplay route engaged / disengaged" events without identifiers — keep out of scope unless trivially cheap.
- **Tests**: ViewModel unit tests for the Now-Playing metadata lifecycle (set on play, clear on dismiss, update on rate change). UI of the route picker is provided by `AVKit` and not unit-testable; verify manually on device with an Apple TV / HomePod (Simulator does not expose AirPlay routes).
