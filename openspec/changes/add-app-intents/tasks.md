<!--
TDD discipline (REQUIRED): Tests group MUST come before Implementation.
Implementation tasks cite which test they make pass.
Final task in each group: run `make lint` and `make format`.
-->

## 1. Setup

- [x] 1.1 Confirm `AppIntents.framework` and `Intents.framework` are
  linked to the SeerApp target and to `SeerCore` via `project.yml`
  (system frameworks, no SwiftPM dep needed); regenerate via
  `make generate`. — Both are system frameworks that auto-link via
  Swift `import AppIntents` / `import Intents`. xcodegen handles them
  automatically; no `project.yml` declaration needed for system
  frameworks. Confirmed `SeerApp` and `SeerCore` targets carry no
  `system` framework declarations today; this stays the same.
- [x] 1.2 Add an `appIntentsIndexingEnabled: Bool` flag to `AppState` in
  `Packages/SeerCore/Sources/SeerCore/AppState.swift`. Backed by
  `UserDefaults.standard` only (per-device, NOT mirrored to iCloud KVS
  — see design D5), default `false`. Matches the existing
  `DiagnosticsConsent` pattern. — Added `@Published` with UserDefaults
  `didSet`, key `appIntents.indexingEnabled`, exposed via
  `AppState.AppIntentsKeys.indexingEnabled` so tests can assert
  persistence semantics directly.
- [x] 1.3 Add a new `CachedRequest` SwiftData model under
  `Packages/SeerCore/Sources/SeerCore/Models/` mirroring the Jellyseerr
  request shape used by `RequestsView` (id, title, type, status,
  requestedAt, mediaTmdbId). — Added with composite id
  (`<serverID>:<requestID>`) so two servers don't collide on numeric
  ids. Registered in the existing CloudKit-backed `Schema` in
  `App/SeerApp/SeerApp.swift` alongside the other `Cached*` models;
  matches the existing precedent (`CachedMediaItem` is also
  server-derived and CloudKit-synced).
- [x] 1.4 Register the `flowmark://` URL scheme in `project.yml`'s
  `infoPlist` block: `CFBundleURLTypes` with one entry naming
  `CFBundleURLSchemes = ["flowmark"]` and `CFBundleURLName =
  "com.cedricziel.seer.flowmark"`. Regenerate via `make generate`. —
  Info.plist is hand-managed in this project (`GENERATE_INFOPLIST_FILE:
  false`, `INFOPLIST_FILE: App/SeerApp/Info.plist`), so the
  `CFBundleURLTypes` entry was added directly to
  `App/SeerApp/Info.plist` rather than to a `project.yml` `infoPlist`
  block. No `make generate` needed for plist-only edits.
- [x] 1.5 Run `make generate && make build` to confirm scaffolding
  compiles before adding tests. — `make generate` succeeded after
  bootstrapping `Config/Secrets.xcconfig` from the template (the file
  is not checked in). `make build SIMULATOR="iPhone 17 Pro"` succeeded
  (the default `iPhone 17` simulator is not available on this Xcode
  install — only `iPhone 17 Pro`, `iPhone 17 Pro Max`, `iPhone 17e`,
  `iPhone Air`). Build emits a benign "No AppIntents.framework
  dependency found" warning during metadata extraction; this clears
  once any `AppIntent`-conforming type is added in section 5.


## 2. Tests (red) — SeerCore (AppEntity foundation)

- [x] 2.1 `MediaItemEntityQueryTests.testEntitiesReturnedFromOfflineSync`
  — fixture `OfflineSync` SwiftData store with two `CachedMediaItem`s,
  expect `MediaItemEntityQuery().entities(matching:)` to return both
  (covers Scenario: "Entity query returns library items from offline cache"
  in `app-intents-foundation`). — Implemented in
  `Tests/SeerCoreTests/AppIntents/AppEntityQueryTests.swift` against an
  in-memory ModelContainer injected via `AppIntentsContext`.
- [x] 2.2 `MediaItemEntityQueryTests.testEmptyCacheReturnsEmpty`
  — covers Scenario: "Empty cache returns no results".
