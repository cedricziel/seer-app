## Context

Seer is a one-person iOS / tvOS app for Jellyfin and Jellyseerr. Device
family is already `1,2` and `SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD: true`.
The current shell is `TabView` (bottom bar) wrapping five
`NavigationStack`s. The maintainer doesn't use the app on iPad today
because the experience is literally a stretched iPhone — tiny tiles,
modal detail, sheet-summoned settings.

iOS 26 minimum lets us assume `NavigationSplitView`,
`.tabViewStyle(.sidebarAdaptable)`, and the new sidebar TabView APIs are
all available. No fallback paths needed.

## Goals / Non-Goals

**Goals:**
- iPad regular width feels like an iPad app, not a stretched phone.
- iPhone compact width is unchanged (regression gate).
- Foundation that Proposals 2 (hardware input) and 3 (multi-window
  playback) can build on.
- Centralize size-class adaptation so future features inherit the
  pattern.

**Non-Goals:**
- Hardware input affordances (keyboard shortcuts, hover) — Proposal 2.
- Player as a separate scene — Proposal 3.
- tvOS layout changes — focus engine is its own world.
- Apple Pencil / drag-and-drop — out of scope.
- New design language for tile or poster aesthetics — preserve existing
  visuals.

## Decisions

**1. `.tabViewStyle(.sidebarAdaptable)` over a hand-rolled root
`NavigationSplitView`.** The sidebar-adaptable TabView is the iOS 26
SwiftUI primitive Apple ships for exactly this purpose: phone shows
bottom tabs, iPad shows a collapsible floating sidebar with the same
`Tab` declarations. Hand-rolling at the root would mean two parallel
content trees and divergent state restoration. This decision keeps the
existing `MainTabView` largely intact.

**2. `NavigationSplitView` inside each tab, not at the app root.** With
sidebar-adaptable TabView, each tab gets its own column hierarchy.
Library/Discover/Requests each adopt their own `NavigationSplitView` so
detail content has a stable column. Search and Downloads stay as
`NavigationStack` (their content doesn't have a list-detail shape).

**3. Selection by ID, not by reference.** Detail-column selection uses
`selectedItemID: MediaItem.ID?` (a stable identifier) rather than a
captured `MediaItem` reference, so selection survives list reloads and
offline-cache flips without dangling state.

**4. Centralize grid sizing.** `MediaGridColumns(horizontalSizeClass:)`
is the single source of truth for tile minimums. Three call sites today
(`LibraryView:263`, `SearchView:251`, `GenreBrowseView:115`) get
migrated. Future grids inherit by default.

**5. Compact-width unchanged, type-erased path.** The new
`SizeClassAdaptive<Compact, Regular>` helper lets feature views express
both shapes without `Group { if ... else ... }` boilerplate. On compact
width the regular branch never instantiates, preserving the current
performance profile.

**6. Server management body extraction.** `ServerManagementView` today
hard-codes `presentationDetents` and dismiss chrome. Extract a
`ServerManagementBody` view (no presentation chrome); wrap in sheet on
compact, embed in sidebar destination on regular. Single source of
truth, two presentation shells.

## HIG & Layout

### iPhone (compact width)

Bottom TabView retained. `NavigationStack` inside each tab retained.
`MediaGridColumns` returns the current `140pt` minimum on compact, so
visual layout is identical. No regression budget on compact width —
snapshots gate it.

### iPad (regular width)

Sidebar-adaptable TabView shows a collapsible floating sidebar by
default. Library/Discover/Requests use `NavigationSplitView` with the
`.balanced` preferred-compact-column behavior so detail is visible at
split-view-1/2 and above. At split-view-1/3 the detail collapses; the
sidebar narrows. Stage Manager resize triggers a `horizontalSizeClass`
change which flips the structure live (animated, no snap). Multitasking:
the app is a regular full-screen-or-multi-tasked UIScene; nothing in
this proposal changes that.

### tvOS

Out of scope. `MainTabView`'s tvOS path remains. `#if os(tvOS)` branches
in feature views remain untouched.

### Aspect ratios

Portrait + landscape on iPad both supported (already in Info.plist).
Landscape iPhone unchanged. External display (mirror) unchanged — the
player is still modal in this proposal.

### Accessibility

- VoiceOver order: sidebar entries → content list → detail column.
  Verified at each split-view fraction.
- Dynamic Type AX5: tile minimums grow, but the grid uses `.adaptive`
  so column count compresses gracefully.
- Reduce Motion: sidebar collapse animation honors the setting
  (crossfade instead of slide).
- Increase Contrast: sidebar separator and selection chrome obey the
  system tint.

### HIG references

- "Tab bars" — Apple Human Interface Guidelines, sidebar adaptation
  pattern for iPad
  (developer.apple.com/design/human-interface-guidelines/tab-bars).
- "Sidebars" — collapsible behavior, selection chrome
  (developer.apple.com/design/human-interface-guidelines/sidebars).
- "Layout — Adapt to different size classes"
  (developer.apple.com/design/human-interface-guidelines/layout).
- "Split views" — `.balanced`, `.prominentDetail`, multi-column
  guidance
  (developer.apple.com/design/human-interface-guidelines/split-views).

## Risks / Trade-offs

- **[Risk] Library snapshot tests rely on `NavigationStack` rendering.**
  → Mitigation: snapshot fixtures gain regular-width variants; existing
  compact-width snapshots remain authoritative for compact behavior.
- **[Risk] Detail-column content double-renders when selection
  changes.** → Mitigation: keyed by stable ID, AsyncImage / Kingfisher
  cache prevents poster reload; selection animation set to `.none` on
  first appearance.
- **[Risk] `ServerManagementView` coupling — its sheet-shaped
  presentation hard-codes presentation chrome.** → Mitigation: extract
  `ServerManagementBody`; presentation chrome lives in caller, not in
  the body.
- **[Trade-off] `.tabViewStyle(.sidebarAdaptable)` opinions conflict
  with hand-rolled custom sidebars.** → Accept Apple's chrome — fighting
  the system primitive is more work and worse-feeling than embracing it.
- **[Risk] `selectedItemID` lifecycle when the underlying item leaves
  the list (e.g. removed from Continue Watching).** → Mitigation:
  observer clears `selectedItemID` if it no longer resolves; detail
  column shows the existing empty-state on nil selection.

## Migration Plan

No data migration. UI rollout is one ship — there is no feature flag
because the size-class branch is the gate. Existing iPhone users see no
change. iPad users see the new shell on first launch after update.

Rollback plan: revert the proposal's diff. State restoration uses
standard `SceneStorage` / `NavigationSplitView` restoration, so no
orphaned persisted state survives a rollback.

## Open Questions

- Does the sidebar default to collapsed or expanded on first launch on
  iPad? Apple's default is "expanded on iPad regular full width,
  collapsed on split-view-1/3". Lean: accept Apple's default; revisit
  only if user testing surfaces friction.
- Should `SearchView` also adopt `NavigationSplitView`? Search results
  have a list-detail shape too. Lean: yes, but defer to a follow-up
  because the search empty-state design is its own conversation.
- Does the new sidebar need a server switcher at the bottom?
  `ServerSwitcherButton` exists today in toolbars; an iPad sidebar
  might host it more naturally. Lean: yes, fits in this proposal.
  Decide before implementing 3.8.
