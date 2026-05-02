## Context

Seer's video playback path is `Features/Playback/VideoPlayerView.swift` (iOS, wrapping `AVPlayerViewController` via `UIViewControllerRepresentable`) and `TVPlayerView.swift` (tvOS, native `AVPlayerViewController`). The `VideoPlayerViewModel` owns the `AVPlayer`, sets up `AVAudioSession` with `.playback / .moviePlayback`, and drives PiP through the existing `PiPPlaybackManager` in `Packages/PlaybackClient/`.

Today the AVPlayer is created without ever touching `allowsExternalPlayback`. AVPlayer's default for that flag is `true`, so the system three-dot menu *can* show AirPlay rows — but the behavior is undocumented enough that we should set it explicitly. The custom `PlayerControlsOverlay` has no AirPlay button at all, so on devices where the three-dot menu is hidden (during gestures, in PiP transitions) AirPlay is unreachable. There is also no `MPNowPlayingInfoCenter` integration, so AirPlay receivers display generic placeholder metadata.

Stream URLs are produced by `StreamURLBuilder` (HLS for transcoded items, progressive MP4 for direct play). Both formats are AirPlay-compatible — no work needed on the streaming side. `UIBackgroundModes` already includes `audio`, audio-session category is correct, no entitlement is required for AirPlay.

## Goals / Non-Goals

**Goals:**
- iOS users can route the currently playing item to any AirPlay receiver via a discoverable button in the player controls.
- AirPlay receivers (Apple TV, HomePod, AirPlay-2 speakers) and the iOS lock screen show real Now-Playing metadata: title, artwork, duration, current time, and playback rate.
- Continued playback when the device locks while AirPlay is engaged.
- Zero regression to the existing PiP flow, gesture overlay, audio session, or the tvOS player path.

**Non-Goals:**
- tvOS *receiving* AirPlay (would require `AVAudioSession` route-detection wiring, separate UX, and a different audio-session category — substantial scope).
- Chromecast / Google Cast support (separate SDK, binary-size and privacy implications, deserves its own proposal).
- DLNA / UPnP discovery (Jellyfin server-side concern, not an iOS-app concern).
- Custom AirPlay route picker styling beyond what `AVRoutePickerView` natively offers.
- Multi-room AirPlay-2 *grouping* UI — the system route picker already supports this; we don't build our own.

## Decisions

### D1. Use the system `AVRoutePickerView` rather than a custom picker

We wrap `AVRoutePickerView` in a `UIViewRepresentable` (`AirPlayRouteButton`) and surface the system-provided picker directly. **Rationale:** the OS picker handles route discovery, mirroring negotiation, lock-screen propagation, and (on AirPlay-2) speaker grouping. Re-implementing it would require private APIs and would never reach feature parity. Apple explicitly recommends `AVRoutePickerView` over `MPVolumeView` for video apps. **Alternatives considered:** (a) `MPVolumeView` — deprecated for AirPlay UI since iOS 11, audio-only; (b) custom button that programmatically opens the system route picker via `MPVolumeView`'s `showsVolumeSlider = false` trick — works but is brittle and shows the deprecated warning.

### D2. Set external-playback flags explicitly, on the `AVPlayer` (not the controller)

`allowsExternalPlayback` and `usesExternalPlaybackWhileExternalScreenIsActive` live on `AVPlayer`, not `AVPlayerViewController`. We set them in the ViewModel, immediately after assigning `viewModel.player`, so the timing is independent of view-controller lifecycle. **Rationale:** keeps state ownership in the ViewModel where the rest of player config already lives; avoids re-applying flags inside `updateUIViewController` (which fires on every parent re-render).

### D3. Own Now-Playing info in the ViewModel

