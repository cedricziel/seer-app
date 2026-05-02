## ADDED Requirements

### Requirement: Detached player scene available on iPad

The application SHALL declare a second `WindowGroup` keyed on a
`PlaybackHandoff` value type. Invoking the "Open in New Window"
toolbar action in `MediaDetailView` (or its keyboard shortcut ⇧⌘N) on
iPad regular width MUST present the player in a separate scene; the
originating main scene MUST remain visible and interactive.

#### Scenario: iPad regular width opens player in new window

- **WHEN** the user on iPad regular width landscape opens
  `MediaDetailView` for an item, taps "Open in New Window", and the
  system reports `supportsMultipleWindows == true`
- **THEN** a new player scene MUST be opened with the same
  `MediaItem.ID` and `startPositionTicks: 0`, the player scene MUST
  begin playback within 3 seconds of opening, the originating main
  scene MUST remain visible, and no `fullScreenCover` MUST present in
  the main scene

#### Scenario: iPad regular width ⇧⌘N keyboard shortcut

- **WHEN** the user on iPad regular width landscape with hardware
  keyboard has `MediaDetailView` open and presses ⇧⌘N
- **THEN** the same outcome as the toolbar tap MUST occur

#### Scenario: iPhone compact width hides the affordance

- **WHEN** the user on iPhone compact width portrait opens
  `MediaDetailView`
- **THEN** the "Open in New Window" toolbar action MUST NOT be
  visible, and ⇧⌘N MUST NOT be bound

### Requirement: Now Playing mini bar in main scene

The application SHALL render a "Now Playing" mini bar in the main
scene whenever a player scene is active and the main scene is also
visible. The mini bar MUST show the currently playing item's title,
a non-interactive progress indicator, a play/pause control, and a
tap target that brings the player scene to front.

#### Scenario: iPad regular width mini bar appears when player is detached

- **WHEN** the user on iPad regular width landscape has an active
  player scene running and the main scene visible
- **THEN** a 56pt-tall mini bar MUST be visible at the bottom of the
  main scene content area, MUST display the playing item's title, and
  MUST update the progress indicator at least every 2 seconds

#### Scenario: iPad mini bar tap focuses player scene

- **WHEN** the user on iPad regular width landscape taps the mini
  bar's primary tap target
- **THEN** the player scene MUST be brought to front (system focus
  event), and the main scene MUST remain visible adjacent (Stage
  Manager) or behind (full-screen)

#### Scenario: iPhone compact width never shows mini bar

- **WHEN** the user on iPhone compact width portrait is in the app
  while any item plays
- **THEN** the mini bar MUST NOT be visible (single-scene device —
  player is either modal or PiP, not detached)

### Requirement: Player scene state restoration

The application SHALL persist active player scenes via `NSUserActivity`
such that an open player scene at app exit reopens on relaunch with
the same `PlaybackHandoff` payload (server, item ID, last known
position within ±5 seconds). The user activity MUST be cleared on
explicit player dismissal so dismissed sessions do not reopen.

#### Scenario: iPad regular width player scene restores on relaunch

- **WHEN** the user on iPad regular width landscape has an active
  player scene playing an item, sends the app to the background
  (system terminate or Force Quit), and relaunches the app
- **THEN** the player scene MUST reopen with the same item, playback
  MUST resume within ±5 seconds of the position at backgrounding, and
  the main scene MUST also restore its prior tab and detail selection

#### Scenario: Dismissed player does not restore

- **WHEN** the user on iPad regular width landscape has an active
  player scene, dismisses it (close button or ⌘W), and then relaunches
  the app
- **THEN** no player scene MUST reopen; only the main scene MUST
  restore

### Requirement: PiP across scenes

`PiPPlaybackManager` SHALL track the active player scene's ID and
route PiP restore events to the most-recently-active scene. Closing
the player scene while PiP is active MUST hand off audio to the
system PiP overlay without interruption.

#### Scenario: iPad PiP audio survives player scene close

- **WHEN** the user on iPad regular width landscape has an active
  player scene with PiP engaged, audio playing, and closes the player
  scene window
- **THEN** audio MUST continue without a gap exceeding 100ms, the
  system PiP overlay MUST remain visible, and tapping PiP "return to
  player" MUST reopen the player scene with the captured AVPlayer
  instance

### Requirement: PlaybackHandoff value type contract

The `PlaybackHandoff` value type SHALL conform to `Codable`,
`Hashable`, and `Identifiable`. Its fields MUST include a per-instance
`id: UUID`, the originating `serverID: UUID`, the `mediaItemID:
String`, and the `startPositionTicks: Int64`. It MUST NOT carry server
credentials (access token, API key, password); credentials MUST be
re-resolved from `AppState`/Keychain at scene appear time.

#### Scenario: PlaybackHandoff round-trips through Codable

- **WHEN** a `PlaybackHandoff` value is encoded to a JSON
  representation suitable for `NSUserActivity` userInfo and decoded
  back
- **THEN** all fields MUST be preserved bit-for-bit, the resulting
  value MUST equal (`==`) the original, and the `id` MUST be unchanged

#### Scenario: PlaybackHandoff carries no credentials

- **WHEN** a `PlaybackHandoff` is constructed for any media item
- **THEN** the encoded representation MUST NOT contain any field
  resembling `accessToken`, `apiKey`, `password`, or `keychainRef`,
  verified by inspecting the JSON output for those substrings
