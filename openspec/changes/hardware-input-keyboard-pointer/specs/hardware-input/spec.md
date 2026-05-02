## ADDED Requirements

### Requirement: Keyboard shortcuts cycle primary tabs

The application SHALL bind ⌘1 through ⌘5 to selecting the Library,
Discover, Search, Downloads, and Requests tabs respectively. The
shortcut MUST be discoverable via the system menu bar on iPad (Stage
Manager) and Mac (Catalyst / Designed-for-iPad).

#### Scenario: iPad regular width keyboard shortcut switches tabs

- **WHEN** the user on iPad regular width landscape with Magic Keyboard
  attached presses ⌘3 from any surface other than Search
- **THEN** the active tab MUST become Search, the search field MUST
  become the focused first responder within 250ms, and the previously
  visible content MUST be unloaded per existing tab-switch semantics

#### Scenario: iPhone compact width with hardware keyboard

- **WHEN** the user on iPhone compact width portrait with a Smart
  Keyboard Folio attached presses ⌘1
- **THEN** the active tab MUST become Library; the bottom tab bar MUST
  reflect the change

### Requirement: ⌘F focuses the active surface's search field

The application SHALL bind ⌘F to focusing the `.searchable` field on
the currently visible surface. If the active surface has no searchable
field, ⌘F MUST be a no-op (not consumed).

#### Scenario: iPad regular width ⌘F on Search

- **WHEN** the user on iPad regular width landscape with hardware
  keyboard is on the Search tab and presses ⌘F
- **THEN** the search field MUST receive keyboard focus, any prior text
  MUST be selected for replacement, and the on-screen keyboard MUST NOT
  appear (hardware keyboard preserved)

#### Scenario: iPad regular width ⌘F on Downloads (no-op)

- **WHEN** the user on iPad regular width landscape with hardware
  keyboard is on the Downloads tab (no `.searchable`) and presses ⌘F
- **THEN** the keystroke MUST NOT be consumed (system default behavior
  applies), no focus change MUST occur, and no error MUST be logged

### Requirement: Player keyboard shortcuts

`VideoPlayerView` SHALL bind Space to play/pause, ← (left arrow) to
skip backwards 10 seconds, → (right arrow) to skip forwards 10 seconds,
and ⌘. to dismissing the player. These bindings MUST be active only
while the player is the topmost modal.

#### Scenario: iPad regular width player Space toggles playback

- **WHEN** the user on iPad regular width landscape has
  `VideoPlayerView` presented as a `fullScreenCover` and is currently
  playing, and presses Space on a hardware keyboard
- **THEN** playback MUST pause, the AVPlayerViewController controls
  MUST reflect the paused state, and a subsequent Space keystroke MUST
  resume playback

#### Scenario: iPad player ←/→ skip

- **WHEN** the user on iPad regular width landscape has
  `VideoPlayerView` presented and presses → on a hardware keyboard
- **THEN** the playback time MUST advance by 10 seconds (capped at
  duration), the controls MUST reflect the new position, and a `seek`
  event MUST be recorded if telemetry consent is granted

### Requirement: Pointer hover lifts media tiles

The application SHALL apply `hoverEffect(.lift)` to `MediaCard`,
`SearchResultCard`, and any poster-tile view in `SeerUI` such that
pointer hover on iPad (with trackpad or mouse) lifts the tile by
approximately 4 points with a smooth animation. Touch interaction
MUST remain unchanged.

#### Scenario: iPad regular width pointer over a Library tile

- **WHEN** the user on iPad regular width landscape with a pointing
  device hovers the cursor over a media tile in `LibraryView`
- **THEN** the tile MUST lift by approximately 4 points, the
  surrounding tiles MUST remain stationary, and the lift MUST animate
  with default hover-effect timing

#### Scenario: iPhone compact width touch unchanged

- **WHEN** the user on iPhone compact width portrait taps and holds a
  media tile (touch-only)
- **THEN** the existing context menu long-press behavior MUST be
  preserved, no lift effect MUST occur, and no hover-related telemetry
  MUST fire

### Requirement: Grid items participate in focus-engine navigation

`LibraryView`, `SearchView`, and `DiscoverView` grid tiles SHALL be
focusable via `@FocusState` such that arrow keys move keyboard focus
across tiles in reading order, Tab/Shift-Tab move focus into and out
of the grid, and Return opens the focused tile's detail view (using
the same path as tap).

#### Scenario: iPad regular width arrow keys move focus

- **WHEN** the user on iPad regular width landscape has keyboard focus
  on a Library tile and presses → (right arrow)
- **THEN** focus MUST advance to the next tile in reading order, the
  previously focused tile MUST lose focus chrome, and the focused tile
  MUST remain on screen (auto-scroll if out of viewport)

#### Scenario: iPad Return opens detail

- **WHEN** the user on iPad regular width landscape has keyboard focus
  on a Library tile and presses Return
- **THEN** `MediaDetailView` for that item MUST become the active
  detail selection (per Proposal `ipad-navigation-shell` Requirement
  `Primary list surfaces use NavigationSplitView on regular width`),
  exactly as if the tile had been tapped

### Requirement: Menu-bar Commands surface system shortcuts

The application SHALL expose ⌘1–⌘5, ⌘F, ⌘R, and ⌘D in the system menu
bar via a `Commands` builder on the root `WindowGroup`. The menu bar
MUST be visible whenever a hardware keyboard is attached on iPad (Stage
Manager / full-screen) and on Mac via Catalyst / Designed-for-iPad.

#### Scenario: iPad Stage Manager menu bar populated

- **WHEN** the user on iPad regular width landscape with Magic Keyboard
  in Stage Manager opens the system menu bar
- **THEN** the Tabs menu MUST list Library, Discover, Search, Downloads,
  Requests with their respective ⌘1–⌘5 shortcuts visible alongside
  each entry

#### Scenario: Mac Catalyst menu bar populated

- **WHEN** the user runs the Designed-for-iPad-on-Mac app and opens the
  system menu bar
- **THEN** the same menu structure MUST appear, ⌘1–⌘5 MUST be bound,
  and `commandsRemoved()` MUST have removed irrelevant default groups
  (e.g. `HelpCommands` if no help target is registered)
