## ADDED Requirements

### Requirement: AppEntity types for media, requests, and servers

The system SHALL define `AppEntity` types in `SeerCore` representing
the user's media library items, Jellyseerr requests, and configured
servers. `MediaItemEntity` and `RequestEntity` MUST conform to
`IndexedEntity` so that the system can semantic-index them when
indexing is enabled. Every entity MUST expose a stable identifier
suitable for cross-process resolution.

#### Scenario: Entity query returns library items from offline cache

- **WHEN** the system on iPhone invokes `MediaItemEntityQuery.entities-
  (matching:)` with a string query and the user has
  `OfflineSync` cached items matching that query
- **THEN** the query MUST return matching `MediaItemEntity` values
  sourced from the SwiftData cache without making any network call

#### Scenario: Empty cache returns no results

- **WHEN** the system on iPhone invokes any entity query and the
  `OfflineSync` cache contains no rows
- **THEN** the query MUST return an empty array, MUST NOT throw, and
  MUST NOT contact the network

#### Scenario: Siri suggestions surface recent items

- **WHEN** the system on iPhone requests `MediaItemEntityQuery.suggested-
  Entities()` to populate Siri suggestions or shortcut auto-fill
- **THEN** the query MUST return up to 10 recently accessed items, ordered
  by `CachedUserProgress.lastPlayedAt` descending, falling back to
  recently added library items if no progress is recorded

### Requirement: Multi-server entity resolution defaults to active server

The system SHALL expose `ServerEntity` values for every configured
`ServerConfiguration`. `ServerEntityQuery.defaultResult()` MUST return
the currently active server. When only one server is configured, the
default MUST be that server.

#### Scenario: Server entity default is active server

- **WHEN** the system on iPhone resolves an intent's optional
  `ServerEntity` parameter without an explicit user-supplied value, and
  the user has two `ServerConfiguration` rows with the second marked
  active
- **THEN** the resolved `ServerEntity` MUST correspond to the active
  server's id

#### Scenario: Single configured server resolves implicitly

- **WHEN** the system on iPhone resolves a `ServerEntity` parameter and
  the user has exactly one `ServerConfiguration`
- **THEN** the resolved entity MUST be that server with no
  disambiguation prompt

### Requirement: AppShortcutsProvider registers Tier 1 intents

The system SHALL register exactly three App Shortcuts at the app level
through a `SeerAppShortcutsProvider` defined in the SeerApp target:
`RequestMediaIntent`, `SearchMediaIntent`, and `ResumeWatchingIntent`.
Each App Shortcut MUST provide an `AppShortcutPhrase` set referring to
the application by the literal string `Seer`, an SF Symbol icon, and a
parameter summary that reads naturally in the user's locale.

#### Scenario: App Shortcuts surface in Spotlight without setup

- **WHEN** the user on iPhone with a freshly installed and signed-in
  Seer types `request` into Spotlight
- **THEN** Spotlight MUST surface the "Request <title> on Seer"
  shortcut without requiring the user to have opened or configured
  Shortcuts.app

#### Scenario: Each App Shortcut has user-readable phrasing

- **WHEN** the user on iPhone inspects the registered App Shortcuts via
  the Shortcuts app or Settings → Siri & Search
- **THEN** each of the three shortcuts MUST display a title, a
  subtitle, an SF Symbol, and at least one example invocation phrase

### Requirement: flowmark:// URL scheme registration and routing

The system SHALL register the `flowmark://` URL scheme in the app's
`Info.plist` (via `project.yml`'s `infoPlist` block) under a
`CFBundleURLTypes` entry. The scheme MUST be the user-facing brand
"Flowmark", not the engineering bundle name "Seer". The system SHALL
provide a `FlowmarkURLRouter` that parses incoming URLs and routes
them to navigation state without the originating intent needing to
know how the app's navigation is structured.

Routes defined under this change:

- `flowmark://media/<id>` — open the player or detail view for the
  given cached `MediaItem.id` on the active server.
- `flowmark://library` — open the Library tab.

#### Scenario: Flowmark media URL opens the player for the matching cached item

- **WHEN** the system on iPhone dispatches a URL `flowmark://media/abc-123`
  to `ContentView.onOpenURL` and `OfflineSync` cache contains a
  `CachedMediaItem` with that id
- **THEN** `FlowmarkURLRouter` MUST navigate the app to that item's
  detail or player view on the active server, without requiring any
  network round-trip to verify the item

#### Scenario: Flowmark library URL opens the Library tab

- **WHEN** the system on iPhone dispatches `flowmark://library`
- **THEN** `FlowmarkURLRouter` MUST switch the main tab view's
  selection to the Library tab

#### Scenario: Flowmark URL with unknown path is a no-op

- **WHEN** the system on iPhone dispatches a URL with the
  `flowmark://` scheme and a path component this version does not
  recognise (e.g. `flowmark://requests/42` before that route exists)
- **THEN** `FlowmarkURLRouter` MUST log the unknown route to the OS
  log subsystem, MUST NOT throw, and MUST NOT change navigation state

#### Scenario: Resume opens flowmark:// route

- **WHEN** `ResumeWatchingIntent.perform()` resolves an in-progress
  item with `MediaItem.id == "abc-123"`
- **THEN** the returned `OpensIntent` MUST carry the URL
  `flowmark://media/abc-123`; for the empty case, the URL MUST be
  `flowmark://library`

### Requirement: Spotlight semantic indexing is opt-in and per-device

The system SHALL gate Spotlight semantic indexing of `MediaItemEntity`
behind an `appIntentsIndexingEnabled` flag on `AppState`, defaulting to
`false`. The flag MUST be persisted in `UserDefaults.standard` only
and MUST NOT be mirrored to iCloud key-value storage; each device
holds its own value, matching the inherently device-local nature of
`CSSearchableIndex` and the existing `DiagnosticsConsent` precedent.
When the flag is `false`, NO `MediaItemEntity` MUST be registered
with `CSSearchableIndex` and any previously registered items MUST be
removed. The flag MUST be exposed in
`Features/Feedback/PrivacySettingsView` with footer text describing
exactly what is indexed (title, year, type, identifier — no posters,
no plot, no watched state) AND noting that the choice applies only
to this device.

#### Scenario: Spotlight indexing registers items when enabled

- **WHEN** the user on iPhone enables the privacy setting and the
  `OfflineSync` cache contains 50 items
- **THEN** the system MUST register a `CSSearchableIndex` transaction
  with all 50 items within 30 seconds, each item carrying only title,
  year, mediaType, and identifier in its `CSSearchableItemAttributeSet`

#### Scenario: Spotlight indexing removes items when disabled

- **WHEN** the user on iPhone disables the privacy setting after
  having previously enabled it
- **THEN** the system MUST issue a `deleteAllSearchableItems` call to
  remove every previously registered item from the index, completing
  within 30 seconds

#### Scenario: Spotlight index updates on library refresh

- **WHEN** the user on iPhone has indexing enabled and `OfflineSync`
  completes a refresh that adds, removes, or modifies cached items
- **THEN** the system MUST re-index by replacing the previous batch with
  the current cached set without manual user action

#### Scenario: Indexing flag does not sync between devices

- **WHEN** the user on iPhone enables `appIntentsIndexingEnabled` and
  also has Seer signed in on iPad with the same iCloud account
- **THEN** the iPad's `appIntentsIndexingEnabled` flag MUST remain at
  whatever value that device last set it to (defaulting to `false`),
  AND no Spotlight items MUST be registered on the iPad until the
  user enables the flag separately on that device
