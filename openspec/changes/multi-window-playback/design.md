## Context

Today's player path:

```
  LibraryView → tap tile → MediaDetailView → tap Play
   → fullScreenCover(item: selectedItemForPlayback) { VideoPlayerView }
   → VideoPlayerView wraps AVPlayerViewController; PiP available.
   → On dismiss: PiPPlaybackManager carries audio if PiP was active.
```

This is fine on iPhone. On iPad it's the limiter — you can't
simultaneously browse and watch. The Info.plist already declares
multi-scene but the SwiftUI app has only one `WindowGroup`, so the
system never opens a second scene for any reason.

This proposal threads a second `WindowGroup` keyed on `PlaybackHandoff`,
used as both the route key (via `OpenWindowAction`) and the restoration
payload (via `NSUserActivity`). The existing `PiPPlaybackManager`
becomes scene-id aware so audio handoff still works when a window is
dismissed.

## Goals / Non-Goals

**Goals:**
- iPad users can open playback in its own window via toolbar action
  and ⇧⌘N keyboard shortcut.
- Existing in-window playback path preserved as the default (no UI
  regression for current users).
- Scene state restoration: an open player window survives app relaunch.
- PiP behavior preserved across scene boundaries.
- "Now Playing" mini bar surfaces in the main window when player is
  detached.

**Non-Goals:**
- Multiple simultaneous player windows (one player scene at a time).
- Multiple browser windows of Seer (one main window suffices).
- Mac-specific window menu / "Bring All to Front" customization
  (Catalyst inherits; not optimized).
- Live Activities / Dynamic Island integration (separate concern).
- Audio-only background playback model changes.

## Decisions

**1. One main scene + one player scene.** Not arbitrary multi-window.
Explicitly limit `UISceneConfigurations` to "default" (Content) and
"player" (Player). Simplifies state, restoration, and the mini-bar
logic.

**2. `PlaybackHandoff` is a value type:
`Codable`+`Hashable`+`Identifiable`.** The
`WindowGroup(for: PlaybackHandoff.self)` API requires `Codable` +
`Hashable`. `Identifiable` lets the player scene route on the value's
`id` and supports state restoration via `NSUserActivity` userInfo.

**3. Server credentials by reference, not by value.** `PlaybackHandoff`
carries `serverID: UUID` + `mediaItemID: String` +
`startPositionTicks: Int64`. The player scene re-reads credentials
from `AppState`/Keychain on appear. This avoids leaking secrets
through `NSUserActivity` payload.

**4. Mini bar surfaces only when a player scene is active in *another*
scene.** Detect via a `@MainActor PlaybackPresenceObserver` in
`SeerCore` that maintains a small `Set<UUID>` of active scene IDs and
exposes `hasDetachedScene: Bool`.

**5. Existing in-window `fullScreenCover` path remains the default.**
"Open in New Window" toolbar action is opt-in. ⇧⌘N keyboard shortcut.
A user preference "Always open playback in new window on iPad" could
be added later — out of scope for v1.

**6. `PiPPlaybackManager` scene-id awareness.** Today it's a singleton
tracking the most recent player. Add `windowID: UISceneSession.ID?` so
it knows which scene's player is the audio source. On scene dismiss
while PiP is active, audio rolls over — system PiP overlay survives.

**7. "Move to Window" preserves AVPlayer instance.** When a user
invokes "Open in New Window" while the modal player is already
running, migrate the existing AVPlayer rather than spawning a new one.
Position, buffered ranges, audio/subtitle selection all preserved.

## HIG & Layout

### iPhone (compact width)

"Open in New Window" hidden — phones don't have multi-window.
`UIApplication.shared.supportsMultipleScenes` is false on iPhone.
Existing player path unchanged. "Now Playing" mini bar never appears
(no detached scene possible).

### iPad (regular width)

- "Open in New Window" toolbar item appears in `MediaDetailView` on
  regular width. Adjacent to existing Play / Download buttons. SF
  Symbol: `macwindow.badge.plus` (or `rectangle.split.2x1.slash.fill`
  if `macwindow.badge.plus` doesn't exist on the target SDK — verify
  during implementation).