- [x] 2.3 `MediaItemEntityQueryTests.testSuggestedEntitiesReturnsRecent`
  — `OfflineSync` with five items, three with recent
  `CachedUserProgress`. Expect `suggestedEntities()` to return the three
  recent ones (covers Scenario: "Siri suggestions surface recent items").
- [x] 2.4 `RequestEntityQueryTests.testEntitiesFromCachedRequests`
  — fixture `CachedRequest` rows, expect query to return matching ones.
- [x] 2.5 `ServerEntityQueryTests.testEntitiesFromConfiguredServers`
  — two `ServerConfiguration` rows, expect both as entities.
- [x] 2.6 `ServerEntityQueryTests.testDefaultsToActiveServer`
  — covers Scenario: "Server entity default is active server".
- [x] 2.7 Run `make lint` and `make format`. — Both clean (0 violations,
  0 files formatted).

## 3. Implementation (green) — SeerCore (AppEntity foundation)

- [x] 3.1 Define `MediaItemEntity` in
  `Packages/SeerCore/Sources/SeerCore/AppIntents/MediaItemEntity.swift`
  conforming to `AppEntity` + `IndexedEntity`. Properties: `id`,
  `title`, `year`, `mediaType`, `posterURL` (display only). — Posters
  not surfaced in v1; spec privacy footer says "title, year, type,
  identifier — no posters". Added `Equatable` conformance for
  `XCTAssertEqual` ergonomics in tests.
- [x] 3.2 Define `MediaItemEntityQuery` reading from the shared
  `OfflineSync` `ModelContext`; implement `entities(matching:)`,
  `entities(for:)`, `suggestedEntities()` (makes 2.1, 2.2, 2.3 pass).
  — `EntityStringQuery` conformance; empty match string returns all
  rows. Falls back to a transient in-memory container when
  `AppIntentsContext.modelContainer` is nil (intent fired before app
  launch finished) so queries never throw on cold-start.
- [x] 3.3 Define `RequestEntity` and `RequestEntityQuery` reading from
  `CachedRequest` (makes 2.4 pass).
- [x] 3.4 Define `ServerEntity` and `ServerEntityQuery` reading from
  `ServerConfiguration`; `defaultResult()` returns `AppState.activeServer`
  (makes 2.5, 2.6 pass). — `SortDescriptor` does not accept `Bool`
  key-paths in SwiftData (Bool is not `Comparable` in Swift), so
  active-first sort is done in-memory after a `lastUsed`/`name`
  database sort.
- [x] 3.5 Run `make lint` and `make format`. — Both clean. Also added
  `AppIntentsContext.modelContainer = modelContainer` to
  `App/SeerApp/SeerApp.swift` so production queries read from the
  same CloudKit-backed store the app uses.

## 4. Tests (red) — SeerCore (verb intents)

- [ ] 4.1 `RequestMediaIntentTests.testRequestsViaJellyseerr`
  with a fake `JellyseerrService` recording the call (covers Scenario:
  "Voice-triggered request reaches Jellyseerr" in `app-intents-actions`).
- [ ] 4.2 `RequestMediaIntentTests.testThrowsNeedsConfigurationWhenSignedOut`
  (covers Scenario: "Intent invoked while signed out").
- [ ] 4.3 `RequestMediaIntentTests.testReturnsAlreadyOwnedSnippetWhenInLibrary`
  with a `CachedMediaItem` matching by tmdbId (covers Scenario:
  "Requesting an already-owned title surfaces the library result").
- [ ] 4.4 `RequestMediaIntentTests.testHonorsServerParameterOverride`
  (covers Scenario: "Server parameter overrides active server").
- [ ] 4.5 `SearchMediaIntentTests.testReturnsLocalCacheHitsFirst`
  (covers Scenario: "Search prefers local library hits").
- [ ] 4.6 `SearchMediaIntentTests.testMergesJellyseerrDiscoveryWhenSparse`
  (covers Scenario: "Search supplements with Jellyseerr discovery when local hits are few").
