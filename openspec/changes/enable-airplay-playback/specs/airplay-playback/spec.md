## ADDED Requirements

### Requirement: External playback enabled on iOS player

The iOS video player SHALL explicitly enable external playback so that the system can route audio and video to AirPlay receivers (Apple TV, AirPlay-2 displays and speakers) without relying on undocumented `AVPlayer` defaults.

The `AVPlayer` driving `AVPlayerViewController` MUST have `allowsExternalPlayback` set to `true`. It MUST also have `usesExternalPlaybackWhileExternalScreenIsActive` set to `true` so that wired-display and AirPlay scenarios coexist.

These flags MUST be set on the iOS code path only. tvOS MUST NOT set these properties — the tvOS player is unaffected by this requirement.

#### Scenario: External playback flag set on player creation

- **WHEN** the iOS user opens an item in the video player (compact or regular width) and the `VideoPlayerViewModel` finishes assembling the `AVPlayer`
- **THEN** `player.allowsExternalPlayback` is `true` and `player.usesExternalPlaybackWhileExternalScreenIsActive` is `true`

#### Scenario: tvOS player unchanged

- **WHEN** the tvOS user opens an item in `TVPlayerView`
- **THEN** no code path sets `allowsExternalPlayback` or `usesExternalPlaybackWhileExternalScreenIsActive` from this change, and the tvOS player continues to work exactly as before

### Requirement: AirPlay route-picker control in player overlay

The iOS player controls overlay SHALL surface a discoverable AirPlay route-picker control next to the existing audio/subtitle button. The control MUST be the system-provided `AVRoutePickerView`, wrapped for SwiftUI use, so users get the standard iOS route selection sheet, including AirPlay-2 grouping and live "currently routing to <name>" feedback.

The control MUST prioritize video-capable receivers when listing routes (`prioritizesVideoDevices = true`).

The control MUST NOT appear on tvOS — `AVRoutePickerView` does not exist on tvOS, and the platform handles route selection through Siri Remote and Control Center.

The control MUST meet a 44×44pt minimum touch target.

#### Scenario: User on iPhone compact width sees the AirPlay button

- **WHEN** an iPhone user (compact width, portrait or landscape) is playing an item and reveals the controls overlay
- **THEN** an AirPlay route-picker button is visible next to the audio/subtitle button, with the system AirPlay glyph and a 44×44pt minimum hit area

#### Scenario: User on iPad regular width sees the AirPlay button

- **WHEN** an iPad user (regular width, including Split View 1/3) is playing an item and reveals the controls overlay
- **THEN** an AirPlay route-picker button is visible in the same logical position as on iPhone, retaining its 44×44pt hit area

#### Scenario: Tapping the button presents the system route sheet

- **WHEN** the iOS user taps the AirPlay button in the controls overlay
- **THEN** the system route-picker sheet appears, video-capable receivers are listed first, and selecting one routes the active playback session to that receiver

#### Scenario: Button absent on tvOS

- **WHEN** the tvOS user is playing an item and brings up the controls overlay
- **THEN** no AirPlay route-picker button is rendered by this change, and the tvOS player retains its existing controls

### Requirement: Now-Playing metadata published while playback is active

The iOS video player SHALL publish Now-Playing metadata to `MPNowPlayingInfoCenter` while playback is active so that AirPlay receivers (Apple TV, HomePod, AirPlay-2 speakers) and the iOS lock screen display the correct title, artwork, duration, elapsed time, and playback rate instead of generic placeholders.

The `VideoPlayerViewModel` MUST populate `MPNowPlayingInfoCenter.default().nowPlayingInfo` when a stream is resolved and playback begins, including at minimum: title, artwork (when available), total duration, current elapsed time, and current playback rate.

The ViewModel MUST keep elapsed time and playback rate fresh by observing the `AVPlayer`'s rate and a periodic time observer. Time updates SHALL be throttled to no more than once per second to avoid receiver re-render stutter.

The ViewModel MUST clear `nowPlayingInfo` to `nil` when the player tears down (dismiss, fatal error, or when a new playback session starts before the previous one's info is overwritten), so stale metadata from a previous item never persists on the lock screen or AirPlay receiver.

#### Scenario: Now-Playing populated on play

- **WHEN** the iOS user starts playback of an item with title and artwork
- **THEN** `MPNowPlayingInfoCenter.default().nowPlayingInfo` contains the item's title, the item's artwork (once fetched), the total duration, the current elapsed time, and a playback rate matching the `AVPlayer` rate

#### Scenario: Now-Playing updated on rate change

- **WHEN** the iOS user pauses or resumes playback while AirPlay is engaged
- **THEN** `MPNowPlayingInfoPropertyPlaybackRate` reflects the new rate within the next periodic time-observer tick

#### Scenario: Now-Playing cleared on dismiss

- **WHEN** the iOS user dismisses the player or a fatal playback error tears down the session
- **THEN** `MPNowPlayingInfoCenter.default().nowPlayingInfo` is set to `nil` so no stale metadata remains on the lock screen or AirPlay receiver

#### Scenario: Now-Playing cleared between sessions

- **WHEN** the iOS user dismisses one item and immediately starts a different item
- **THEN** the second session's `setupPlayer()` first clears `nowPlayingInfo` to `nil` and then populates it with the new item's metadata, so no stale title or artwork from the previous item ever appears for the new session

### Requirement: AirPlay does not regress existing playback features

Enabling AirPlay MUST NOT regress existing playback behavior: PiP, the gesture-overlay seek, audio-session configuration, the tvOS player path, and the existing offline-download playback experience MUST continue to work.

When AirPlay engages while PiP is active, the system will exit PiP automatically — this is documented Apple behavior and is acceptable. The controls overlay state MUST remain consistent with reality after the auto-PiP-exit (no orphaned PiP indicators).

#### Scenario: PiP still works without AirPlay

- **WHEN** the iOS user taps the PiP button on an item with no AirPlay route engaged
- **THEN** PiP starts as it did before this change

#### Scenario: AirPlay engaging while PiP is active

- **WHEN** the iOS user is in PiP and selects an AirPlay receiver via the route picker
- **THEN** PiP exits automatically, playback continues on the AirPlay receiver, and the controls overlay no longer shows a PiP-active state

#### Scenario: Audio session unchanged

- **WHEN** the iOS user starts playback after this change
- **THEN** `AVAudioSession.sharedInstance().category` is `.playback` and `mode` is `.moviePlayback`, identical to behavior before this change
