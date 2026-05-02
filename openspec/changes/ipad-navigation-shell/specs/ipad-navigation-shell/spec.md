## ADDED Requirements

### Requirement: Sidebar-adaptable tabbed shell on iPad regular width

The application SHALL render its primary tab structure as a sidebar-
adaptable `TabView` such that compact width devices show the existing
bottom tab bar and regular width devices show a collapsible floating
sidebar with the same five tabs (Library, Discover, Search, Downloads,
Requests). The five tab identities, ordering, and labels MUST be
identical across size classes.

#### Scenario: iPhone compact width preserves bottom tabs

- **WHEN** the user on iPhone compact width portrait launches the app
  while authenticated
- **THEN** the shell MUST render `MainTabView` with a bottom-aligned tab
  bar, the five existing tabs in their existing order, and `selectedTab`
  defaulting to `.library`

#### Scenario: iPad regular width renders a sidebar

- **WHEN** the user on iPad regular width landscape launches the app
  while authenticated
- **THEN** the shell MUST render the same five tabs as a leading sidebar
  with identical labels and identical SF Symbol images, MUST select
  `.library` by default, and MUST allow the user to collapse the sidebar
  via the system sidebar-toggle affordance

#### Scenario: Stage Manager resize flips the layout live

- **WHEN** the user on iPad with Stage Manager active resizes the window
  from a regular-width footprint to a compact-width footprint
- **THEN** the shell MUST animate the transition from sidebar to bottom
  tab bar, MUST preserve the active tab selection across the transition,
  and MUST NOT lose detail-column selection state

### Requirement: Primary list surfaces use NavigationSplitView on regular width

`LibraryView`, `DiscoverView`, and `RequestsView` SHALL render as a
three-column `NavigationSplitView` on regular width with the existing
primary content as the content column and `MediaDetailView` (or the
request-equivalent detail) in the detail column. On compact width these
views SHALL render as a `NavigationStack` with detail pushed onto the
stack as today.

#### Scenario: iPad regular width Library renders detail in the trailing column

- **WHEN** the user on iPad regular width landscape opens Library and
  taps a media tile
- **THEN** `MediaDetailView` for that item MUST render in the detail
  column WITHOUT presenting a `fullScreenCover`, the tapped tile MUST
  show selection chrome, and the content column MUST remain visible

#### Scenario: iPhone compact width Library pushes detail onto the stack

- **WHEN** the user on iPhone compact width portrait opens Library and
  taps a media tile
- **THEN** `MediaDetailView` MUST be pushed onto the existing
  `NavigationStack` exactly as today, with no `NavigationSplitView`
  chrome visible

#### Scenario: Detail selection survives list reload

- **WHEN** the user on iPad regular width landscape has a media item
  selected in the detail column and the underlying `LibraryViewModel`
  triggers a reload of the library list
- **THEN** the same `MediaItem.ID` MUST remain selected, the detail
  column MUST NOT flicker to empty and back, and the content column
  scroll position MUST be preserved

### Requirement: Adaptive grid columns respond to size class

`LibraryView`, `SearchView`, and `GenreBrowseView` SHALL use a single
helper `MediaGridColumns(horizontalSizeClass:)` to compute their
`LazyVGrid` column rule. The helper MUST return
`GridItem(.adaptive(minimum: 140))` for compact width and a larger
minimum (≥ 180pt) for regular width such that 13" iPad Pro full-width
grids render no fewer than 5 columns and no more than 8 columns.

#### Scenario: iPhone compact width grid minimum is 140pt

- **WHEN** the user on iPhone compact width portrait opens Library
- **THEN** the grid column rule used MUST be `.adaptive(minimum: 140)`,
  identical to the pre-change behavior

#### Scenario: iPad regular full width grid renders 5–8 columns

- **WHEN** the user on iPad regular width landscape (full-width window
  on a 13" iPad Pro) opens Library
- **THEN** the grid MUST render between 5 and 8 columns inclusive, tiles
  MUST maintain the existing 16pt spacing, and the column rule MUST come
  from `MediaGridColumns(horizontalSizeClass: .regular)`

#### Scenario: iPad split-view 1/3 narrows columns

- **WHEN** the user on iPad regular base width has the app pinned to
  split-view 1/3 (≈ compact horizontal size class)
- **THEN** the grid MUST fall back to the compact column rule (140pt
  minimum) and tiles MUST match iPhone compact tile sizing

### Requirement: Server management is a sidebar destination on iPad

The application SHALL surface server management as a sidebar destination
on iPad regular width — selectable from the bottom of the sidebar —
instead of the existing sheet presentation. On compact width the
existing sheet presentation summoned via `ServerSwitcherButton` MUST be
preserved.

#### Scenario: iPad regular width sidebar exposes Servers entry

- **WHEN** the user on iPad regular width landscape opens the sidebar
- **THEN** the sidebar MUST expose a "Servers" destination below the
  five primary tabs, separated by a divider, that selects to render
  `ServerManagementBody` (without sheet presentation chrome) in the
  detail column

#### Scenario: iPhone compact width retains sheet presentation

- **WHEN** the user on iPhone compact width portrait taps the existing
  server switcher button in any toolbar
- **THEN** `ServerManagementView` MUST present as a sheet exactly as
  today, with the existing presentation detents

### Requirement: Size-class adaptive view helper

The `SeerUI` package SHALL expose a
`SizeClassAdaptive<Compact: View, Regular: View>` view that selects
between two view builders based on the ambient `horizontalSizeClass`.
The unselected branch's body MUST NOT be invoked.

#### Scenario: Compact width evaluates only the compact branch

- **WHEN** a `SizeClassAdaptive` is hosted in a
  `horizontalSizeClass = .compact` environment
- **THEN** only the `Compact` builder's body MUST be invoked; the
  `Regular` builder MUST NOT be evaluated in that frame

#### Scenario: Regular width evaluates only the regular branch

- **WHEN** a `SizeClassAdaptive` is hosted in a
  `horizontalSizeClass = .regular` environment
- **THEN** only the `Regular` builder's body MUST be invoked; the
  `Compact` builder MUST NOT be evaluated in that frame
