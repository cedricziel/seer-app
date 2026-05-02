## 1. Setup

- [ ] 1.1 Audit current `NavigationStack` usages across `LibraryView`,
  `DiscoverView`, `GenreBrowseView`, `RequestsView` to map detail-
  presentation patterns and identify state coupling that doesn't survive
  a hoisted-selection model.
- [ ] 1.2 Extend snapshot test scaffolding for iPad regular width:
  `Tests/SeerUITests/` gains a `iPad Pro 13-inch (M4)` device + `regular`
  size-class trait helper.

## 2. Tests (red)

- [ ] 2.1 Snapshot test: `MainTabView` on iPhone 17 Pro compact portrait
  — covers Scenario `iPhone compact width preserves bottom tabs`. Pixel-
  equivalent to current baseline.
- [ ] 2.2 Snapshot test: `MainTabView` on iPad Pro 13" regular landscape
  — covers Scenario `iPad regular width renders a sidebar`. Sidebar
  visible, five tabs, Library selected.
- [ ] 2.3 Snapshot test: `LibraryView` on iPad Pro 13" regular landscape
  with no selection — covers Scenario `iPad regular width Library
  renders detail in the trailing column` (empty-state branch). Three
  columns visible.
- [ ] 2.4 Snapshot test: `LibraryView` on iPhone 17 compact portrait —
  covers Scenario `iPhone compact width Library pushes detail onto the
  stack`. `NavigationStack` chrome only, no split view.
- [ ] 2.5 Snapshot test: `LibraryView` on iPad Pro 11" pinned to
  split-view 1/3 — covers Scenario `iPad split-view 1/3 narrows
  columns`. 140pt grid minimum applied.
- [ ] 2.6 Unit test: `MediaGridColumns(.compact)` returns
  `.adaptive(minimum: 140)`; `MediaGridColumns(.regular)` returns ≥
  180pt — covers Scenarios `iPhone compact width grid minimum is 140pt`
  and `iPad regular full width grid renders 5–8 columns`.
- [ ] 2.7 Unit test: `SizeClassAdaptive` evaluates only the matching
  branch — covers Scenarios `Compact width evaluates only the compact
  branch` and `Regular width evaluates only the regular branch`. Use a
  counter-based test view that increments on body invocation.
- [ ] 2.8 Snapshot test: `ServerManagementBody` embedded in iPad sidebar
  destination — covers Scenario `iPad regular width sidebar exposes
  Servers entry`.
- [ ] 2.9 Snapshot test: `ServerManagementView` summoned as sheet on
  iPhone compact — covers Scenario `iPhone compact width retains sheet
  presentation`. Pixel-equivalent to current baseline.
- [ ] 2.10 UI test: Stage Manager-style resize from regular to compact
  preserves selected tab and detail selection — covers Scenario `Stage
  Manager resize flips the layout live`.
- [ ] 2.11 **iPad regular landscape snapshot regression suite** — every
  primary screen in the app gets at least one iPad Pro 13" landscape
  snapshot baseline as part of this change. The new shell touches every
  surface, so this is the regression gate. Required surfaces (one
  snapshot each minimum; multiple where state branches are visually
  distinct):
  - `MainTabView` (covered by 2.2)
  - `LibraryView` no-selection + with-selection (2.3 + new)
  - `DiscoverView`, `GenreBrowseView`
  - `SearchView` empty state + with results
  - `RequestsView` all + pending + approved + declined filter states
  - `DownloadsView` empty + with downloads
  - `MediaDetailView` movie + series + episode forms
  - `EpisodeDetailSheet`, `SearchResultDetailSheet`
  - `ServerManagementBody` (2.8) + `AddServerView` + `ServerEditView`
    + `InternalURLSettingsView`
  - `DownloadSettingsView`
  - `PrivacySettingsView`, `FeedbackView`, `DiagnosticsConsentSheet`
  - `AudioSubtitleSheet`, `RequestOptionsSheet`,
    `SharedRequestOptionsSheet`
  - `WhatsNewView` (`.large` detent)
  - `OnboardingFlowView` welcome + `ManualServerEntryView` +
    `JellyseerrConnectSheet`
  - `VideoPlayerView` iPad `fullScreenCover` form (player remains modal
    in this proposal; Proposal 3 detaches it)
