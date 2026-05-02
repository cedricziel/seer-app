## Why

`Info.plist` already declares `UIApplicationSupportsMultipleScenes: true`
but with an empty `UISceneConfigurations` dict — multi-window is
*advertised* but never delivered. On iPad regular width, especially in
Stage Manager, video playback in `fullScreenCover` is a phone-shaped
instinct: it monopolizes the only window. The maintainer wants to keep
browsing the library while the player runs in its own window. This
proposal turns playback into a first-class detached scene, building on
Proposal 1's navigation shell to wire up the "Open in New Window"
affordance and on Proposal 2's keyboard infrastructure for the ⇧⌘N /
⌘W shortcuts.

```
   TODAY                                AFTER (iPad regular)
   ──────────────────────                ──────────────────────────────
   ┌────────────────────┐               ┌───────────────┬──────────────┐
   │  Library            │               │   Library     │  Player win  │
   │                     │   ⌘O on a    │   (browsing   │  ▶ playing   │
   │                     │   media item │    continues) │              │
   │   tap a tile        │              │               │              │
   │       ↓             │              │   bottom shows│              │
   │  fullScreenCover    │              │   "Now Playing"              │
   │   (only one win)    │              │   mini bar    │              │
   └────────────────────┘               └───────────────┴──────────────┘
                                         tap mini bar to focus player win
                                         close window: PiP carries audio
```

## What Changes

- **Second `WindowGroup` for playback** in `SeerApp.swift`, keyed on a
  `PlaybackHandoff` value type carrying `serverID: UUID` +
  `mediaItemID: String` + `startPositionTicks: Int64`. Opened via
  `OpenWindowAction(id: "player", value:)`. Credentials are re-read
  from `AppState`/Keychain in the player scene on appear; not carried
  in the handoff payload.
- **"Open in New Window" toolbar item** in `MediaDetailView` on iPad
  regular only (gated on `horizontalSizeClass == .regular` and
  `UIApplication.shared.supportsMultipleScenes`). Keyboard shortcut:
  ⇧⌘N. Hidden on iPhone.
- **"Move to Window" command** in active in-window player on iPad:
  pulls a currently-playing in-window player out of the
  `fullScreenCover` and into a new scene preserving playback time.
- **"Now Playing" mini bar** at the bottom of the main scene (above
  the bottom tabs on compact iPad split-view-1/3, above the sidebar
  content on regular) when a separate player scene is active. 56pt
  tall. Tap brings the player scene to front. Long-press shows
  context menu (PiP, close).
- **Scene state restoration**: a player scene that was open at last
  app exit reopens after relaunch via `NSUserActivity` carrying the
  `PlaybackHandoff` payload. Dismissing the player clears the
  activity so dismissed sessions do not reopen.
- **PiP across scenes**: `PiPPlaybackManager` becomes scene-id aware;
  on player scene close while PiP is active, audio continues without
  a gap, and "return to player" reopens the scene with the captured
  AVPlayer.

## Screen-by-Screen Reshape

### Main scene with detached player active

```
  Main scene (iPad regular landscape)        Player scene (separate window)
  ──────────────────────────────────         ─────────────────────────────

  ┌──────┬──────────┬─────────────┐          ┌──────────────────────────┐
  │ ☰    │ Library  │ Movie Title │          │                          │
  │      │          │ ─────────── │          │                          │
  │ Lib  │ Cont. W. │ ┌─────────┐ │          │                          │
  │ Disc │ ▢▢▢▢▢   │ │ poster  │ │          │     ▶  video playing     │
  │ Srch │          │ └─────────┘ │          │                          │
  │ DLs  │ Latest   │ 2024 · 2h08 │          │                          │
  │ Reqs │ ▢▢▢▢▢▢▢ │ Action      │          │                          │
  │      │ ▢▢▢▢▢▢▢ │ [▶ Play]    │          │                          │
  │ Srvr │          │ [⤓ Get]     │          │     ◀─◀  ⏯  ▶─▶          │
  │      │          │ [⊞ New Win] │          │                          │
  ├──────┴──────────┴─────────────┤          │     PiP active           │
  │ ♪ Now Playing: <other movie>  │ ◀── 56pt └──────────────────────────┘
  │ ▶  ━━━━━━○━━━━━━━━            │   bar           independent window
  └───────────────────────────────┘                  resizable in Stage
                                                     Manager; min 320×240
  tap mini bar → focuses player scene
  tap [⊞ New Win] → spawns NEW player window
                    (or migrates current modal player to one)
```

