# UX review backlog

Reviewed against `a517623` on 2026-10-25. Confirmed items below come from the
current SwiftUI implementation. UX009 was confirmed with isolated compact and AX5
renders on 2026-10-26.

## Delivery rules

- Keep queued UX work out of the current bug-fix PRs.
- Start a replacement chat only after an existing task merges and its chat is
  archived. Archive its managed worktree when allowed; preserve protected primary
  checkouts. Each replacement gets a fresh managed worktree.
- Recheck current `origin/main`, active chats, and open PRs before assigning work.
- Rebase at implementation checkpoints, before pushing, and before merging.
- Use auto-merge with required CI and approvals intact. When CodeRabbit is rate
  limited, review the exact PR revision independently in isolation.
- Run at most **two local native builds or full package compilations** at once,
  with `-jobs 2` per build. CI does not consume a local slot. Prefer CI over a
  redundant full local build; never stop another task's process. Use the designated
  build coordinator's grants; it may serialize work below this ceiling.
- Use the pinned SwiftLint 0.63.2 and SwiftFormat 0.61.1 until the shared tooling
  entrypoints land. Tool upgrades and repository-wide formatting need separate PRs.

## Queue

Area names identify ownership for overlap checks, not permission to add work to
an active PR. UX001 replaces the archived sign-in task after PR 75 merged.

