## Why

Real iPad use means Magic Keyboard, trackpad, sometimes a Bluetooth
mouse. Today Seer has zero `keyboardShortcut`, zero `hoverEffect`, and
no focus-state styling — so on iPad with hardware, navigating feels
like a glass surface that responds only to taps. This is mostly
mechanical work that pays off across iPad and Designed-for-iPad-on-Mac,
and it raises the floor for the navigation-shell reshape (Proposal 1)
and the multi-window playback reshape (Proposal 3) by giving them
keyboard access from day one.

```
   TODAY                                AFTER
   ────────────────────────             ─────────────────────────────
   Hardware keyboard:                   Hardware keyboard:
     • nothing happens                    • ⌘1–⌘5 cycle tabs
                                          • ⌘F focuses search
   Trackpad / pointer:                    • Space play/pause player
     • cursor over a tile = nothing       • ←/→ skip 10s in player
                                          • ⌘. close player
   Focus engine:                          • ⌘[ / ⌘] back/forward
     • no focus rings                     • ⌘D download focused item
     • arrow keys ignored                 • ⌘R refresh current view
                                        Trackpad / pointer:
                                          • cursor over a tile = lift 4pt
                                          • toolbar items highlight on hover
                                          • right-click = existing context menu
                                        Focus engine:
                                          • arrow keys move focus across grid
                                          • Return opens detail
                                          • Tab/Shift-Tab in/out of grid
```

## What Changes

- **Tab cycling**: ⌘1–⌘5 select Library / Discover / Search / Downloads /
  Requests respectively. Hosted via a shared `TabSelection` observable
  (in `SeerCore`) so commands can drive selection from outside the body.
- **Search focus**: ⌘F focuses the `.searchable` field on the active
  surface (SearchView, LibraryView genre filter, etc.). Implemented via
  `@FocusState` and a `Commands` builder. ⌘F is a no-op (not consumed)
  on surfaces without a searchable field.
- **Playback shortcuts** in `VideoPlayerView`: Space toggles play/pause;
  ← skips back 10s; → skips forward 10s; ⌘. closes the player. Only
  active while the player is the topmost modal.
- **Navigation shortcuts**: ⌘[ dismisses the top-of-stack push (back);
  ⌘] is a no-op until forward navigation exists.
- **Action shortcuts**: ⌘D — start download for the focused/selected
  media item; ⌘R — refresh the current ViewModel.
- **`hoverEffect(.lift)`** on every `MediaCard`, `SearchResultCard`,
  poster tile, `ServerSwitcherButton`, and primary toolbar item.
- **Focus state on grid tiles**: arrow keys move focus across the grid
  in reading order; Return opens the focused tile's detail (using the
  same selection path as tap — depends on Proposal 1's `selectedItemID`
  hoist).
- **`Commands { ... }` builder** on `WindowGroup` exposing the above as
  menu-bar items so Stage Manager (iPad) and Mac Catalyst show them in
  the system menu bar. Default menu groups (`SidebarCommands`,
  `ToolbarCommands`) kept; irrelevant defaults removed via
  `commandsRemoved()`.

## Screen-by-Screen Reshape

The shape of each screen is unchanged. What changes is chrome — focus
rings, hover lifts, and menu-bar items. Diagrams show the chrome only.

### Hover state on a media tile

```
  resting                hover (cursor over)
  ───────                ─────────────────────

  ┌─────┐                ┌─────┐  ◀── lifts 4pt
  │     │                │     │      smooth ease, ~120ms
  │  ▢  │       →        │  ▢  │      drop-shadow expands
  │     │                │     │      tile content stays
  └─────┘                └─────┘      pixel-aligned
                          ╲ ╱
                           ─  shadow
```

### Focus ring on a media tile (keyboard navigation)

