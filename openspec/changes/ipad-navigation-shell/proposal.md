## Why

Seer ships with `TARGETED_DEVICE_FAMILY: "1,2"` and runs on iPad today, but
the shell is pure phone: a 5-tab bottom `TabView`, every primary surface
uses `NavigationStack`, detail views open via `fullScreenCover`, settings
and server management are summoned as sheets, and
`LazyVGrid(.adaptive(minimum: 140))` produces tiny tiles on a 13" iPad
Pro. The maintainer doesn't currently use Seer on iPad because of this.
The fix is structural, not cosmetic: the iPad-native combination of
`.tabViewStyle(.sidebarAdaptable)`, `NavigationSplitView` for the
list-detail surfaces, and size-class branching as a foundational pattern
for tile and toolbar density.

```
   TODAY (iPad)                         AFTER (iPad regular width)
   ─────────────────────────            ─────────────────────────────────
                                        ┌──────┬───────────┬────────────┐
   ┌──────────────────────────┐         │ ☰    │ Library   │   Movie    │
   │                          │         │      │           │   poster   │
   │   stretched grid of      │         │ Lib  │ ▢ ▢ ▢ ▢   │            │
   │   tiny 140pt tiles       │         │ Disc │ ▢ ▢ ▢ ▢   │   Title    │
   │                          │         │ Srch │ ▢ ▢ ▢ ▢   │   Meta     │
   │                          │         │ DLs  │ ▢ ▢ ▢ ▢   │   [Play]   │
   │                          │         │ Reqs │           │            │
   │                          │         │      │           │            │
   ├──────────────────────────┤         │ Srvr │           │            │
   │  Lib  Disc  Srch  DL  Rq │         │ Sets │           │            │
   └──────────────────────────┘         └──────┴───────────┴────────────┘
   bottom tab bar = phone               sidebar + content + detail
   tap a tile = fullScreenCover         tap a tile = detail column
   settings = sheet                     settings = sidebar destination
```

## What Changes

- **TabView gets `.tabViewStyle(.sidebarAdaptable)`** so on regular width
  the bottom tab bar becomes a collapsible floating sidebar. Compact width
  is unchanged — iPhone keeps the bottom tabs.
- **`LibraryView`, `DiscoverView`, `RequestsView` adopt
  `NavigationSplitView`** with three columns (`.balanced`) on regular
  width, falling back to `NavigationStack` on compact width. Detail-column
  content uses the existing `MediaDetailView` body without modal
  presentation.
- **Detail navigation reshape**: `LibraryView` today opens
  `MediaDetailView` via `NavigationLink` inside the stack. On iPad the
  `selectedItemID: MediaItem.ID?` becomes `@State` driving the detail
  column; `fullScreenCover(item:)` for inline playback is preserved on
  both platforms (player remains modal in this proposal — Proposal 3
  detaches it).
- **Server management surfaces from the sidebar root** as a separate
  destination on iPad regular width — not a sheet. On compact width
  `ServerManagementView` continues to present as a sheet from the existing
  `ServerSwitcherButton`.
- **Adaptive grid sizing by size class**:
  `GridItem(.adaptive(minimum: 140))` becomes a single helper
  `MediaGridColumns(horizontalSizeClass:)` that returns 140pt for compact,
  ≥ 180pt for regular width such that 13" iPad Pro full-width grids show
  5–8 columns. Centralizes the rule so future tweaks are one-place.
- **New `SizeClassAdaptive<Compact, Regular>` helper in `SeerUI`** picks
  one of two view builders by `horizontalSizeClass`. Lets feature views
  stay declarative without `if sizeClass == .compact` boilerplate. The
  unselected branch MUST NOT be evaluated.
- **No change to compact-width iPhone layout** beyond the type-erased
  helper. tvOS is unaffected (focus engine + 10-foot UI is its own world).

## Screen-by-Screen Reshape

Each diagram pair is iPhone compact (unchanged baseline) on the left,
iPad regular landscape (new) on the right. Sidebar = `☰` (collapsible).
Tabs collapsed to initials to fit (Lib/Disc/Srch/DLs/Reqs).

### Library

```
  iPhone compact (unchanged)         iPad regular (after)
  ─────────────────────              ──────────────────────────────────

  ┌────────────────────┐             ┌──────┬──────────┬─────────────┐
  │ Library      🔍 ⚙ │             │ ☰    │ Library  │ Movie Title │
  │                    │             │      │  🔍 ⚙   │ ─────────── │
  │ Continue Watching  │             │ Lib  │ Cont. W. │ ┌─────────┐ │
  │ ▢ ▢ ▢ ▢           │             │ Disc │ ▢▢▢▢▢   │ │ poster  │ │
  │                    │             │ Srch │          │ └─────────┘ │
  │ Latest Movies      │             │ DLs  │ Latest   │             │
  │ ▢ ▢ ▢ ▢           │             │ Reqs │ ▢▢▢▢▢▢▢ │ 2024 · 2h08 │
  │                    │             │      │ ▢▢▢▢▢▢▢ │ Action      │
  │ TV Shows           │             │ ╌╌╌╌ │          │ [▶ Play]    │
  │ ▢ ▢ ▢ ▢           │             │ Srvr │ TV       │ [⤓ Get]     │
  │                    │             │      │ ▢▢▢▢▢▢▢ │             │
  ├────────────────────┤             │      │ ▢▢▢▢▢▢▢ │ Synopsis... │
  │ Lib Dis Srch DL Rq │             │      │          │             │
  └────────────────────┘             └──────┴──────────┴─────────────┘
  push to detail                     tap tile → detail column
  140pt grid tiles                   ≥180pt grid, 5–8 columns
```

