## Context

Seer has no hardware-input affordances today. Adding them is mostly
mechanical and largely orthogonal to the navigation-shell reshape — but
the shell makes shortcuts more valuable, because now there's something
for ⌘1–⌘5 to do that *feels* like switching contexts in an iPad app.

The maintainer wants to use Seer on iPad. iPad use today means Magic
Keyboard + trackpad. This change is about closing the basic
discoverability gap.

## Goals / Non-Goals

**Goals:**
- Hardware keyboard usage feels native on iPad regular width.
- Pointer hover gives feedback consistent with HIG for iPad and Mac.
- Shortcuts surface in the menu bar (Stage Manager / Mac Catalyst).
- iPhone with a Magic Keyboard accessory inherits everything for free.
- Foundation for Proposal 3's ⇧⌘N "open in new window" shortcut.

**Non-Goals:**
- Custom shortcut configuration (system-defined defaults only).
- A custom command palette (⌘K). Out of scope; revisit once shortcuts
  are battle-tested.
- Drag-and-drop. Separate concern.
- Apple Pencil. Not relevant to a media app.
- tvOS focus engine work. Its own world.

## Decisions

**1. Shortcut definitions live next to the view that owns the action,
not in a global registry.** Each `keyboardShortcut(_:modifiers:)` is
collocated with the `Button` or `Picker` it triggers. The `Commands`
builder at the WindowGroup level only mirrors the *menu-bar* surface,
not the in-view bindings. This avoids a parallel registration problem.

**2. Tab selection hoisted to a `@MainActor` observable
`TabSelection` in `SeerCore`.** Today `selectedTab` is private `@State`
in `MainTabView`. A small `TabSelection` (in `SeerCore` so it's visible
everywhere) lets `SeerCommands` change tabs from the menu bar and
keyboard shortcuts without hunting for the view. Also benefits Proposal
3 (multi-window scene routing needs to know the active tab).

**3. `@FocusState` for search focus, not `becomeFirstResponder`
shenanigans.** SwiftUI 6 + iOS 26 has stable `@FocusState` integration
with `.searchable` via `searchFocused`. Use that.

**4. `hoverEffect(.lift)` is the default; opt out where it's wrong
(large hero cards, small inline chips).** A consistent default beats
per-component bespoke decisions.

**5. Grid focusable tiles are added but Return-to-open is opt-in per
surface.** Library yes, Search yes, Discover yes. Downloads is a `List`
— `List` already supports focus.

**6. ⌘F dispatch via `TabSelection.searchFocusRequested` signal.** The
`Commands` builder cannot directly bind to a `@FocusState` inside an
arbitrary view. Instead, `SeerCommands` calls
`tabSelection.requestSearchFocus()`; the active surface observes and
flips its `@FocusState`. Stale signals are discarded on tab switch.

## HIG & Layout

### iPhone (compact width)

With Smart Keyboard Folio attached: shortcuts work; menu bar surfaces
during keyboard-attached use. Without keyboard: no visible chrome
change. `hoverEffect(.lift)` is a no-op without a pointer device — zero
cost on touch-only.

### iPad (regular width)

Sidebar entries get `keyboardShortcut`-tagged Tab labels rendering as
`⌘1` etc. in the sidebar item's discoverability hint. Pointer hover
lifts tiles by 4pt with ~120ms ease. Magic Keyboard menu bar (in Stage
Manager) shows the full Commands hierarchy. Voice Control reads
shortcuts as audible alternatives ("press command 1").

### tvOS

Out of scope. `#if !os(tvOS)` gate around `keyboardShortcut` and
`hoverEffect` modifiers in shared SeerUI components.

### Aspect ratios

Hover and focus chrome scale with the tile size, which itself scales
by size class (Proposal 1's grid sizing). No additional aspect-ratio
work required.

### Accessibility

- VoiceOver: keyboard shortcuts read as part of the action label
  ("Library, command 1"). Verified.
- Switch Control: focusable tiles included in auto-scan path.
- Voice Control: shortcut surfaces as an audible alternative.
- Dynamic Type AX5: shortcut chrome is metadata on actions, not layout.
- Reduce Motion: hover lift becomes opacity change instead of
  translation.

### HIG references

- "Keyboard shortcuts" — general guidance + reserved combos
  (developer.apple.com/design/human-interface-guidelines/keyboards).
- "Pointing devices" — hover, lift, default vs. highlight effects
  (developer.apple.com/design/human-interface-guidelines/pointing-devices).
- "Menus" — menu-bar grouping for Stage Manager / Mac
  (developer.apple.com/design/human-interface-guidelines/menus).
- "Focus and selection"
  (developer.apple.com/design/human-interface-guidelines/focus-and-selection).

## Risks / Trade-offs

- **[Risk] ⌘D conflicts with reserved combos in some surfaces.** →
  Mitigation: scope ⌘D to in-detail and in-grid contexts only; let
  system reserved combos win at the root.
- **[Risk] Space-as-play-pause clobbers space-as-search-clear in a
  searchable field.** → Mitigation: bind `keyboardShortcut(.space,
  modifiers: [])` only inside `VideoPlayerView`; the player is a modal
  in this proposal so no conflict at the root.
- **[Risk] Grid focus shows focus rings even on touch-only iPads
  (no keyboard).** → SwiftUI hides focus chrome when input mode is
  touch; verified via runtime check in 4.x verification tasks.
- **[Trade-off] Hoisting `TabSelection` from private state to an
  observable adds an environment object.** → Accept; it also benefits
  Proposal 3.
- **[Trade-off] Discoverability of shortcuts depends on the menu bar,
  which only appears with hardware keyboard or on Mac.** → Accept; iPad
  with no keyboard sees no degradation. Long-press hint sheets are out
  of scope.

## Migration Plan

No data migration. Rollout is one ship. Rollback = revert.

## Open Questions

- Should ⌘+ / ⌘- adjust grid tile size (a "zoom" affordance)? Probably
  not for v1, but interesting if user feedback asks.
- Stage Manager menu-bar grouping: keep flat, or organize by surface
  (Library / Search / Player)? Lean: organized — better
  discoverability.
- Do we want a "Show Keyboard Shortcuts" sheet (long-press ⌘ on iPad)?
  iOS provides this automatically via the Commands builder; verify it
  works without extra wiring.