- [ ] 4.7 `SearchMediaIntentTests.testDeduplicatesByTmdbId`
  (covers Scenario: "Local and discover hits with same TMDB id deduplicate").
- [ ] 4.8 `ResumeWatchingIntentTests.testReturnsMostRecentInProgressItem`
  (covers Scenario: "Resume returns most recent in-progress item").
- [ ] 4.9 `ResumeWatchingIntentTests.testReturnsNothingWhenNoneInProgress`
  (covers Scenario: "Resume with empty Continue Watching list").
- [ ] 4.9a `ResumeWatchingIntentTests.testOpensIntentTargetsFlowmarkMediaURL`
  — asserts the returned `OpensIntent` carries `flowmark://media/<id>`
  for the resolved item, and `flowmark://library` for the empty case
  (covers Scenario: "Resume opens flowmark:// route" in
  `app-intents-foundation`).
- [ ] 4.10 `MarkAsWatchedIntentTests.testCallsJellyfinSetPlayed`
  with a fake `JellyfinService`.
- [ ] 4.11 `DownloadForOfflineIntentTests.testEnqueuesDownloadJob`
  with a fake `DownloadClient`.
- [ ] 4.12 `CheckRequestStatusIntentTests.testReturnsListOfPendingAndReady`
  with fixture `CachedRequest` rows.