### Discover

```
  iPhone compact (unchanged)         iPad regular (after)
  ─────────────────────              ──────────────────────────────────

  ┌────────────────────┐             ┌──────┬──────────────┬─────────┐
  │ Discover      ⚙   │             │ ☰    │ Discover  ⚙ │ Tile    │
  │                    │             │      │              │ detail  │
  │ Trending           │             │ Lib  │ Trending     │ ─────── │
  │ ▢ ▢ ▢ ▢           │             │ Disc │ ▢▢▢▢▢▢▢▢   │ Title   │
  │                    │             │ Srch │              │ Meta    │
  │ Popular Movies     │             │ DLs  │ Popular      │ Cast    │
  │ ▢ ▢ ▢ ▢           │             │ Reqs │ ▢▢▢▢▢▢▢▢   │ [Req]   │
  │                    │             │      │              │         │
  │ By Genre →         │             │      │ By Genre     │         │
  │ Action Drama Sci-Fi│             │      │ Action       │         │
  │                    │             │      │ Drama        │         │
  └────────────────────┘             └──────┴──────────────┴─────────┘
  GenreBrowseView pushed             GenreBrowseView in middle column
                                     (still a NavigationStack inside it)
```

### Requests

```
  iPhone compact (unchanged)         iPad regular (after)
  ─────────────────────              ──────────────────────────────────

  ┌────────────────────┐             ┌──────┬──────────────┬─────────┐
  │ Requests      ⊕   │             │ ☰    │ Requests ⊕  │ Request │
  │ [All|Pnd|Apv|Dec]  │             │      │ [All|Pnd|Av] │ detail  │
  │                    │             │ Lib  │              │ ─────── │
  │ ▣ Movie A    ⏳  │             │ Disc │ ▣ Movie A ⏳│ Title   │
  │ ▣ Show B     ✓   │             │ Srch │ ▣ Show B  ✓ │ Status  │
  │ ▣ Movie C    ✗   │             │ DLs  │ ▣ Movie C ✗ │ User    │
  │ ▣ Show D     ⏳  │             │ Reqs │ ▣ Show D  ⏳│         │
  │                    │             │      │              │ [Apv]   │
  │                    │             │      │              │ [Dec]   │
  └────────────────────┘             └──────┴──────────────┴─────────┘
  detail = NavigationStack push      detail = trailing column
  approve/decline = sheet            approve/decline = inline buttons
```

### Search

```
  iPhone compact (unchanged)         iPad regular (after — Phase 1)
  ─────────────────────              ──────────────────────────────────

  ┌────────────────────┐             ┌──────┬──────────────────────────┐
  │ 🔍 [search field]  │             │ ☰    │ 🔍 [search field]        │
  │                    │             │      │                          │
  │ Recent searches    │             │ Lib  │ Recent searches          │
  │ • spider-man       │             │ Disc │ • spider-man             │
  │ • the bear         │             │ Srch │ • the bear               │
  │                    │             │ DLs  │                          │
  │ Results            │             │ Reqs │ Results (≥180pt grid)    │
  │ ▢ ▢ ▢ ▢           │             │      │ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢         │
  │ ▢ ▢ ▢ ▢           │             │      │ ▢ ▢ ▢ ▢ ▢ ▢ ▢ ▢         │
  └────────────────────┘             └──────┴──────────────────────────┘
  Search stays NavigationStack       grid widens; Search keeps stack
                                     until follow-up adds split view
```

### Media detail

```
  iPhone compact (unchanged)         iPad regular (after)
  ─────────────────────              ──────────────────────────────────

  pushed onto NavigationStack        embedded in detail column

  ┌────────────────────┐             ┌──────┬──────────┬─────────────┐
  │ ◀ Library          │             │ ☰    │ Library  │ ◀ back      │
  │ ┌──────┐           │             │      │          │ ┌─────────┐ │
  │ │poster│           │             │ Lib  │ ▢▢▢▢▢▢   │ │ poster  │ │
  │ └──────┘           │             │ Disc │ ▢▢▢▢▢▢   │ └─────────┘ │
  │ Title              │             │ Srch │ ▢▢▢▢▢▢   │ Title       │
  │ Meta · 2h 8m       │             │ DLs  │ ▢▢▢▢▢▢   │ Meta·2h08   │
  │ [▶ Play] [⤓ DL]   │             │ Reqs │          │ [▶][⤓][⋯]  │
  │ Synopsis...        │             │      │          │ Synopsis... │
  │                    │             │ Srvr │          │             │
  └────────────────────┘             └──────┴──────────┴─────────────┘
  player stays modal                 player still modal in this proposal
                                     (Proposal 3 detaches it)
```