- [ ] 2.12 **iPad regular portrait sweep** — same surfaces as 2.11 at
  portrait orientation; targets reflow regressions specific to
  portrait-aspect iPad use.
- [ ] 2.13 **iPad split-view 1/3 sweep** — `LibraryView`, `DiscoverView`,
  `RequestsView`, `SearchView`, `DownloadsView` snapshots at
  split-view-1/3 (compact horizontal size class on regular base width).
  Verifies 2.5's compact-fallback rule applies to every primary surface,
  not just Library.

## 3. Implementation (green)

- [ ] 3.1 Add `SizeClassAdaptive<Compact: View, Regular: View>` to
  `Packages/SeerUI/Sources/SeerUI/SizeClassAdaptive.swift` — makes 2.7
  pass.
- [ ] 3.2 Add `MediaGridColumns(horizontalSizeClass:)` helper to
  `Packages/SeerUI/Sources/SeerUI/MediaGridColumns.swift` — makes 2.6
  pass.
- [ ] 3.3 Apply `.tabViewStyle(.sidebarAdaptable)` to `MainTabView` in
  `App/SeerApp/ContentView.swift` — makes 2.2 pass; verify 2.1 unchanged.
- [ ] 3.4 Wrap `LibraryView`'s body in `NavigationSplitView` on regular
  width using `SizeClassAdaptive`, hoist
  `selectedItemID: MediaItem.ID?` to `@State`, render `MediaDetailView`
  in the detail column — makes 2.3 + 2.10 pass; verify 2.4 unchanged.
- [ ] 3.5 Apply same `NavigationSplitView` pattern to `DiscoverView`
  and `GenreBrowseView`.
- [ ] 3.6 Apply same pattern to `RequestsView` (request-detail in the
  detail column on iPad regular).
- [ ] 3.7 Migrate all `LazyVGrid` call sites to
  `MediaGridColumns(horizontalSizeClass:)`:
  `Features/Library/LibraryView.swift:263`,
  `Features/Search/SearchView.swift:251`,
  `Features/Discover/GenreBrowseView.swift:115` — makes 2.5 pass.
- [ ] 3.8 Extract `ServerManagementBody` view from
  `Features/Servers/ServerManagementView.swift` (no presentation
  chrome); wrap in sheet on compact, embed in sidebar destination on
  regular; add Servers destination to `MainTabView` sidebar (regular-
  only) — makes 2.8 + 2.9 pass.

## 4. HIG verification

- [ ] 4.1 Manual verification on iPhone 17 Pro compact portrait + landscape:
  bottom tab bar present, behavior unchanged, Dynamic Type AX5 grid
  reflows without truncation.
- [ ] 4.2 Manual verification on iPad Pro 13" regular at split-view 1/3,
  1/2, 2/3, full-width: sidebar collapses appropriately, grid columns
  5–8 at full width, detail column visible at 1/2 and above.
- [ ] 4.3 Manual verification with Stage Manager: resize between regular
  and compact, confirm animation, selection preservation, no dropped
  frames.
- [ ] 4.4 VoiceOver pass: sidebar entries → content → detail column
  reading order; selection chrome announced; "Servers" destination
  announced from sidebar.
- [ ] 4.5 Reduce Motion: sidebar collapse uses crossfade not slide.
- [ ] 4.6 Increase Contrast: sidebar separator and selection chrome
  obey system tint.
- [ ] 4.7 Designed-for-iPad on Mac: launch, confirm sidebar renders, no
  Catalyst-specific regressions.
- [ ] 4.8 Run `make lint` and `make format`.

## 5. Refactor (optional)

- [ ] 5.1 Centralize sidebar destination registration so future
  tabs/destinations register in one list (a `SidebarDestination` enum
  with associated views).
- [ ] 5.2 Extract `LibraryViewModel.selectedItemID` to a
  `MediaSelectionCoordinator` if Discover/Requests need to share
  selection across surfaces (defer until that need is real).
