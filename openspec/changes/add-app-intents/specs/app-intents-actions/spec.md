## ADDED Requirements

### Requirement: RequestMediaIntent submits to Jellyseerr

The system SHALL provide a `RequestMediaIntent` accepting a title
string parameter, an optional media-type parameter (movie / show), and
an optional `ServerEntity` parameter. When invoked while the user is
authenticated, the intent MUST call the existing
`JellyseerrService.createRequest` path against the resolved server,
returning a result snippet describing the outcome (created, pending
admin approval, or already in library). The intent MUST NOT bypass
the authenticated user's Jellyseerr permissions.

#### Scenario: Voice-triggered request reaches Jellyseerr

- **WHEN** the user on iPhone says "Hey Siri, request The Bear on
  Seer" with Jellyseerr configured and auto-approval enabled for their
  account
- **THEN** the intent MUST call `JellyseerrService.createRequest` with
  the matched media's external identifier, MUST surface a result
  snippet "Requested The Bear", and MUST NOT open the app

#### Scenario: Intent invoked while signed out

- **WHEN** the user on iPhone invokes any verb intent and
  `appState.isAuthenticated` is `false`
- **THEN** the intent MUST throw `IntentError.needsConfiguration`,
  causing the system to surface a "Set up Seer to use this shortcut"
  message with an "Open Seer" affordance

#### Scenario: Requesting an already-owned title surfaces the library result

- **WHEN** the user on iPhone says "Request The Bear on Seer" and
  `OfflineSync` cache contains a `CachedMediaItem` whose `tmdbId`
  matches the discovered title
- **THEN** the intent MUST NOT call Jellyseerr, MUST return a result
  snippet "You already have The Bear in your library", and MUST offer
  a "Resume" affordance routed to `ResumeWatchingIntent` for that item

#### Scenario: Server parameter overrides active server

- **WHEN** the user on iPhone has two configured Jellyseerr servers
  with the second marked active, and runs a Shortcut wired to
  `RequestMediaIntent` with the first server explicitly chosen as the
  `ServerEntity` parameter
- **THEN** the intent MUST issue the request against the first server,
  not the active server

### Requirement: SearchMediaIntent prefers local cache, supplements with Jellyseerr

The system SHALL provide a `SearchMediaIntent` returning up to 10
`MediaItemEntity` values for a query string. The intent MUST query
the `OfflineSync` cache first; if local matches number fewer than 3
AND the device has network reachability AND a Jellyseerr server is
configured, the intent MUST also issue a Jellyseerr discover query
and merge results, deduplicating by TMDB id. Library hits MUST sort
before discovery hits in the merged list.

#### Scenario: Search prefers local library hits

- **WHEN** the user on iPhone says "Search Seer for Dune" and the
  `OfflineSync` cache contains 5 matches
- **THEN** the intent MUST return only the 5 local matches and MUST
  NOT issue a Jellyseerr query

#### Scenario: Search supplements with Jellyseerr discovery when local hits are few

- **WHEN** the user on iPhone says "Search Seer for Dune" with one
  local cache hit and Jellyseerr configured
- **THEN** the intent MUST issue a discover query, MUST merge the
  results, MUST place the local hit first, and MUST return up to 10
  total entities

#### Scenario: Local and discover hits with same TMDB id deduplicate

- **WHEN** the merged result set contains a local hit and a discover
  hit with the same `tmdbId`
- **THEN** the deduplicated result MUST contain a single entity for
  that TMDB id, sourced from the local cache (the one with library
  state)

### Requirement: ResumeWatchingIntent opens to the most recent in-progress item

The system SHALL provide a parameter-less `ResumeWatchingIntent` that
resolves the most recent `CachedUserProgress` row with
`playbackPositionTicks > 0`, identifies the corresponding
`CachedMediaItem`, and returns an `OpensIntent` directing the app to
the player view for that item. When no in-progress item exists, the
intent MUST NOT throw; it MUST return a result snippet "Nothing to
resume yet" and open the Library tab.

#### Scenario: Resume returns most recent in-progress item