```
  resting                focused (⌨ tab/arrow)
  ───────                ─────────────────────

  ┌──────┐               ┌══════┐  ◀── 3pt accent-tinted ring
  │      │               ║┌────┐║      hugs the tile bounds
  │  ▢   │      →        ║│ ▢  │║      auto-scrolls if off-screen
  │      │               ║└────┘║
  └──────┘               └══════┘

  ← →  move focus to next/prev tile in reading order
  ↑ ↓  move focus row up/down
  ↩    open detail (same as tap)
  ⇥    move focus into/out of grid
```

### Menu bar (Stage Manager on iPad / Mac Catalyst)

```
  ╭───────────────────────────────────────────────────────────────╮
  │ Seer   File   Edit   View   Tabs           Window   Help      │
  ╰───────────────────────────────╲──────────────────────────────╯
                                   ╲
                                    ▼
                             ┌──────────────┐
                             │ Library  ⌘1  │
                             │ Discover ⌘2  │
                             │ Search   ⌘3  │
                             │ Downloads⌘4  │
                             │ Requests ⌘5  │
                             ├──────────────┤
                             │ Find...  ⌘F  │
                             │ Refresh  ⌘R  │
                             │ Download ⌘D  │
                             └──────────────┘
```

### Player keyboard shortcuts (modal player)

```
  ┌───────────────────────────────────────────────────────────┐
  │                                                           │
  │            ┌──────────────────────────┐                   │
  │            │                          │                   │
  │            │     ▶  video playing     │                   │
  │            │                          │                   │
  │            └──────────────────────────┘                   │
  │            ◀──◀  ⏯  ▶──▶                                  │
  │                                                           │
  │  Space  →  play / pause                                   │
  │   ←  →  →  skip back 10s                                  │
  │   →  →  →  skip forward 10s                               │
  │   ⌘ .   →  dismiss                                        │
  │                                                           │
  └───────────────────────────────────────────────────────────┘
  bindings active only while player is topmost modal;
  no conflict with .searchable space-clear elsewhere
```

## Capabilities

### New Capabilities
- `hardware-input`: keyboard shortcuts, pointer hover effects, and
  focus-state polish across the app, plus the menu-bar `Commands`
  surface for Stage Manager / Mac Catalyst.

### Modified Capabilities
(None.)

## Impact

**Affected code:**
- `App/SeerApp/SeerApp.swift` — `WindowGroup` gets a `Commands` builder.
- `App/SeerApp/SeerCommands.swift` — new file; menu-bar items + ⌘1–⌘5,
  ⌘F, ⌘R, ⌘D wired to a shared `TabSelection` observable.
- `App/SeerApp/ContentView.swift` — `MainTabView` selection plumbed via
  `@EnvironmentObject TabSelection` (hoisted from private state).
- `Packages/SeerCore/Sources/SeerCore/TabSelection.swift` — new
  observable holding the active tab + a focus signal for ⌘F.
- `Packages/SeerUI/Sources/SeerUI/MediaCard.swift`,
  `Packages/SeerUI/Sources/SeerUI/PosterImage.swift`,
  `Features/Search/SearchResultCard.swift` — `hoverEffect(.lift)`.
- `Features/Library/LibraryView.swift`,
  `Features/Search/SearchView.swift`,
  `Features/Discover/DiscoverView.swift` — `@FocusState` for search
  field focus, focus-state binding on grid tiles, arrow-key
  navigation via `onKeyPress`.
- `Features/Playback/VideoPlayerView.swift` — keyboard shortcuts
  (Space / ←/→ / ⌘.).

**Platforms:** iPad (primary), Mac via Catalyst / Designed-for-iPad
(free), iPhone with Magic Keyboard accessory (bonus). tvOS: out of
scope (focus engine is its own world).

**Dependencies:** None. `keyboardShortcut`, `hoverEffect`, and
`Commands` all ship with iOS 26.

**Telemetry:** `seer.input.shortcut` event with the shortcut identifier
(gated on consent).

**Migration:** None on disk. UI rollout is one ship.