`MPNowPlayingInfoCenter` is a process-global singleton. `VideoPlayerViewModel` is the only place that knows when playback starts, the current `MediaItem`, and the active `AVPlayer`. The ViewModel populates the info dictionary in `setupPlayer()` after stream resolution, observes rate / time-control-status to keep `MPNowPlayingInfoPropertyPlaybackRate` and `MPNowPlayingInfoPropertyElapsedPlaybackTime` fresh, and **clears `nowPlayingInfo = nil` in `tearDown()`**. **Rationale:** any other owner (player view, app delegate) leaks metadata of the previous item once dismissed. Artwork is loaded from the existing `MediaItem.imageURL` via async `URLSession`; we cache the most recent artwork keyed by item id to avoid refetching during scrubbing.

### D4. Do not engage `MPRemoteCommandCenter` in this change

Lock-screen / AirPlay-receiver play/pause/seek controls are nice but not strictly required for AirPlay UX — `AVPlayerViewController` already wires them up when an item is current. **Rationale:** scope discipline; can ship as a follow-up if testing reveals gaps.

### D5. iOS only — no tvOS code paths

`AVRoutePickerView` does not exist on tvOS, and tvOS already exposes route selection through Siri Remote / Control Center. All new code is wrapped in `#if os(iOS)`. **Rationale:** matches existing pattern in `setupAudioSession()` (iOS-gated) and avoids dead code in the tvOS binary.

### D6. Place the route button next to the audio/subtitle button in `PlayerControlsOverlay`

The overlay is the natural home for playback-adjacent controls; users discovering AirPlay through PiP-related gestures will expect it there. **Alternatives considered:** title bar (cluttered), gesture-only (undiscoverable), top-right corner (collides with the dismiss control on iPhone landscape).

## HIG & Layout

### iPhone (compact width)