- **WHEN** the user on iPhone says "Hey Siri, resume on Seer" and
  `CachedUserProgress` contains three rows with `playbackPositionTicks
  > 0`
- **THEN** the intent MUST resolve the row with the most recent
  `lastPlayedAt`, MUST surface a result snippet naming that item, and
  MUST open the app to the player for that item

#### Scenario: Resume with empty Continue Watching list

- **WHEN** the user on iPhone says "Resume on Seer" and
  `CachedUserProgress` contains zero rows with progress
- **THEN** the intent MUST return a result snippet "Nothing to resume
  yet", MUST open the app to the Library tab, and MUST NOT throw

### Requirement: MarkAsWatchedIntent toggles play state

The system SHALL provide a `MarkAsWatchedIntent` accepting a
`MediaItemEntity` parameter and an optional boolean `watched` parameter
defaulting to `true`. The intent MUST call the same Jellyfin set-played
path that `LibraryViewModel.markAsWatched` uses today, against the
server hosting the entity.

#### Scenario: Mark as watched calls Jellyfin

- **WHEN** the user on iPhone runs a Shortcut invoking
  `MarkAsWatchedIntent` for an in-library item
- **THEN** the intent MUST call `JellyfinService.setPlayed(itemId:)`
  for the entity's id, MUST update the corresponding
  `CachedUserProgress` row, and MUST return a result snippet "Marked
  watched"

### Requirement: DownloadForOfflineIntent enqueues a download job

The system SHALL provide a `DownloadForOfflineIntent` accepting a
required `MediaItemEntity` parameter. The intent MUST invoke
`DownloadClient.enqueue` with the same options the
`MediaDetailView+Downloads` UI uses, returning a result snippet
indicating that the download is queued.

#### Scenario: Download enqueues via DownloadClient

- **WHEN** the user on iPhone runs a Shortcut "Download <title> for
  offline"
- **THEN** the intent MUST call `DownloadClient.enqueue` with the
  entity's id and MUST surface a "Download started" result snippet

### Requirement: CheckRequestStatusIntent returns request entities

The system SHALL provide a parameter-less `CheckRequestStatusIntent`
returning `[RequestEntity]` of the user's pending and recently
fulfilled requests, sourced from the `CachedRequest` SwiftData store.

#### Scenario: Status intent returns cached requests

- **WHEN** the user on iPhone runs a Shortcut "Check my Seer requests"
  and `CachedRequest` contains rows
- **THEN** the intent MUST return matching `RequestEntity` values
  ordered by `requestedAt` descending, with status fields populated

### Requirement: RequestsViewModel populates the CachedRequest store

The system SHALL upsert into `CachedRequest` from
`RequestsViewModel` on every successful fetch from Jellyseerr,
mapping each live `MediaRequest` to a `CachedRequest` row keyed by
`<serverConfigurationID>:<requestID>`. Rows for requests that no
longer appear in the server's response MUST be deleted in the same
transaction so the cache cannot grow stale-positive. Cache writes
MUST NOT block the UI render of the Requests tab — the upsert
happens after the live data is presented.

#### Scenario: Opening Requests tab refreshes the cache

- **WHEN** the user on iPhone opens the Requests tab and
  `RequestsViewModel` completes a successful fetch returning N rows
- **THEN** the `CachedRequest` store MUST contain exactly N rows
  scoped to the active server's id within the same async context,
  with rows for any previously-cached requests that are no longer
  in the live response removed

#### Scenario: Cache write failure does not break the UI

- **WHEN** the user on iPhone opens the Requests tab and the
  `CachedRequest` upsert throws (e.g., SwiftData write error)
- **THEN** the Requests tab MUST still render the live response,
  the error MUST be logged to the OS log subsystem, and a
  subsequent intent invocation MUST gracefully return whatever
  rows happen to be in the cache (possibly empty, possibly stale)

#### Scenario: Intent works on a fresh install before the cache is populated

- **WHEN** the user on iPhone invokes `CheckRequestStatusIntent` and
  has never opened the Requests tab on this device since signing in
- **THEN** the intent MUST return an empty array, MUST surface a
  result snippet "No cached requests yet — open Seer's Requests tab
  to populate", and MUST NOT throw