- Player scene fills its window; AVPlayerViewController fills the
  scene; system chrome (close, traffic-light on Catalyst) decorates.
- "Now Playing" mini bar: 56pt tall, pinned above the bottom of the
  main scene's content frame. Title + scrubber + play/pause + tap
  target. Tap brings player scene to front. Long-press shows context
  menu (PiP, close).
- Stage Manager: both windows resizable independently; player scene
  minimum size enforced (320×240 via `restorationActivity` constraints
  and `windowResizability(.contentMinSize)`).

### tvOS

Out of scope. `#if !os(tvOS)` gate around `OpenWindowAction` and
multi-window UI surfaces.

### Aspect ratios

Player scene defaults to media's natural aspect ratio on first open;
resizable thereafter. Letterboxes on aspect mismatch. External display
(AirPlay) inherits scene contents — no special handling required.

### Accessibility

- VoiceOver: mini bar announces "Now Playing, <title>, <progress>";
  activation focuses the player scene.
- Reduce Motion: scene focus animation crossfades instead of zooms.
- Dynamic Type AX5: mini bar reflows via existing toolbar-density
  patterns.
- Switch Control: mini bar's tap target is reachable in auto-scan path.

### HIG references

- "Multitasking" — multiple-scenes guidance, Stage Manager
  (developer.apple.com/design/human-interface-guidelines/multitasking).
- "Picture in Picture"
  (developer.apple.com/design/human-interface-guidelines/picture-in-picture).
- "Playing audio" — Now Playing mini-bar conventions
  (developer.apple.com/design/human-interface-guidelines/playing-audio).
- "Windows" — multi-window behavior, scene state restoration
  (developer.apple.com/design/human-interface-guidelines/windows).

## Risks / Trade-offs

- **[Risk] Two AVPlayer instances if user invokes both in-window and
  detached playback simultaneously.** → Mitigation: opening a detached
  player while in-window is active migrates the existing AVPlayer
  rather than spawning a new one (Decision 7).
- **[Risk] PiP confusion across scenes — which scene "owns" PiP?** →
  Mitigation: `PiPPlaybackManager` is the singleton owner; scenes
  register/unregister; only the most-recently-active scene receives
  PiP restore events.
- **[Risk] State restoration replays a player on relaunch even after
  the user dismissed it during `applicationWillTerminate`.** →
  Mitigation: clear `NSUserActivity` synchronously on dismiss.
- **[Risk] Scene minimum size enforcement is best-effort on iPad
  Stage Manager — system may still allow smaller frames.** → Accept;
  AVPlayer degrades gracefully on small frames.
- **[Trade-off] Adding a value-typed handoff means data-flow plumbing
  through scenes.** → Accept; SwiftUI 6's `WindowGroup(for:)` API is
  the supported model.
- **[Trade-off] Mini bar competes for vertical space at the bottom of
  the main scene.** → Hide on iPhone (no detached scene possible);
  show on iPad regular only.

## Migration Plan

No data migration. Rollout is feature-flagged via
`MultiWindowPlaybackEnabled` boolean in `Config/Secrets.xcconfig`:

1. **TestFlight 1**: ship with flag `false`. No behavioral change.
2. **TestFlight 2** (after manual test on iPad Pro 13" Stage Manager
   + Mac Catalyst): flip flag to `true`. Toolbar action surfaces.
3. **App Store**: ship with flag `true` once TestFlight feedback is
   green.

Rollback = revert + flip flag off in a hotfix; existing in-window
player path is unaffected.

## Open Questions

- Should the "Open in New Window" toolbar item be hidden when an
  in-window player is currently active? (Discoverability vs. accidental
  dual-player.) → Lean: yes, hide. Decide before 3.3.
- Should ⌘W close just the player window or also save state? Apple
  convention: ⌘W closes; state restoration handles re-open. → Lean:
  yes, ⌘W closes only.
- Mini bar on Mac Catalyst: keep it, or rely on the system menu bar's
  Window menu instead? → Lean: keep mini bar for consistency with iPad.
- Should `PlaybackPresenceObserver` survive scene termination, or
  rebuild on next launch from `NSUserActivity`? → Lean: rebuild;
  simpler lifecycle.