- [ ] 4.12a `CheckRequestStatusIntentTests.testReturnsEmptySnippetOnFreshInstall`
  (covers Scenario: "Intent works on a fresh install before the cache
  is populated").
- [ ] 4.12b `RequestsViewModelCacheTests.testUpsertsCachedRequestOnFetch`
  against an in-memory SwiftData container (covers Scenario:
  "Opening Requests tab refreshes the cache").
- [ ] 4.12c `RequestsViewModelCacheTests.testRemovesRowsNoLongerOnServer`
  (covers same scenario, deletion side).
- [ ] 4.12d `RequestsViewModelCacheTests.testCacheWriteFailureDoesNotBreakUI`
  with an injected failing model context (covers Scenario:
  "Cache write failure does not break the UI").
- [ ] 4.13 Run `make lint` and `make format`.

## 5. Implementation (green) — SeerCore (verb intents)

- [ ] 5.1 Implement `IntentError` (LocalizedError + AppIntentError) in
  `Packages/SeerCore/Sources/SeerCore/AppIntents/IntentError.swift` with
  cases `needsConfiguration`, `serverNotReachable`, `notFound`.
- [ ] 5.2 Implement `RequestMediaIntent.perform()`: check
  `appState.isAuthenticated`, dedupe against library cache by tmdbId,
  resolve `ServerEntity` via hybrid rule, call existing
  `JellyseerrService.createRequest` (makes 4.1, 4.2, 4.3, 4.4 pass).
- [ ] 5.3 Implement `SearchMediaIntent.perform()`: query OfflineSync
  cache; if local hits < threshold (3), supplement via Jellyseerr
  discover; merge dedup by tmdbId; return up to 10 (makes 4.5, 4.6, 4.7
  pass).
- [ ] 5.4 Implement `ResumeWatchingIntent.perform()`: read most recent
  `CachedUserProgress` with `playbackPositionTicks > 0`, return
  `OpensIntent` that the app handles via in-process navigation; empty
  case returns "Nothing to resume" snippet (makes 4.8, 4.9 pass).
- [ ] 5.5 Implement `MarkAsWatchedIntent.perform()` calling existing
  `JellyfinService.setPlayed` path (makes 4.10 pass).
- [ ] 5.6 Implement `DownloadForOfflineIntent.perform()` invoking
  `DownloadClient.enqueue` against the `MediaItemEntity` parameter
  (makes 4.11 pass).
- [ ] 5.7 Implement `CheckRequestStatusIntent.perform()` reading
  `CachedRequest` and returning `[RequestEntity]` (makes 4.12 pass).
  When the cache is empty, return the "No cached requests yet" snippet
  (makes 4.12a pass).
- [ ] 5.7a Implement `RequestsViewModel.cacheLiveRequests` extension
  point that upserts `CachedRequest` rows after a successful
  Jellyseerr fetch and deletes rows no longer present (makes 4.12b,
  4.12c pass). Cache write happens after UI render, errors swallowed
  to OS log (makes 4.12d pass).
- [ ] 5.7b Wire the new cache step into `RequestsViewModel.refresh()`
  / `loadInitialData()` so it runs every time the user lands on the
  Requests tab.
- [ ] 5.8 Run `make lint` and `make format`.

## 6. Tests (red) — App target (AppShortcutsProvider + Spotlight)

- [ ] 6.1 `SeerAppShortcutsProviderTests.testRegistersThreeAppShortcuts`
  (covers Scenario: "App Shortcuts surface in Spotlight without setup").
- [ ] 6.2 `SeerAppShortcutsProviderTests.testEachShortcutHasParameterSummary`
  (covers Scenario: "Each App Shortcut has user-readable phrasing").
- [ ] 6.3 `SpotlightIndexerTests.testIndexesWhenFlagEnabled` against a
  fake `CSSearchableIndex` (covers Scenario: "Spotlight indexing
  registers items when enabled" in `app-intents-foundation`).
- [ ] 6.4 `SpotlightIndexerTests.testRemovesIndexWhenFlagDisabled`
  (covers Scenario: "Spotlight indexing removes items when disabled").
- [ ] 6.4a `AppStateTests.testIndexingFlagIsNotMirroredToICloudKVS`
  — writes `appIntentsIndexingEnabled = true`, asserts
  `NSUbiquitousKeyValueStore.default` has no key for it (covers
  Scenario: "Indexing flag does not sync between devices").
- [ ] 6.5 `SpotlightIndexerTests.testReindexesAfterOfflineSyncRefresh`
  (covers Scenario: "Spotlight index updates on library refresh").
- [ ] 6.6 `PrivacySettingsViewSnapshotTests.testIndexingToggle_iPhoneCompact`
  — snapshot covering the new toggle row.
- [ ] 6.7 `FlowmarkURLRouterTests.testRoutesMediaURLToPlayer` against a
  fake navigation coordinator (covers Scenario: "Flowmark media URL
  opens the player for the matching cached item").
- [ ] 6.8 `FlowmarkURLRouterTests.testRoutesLibraryURLToLibraryTab`
  (covers Scenario: "Flowmark library URL opens the Library tab").
- [ ] 6.9 `FlowmarkURLRouterTests.testIgnoresUnknownPath` (covers
  Scenario: "Flowmark URL with unknown path is a no-op").
- [ ] 6.10 Run `make lint` and `make format`.

## 7. Implementation (green) — App target (AppShortcutsProvider + Spotlight)

- [ ] 7.1 Create `App/SeerApp/AppIntents/SeerAppShortcutsProvider.swift`
  registering `RequestMediaIntent`, `SearchMediaIntent`,
  `ResumeWatchingIntent` with phrases and SF Symbols (makes 6.1, 6.2 pass).
- [ ] 7.2 Create `Packages/SeerCore/Sources/SeerCore/AppIntents/SpotlightIndexer.swift`
  using `CSSearchableIndex.default()`. Indexes `CachedMediaItem` rows
  with `CSSearchableItemAttributeSet(itemContentType: kUTTypeMovie /
  kUTTypeTVShow)`. Subscribes to `OfflineSync` refresh notifications
  to re-index (makes 6.3, 6.5 pass).
- [ ] 7.3 Wire `SpotlightIndexer.start/stop` to
  `appState.appIntentsIndexingEnabled` toggle changes; on disable,
  delete the previous batch (makes 6.4 pass).
- [ ] 7.4 Add the indexing toggle to
  `Features/Feedback/PrivacySettingsView.swift` (makes 6.6 pass);
  footer text spells out what is indexed.
- [ ] 7.5 Wire `SeerApp.swift` to start `SpotlightIndexer` on launch
  when authenticated and the flag is on.
- [ ] 7.6 Implement `FlowmarkURLRouter` in `App/SeerApp/AppIntents/`
  parsing `flowmark://media/<id>` and `flowmark://library`; expose a
  `route(_ url: URL)` entry point (makes 6.7, 6.8, 6.9 pass).
- [ ] 7.7 Wire `ContentView.onOpenURL` to dispatch through
  `FlowmarkURLRouter`; route hits update the appropriate
  `@Environment` navigation state (selected tab, presented detail).
- [ ] 7.8 Run `make lint` and `make format`.

## 8. Tests (red) — System integration (Tier 3)

- [ ] 8.1 `SearchMediaIntentSchemaTests.testConformsToMediaSearchSchema`
  — verifies the `@AssistantIntent(schema: .media.search)`
  annotation compiles and the parameter shape matches the schema
  (covers Scenario: "Search intent participates in Apple Intelligence
  semantic search" in `app-intents-system-integration`).
- [ ] 8.2 `INPlayMediaIntentDonationTests.testDonationFiresOnPlaybackStart`
  with a fake `INInteraction` recorder (covers Scenario:
  "Playback start donates to system").
- [ ] 8.3 `INPlayMediaIntentDonationTests.testSkipsDonationForLiveTV`
  (covers Scenario: "Live TV streams do not donate").
- [ ] 8.4 `SeerFocusFilterTests.testActivationPinsActiveServer`
  (covers Scenario: "Focus mode pins active server").
- [ ] 8.5 `SeerFocusFilterTests.testDeactivationRestoresPreviousServer`
  (covers Scenario: "Focus mode deactivation restores previous server").
- [ ] 8.6 Run `make lint` and `make format`.

## 9. Implementation (green) — System integration (Tier 3)

- [ ] 9.1 Annotate `SearchMediaIntent` with
  `@AssistantIntent(schema: .media.search)` (makes 8.1 pass). Verify
  parameter names match the schema.
- [ ] 9.2 Add `INPlayMediaIntent` donation in
  `Packages/PlaybackClient/Sources/PlaybackClient/PlaybackService.swift`
  on the playback start success path; gate on
  `MediaItem.isResumable` (makes 8.2, 8.3 pass).
- [ ] 9.3 Implement `SeerFocusFilter: SetFocusFilterIntent` in
  `App/SeerApp/AppIntents/SeerFocusFilter.swift` with a required
  `ServerEntity` parameter; on activation, push the server onto a
  stack on `AppState`; on deactivation, pop (makes 8.4, 8.5 pass).
- [ ] 9.4 Run `make lint` and `make format`.

## 10. HIG verification

- [ ] 10.1 Verify intent dialog snippets render correctly in the
  Shortcuts app preview pane on iPhone portrait + landscape, AX5
  Dynamic Type, no truncation.
- [ ] 10.2 Verify App Shortcuts surface in Spotlight without setup —
  fresh install, search "request", confirm "Request <title> on Seer"
  appears.
- [ ] 10.3 Verify Action Button assignment — assign "Resume on Seer"
  to the Action Button on a supported device, confirm trigger.
- [ ] 10.4 Verify Focus Filter UI — create a Focus mode, attach the
  Seer filter, choose a server, confirm pinning behavior.
- [ ] 10.5 Verify privacy toggle behavior — toggle on, confirm Spotlight
  starts surfacing media titles within ~30s; toggle off, confirm titles
  removed within ~30s.
- [ ] 10.6 Verify VoiceOver: dialog snippets read as combined elements;
  privacy toggle reads label + footer-derived hint.
- [ ] 10.7 Verify Reduce Transparency: snippet backgrounds are solid.
- [ ] 10.8 Verify Smart Invert: any SF Symbols in snippets that carry
  brand color use `.accessibilityIgnoresInvertColors(true)`.
- [ ] 10.9 Run `make lint` and `make format`.

## 11. Refactor (optional)

- [ ] 11.1 Extract a shared `IntentServiceFactory` if duplication
  emerges between intents constructing `JellyfinService` /
  `JellyseerrService`.
- [ ] 11.2 Consider promoting the multi-server hybrid resolution logic
  to a `ServerResolver` helper if more than three intents reuse it.