The route button renders in `PlayerControlsOverlay` next to the audio/subtitle button. Sized to `44×44pt` minimum hit area (Apple's HIG → Inputs → Touch Targets). Uses the system AirPlay glyph supplied by `AVRoutePickerView` — we do **not** override the icon, so it inherits Apple's familiar triangle-on-rectangle that users already recognize.

- **Portrait:** controls overlay is bottom-aligned; route button sits in the secondary-controls row above the timeline. Safe-area-respected.
- **Landscape:** overlay extends edge-to-edge; route button stays in the same logical position. No collision with the home-indicator inset (controls already inset by `safeAreaInsets`).
- **One-handed reach:** within the lower-half of the screen in landscape; in portrait, falls just above the timeline (mid-screen on tall iPhones — acceptable for a transient control reached during deliberate adjustment).
- **Dynamic Type AX5:** the picker view is glyph-only (no text), so AX5 type sizes do not affect its layout.

### iPad (regular width)

Same overlay layout as iPhone landscape. In Split-View 1/3, the controls compress horizontally — the route button keeps its 44pt hit area but reduces visual padding. In Stage Manager resized windows, the overlay scales with the window; minimum supported width is the existing player's minimum (no new floor).

Pointer interaction: `AVRoutePickerView` provides hover state automatically when `prioritizesVideoDevices = true`. Tooltip text is supplied by the system.

### tvOS

N/A — no AirPlay button on tvOS. The native `AVPlayerViewController` already exposes route selection via Siri Remote (long-press Play/Pause → "AirPlay & Audio Routing") and Control Center. No code changes on `TVPlayerView.swift`.

### Aspect ratios

- **Portrait video on iPhone:** controls overlay sits at the bottom; route button position unchanged.
- **Landscape video full-screen:** overlay edge-to-edge; route button position unchanged.
- **External display (iPad → external display, or AirPlay mirroring):** when AirPlay is active and `usesExternalPlaybackWhileExternalScreenIsActive = true`, the iPad screen continues to show the controls overlay while video plays on the external receiver. The "currently playing on <Device>" indicator is supplied by `AVPlayerViewController` automatically. Letterboxing is the receiver's responsibility — Apple TV and AirPlay-2 displays handle aspect-ratio adaptation.

### Accessibility

- **VoiceOver:** `AVRoutePickerView` ships with localized accessibility labels ("AirPlay" / "AirPlay, currently routed to <name>"). Place it after the audio/subtitle button in the VoiceOver order so the announce sequence is timeline → playback → audio/subtitles → AirPlay → close. Set `.accessibilitySortPriority` on the SwiftUI wrapper if needed.
- **Reduce Motion:** the route picker animation is a simple fade; nothing to disable.
- **Reduce Transparency:** the controls overlay already uses the same material as before; no new translucent surface.
- **Increase Contrast:** route button uses `activeTintColor = .systemBlue` (resolves to high-contrast variant automatically) and the system glyph stroke weight.
- **Smart Invert:** glyph is automatically excluded by the system (system-provided control).

### HIG references

- HIG → System Experiences → **Playing audio and video** (AirPlay UX patterns and recommendation to use `AVRoutePickerView`).
- HIG → Inputs → **Touch Targets** (44×44pt minimum).
- HIG → Foundations → **Accessibility** (VoiceOver order, Dynamic Type behavior).
- Apple Developer → AVKit → `AVRoutePickerView` reference (for `prioritizesVideoDevices`, tint colors).

## Risks / Trade-offs

- **[AirPlay "Mirroring" vs "AirPlay Video" confusion]** → Setting `prioritizesVideoDevices = true` on the picker promotes video-capable receivers (Apple TV, AirPlay-2 displays) above audio-only ones; this matches user intent ~95% of the time. Users who specifically want audio-only playback on a HomePod can still scroll the list — they just have to look past the TV.
- **[Now-Playing metadata staleness during scrubbing]** → The ViewModel updates `MPNowPlayingInfoPropertyElapsedPlaybackTime` on every `AVPlayer` rate change; we throttle high-frequency time updates to once per second using a periodic time observer. Without throttling, the receiver can stutter as it re-renders metadata on every frame.
- **[Artwork load timing]** → Artwork URL resolution is async. If the user starts playback and immediately AirPlays before the image arrives, the receiver shows the title without artwork for a beat. Mitigation: pre-fetch artwork in `setupPlayer()` before stream resolution; cache by item id so subsequent plays show artwork immediately.
- **[Simulator can't test AirPlay]** → iOS Simulator does not advertise AirPlay routes. Manual verification requires a physical device + Apple TV / HomePod / AirPlay-2 speaker on the same network. Document in `tasks.md` that this step is hands-on.
- **[`MPNowPlayingInfoCenter` is process-global]** → If the app launches the player twice in quick succession (e.g., user dismisses and immediately picks another item), the stale info dictionary from the first session can flash on the lock screen for a frame. Mitigation: clear `nowPlayingInfo` to `nil` in the ViewModel's `tearDown()` and again in `setupPlayer()` *before* populating, so the transition is atomic.
- **[Background-mode interaction with AirPlay]** → `audio` background mode is already set; AirPlay continues across screen-lock. No risk anticipated.

## Migration Plan

No migration. Users who already had playback working get AirPlay automatically once the build ships. Rollback is a code revert; no data, no API surface, no on-device state to clean up.

## Open Questions

- **Telemetry?** Should we emit an OTLP event when a route engages / disengages (event name only, no receiver identifier or PII)? Default position: no, keep this change scope-tight. Easy to add as a follow-up if we want adoption metrics.
- **Continue-watching reporting during AirPlay?** The existing `JellyfinService` progress reporter listens to the local `AVPlayer` time. Because `AVPlayer` is the source of truth for time even when output is external, this should "just work" — but worth verifying on a device that the periodic time observer keeps firing while output is on Apple TV.
- **PiP + AirPlay interaction:** `AVPlayerViewController` documents that engaging AirPlay automatically exits PiP. We don't try to fight this; the existing PiP teardown should handle it. Verify in QA that the controls overlay state matches reality after the auto-PiP-exit.
