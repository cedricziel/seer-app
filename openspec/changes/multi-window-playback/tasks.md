## 1. Setup

- [ ] 1.1 Add `PlaybackHandoff: Codable, Hashable, Identifiable` value
  type to `Packages/SeerCore/Sources/SeerCore/PlaybackHandoff.swift`.
  Fields: `id: UUID`, `serverID: UUID`, `mediaItemID: String`,
  `startPositionTicks: Int64`.
- [ ] 1.2 Register a `UISceneConfiguration` for the player scene in
  `App/SeerApp/Info.plist` (`UISceneConfigurations` →
  `UIWindowSceneSessionRoleApplication` array entry with name
  `PlayerScene`).
- [ ] 1.3 Add `MultiWindowPlaybackEnabled` boolean to
  `Config/Secrets.xcconfig` (default `false` committed; flip via
  TestFlight workflow).

## 2. Tests (red)

- [ ] 2.1 Unit test: `PlaybackHandoff` round-trips through `Codable`
  (`NSUserActivity` userInfo) preserving all fields and `id`.
- [ ] 2.2 UI test: iPad Pro 13" landscape — open `MediaDetailView`,
  tap "Open in New Window", verify a new scene opens and the
  originating scene stays visible — covers Scenario `iPad regular
  width opens player in new window`.
- [ ] 2.3 UI test: iPad ⇧⌘N keyboard shortcut opens player scene —
  covers Scenario `iPad regular width ⇧⌘N keyboard shortcut`.
- [ ] 2.4 UI test: iPhone 17 Pro portrait — verify "Open in New
  Window" toolbar action absent and ⇧⌘N unbound — covers Scenario
  `iPhone compact width hides the affordance`.
- [ ] 2.5 UI snapshot test: iPad Pro 13" regular landscape with active
  detached player — main scene mini bar visible, 56pt tall — covers
  Scenario `iPad regular width mini bar appears when player is
  detached`.
- [ ] 2.6 UI test: iPad mini bar tap brings player scene to front —
  covers Scenario `iPad mini bar tap focuses player scene`.
- [ ] 2.7 UI test: iPhone with active in-window player — verify mini
  bar absent — covers Scenario `iPhone compact width never shows mini
  bar`.
- [ ] 2.8 UI test: kill app while player scene active, relaunch,
  verify scene restored within ±5s — covers Scenario `iPad regular
  width player scene restores on relaunch`.
- [ ] 2.9 UI test: dismiss player scene, kill, relaunch, verify no
  scene restore — covers Scenario `Dismissed player does not restore`.
- [ ] 2.10 Integration test: PiP active in player scene, close window,
  verify audio continues and PiP overlay survives — covers Scenario
  `iPad PiP audio survives player scene close`.
- [ ] 2.11 **iPad regular landscape snapshot regression suite —
  multi-window variants**: snapshots of `MediaDetailView` with the new
  toolbar item visible (regular only) and absent (compact); snapshot
  of main scene with mini bar (detached); snapshot of player scene at
  full-window, half-window, and minimum-size (320×240).

## 3. Implementation (green)

- [ ] 3.1 Implement `PlaybackHandoff` value type — makes 2.1 pass.
- [ ] 3.2 Add second `WindowGroup(for: PlaybackHandoff.self)` to
  `SeerApp.swift` body; render new `PlayerSceneView` constructing
  `VideoPlayerView` from the handoff payload (re-reading credentials
  from `AppState`).
- [ ] 3.3 Add "Open in New Window" toolbar button in `MediaDetailView`,
  gated on `horizontalSizeClass == .regular`,
  `UIApplication.shared.supportsMultipleScenes`, and the
  `MultiWindowPlaybackEnabled` flag. Invokes `OpenWindowAction(id:
  "player", value: handoff)` — makes 2.2 + 2.4 pass.
- [ ] 3.4 Add ⇧⌘N `keyboardShortcut("n", modifiers: [.command,
  .shift])` to that toolbar button — makes 2.3 pass.
- [ ] 3.5 Implement `PlaybackPresenceObserver` in `SeerCore` tracking
  active scene IDs; expose `hasDetachedScene: Bool` — used by mini
  bar — makes 2.5 + 2.7 pass.
- [ ] 3.6 Implement `NowPlayingMiniBar` in `SeerUI`: 56pt tall, title
  + scrubber + play/pause; tap action invokes `OpenWindowAction` to
  focus existing scene — makes 2.6 pass.
- [ ] 3.7 Wire `NSUserActivity` for the player scene:
  `userActivity(_:isEligibleForHandoff:isEligibleForSceneAssociation:)`
  saving the handoff; `restoreUserActivityState` reading it; clear
  on explicit dismiss — makes 2.8 + 2.9 pass.
- [ ] 3.8 Update `PiPPlaybackManager` to track `windowID:
  UISceneSession.ID?` and survive scene close while PiP active —
  makes 2.10 pass.

## 4. HIG verification

- [ ] 4.1 Manual: iPad Pro 13" Stage Manager — open player scene,
  resize independently, verify min size 320×240 enforced, no
  AVPlayer crash on small frames.
- [ ] 4.2 Manual: iPad full-screen — open player scene; verify split
  with main scene if user drags it via the system multitasking dock.
- [ ] 4.3 Manual: iPhone 17 Pro — verify "Open in New Window" hidden,
  no mini bar, no regression in existing in-window player path.
- [ ] 4.4 Manual: Designed-for-iPad on Mac — verify menu-bar Window
  menu populated; ⌘W closes player scene only (not main scene).
- [ ] 4.5 Manual: PiP — engage PiP in player scene, close window,
  audio continues, system PiP overlay reopens scene on tap.
- [ ] 4.6 Manual: state restoration — open player scene, kill app via
  Force Quit, relaunch, verify both scenes restore within ±5s of
  prior position.
- [ ] 4.7 Manual: dismissed-player non-restoration — open scene,
  dismiss via close button, kill app, relaunch, verify only main
  scene restores.
- [ ] 4.8 VoiceOver: mini bar announces "Now Playing, <title>,
  <progress>"; player scene focus path verified.
- [ ] 4.9 Reduce Motion: scene focus crossfades instead of zoom.
- [ ] 4.10 Run `make lint` and `make format`.

## 5. Refactor (optional)

- [ ] 5.1 Extract `SceneRouter` coordinator in `SeerCore` if more
  scene types arise (e.g. settings window, audio-only window).
- [ ] 5.2 Consider adding a user preference "Always open playback in
  new window on iPad" — defer to user feedback.
- [ ] 5.3 Consider adding "Move to Window" command on the in-window
  player (separate from "Open in New Window") for symmetry — defer
  unless feedback asks.
