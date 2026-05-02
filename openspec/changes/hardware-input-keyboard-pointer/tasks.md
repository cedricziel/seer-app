## 1. Setup

- [ ] 1.1 Hoist `selectedTab` from `MainTabView` private state to a
  `@MainActor` observable `TabSelection` in `SeerCore`. Inject via
  `@EnvironmentObject` from `SeerApp`. Public surface: `tab: Tab` plus
  `requestSearchFocus()` / `consumeSearchFocusRequest() -> Bool`.
- [ ] 1.2 Create `App/SeerApp/SeerCommands.swift` for the menu-bar
  `Commands` builder — initially empty, fills in across implementation.

## 2. Tests (red)

- [ ] 2.1 UI test: ⌘3 on iPad Pro 13" regular landscape simulator
  switches to Search tab and focuses search field — covers Scenario
  `iPad regular width keyboard shortcut switches tabs`.
- [ ] 2.2 UI test: ⌘1 on iPhone 17 compact portrait simulator with
  hardware keyboard simulator attached selects Library — covers
  Scenario `iPhone compact width with hardware keyboard`.
- [ ] 2.3 UI test: ⌘F on iPad Pro 13" regular landscape on the Search
  tab focuses the search field, hardware keyboard preserved — covers
  Scenario `iPad regular width ⌘F on Search`.
- [ ] 2.4 UI test: ⌘F on iPad regular landscape on the Downloads tab
  is a no-op (system default) — covers Scenario `iPad regular width ⌘F
  on Downloads (no-op)`.
- [ ] 2.5 UI test: Space toggles playback in `VideoPlayerView` — covers
  Scenario `iPad regular width player Space toggles playback`.
- [ ] 2.6 UI test: → seeks +10s in `VideoPlayerView` — covers Scenario
  `iPad player ←/→ skip`.
- [ ] 2.7 Snapshot test: `MediaCard` hover state on iPad Pro 13"
  regular (using a `_PointerHoverEffect` test trait) — covers Scenario
  `iPad regular width pointer over a Library tile`.
- [ ] 2.8 Snapshot test: `MediaCard` touch state on iPhone 17 compact
  unchanged — covers Scenario `iPhone compact width touch unchanged`.
- [ ] 2.9 UI test: arrow-key focus traversal across Library grid on
  iPad Pro 13" regular landscape — covers Scenario `iPad regular width
  arrow keys move focus`.
- [ ] 2.10 UI test: Return on focused tile opens detail — covers
  Scenario `iPad Return opens detail`.
- [ ] 2.11 **iPad regular landscape snapshot regression suite —
  hardware-chrome variants**: focused-tile snapshots for `LibraryView`,
  `SearchView`, `DiscoverView`; hover-state snapshots for `MediaCard`,
  `SearchResultCard`, `PosterImage`, `ServerSwitcherButton`; menu-bar
  expanded screenshot via XCUITest with hardware keyboard attached.

## 3. Implementation (green)

- [ ] 3.1 Implement `TabSelection` observable in `SeerCore`; thread via
  `@EnvironmentObject` in `SeerApp`. Update `MainTabView` to bind
  `$selection.tab` — makes 2.1 + 2.2 pass.
- [ ] 3.2 Implement `SeerCommands` builder in
  `App/SeerApp/SeerCommands.swift`:
  `CommandGroup(.replacing: .sidebar)` with five tab buttons each with
  `keyboardShortcut("1"..."5")` wired to `TabSelection`.
- [ ] 3.3 Add `@FocusState searchFieldFocused` in `SearchView`, bind
  via `searchFocused(_:)`; expose ⌘F via `CommandGroup` that calls
  `tabSelection.requestSearchFocus()`. Active surface observes and
  flips focus — makes 2.3 + 2.4 pass.
- [ ] 3.4 Add player shortcuts in `VideoPlayerView`: hidden buttons
  with `keyboardShortcut(.space, modifiers: [])`, `.leftArrow`,
  `.rightArrow`, `.escape` driving `togglePlayPause` /
  `seek(±10)` / `dismiss` — makes 2.5 + 2.6 pass.
- [ ] 3.5 Apply `hoverEffect(.lift)` in `MediaCard`, `SearchResultCard`,
  `PosterImage`, `ServerSwitcherButton`, primary toolbar items. Wrap
  with `#if !os(tvOS)` — makes 2.7 + 2.8 pass.
- [ ] 3.6 Add `@FocusState focusedItemID: MediaItem.ID?` in Library /
  Search / Discover, apply `focusable()` to each grid tile, handle
  arrow-key advance via `onKeyPress` of `.upArrow` / `.downArrow` /
  `.leftArrow` / `.rightArrow` — makes 2.9 pass.
- [ ] 3.7 Wire Return on focused tile to set `selectedItemID`
  (depends on Proposal 1's selection model) — makes 2.10 pass.
- [ ] 3.8 Add ⌘D, ⌘R, ⌘[ / ⌘] commands. Scope ⌘D to grid+detail
  contexts; ⌘R to ViewModel refresh on the active surface.

## 4. HIG verification

- [ ] 4.1 Manual: iPad Pro 13" with Magic Keyboard — ⌘1–⌘5 switch tabs,
  menu bar surfaces all shortcuts, Stage Manager preserves bindings.
- [ ] 4.2 Manual: iPhone 17 Pro with Smart Keyboard Folio attached —
  bottom tabs respond to ⌘1–⌘5; menu bar surfaces.
- [ ] 4.3 Manual: Designed-for-iPad on Mac — full menu bar populated,
  no Catalyst regressions.
- [ ] 4.4 Manual: Trackpad hover on every tile type, all surfaces —
  lift consistent, no flicker, no z-index issues.
- [ ] 4.5 Manual: long-press ⌘ on iPad with hardware keyboard — system
  shortcut overlay shows the full Commands hierarchy.
- [ ] 4.6 VoiceOver: shortcuts announced as part of the action label
  ("Library, command 1").
- [ ] 4.7 Voice Control: "press command F" navigates to search.
- [ ] 4.8 Switch Control: grid focusable tiles included in auto-scan
  path.
- [ ] 4.9 Reduce Motion: hover lift becomes opacity change.
- [ ] 4.10 Run `make lint` and `make format`.

## 5. Refactor (optional)

- [ ] 5.1 Extract `KeyboardShortcuts.swift` constants file (⌘1, ⌘F,
  etc.) so per-view shortcuts reference named constants.
- [ ] 5.2 Consider a `FocusableGrid` view in SeerUI to encapsulate
  arrow-key + focus-state plumbing if more grid surfaces appear.