### Server management

```
  iPhone compact (unchanged)         iPad regular (after)
  ─────────────────────              ──────────────────────────────────

  sheet from ServerSwitcherButton    sidebar destination "Servers"

  ┌────────────────────┐             ┌──────┬──────────────────────┐
  │     Servers   Done │             │ ☰    │ ◀ Servers       ⊕   │
  │ ─────────────────  │             │      │ ─────────────────── │
  │                    │             │ Lib  │                      │
  │ ⊙ Home Server  ✓  │             │ Disc │ ⊙ Home Server  ✓    │
  │ ⊙ Office       ◯  │             │ Srch │ ⊙ Office       ◯    │
  │                    │             │ DLs  │                      │
  │ + Add Server       │             │ Reqs │ + Add Server         │
  │                    │             │      │                      │
  │ Internal URLs →    │             │ ╌╌╌╌ │ Internal URLs        │
  │ Diagnostics →      │             │ Srvr │ Diagnostics          │
  │                    │             │ ▶◉◀ │                      │
  └────────────────────┘             └──────┴──────────────────────┘
  presentationDetents preserved      ServerManagementBody embedded
```

### Onboarding (welcome)

```
  iPhone compact (unchanged)         iPad regular (after)
  ─────────────────────              ──────────────────────────────────

  ┌────────────────────┐             ┌──────────────────────────────┐
  │   Welcome to Seer  │             │       Welcome to Seer        │
  │   ──────────────   │             │       ─────────────────       │
  │                    │             │                              │
  │ Sign back in to    │             │   ┌────────────────────┐     │
  │ <iCloud server>    │             │   │ Sign back in to    │     │
  │ ─────────────────  │             │   │ <iCloud server>    │     │
  │                    │             │   ├────────────────────┤     │
  │ Use <hostname>     │             │   │ Use <hostname>     │     │
  │ on this Wi-Fi      │             │   │ on this Wi-Fi      │     │
  │ ─────────────────  │             │   ├────────────────────┤     │
  │                    │             │   │ Enter URL manually │     │
  │ Enter URL manually │             │   └────────────────────┘     │
  │                    │             │                              │
  └────────────────────┘             └──────────────────────────────┘
  full-width buttons                 centered, max-width column
                                     (no NavigationSplitView in onboarding —
                                     onboarding is pre-tab, single column)
```

## Capabilities

### New Capabilities
- `ipad-navigation-shell`: sidebar-adaptable tabbed shell, list-detail
  split view for primary surfaces, server management as a sidebar
  destination on iPad regular width, and the size-class-aware grid
  column rule.

### Modified Capabilities
(None — no existing specs cover the navigation shell.)

## Impact

**Affected code:**
- `App/SeerApp/ContentView.swift` — `MainTabView` adds
  `.tabViewStyle(.sidebarAdaptable)`; ContentView gains a sidebar
  destination for Servers on regular width.
- `Features/Library/LibraryView.swift` — wrapped in `NavigationSplitView`
  on regular; selection state hoisted to a `@State` `selectedItemID`.
- `Features/Discover/DiscoverView.swift`,
  `Features/Discover/GenreBrowseView.swift` — same pattern.
- `Features/Requests/RequestsView.swift` — same pattern; the existing
  inner sheets (request detail) become detail-column content on iPad.
- `Features/Library/MediaDetailView.swift` — no body changes; embeds in
  the detail column once unwrapped from a `NavigationStack`.
- `Features/Servers/ServerManagementView.swift` — extract a
  `ServerManagementBody` view (no presentation chrome); wrap in sheet on
  compact, embed in sidebar destination on regular.
- `Packages/SeerUI/Sources/SeerUI/` — new `SizeClassAdaptive.swift` and
  `MediaGridColumns.swift` helpers.
- Existing `LazyVGrid` call sites migrated:
  `Features/Library/LibraryView.swift:263`,
  `Features/Search/SearchView.swift:251`,
  `Features/Discover/GenreBrowseView.swift:115`.

**Platforms:** iPad regular width (primary), iPhone compact (regression
gate — must remain pixel-similar), Designed-for-iPad on Mac (free with
iPad work). tvOS: out of scope.

**Dependencies:** None. `NavigationSplitView` and
`.tabViewStyle(.sidebarAdaptable)` ship with iOS 26 (project minimum).

**Telemetry:** Add `seer.shell.layout` event with `sizeClass` and
`splitViewVisibility` properties (gated on DiagnosticsConsent — same
opt-in path as today).

**Migration:** None on disk.