### Open in New Window affordance

```
  MediaDetailView toolbar (iPad regular only)
  ────────────────────────────────────────────────────

  ┌─────────────────────────────────────────────────┐
  │ ◀  Movie Title                  ⊞   ⤓   ⋯       │
  │                                  ▲                │
  │                                  └── new window   │
  │ ┌─────────┐                          (⇧⌘N)        │
  │ │ poster  │                                       │
  │ └─────────┘                                       │
  │ Synopsis...                                       │
  └─────────────────────────────────────────────────┘

  iPhone: [⊞] hidden, ⇧⌘N unbound
```

### State restoration after relaunch

```
  Time T-1: app backgrounded, player scene open
  Time T:   app relaunched

  ┌──────────────────────────────────────────────────────────┐
  │ Backgrounded state                                       │
  │   main scene: Library, item X selected                   │
  │   player scene: PlaybackHandoff{                         │
  │     serverID: <uuid>, mediaItemID: "abc",                │
  │     startPositionTicks: 4_100_000_000  (~4m 33s)         │
  │   }                                                      │
  │                                                          │
  │ NSUserActivity persisted via .userActivity()             │
  └──────────────────────────────────────────────────────────┘
                             ↓ (relaunch)
  ┌──────────────────────────────────────────────────────────┐
  │ Restored state                                           │
  │   main scene: Library, item X selected ✓                 │
  │   player scene: same item, position within ±5s ✓         │
  │                                                          │
  │ EXCEPT if the user dismissed the player before exit —    │
  │ then NSUserActivity was cleared and only the main        │
  │ scene restores.                                          │
  └──────────────────────────────────────────────────────────┘
```

## Capabilities

### New Capabilities
- `multi-window-playback`: detached player scene, "Now Playing" mini
  bar, scene routing with `OpenWindowAction`, scene state restoration
  via `NSUserActivity`, and PiP across scene boundaries.

### Modified Capabilities
(None.)

## Impact

**Affected code:**
- `App/SeerApp/SeerApp.swift` — second
  `WindowGroup(for: PlaybackHandoff.self)`.
- `App/SeerApp/Info.plist` — at least one `UISceneConfiguration` named
  `PlayerScene` registered.
- `Packages/SeerCore/Sources/SeerCore/PlaybackHandoff.swift` — new
  value type (`Codable`, `Hashable`, `Identifiable`).
- `Packages/SeerCore/Sources/SeerCore/PlaybackPresenceObserver.swift` —
  new observable tracking active scene IDs; mini-bar visibility binds
  to it.
- `Packages/PlaybackClient/Sources/PlaybackClient/PiPPlaybackManager.swift`
  — scene-id aware; cross-scene audio handoff.
- `Packages/SeerUI/Sources/SeerUI/NowPlayingMiniBar.swift` — new view.
- `Features/Library/MediaDetailView.swift` — "Open in New Window"
  toolbar item; ⇧⌘N.
- `Features/Playback/VideoPlayerView.swift` — ⌘W close; "Move to
  Window" affordance.
- `App/SeerApp/ContentView.swift` — `NowPlayingMiniBar` mounted when
  `PlaybackPresenceObserver.hasDetachedScene == true`.

**Platforms:** iPad regular width (primary). Compact iPad and iPhone:
"Open in New Window" hidden (only one window allowed); existing
behavior preserved. Mac (Designed-for-iPad / Catalyst): inherits multi-
window for free; ⌘W closes player scene only. tvOS: out of scope.

**Dependencies:** None new. `OpenWindowAction` ships in iOS 26.

**Telemetry:** `seer.player.window_open`, `seer.player.window_close`,
`seer.player.scene_handoff`. All gated on consent.

**Migration:** No on-disk schema change. Behavioral change: existing
users keep the in-window player as the default (no regression) until
they explicitly invoke "Open in New Window".

**Feature flag:** `MultiWindowPlaybackEnabled` boolean in
`Config/Secrets.xcconfig` (default `false` in committed config; flip
to `true` after manual testing on TestFlight). Allows safe staged
rollout.