| ID | Priority | Status | Experience to fix | Area | Completion check |
| --- | --- | --- | --- | --- | --- |
| UX001 | P2 | Complete, [PR #93](https://github.com/cedricziel/seer-app/pull/93) | Quick Connect expiration and failures appear only as "Polling paused", with no retry. | Onboarding | Show the actual error, offer a new code, and retain password sign-in. Test expiration and retry. |
| UX002 | P2 | Complete, [PR #105](https://github.com/cedricziel/seer-app/pull/105), chat `01a17687-86ac-7652-b3dd-88623c0e9584` | Discover can become blank when its initial section loads fail. | Discover | Show an actionable error and Retry; preserve any sections that loaded successfully. |
| UX003 | P2 | Complete, [PR #103](https://github.com/cedricziel/seer-app/pull/103), chat `01a17635-2d2c-7fd0-8d71-b598f1905ec9` | Failed library-grid loads show a passive message without recovery. | Library | Offer visible Retry and verify recovery without leaving the screen or changing filters. |
| UX004 | P2 | Complete, [PR #100](https://github.com/cedricziel/seer-app/pull/100), chat `01a175c7-4e30-7a12-b4d3-8562f22549af` | TV requests can submit an empty season selection while seasons are still loading. | Request options | Disable submission until a valid selection is ready. Distinguish loading errors from no seasons and offer Retry. |
| UX005 | P2 | Complete, [PR #108](https://github.com/cedricziel/seer-app/pull/108), chat `01a176d0-d6c9-78f2-8c4a-402cbea77dd9` | Cancel Request is hidden in a long-press menu and absent from normal request details. | Requests | Add an eligible cancellation action to details, confirmation, loading state, and failure feedback. |
| UX006 | P2 | Complete, [PR #98](https://github.com/cedricziel/seer-app/pull/98) | Denied location permission still shows "Grant Location Permission", which cannot recover the denial. | Network settings | Offer Open Settings after denial, explain why access is useful, and preserve manual configuration. |
| UX007 | P2 | Complete, [PR #98](https://github.com/cedricziel/seer-app/pull/98) | Internal URL settings accept unsupported schemes and hostless addresses, then dismiss as if saved successfully. | Network settings | Accept HTTP/HTTPS with a host; keep actionable validation beside the field and test invalid inputs. |
| UX008 | P2 | Complete, [PR #103](https://github.com/cedricziel/seer-app/pull/103), chat `01a17635-2d2c-7fd0-8d71-b598f1905ec9` | Custom filter and season buttons expose selection only through color. | Library accessibility | Expose the selected trait or value and verify the active choice with VoiceOver. |
| UX009 | P3 | Complete, [PR #113](https://github.com/cedricziel/seer-app/pull/113), chat `01a17732-7688-7ec0-a8ae-3a9ca7ee45a7` | Continue Watching text overlaps Resume at compact width and AX5. | Library layout | Render a long title and subtitle at compact width and AX5. If overlap occurs, reserve button space or stack the content. |
| UX010 | P2 | Complete, [PR #109](https://github.com/cedricziel/seer-app/pull/109), chat `01a176fa-7236-7623-9fd2-0662586b6244` | Download actions can fail silently, while failed rows hide the stored reason. | Downloads | Show enqueue errors immediately and expose an actionable failure reason with Retry. |

## Evidence

- UX001: [OnboardingFlowView](../Features/Auth/OnboardingFlowView.swift),
  [OnboardingViewModel](../Features/Auth/OnboardingViewModel.swift), and
  [QuickConnectView](../Packages/SeerUI/Sources/SeerUI/Onboarding/QuickConnectView.swift).
- UX002: [DiscoverViewModel](../Features/Discover/DiscoverViewModel.swift) tracks
  failed sections, and [DiscoverView](../Features/Discover/DiscoverView.swift)
  offers Retry for total or partial failure. Successful content remains visible
  during refresh, including independently loaded movie and TV genres.
  [PR #105](https://github.com/cedricziel/seer-app/pull/105) merged at `0a9d4d1`.
  Six Discover regressions and 14 service lifecycle tests passed locally;
  required iOS tests and tvOS/macOS builds passed, with independent exact-head
  review and bot approval. The first CI attempt passed 636 tests before a
  simulator host-launch failure; its targeted rerun passed all 111 Library tests.
- UX003 and UX008: [LibraryGridView](../Features/Library/LibraryGridView.swift)
  error state and filter buttons; UX008 also covers
  [series season controls](../Features/Library/MediaDetailView+SeriesSection.swift).
- UX004: [SharedRequestOptionsSheet](../Features/Discover/SharedRequestOptionsSheet.swift)
  and [RequestOptionsSheet](../Features/Search/RequestOptionsSheet.swift) submit
  validation and season-loading state.
- UX005: [RequestsView](../Features/Requests/RequestsView.swift) exposes eligible
  cancellation in request details with confirmation, progress, and inline failure
  feedback and retry. The row menu opens the same flow.
  [PR #108](https://github.com/cedricziel/seer-app/pull/108) merged at `b540dbd`.
  Both isolated UI flow tests passed after the baseline failed on the missing
  action. Required iOS tests and native tvOS/macOS builds passed. An independent
  review of exact head `a5a0f31` found no actionable issues.
- UX006 and UX007: [InternalURLSettingsView](../Features/Servers/InternalURLSettingsView.swift)
  permission controls and save validation.
- UX009: [ContinueWatchingCards](../Features/Library/ContinueWatchingCards.swift)
  caption and Resume overlays. An isolated 320-point iOS 27 render with long text
  confirmed title/subtitle overlap at standard size and subtitle overlap plus
  top clipping at AX5. The baseline ran three UI tests: two failed on three
  overlap assertions; offline disabling passed. With stacked content and a
  content-sized card, all four UI regressions passed, including Resume taps and
  downloaded badge separation. Both fixed screenshots were inspected. Image
  loading, context menus, and live playback are outside this isolated fixture.
  [PR #113](https://github.com/cedricziel/seer-app/pull/113) merged at `50cf0d1`
  on 2026-10-26 after independent exact-head review, lint, iOS tests, and
  iOS/tvOS/macOS archive checks passed.
- UX010: [media detail download actions](../Features/Library/MediaDetailView+Downloads.swift)
  and [DownloadRow](../Features/Downloads/DownloadsView.swift) present action errors.
  Failed rows show the stored reason or a fallback and a visible Retry button.
  [PR #109](https://github.com/cedricziel/seer-app/pull/109) merged at `4e93997`.
  Three feedback tests, 40 isolated offline tests, and three isolated iPhone UI
  tests passed. The baseline failed four missing-reason/Retry assertions across
  two UI tests. Final-head lint, iOS tests, and iOS/tvOS/macOS builds passed;
  independent exact-head review found no issues and the bot review approved.

## Completed or excluded

- Original progress isolation, catalog pagination, and request-cache fixes merged
  in [PR 73](https://github.com/cedricziel/seer-app/pull/73). All 25 selected native
  tests and required CI passed.
- Diagnostics consent findings were stale. [PR 70](https://github.com/cedricziel/seer-app/pull/70)
  already fixed runtime consent and crash-reporting preference changes.
- Unused player controls and the unused tvOS player wrapper were excluded as
  unreachable paths, rather than added as active UX defects.
